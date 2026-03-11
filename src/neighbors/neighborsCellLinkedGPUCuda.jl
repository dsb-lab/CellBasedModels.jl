import CellBasedModels: assignCell!, countInCell!, fillPermTable!, platform, toBackend, update!
import CellBasedModels: positionToLinear1D, positionToLinear2D, positionToLinear3D

# toBackend for NeighborsCellLinked - converts CPU to GPU
function toBackend(neighbors::NeighborsCellLinked{D, P, UM, B, CS, G, C, CO, Per}, backend::CUDA.CUDABackend) where {D, P<:CPU, UM, B, CS, G, C, CO, Per}
    box_gpu = neighbors.box === nothing ? nothing : CUDA.CuArray(neighbors.box)
    cell_gpu = neighbors.cell === nothing ? nothing : CUDA.CuArray(neighbors.cell)
    cellOffset_gpu = neighbors.cellOffset === nothing ? nothing : CUDA.CuArray(neighbors.cellOffset)
    cellCounts_gpu = neighbors.cellCounts === nothing ? nothing : CUDA.CuArray(neighbors.cellCounts)
    permTable_gpu = neighbors.permTable === nothing ? nothing : CUDA.CuArray(neighbors.permTable)
    
    return NeighborsCellLinked{
        D, GPUCuda,
        Nothing,  # No mesh reference at field level
        typeof(box_gpu), CS, G,
        typeof(cell_gpu), typeof(cellOffset_gpu),
        Per,
    }(
        nothing,  # u
        box_gpu,
        neighbors.cellSize,
        neighbors.grid,
        cell_gpu,
        cellOffset_gpu,
        cellCounts_gpu,
        permTable_gpu,
        neighbors.periodic,
    )
end

# Already on GPU - no conversion needed
toBackend(neighbors::NeighborsCellLinked{D, P}, ::CUDA.CUDABackend) where {D, P<:GPUCuda} = neighbors

# toBackend for NeighborsCellLinked - converts GPU back to CPU
function toBackend(neighbors::NeighborsCellLinked{D, P, UM, B, CS, G, C, CO, Per}, ::CPU) where {D, P<:GPU, UM, B, CS, G, C, CO, Per}
    box_cpu = neighbors.box === nothing ? nothing : Array(neighbors.box)
    cell_cpu = neighbors.cell === nothing ? nothing : Array(neighbors.cell)
    cellOffset_cpu = neighbors.cellOffset === nothing ? nothing : Array(neighbors.cellOffset)
    cellCounts_cpu = neighbors.cellCounts === nothing ? nothing : Array(neighbors.cellCounts)
    permTable_cpu = neighbors.permTable === nothing ? nothing : Array(neighbors.permTable)
    
    return NeighborsCellLinked{
        D, CPU,
        Nothing,
        typeof(box_cpu), CS, G,
        typeof(cell_cpu), typeof(cellOffset_cpu),
        Per,
    }(
        nothing,
        box_cpu,
        neighbors.cellSize,
        neighbors.grid,
        cell_cpu,
        cellOffset_cpu,
        cellCounts_cpu,
        permTable_cpu,
        neighbors.periodic,
    )
end

# Already on CPU - no conversion needed
toBackend(neighbors::NeighborsCellLinked{D, P}, ::CPU) where {D, P<:CPU} = neighbors

function initNeighborsGPU(
        dims, 
        neighbors::NeighborsCellLinked,
        meshParameters::NamedTuple
    )

    D = dims
    P = platform()

    if dims < 1 || dims > 3
        error("NeighborsCellLinked only supports 1D, 2D, or 3D. Found dims=$dims")
    end

    if size(neighbors.box) != (D, 2)
        error("Box size mismatch. Expected size ($(D), 2), found size $(size(neighbors.box))")
    end
    box = neighbors.box

    cellSize = neighbors.cellSize
    if cellSize isa Number
        # Scalar cellSize: replicate for all dimensions
        cellSize = fill(cellSize, D)
    elseif cellSize isa Tuple
        # Tuple cellSize: convert to vector and check length
        cellSize = collect(cellSize)
        if length(cellSize) != D
            error("Cell size mismatch. Expected length $(D), found length $(length(cellSize))")
        end
    elseif cellSize isa AbstractVector
        # Vector cellSize: check length
        if length(cellSize) != D
            error("Cell size mismatch. Expected length $(D), found length $(length(cellSize))")        
        end
    else
        error("Cell size must be a Number, Tuple, or Vector. Found type $(typeof(cellSize))")
    end
    cellSize = Tuple(cellSize)

    # Calculate grid size: no padding for periodic dimensions, padding for non-periodic
    grid = round.(Int, (box[:,2] - box[:,1]) ./ cellSize)
    gridTuple = ntuple(i -> grid[i], D)  # Convert to NTuple for assignCell! compatibility
    gridSize = prod(grid)  # Total number of cells

    box = CUDA.cu(box)

    permTable = Dict()
    cell = Dict()
    cellOffset = Dict()
    cellCounts = Dict()  # Per-thread workspace arrays
    
    for (name, prop) in pairs(meshParameters)
        permTable[name] = CUDA.zeros(Int, lengthCache(prop))
        cell[name] = CUDA.zeros(Int, lengthCache(prop))
        cellOffset[name] = CUDA.zeros(Int, gridSize+1)
        cellCounts[name] = CUDA.zeros(Int, gridSize+1)
    end

    permTableNamed = NamedTuple{tuple(keys(permTable)...)}(values(permTable))
    cellNamed = NamedTuple{tuple(keys(cell)...)}(values(cell))
    cellOffsetNamed = NamedTuple{tuple(keys(cellOffset)...)}(values(cellOffset))
    cellCountsNamed = NamedTuple{tuple(keys(cellCounts)...)}(values(cellCounts))

    NeighborsCellLinked{
        D, GPUCuda, 
        typeof(meshParameters), 
        typeof(box), typeof(cellSize), typeof(gridTuple), 
        typeof(cellNamed), typeof(cellOffsetNamed),
        typeof(neighbors.periodic),
    }(meshParameters, box, cellSize, gridTuple, cellNamed, cellOffsetNamed, cellCountsNamed, permTableNamed, neighbors.periodic)

end

# GPU kernel for cell assignment - we need to dispatch on the assignCell! function
function assignCell!(cellArray, N, prop, neighbors::NeighborsCellLinked{1, GPUCuda})
    x = prop.x
    cell = cellArray
    periodic = neighbors.periodic
    
    function kernel(cell, x, N, box, cellSize, grid, periodic)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            @inbounds begin
                xi = x[i]
                # Wrap position for periodic boundaries
                if periodic
                    boxLen = box[1, 2] - box[1, 1]
                    xi = box[1, 1] + mod(xi - box[1, 1], boxLen)
                end
                cell[i] = positionToLinear1D(xi, box, cellSize, grid)
            end
        end
        return nothing
    end
    
    threads_per_block = 256
    blocks = div(N + threads_per_block - 1, threads_per_block)
    
    CUDA.@cuda threads=threads_per_block blocks=blocks kernel(cell, x, N, neighbors.box, neighbors.cellSize, neighbors.grid, periodic)
    CUDA.synchronize()
end

function assignCell!(cellArray, N, prop, neighbors::NeighborsCellLinked{2, GPUCuda})
    x = prop.x
    y = prop.y
    cell = cellArray
    periodic = neighbors.periodic
    
    function kernel(cell, x, y, N, box, cellSize, grid, periodic)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            @inbounds begin
                xi, yi = x[i], y[i]
                # Wrap positions for periodic boundaries
                if periodic
                    boxLenX = box[1, 2] - box[1, 1]
                    boxLenY = box[2, 2] - box[2, 1]
                    xi = box[1, 1] + mod(xi - box[1, 1], boxLenX)
                    yi = box[2, 1] + mod(yi - box[2, 1], boxLenY)
                end
                cell[i] = positionToLinear2D(xi, yi, box, cellSize, grid)
            end
        end
        return nothing
    end
    
    threads_per_block = 256
    blocks = div(N + threads_per_block - 1, threads_per_block)
    
    CUDA.@cuda threads=threads_per_block blocks=blocks kernel(cell, x, y, N, neighbors.box, neighbors.cellSize, neighbors.grid, periodic)
    CUDA.synchronize()
end

function assignCell!(cellArray, N, prop, neighbors::NeighborsCellLinked{3, GPUCuda})
    x = prop.x
    y = prop.y
    z = prop.z
    cell = cellArray
    periodic = neighbors.periodic
    
    function kernel(cell, x, y, z, N, box, cellSize, grid, periodic)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            @inbounds begin
                xi, yi, zi = x[i], y[i], z[i]
                # Wrap positions for periodic boundaries
                if periodic
                    boxLenX = box[1, 2] - box[1, 1]
                    boxLenY = box[2, 2] - box[2, 1]
                    boxLenZ = box[3, 2] - box[3, 1]
                    xi = box[1, 1] + mod(xi - box[1, 1], boxLenX)
                    yi = box[2, 1] + mod(yi - box[2, 1], boxLenY)
                    zi = box[3, 1] + mod(zi - box[3, 1], boxLenZ)
                end
                cell[i] = positionToLinear3D(xi, yi, zi, box, cellSize, grid)
            end
        end
        return nothing
    end
    
    threads_per_block = 256
    blocks = div(N + threads_per_block - 1, threads_per_block)
    
    CUDA.@cuda threads=threads_per_block blocks=blocks kernel(cell, x, y, z, N, neighbors.box, neighbors.cellSize, neighbors.grid, periodic)
    CUDA.synchronize()
end

# GPU-optimized cell counting using CUDA reductions
function countInCell!(cellOffset::CUDA.CuArray, N, cell::CUDA.CuArray)    

    # Clear workspace
    cellOffset .= 0
    
    # Count particles per cell using atomic operations
    function count_kernel(cell, cellOffset, N)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            cellIdx = cell[i]
            CUDA.@atomic cellOffset[cellIdx+1] += 1
        end
        return nothing
    end

    threads_per_block = 256
    blocks = div(N + threads_per_block - 1, threads_per_block)

    CUDA.@cuda threads=threads_per_block blocks=blocks count_kernel(cell, cellOffset, N)
    CUDA.synchronize()

    cellOffset .= cumsum(cellOffset)
    
    return nothing
end

function fillPermTable!(permTable::CUDA.CuArray, cellOffset::CUDA.CuArray,
                        cell::CUDA.CuArray, N, cellCounts)

    cellCounts .= 0

    function fill_permtable_kernel(permTable, cell, cellOffset, N, cellCounts)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            cellIdx = cell[i]
            p = CUDA.@atomic cellCounts[cellIdx] += 1
            pos = cellOffset[cellIdx] + p + 1
            permTable[pos] = i
        end
        return
    end

    threads = 256
    blocks  = cld(N, threads)

    CUDA.@cuda threads=threads blocks=blocks fill_permtable_kernel(
        permTable, cell, cellOffset, N, cellCounts)

    return nothing
end

# GPU-specific field-level update for NeighborsCellLinked
function update!(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}) where {P<:GPUCuda, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsCellLinked, FI}
    N = lengthProperties(field)
    neighbors = field._neighbors
    
    # Step 1: Assign each particle to its cell (GPU kernel)
    assignCellFieldGPU!(neighbors.cell, N, field, neighbors)
    
    # Step 2: Count particles in each cell (GPU)
    countInCell!(neighbors.cellOffset, N, neighbors.cell)
    
    # Step 3: Fill the permutation table (GPU)
    fillPermTable!(neighbors.permTable, neighbors.cellOffset, 
                  neighbors.cell, N, neighbors.cellCounts)
    
    return nothing
end

# GPU-specific cell assignment for 1D fields
function assignCellFieldGPU!(cellArray, N, field::UnstructuredMeshField, neighbors::NeighborsCellLinked{1, P}) where {P<:GPUCuda}
    x = field._p.x
    periodic = neighbors.periodic
    
    function kernel(cell, x, N, box, cellSize, grid, periodic)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            @inbounds begin
                xi = x[i]
                # Wrap position for periodic boundaries before cell assignment
                if periodic
                    boxLen = box[1, 2] - box[1, 1]
                    xi = box[1, 1] + mod(xi - box[1, 1], boxLen)
                end
                cell[i] = positionToLinear1D(xi, box, cellSize, grid)
            end
        end
        return nothing
    end
    
    threads_per_block = 256
    blocks = div(N + threads_per_block - 1, threads_per_block)
    
    CUDA.@cuda threads=threads_per_block blocks=blocks kernel(cellArray, x, N, neighbors.box, neighbors.cellSize, neighbors.grid, periodic)
    CUDA.synchronize()
end

# GPU-specific cell assignment for 2D fields
function assignCellFieldGPU!(cellArray, N, field::UnstructuredMeshField, neighbors::NeighborsCellLinked{2, P}) where {P<:GPUCuda}
    x = field._p.x
    y = field._p.y
    periodic = neighbors.periodic
    
    function kernel(cell, x, y, N, box, cellSize, grid, periodic)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            @inbounds begin
                xi, yi = x[i], y[i]
                # Wrap positions for periodic boundaries before cell assignment
                if periodic
                    boxLenX = box[1, 2] - box[1, 1]
                    boxLenY = box[2, 2] - box[2, 1]
                    xi = box[1, 1] + mod(xi - box[1, 1], boxLenX)
                    yi = box[2, 1] + mod(yi - box[2, 1], boxLenY)
                end
                cell[i] = positionToLinear2D(xi, yi, box, cellSize, grid)
            end
        end
        return nothing
    end
    
    threads_per_block = 256
    blocks = div(N + threads_per_block - 1, threads_per_block)
    
    CUDA.@cuda threads=threads_per_block blocks=blocks kernel(cellArray, x, y, N, neighbors.box, neighbors.cellSize, neighbors.grid, periodic)
    CUDA.synchronize()
end

# GPU-specific cell assignment for 3D fields
function assignCellFieldGPU!(cellArray, N, field::UnstructuredMeshField, neighbors::NeighborsCellLinked{3, P}) where {P<:GPUCuda}
    x = field._p.x
    y = field._p.y
    z = field._p.z
    periodic = neighbors.periodic
    
    function kernel(cell, x, y, z, N, box, cellSize, grid, periodic)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            @inbounds begin
                xi, yi, zi = x[i], y[i], z[i]
                # Wrap positions for periodic boundaries before cell assignment
                if periodic
                    boxLenX = box[1, 2] - box[1, 1]
                    boxLenY = box[2, 2] - box[2, 1]
                    boxLenZ = box[3, 2] - box[3, 1]
                    xi = box[1, 1] + mod(xi - box[1, 1], boxLenX)
                    yi = box[2, 1] + mod(yi - box[2, 1], boxLenY)
                    zi = box[3, 1] + mod(zi - box[3, 1], boxLenZ)
                end
                cell[i] = positionToLinear3D(xi, yi, zi, box, cellSize, grid)
            end
        end
        return nothing
    end
    
    threads_per_block = 256
    blocks = div(N + threads_per_block - 1, threads_per_block)
    
    CUDA.@cuda threads=threads_per_block blocks=blocks kernel(cellArray, x, y, z, N, neighbors.box, neighbors.cellSize, neighbors.grid, periodic)
    CUDA.synchronize()
end

