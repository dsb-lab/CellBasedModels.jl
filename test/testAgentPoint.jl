using KernelAbstractions
using Atomix 
using DifferentialEquations

@testset verbose=verbose "specializations - AgentPoint" begin

    #Define the model
    model = AgentPoint(
        3,
        (
            a = AbstractFloat, 
            a2 = AbstractFloat,
            b = Integer
        ),
    )

    #v1
    @addODE model=model function globalEvolution(du, u, p, t)
        @kernel_launch ndrange=length(du.n.a) function step(du, u, p, t)
            i = @index(Global)
            du.n.a[i] = -0.1 * u.n.a[i]
        end

        @. du.n.a2 = -0.1 * u.n.a2
    end

    @addRule model=model function globalReset!(uNew, u, p, t)
        @kernel_launch ndrange=length(uNew.n.a) function global_reset_kernel!(uNew, u, p, t)
            i = @index(Global)
            uNew.n.b[i] += 2
            if uNew.n.b[i] > 10
                uNew.n.b[i] = 0
            end
        end
    end

    #Initialize the object
    obj = createObject(model, n=(10,20))
    obj.n.a .= 1.0
    obj.n.a2 .= 1.0
    obj.n.b .= 0

    #Define the problem
    problem = CBProblem(
        model,
        obj
    )

    integrator = init(problem, dt=0.1, globalEvolution=DifferentialEquations.Euler())

    for i in 1:100
        step!(integrator)
        @test all(isapprox.(integrator.u.n.a, exp(-0.1 * integrator.t); atol=1e-2))
        @test all(isapprox.(integrator.u.n.a2, exp(-0.1 * integrator.t); atol=1e-2))
        @test all(integrator.u.n.b .≤ 10)
    end

    if CUDA.has_cuda()

        #Initialize the object
        obj = createObject(model, n=(10,20))
        obj.n.a .= 1.0
        obj.n.a2 .= 1.0
        obj.n.b .= 0

        obj_gpu = toBackend(obj, CUDA.CUDABackend())
        problem = CBProblem(
            model,
            obj_gpu
        )
        integrator_gpu = init(problem, dt=0.1, globalEvolution=DifferentialEquations.Euler())

        for i in 1:100
            step!(integrator_gpu)
            @test all(isapprox.(Array(integrator_gpu.u.n.a), exp(-0.1 * integrator_gpu.t); atol=1e-2))
            @test all(isapprox.(Array(integrator_gpu.u.n.a2), exp(-0.1 * integrator_gpu.t); atol=1e-2))
            @test all(Array(integrator_gpu.u.n.b) .≤ 10)
        end

    end

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
            for j in iterateOverNeighbors(u, :n, x_i, y_i, z_i)
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
            for j in 1:length(uNew.n.b)
                if j == i
                    continue
                end
                x_j = u.n.x[j]
                y_j = u.n.y[j]
                z_j = u.n.z[j]
                if sqrt((x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2) < 1.8
                    uNew.n.b_consistency[i] += 1
                end
            end
        end
    end

    for neighborAlg in [
            NeighborsFull(), 
            NeighborsCellLinked(box=[0 10; 0 10; 0 10], cellSize=1.0),
            NeighborsHash(cellSize=1.0)
        ]
        for backend in backends

            obj = createObject(model, n=(10^3, 10000), neighbors=neighborAlg)
            obj.n.x .= vec([x for x in 0.5:1:9.5, y in 0.5:1:9.5, z in 0.5:1:9.5])
            obj.n.y .= vec([y for x in 0.5:1:9.5, y in 0.5:1:9.5, z in 0.5:1:9.5])
            obj.n.z .= vec([z for x in 0.5:1:9.5, y in 0.5:1:9.5, z in 0.5:1:9.5])

            obj_gpu = toBackend(obj, backend)

            problem = CBProblem(
                model,
                obj_gpu
            )

            integrator = init(problem, dt=0.1)

            step!(integrator)

            # Calculate expected neighbor counts based on position
            # Agents at boundaries (0.5 or 9.5) have fewer neighbors
            expected_b = zeros(Int, length(obj.n.x))
            for iz in 1:10, iy in 1:10, ix in 1:10
                # Linear index matching vec() flattening order (column-major)
                idx = ix + (iy - 1) * 10 + (iz - 1) * 100
                
                # Count how many coordinates are at boundaries
                at_boundary = 0
                if ix == 1 || ix == 10
                    at_boundary += 1
                end
                if iy == 1 || iy == 10
                    at_boundary += 1
                end
                if iz == 1 || iz == 10
                    at_boundary += 1
                end
                
                # Calculate neighbors: interior=26, face=17, edge=11, corner=7
                if at_boundary == 0
                    expected_b[idx] = 26  # Interior
                elseif at_boundary == 1
                    expected_b[idx] = 17  # Face
                elseif at_boundary == 2
                    expected_b[idx] = 11  # Edge
                else
                    expected_b[idx] = 7   # Corner
                end
            end

            @test all(toBackend(integrator.u, CPU()).n.b .== expected_b)
            @test all(toBackend(integrator.u, CPU()).n.b .== toBackend(integrator.u, CPU()).n.b_consistency)
        end
    end

    # Neighbors random
    model = AgentPoint(
        3,
        (
            b = Integer,
            b_consistency = Integer
        ),
    )

    @addRule model=model function neighbors_check_random!(uNew, u, p, t)
        @kernel_launch ndrange=length(uNew.n.b) function neighbors_check_random_kernel!(uNew, u, p, t)
            i = @index(Global)
            x_i = u.n.x[i]
            y_i = u.n.y[i]
            z_i = u.n.z[i]
            for j in iterateOverNeighbors(u, :n, x_i, y_i, z_i)
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
            for j in 1:length(uNew.n.b)
                if j == i
                    continue
                end
                x_j = u.n.x[j]
                y_j = u.n.y[j]
                z_j = u.n.z[j]
                if sqrt((x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2) < 1.8
                    uNew.n.b_consistency[i] += 1
                end
            end
        end
    end

    for neighborAlg in [
            NeighborsFull(), 
            NeighborsCellLinked(box=[0 10; 0 10; 0 10], cellSize=2.0),
            NeighborsHash(box=[0 10; 0 10; 0 10], cellSize=2.0)
        ]
        for backend in backends

            obj = createObject(model, n=(100, 10000), neighbors=neighborAlg)
            obj.n.x .= rand(100)*10
            obj.n.y .= rand(100)*10
            obj.n.z .= rand(100)*10

            obj_gpu = toBackend(obj, backend)

            problem = CBProblem(
                model,
                obj_gpu
            )

            integrator = init(problem, dt=0.1)

            step!(integrator)

            @test all(toBackend(integrator.u, CPU()).n.b .== toBackend(integrator.u, CPU()).n.b_consistency)
        end
    end

    # Neighbors periodic
    model = AgentPoint(
        3,
        (
            b = Integer,
            b_consistency = Integer
        ),
    )

    @addRule model=model function neighbors_check_periodic!(uNew, u, p, t)
        @kernel_launch ndrange=length(uNew.n.b) function neighbors_check_periodic_kernel!(uNew, u, p, t)
            i = @index(Global)
            x_i = u.n.x[i]
            y_i = u.n.y[i]
            z_i = u.n.z[i]
            for j in iterateOverNeighbors(u, :n, x_i, y_i, z_i)
                if j == i
                    continue
                end
                x_j = u.n.x[j]
                y_j = u.n.y[j]
                z_j = u.n.z[j]
                x_j = posRelPeriodicBoundary(x_j, x_i, 0, 10.0)
                y_j = posRelPeriodicBoundary(y_j, y_i, 0, 10.0)
                z_j = posRelPeriodicBoundary(z_j, z_i, 0, 10.0)
                if sqrt((x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2) < 1.8
                    uNew.n.b[i] += 1
                end
            end
            for j in 1:length(uNew.n.b)
                if j == i
                    continue
                end
                x_j = u.n.x[j]
                y_j = u.n.y[j]
                z_j = u.n.z[j]
                x_j = posRelPeriodicBoundary(x_j, x_i, 0, 10.0)
                y_j = posRelPeriodicBoundary(y_j, y_i, 0, 10.0)
                z_j = posRelPeriodicBoundary(z_j, z_i, 0, 10.0)
                if sqrt((x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2) < 1.8
                    uNew.n.b_consistency[i] += 1
                end
            end
        end
    end

    for neighborAlg in [
            NeighborsFull(), 
            NeighborsCellLinked(box=[0 10; 0 10; 0 10], cellSize=1.0, periodic=true),
            NeighborsHash(box=[0 10; 0 10; 0 10], cellSize=1.0, periodic=true)
        ]
        for backend in backends

            obj = createObject(model, n=(10^3, 10000), neighbors=neighborAlg)
            obj.n.x .= vec([x for x in 0.5:1:9.5, y in 0.5:1:9.5, z in 0.5:1:9.5])
            obj.n.y .= vec([y for x in 0.5:1:9.5, y in 0.5:1:9.5, z in 0.5:1:9.5])
            obj.n.z .= vec([z for x in 0.5:1:9.5, y in 0.5:1:9.5, z in 0.5:1:9.5])

            obj_gpu = toBackend(obj, backend)

            problem = CBProblem(
                model,
                obj_gpu
            )

            integrator = init(problem, dt=0.1)

            step!(integrator)

            @test all(toBackend(integrator.u, CPU()).n.b .== 26)
            @test all(toBackend(integrator.u, CPU()).n.b .== toBackend(integrator.u, CPU()).n.b_consistency)
        end
    end

    # Neighbors periodic random
    model = AgentPoint(
        3,
        (
            b = Integer,
            b_consistency = Integer
        ),
    )

    @addRule model=model function neighbors_check_periodic_random!(uNew, u, p, t)
        @kernel_launch ndrange=length(uNew.n.b) function neighbors_check_periodic_kernel!(uNew, u, p, t)
            i = @index(Global)
            x_i = u.n.x[i]
            y_i = u.n.y[i]
            z_i = u.n.z[i]
            for j in iterateOverNeighbors(u, :n, x_i, y_i, z_i)
                if j == i
                    continue
                end
                x_j = u.n.x[j]
                y_j = u.n.y[j]
                z_j = u.n.z[j]
                x_j = posRelPeriodicBoundary(x_j, x_i, 0, 10.0)
                y_j = posRelPeriodicBoundary(y_j, y_i, 0, 10.0)
                z_j = posRelPeriodicBoundary(z_j, z_i, 0, 10.0)
                if sqrt((x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2) < 1.8
                    uNew.n.b[i] += 1
                end
            end
            for j in 1:length(uNew.n.b)
                if j == i
                    continue
                end
                x_j = u.n.x[j]
                y_j = u.n.y[j]
                z_j = u.n.z[j]
                x_j = posRelPeriodicBoundary(x_j, x_i, 0, 10.0)
                y_j = posRelPeriodicBoundary(y_j, y_i, 0, 10.0)
                z_j = posRelPeriodicBoundary(z_j, z_i, 0, 10.0)
                if sqrt((x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2) < 1.8
                    uNew.n.b_consistency[i] += 1
                end
            end
        end
    end

    for neighborAlg in [
            NeighborsFull(), 
            NeighborsCellLinked(box=[0 10; 0 10; 0 10], cellSize=2.0, periodic=true),
            NeighborsHash(box=[0 10; 0 10; 0 10], cellSize=2.0, periodic=true)
        ]
        for backend in backends

            obj = createObject(model, n=(10^3, 10000), neighbors=neighborAlg)
            obj.n.x .= rand(1000)*10
            obj.n.y .= rand(1000)*10
            obj.n.z .= rand(1000)*10

            obj_gpu = toBackend(obj, backend)

            problem = CBProblem(
                model,
                obj_gpu
            )

            integrator = init(problem, dt=0.1)

            step!(integrator)

            @test all(toBackend(integrator.u, CPU()).n.b .== toBackend(integrator.u, CPU()).n.b_consistency)
        end
    end

    #SDE
    model = AgentPoint(
        3,
        (
            a = AbstractFloat, 
            b = AbstractFloat
        ),
    )

    @addSDE model=model function sde_f(du, u, p, t)
        @kernel_launch ndrange=length(du.n.a) function step(du, u, p, t)
            i = @index(Global)
            du.n.a[i] = 0
            du.n.b[i] = 1
        end
    end function sde_g(du, u, p, t)
        @kernel_launch ndrange=length(du.n.a) function step(du, u, p, t)
            i = @index(Global)
            du.n.a[i] = 1
        end
    end

    for backend in backends

        obj = createObject(model, n=10)

        obj_gpu = toBackend(obj, backend)

        problem = CBProblem(
            model,
            obj_gpu
        )

        integrator = init(problem, dt=0.1, sde_f=EM())

        step!(integrator)

        @test all(length(unique(Array(integrator.integrators.sde_f.W.dW.n.a))) == length(integrator.u.n.a))
    end

    # # Add/Remove agents test
    # model = AgentPoint(
    #     2,
    #     (
    #         w = Int,
    #     ),
    # )

    # @addRule model=model function addRemoveRule!(uNew, u, p, t)
    #     # CellBasedModels.sizeProperties(u.n)
    #     @kernel_launch ndrange=CellBasedModels.sizeProperties(u.n) function add_remove_kernel!(uNew, u, p, t)
    #         i = @index(Global)
    #         t = (u.n.w[i]-1) % 3 + 1
    #         if t == 1
    #             @AgentPoint_Add!(uNew, x=u.n.x[i], y=u.n.y[i], w=4)
    #         elseif t == 2
    #             @AgentPoint_remove!(uNew, i)
    #         end
    #     end
    # end

    # for cache in [20, 10] 
    #     for backend in backends
    #         #Initialize the object
    #         obj = createObject(model, n=(10,cache))
    #         obj.n.x .= rand(size(obj.n.x))
    #         obj.n.y .= rand(size(obj.n.y))
    #         obj.n.w .= rand(1:3, length(obj.n.w))

    #         obj_gpu = toBackend(obj, backend)
    #         problem = CBProblem(
    #             model,
    #             obj_gpu
    #         )
    #         integrator_gpu = init(problem, dt=0.1)
    #         initial_count = length(integrator_gpu.u.n.w)
    #         initial_count_1 = sum(integrator_gpu.u.n.w .== 1)
    #         initial_count_2 = sum(integrator_gpu.u.n.w .== 2)
    #         initial_count_3 = sum(integrator_gpu.u.n.w .== 3)
    #         ids = collect(1:initial_count)[Array(integrator_gpu.u.n.w) .!= 2]
    #         ids = [ids..., (initial_count+1):(initial_count+initial_count_1)...]

    #         step!(integrator_gpu)

    #         @test sum(integrator_gpu.u.n.w .== 4) == initial_count_1
    #         @test sum(integrator_gpu.u.n.w .== 2) == 0
    #         @test sum(integrator_gpu.u.n.w .== 3) == initial_count_3
    #         @test length(integrator_gpu.u.n.w) == initial_count_1*2 + initial_count_3
    #         @test all(Array(integrator_gpu.u.n._id[1:(initial_count_1*2 + initial_count_3)]) .== ids)
    #     end

    # end

end