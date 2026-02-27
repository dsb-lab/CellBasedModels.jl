using BenchmarkTools
using CellBasedModels
using CUDA
using CairoMakie

# Neighbors
model = AgentPoint(
    3,
    (
        b = Integer,
        b_consistency = Integer
    ),
)

@addRule model=model function neighbors_check!(uNew, u, p, t)
    @kernel_launch ndrange=length(uNew.n.b) function neighbors_check_kernel!(uNew, u, p, t)
        i = @index(Global)
        x_i = u.n.x[i]
        y_i = u.n.y[i]
        z_i = u.n.z[i]
        for j in iterateOverNeighbors(u.n, x_i, y_i, z_i)
            if j == i
                continue
            end
            x_j = u.n.x[j]
            y_j = u.n.y[j]
            z_j = u.n.z[j]
            if sqrt((x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2) < 1.8
                uNew.n.b[i] += 1
            end
        end
    end
end

# Store timings: Dict of (algorithm_name, backend_name) => (sizes, times)
timings = Dict{Tuple{String, String}, Tuple{Vector{Int}, Vector{Float64}}}()

sizes_list = [round(Int, i^(1/3)) for i in [10, 10^2, 10^3, 10^4, 10^5, 10^6]]  # Cubic root to get size per dimension

for algType in [:NeighborsFull, :NeighborsCellLinked, :NeighborsHash]
    alg_name = string(algType)
    println("Algorithm: ", alg_name)
    
    for backend in backends
        backend_name = string(typeof(backend).name.name)
        
        println("  Backend: ", backend_name)
        
        sizes = Int[]
        times = Float64[]
        
        for size in sizes_list
            N = size^3
            println("    N: ", N)
            
            # Create neighbor algorithm with box matching particle domain
            neighborAlg = if algType == :NeighborsFull
                NeighborsFull()
            elseif algType == :NeighborsCellLinked
                NeighborsCellLinked(box=[0 size; 0 size; 0 size], cellSize=1.0)
            else  # NeighborsHash
                NeighborsHash(cellSize=1.0)
            end
            
            obj = createObject(model, n=(N, N), neighbors=neighborAlg)
            obj.n.x .= vec([x for x in 0.5:1:size-0.5, y in 0.5:1:size-0.5, z in 0.5:1:size-0.5])
            obj.n.y .= vec([y for x in 0.5:1:size-0.5, y in 0.5:1:size-0.5, z in 0.5:1:size-0.5])
            obj.n.z .= vec([z for x in 0.5:1:size-0.5, y in 0.5:1:size-0.5, z in 0.5:1:size-0.5])
            
            obj_gpu = toBackend(obj, backend)
            problem = CBProblem(model, obj_gpu)
            integrator = init(problem, dt=0.1)
            
            # Warmup with timeout check
            warmup_start = time()
            step!(integrator)
            warmup_time = time() - warmup_start
            
            # Skip if warmup already took > 10 seconds (would take too long to benchmark)
            if warmup_time > 10.0
                println("      Skipping remaining sizes (warmup took $(round(warmup_time, digits=1))s)")
                break
            end
            
            # Benchmark with timeout: if warmup suggests > 60s total, limit samples
            max_samples = warmup_time > 1.0 ? 3 : 10
            b = @benchmark step!($integrator) samples=max_samples evals=1 seconds=60
            median_time = median(b.times) / 1e9  # Convert ns to seconds
            
            push!(sizes, N)
            push!(times, median_time)
            
            println("      Time: ", round(median_time * 1000, digits=3), " ms")
        end
        
        timings[(alg_name, backend_name)] = (sizes, times)
    end
end

# Create scaling plot with CairoMakie
fig = Figure(size=(800, 600))
ax = Axis(fig[1, 1],
    title="Neighbor Algorithm Scaling",
    xlabel="Number of Particles (N)",
    ylabel="Time per step (s)",
    xscale=log10,
    yscale=log10
)

# Define markers and colors for different combinations
# Markers by algorithm
algorithm_markers = Dict(
    "NeighborsFull" => :circle,
    "NeighborsCellLinked" => :rect,
    "NeighborsHash" => :diamond,
)

# Colors by backend (blues for CPU, oranges/reds for GPU)
backend_colors = Dict(
    "CPU" => [:steelblue, :royalblue, :dodgerblue],       # Blue range for CPU
    "CUDABackend" => [:orangered, :darkorange, :coral],    # Orange/red range for GPU
)

# Track algorithm index per backend for color selection
alg_indices = Dict{String, Int}()

for (key, (sizes, times)) in timings
    alg_name, backend_name = key
    
    # Get marker based on algorithm
    marker = get(algorithm_markers, alg_name, :star5)
    
    # Get color based on backend and algorithm index
    if !haskey(alg_indices, backend_name)
        alg_indices[backend_name] = 0
    end
    alg_indices[backend_name] += 1
    alg_idx = alg_indices[backend_name]
    
    colors = get(backend_colors, backend_name, [:gray, :darkgray, :lightgray])
    color = colors[mod1(alg_idx, length(colors))]
    
    label = "$alg_name - $backend_name"
    
    scatterlines!(ax, sizes, times, 
        marker=marker,
        color=color,
        linewidth=2,
        markersize=10,
        label=label
    )
end

# Add reference scaling lines
N_ref = [minimum(first(first(values(timings)))), maximum(first(first(values(timings))))]
t_ref_start = minimum([minimum(t) for (s, t) in values(timings)]) * 0.5

# O(N) scaling
lines!(ax, N_ref, t_ref_start .* (N_ref ./ N_ref[1]), 
    linestyle=:dash, color=:gray, linewidth=1, label="O(N)")

# O(N²) scaling  
lines!(ax, N_ref, t_ref_start .* (N_ref ./ N_ref[1]).^2, 
    linestyle=:dot, color=:gray, linewidth=1, label="O(N²)")

axislegend(ax, position=:lt)

mkpath("benchmarkings")
save("benchmarkings/neighbor_algorithm_scaling.pdf", fig)

println("\nPlot saved to benchmarkings/neighbor_algorithm_scaling.pdf")

# # Neighbors periodic
# model = AgentPoint(
#     3,
#     (
#         b = Integer,
#         b_consistency = Integer
#     ),
# )

# @addRule model=model function neighbors_check_periodic!(uNew, u, p, t)
#     @kernel_launch ndrange=length(uNew.n.b) function neighbors_check_periodic_kernel!(uNew, u, p, t)
#         i = @index(Global)
#         x_i = u.n.x[i]
#         y_i = u.n.y[i]
#         z_i = u.n.z[i]
#         for j in iterateOverNeighbors(u, :n, x_i, y_i, z_i)
#             if j == i
#                 continue
#             end
#             x_j = u.n.x[j]
#             y_j = u.n.y[j]
#             z_j = u.n.z[j]
#             x_j = posRelPeriodicBoundary(x_j, x_i, 0, 10.0)
#             y_j = posRelPeriodicBoundary(y_j, y_i, 0, 10.0)
#             z_j = posRelPeriodicBoundary(z_j, z_i, 0, 10.0)
#             if sqrt((x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2) < 1.8
#                 uNew.n.b[i] += 1
#             end
#         end
#         for j in 1:length(uNew.n.b)
#             if j == i
#                 continue
#             end
#             x_j = u.n.x[j]
#             y_j = u.n.y[j]
#             z_j = u.n.z[j]
#             x_j = posRelPeriodicBoundary(x_j, x_i, 0, 10.0)
#             y_j = posRelPeriodicBoundary(y_j, y_i, 0, 10.0)
#             z_j = posRelPeriodicBoundary(z_j, z_i, 0, 10.0)
#             if sqrt((x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2) < 1.8
#                 uNew.n.b_consistency[i] += 1
#             end
#         end
#     end
# end

# for neighborAlg in [
#         NeighborsFull(), 
#         NeighborsCellLinked(box=[0 10; 0 10; 0 10], cellSize=1.0, periodic=true)
#     ]
#     for backend in backends
#         obj = createObject(model, n=(10^3, 10000), neighbors=neighborAlg)
#         obj.n.x .= vec([x for x in 0.5:1:9.5, y in 0.5:1:9.5, z in 0.5:1:9.5])
#         obj.n.y .= vec([y for x in 0.5:1:9.5, y in 0.5:1:9.5, z in 0.5:1:9.5])
#         obj.n.z .= vec([z for x in 0.5:1:9.5, y in 0.5:1:9.5, z in 0.5:1:9.5])
#         obj_gpu = toBackend(obj, backend)
#         problem = CBProblem(
#             model,
#             obj_gpu
#         )
#         integrator = init(problem, dt=0.1)
#         step!(integrator)
#         @test all(toBackend(integrator.u, CPU()).n.b .== 26)
#         @test all(toBackend(integrator.u, CPU()).n.b .== toBackend(integrator.u, CPU()).n.b_consistency)
#     end
# end
