@testset verbose=verbose "Neighbors" begin

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
            NeighborsCellLinked(box=[-5 5; -5 5; -5 5], cellSize=2.0),
            NeighborsHash(box=[-5 5; -5 5; -5 5], cellSize=2.0)
        ]
        for backend in backends

            obj = createObject(model, n=(100, 10000), neighbors=neighborAlg)
            obj.n.x .= rand(100)*10 .- 5
            obj.n.y .= rand(100)*10 .- 5
            obj.n.z .= rand(100)*10 .- 5

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

    #ODE
    model = AgentPoint(
        3,
        (
            a = AbstractFloat,
            b = AbstractFloat,
            b_consistency = AbstractFloat
        ),
    )

    @addODE model=model function ode_f(du, u, p, t)
        @kernel_launch ndrange=length(du.n.b) function ode(du, u, p, t)
            i = @index(Global)
            x_i = u.n.x[i]
            y_i = u.n.y[i]
            z_i = u.n.z[i]
            du.n.a[i] = 0
            for j in iterateOverNeighbors(u, :n, x_i, y_i, z_i)
                if j == i
                    continue
                end
                x_j = u.n.x[j]
                y_j = u.n.y[j]
                z_j = u.n.z[j]
                if sqrt((x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2) < 1.8
                    u.n.b[i] += 1
                end
            end
            for j in 1:length(du.n.b)
                if j == i
                    continue
                end
                x_j = u.n.x[j]
                y_j = u.n.y[j]
                z_j = u.n.z[j]
                if sqrt((x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2) < 1.8
                    u.n.b_consistency[i] += 1
                end
            end
        end
    end

    for neighborAlg in [
            NeighborsFull(), 
            NeighborsCellLinked(box=[-5 5; -5 5; -5 5], cellSize=2.0),
            NeighborsHash(box=[-5 5; -5 5; -5 5], cellSize=2.0)
        ]
        for backend in backends

            obj = createObject(model, n=(100, 10000), neighbors=neighborAlg)
            obj.n.x .= rand(100)*10 .- 5
            obj.n.y .= rand(100)*10 .- 5
            obj.n.z .= rand(100)*10 .- 5

            obj_gpu = toBackend(obj, backend)

            problem = CBProblem(
                model,
                obj_gpu
            )

            integrator = init(problem, dt=0.1, ode_f=Euler())

            step!(integrator)

            # println(toBackend(integrator.u, CPU()).n.b)
            # println(toBackend(integrator.u, CPU()).n.b_consistency)
            @test all(toBackend(integrator.u, CPU()).n.b .== toBackend(integrator.u, CPU()).n.b_consistency)
        end
    end

    #SDE
    model = AgentPoint(
        3,
        (
            a = AbstractFloat,
            b = Integer,
            b_consistency = Integer
        ),
    )

    @addSDE model=model function sde_f(du, u, p, t)
        @kernel_launch ndrange=length(du.n.b) function sde(du, u, p, t)
            i = @index(Global)
            x_i = u.n.x[i]
            y_i = u.n.y[i]
            z_i = u.n.z[i]
            du.n.a[i] = 0
            for j in iterateOverNeighbors(u, :n, x_i, y_i, z_i)
                if j == i
                    continue
                end
                x_j = u.n.x[j]
                y_j = u.n.y[j]
                z_j = u.n.z[j]
                if sqrt((x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2) < 1.8
                    u.n.b[i] += 1
                end
            end
            for j in 1:length(du.n.b)
                if j == i
                    continue
                end
                x_j = u.n.x[j]
                y_j = u.n.y[j]
                z_j = u.n.z[j]
                if sqrt((x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2) < 1.8
                    u.n.b_consistency[i] += 1
                end
            end
        end
    end function sde_g(du, u, p, t)
        @kernel_launch ndrange=length(du.n.b) function sde_g_kernel(du, u, p, t)
            i = @index(Global)
        end
    end

    for neighborAlg in [
            NeighborsFull(), 
            NeighborsCellLinked(box=[-5 5; -5 5; -5 5], cellSize=2.0),
            NeighborsHash(box=[-5 5; -5 5; -5 5], cellSize=2.0)
        ]
        for backend in backends

            obj = createObject(model, n=(100, 10000), neighbors=neighborAlg)
            obj.n.x .= rand(100)*10 .- 5
            obj.n.y .= rand(100)*10 .- 5
            obj.n.z .= rand(100)*10 .- 5

            obj_gpu = toBackend(obj, backend)

            problem = CBProblem(
                model,
                obj_gpu,
            )

            integrator = init(problem, dt=0.1, sde_f=EM())

            step!(integrator)

            @test all(toBackend(integrator.u, CPU()).n.b .== toBackend(integrator.u, CPU()).n.b_consistency)
        end
    end

end