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
            for j in iterateOverNeighbors(u.n, x_i, y_i, z_i)
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
            for j in iterateOverNeighbors(u.n, x_i, y_i, z_i)
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

    # NeighborsHash periodic with negative cell indices
    # Regression test: ensures NeighborsHash correctly handles periodic boundaries
    # when particle positions produce negative cell indices (box centered at origin)
    model = AgentPoint(
        3,
        (
            b = Integer,
            b_consistency = Integer
        ),
    )

    @addRule model=model function neighbors_check_periodic_negative!(uNew, u, p, t)
        @kernel_launch ndrange=length(uNew.n.b) function neighbors_check_periodic_negative_kernel!(uNew, u, p, t)
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
                x_j = posRelPeriodicBoundary(x_j, x_i, -20.0, 20.0)
                y_j = posRelPeriodicBoundary(y_j, y_i, -20.0, 20.0)
                z_j = posRelPeriodicBoundary(z_j, z_i, -20.0, 20.0)
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
                x_j = posRelPeriodicBoundary(x_j, x_i, -20.0, 20.0)
                y_j = posRelPeriodicBoundary(y_j, y_i, -20.0, 20.0)
                z_j = posRelPeriodicBoundary(z_j, z_i, -20.0, 20.0)
                if sqrt((x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2) < 1.8
                    uNew.n.b_consistency[i] += 1
                end
            end
        end
    end

    # Test with box centered at origin [-20, 20]³ - particles will have negative cell indices
    for neighborAlg in [
            NeighborsFull(), 
            NeighborsCellLinked(box=[-20 20; -20 20; -20 20], cellSize=3.0, periodic=true),
            NeighborsHash(box=[-20 20; -20 20; -20 20], cellSize=3.0, periodic=true)
        ]
        for backend in backends

            obj = createObject(model, n=(200, 10000), neighbors=neighborAlg)
            # Random positions spanning negative to positive coordinates
            obj.n.x .= rand(200) .* 40 .- 20  # Range: [-20, 20]
            obj.n.y .= rand(200) .* 40 .- 20
            obj.n.z .= rand(200) .* 40 .- 20

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
        # u.n.b .= 0
        # u.n.b_consistency .= 0
        @kernel_launch ndrange=length(du.n.b) function ode(du, u, p, t)
            i = @index(Global)
            x_i = u.n.x[i]
            y_i = u.n.y[i]
            z_i = u.n.z[i]
            du.n.a[i] = 0
            for j in iterateOverNeighbors(u.n, x_i, y_i, z_i)
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
            for j in iterateOverNeighbors(u.n, x_i, y_i, z_i)
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

    # Test that _neighbors reference is preserved through deepcopy/partialCopy chain
    # This prevents regression of the issue where NeighborsCellLinked/Hash internal arrays
    # were not shared between integrator.u and deintegrator.u
    
    # Helper function to get a mutable array from the neighbor structure for comparison
    function get_neighbor_array(neighbors::NeighborsCellLinked)
        return neighbors.permTable
    end
    function get_neighbor_array(neighbors::NeighborsHash)
        return neighbors.hashTable.mortonCodes
    end
    
    for neighborAlg in [
            NeighborsCellLinked(box=[-5 5; -5 5; -5 5], cellSize=2.0),
            NeighborsHash(box=[-5 5; -5 5; -5 5], cellSize=2.0)
        ]
        
        model_ref = AgentPoint(3, (a = AbstractFloat,))
        @addODE model=model_ref function ref_test_f(du, u, p, t)
            @kernel_launch ndrange=length(du.n.a) function ref_kernel(du, u, p, t)
                i = @index(Global)
                du.n.a[i] = 0
            end
        end

        obj = createObject(model_ref, n=(10, 100), neighbors=neighborAlg)
        obj.n.x .= rand(10)*10 .- 5
        obj.n.y .= rand(10)*10 .- 5
        obj.n.z .= rand(10)*10 .- 5

        # Test 1: deepcopy preserves _neighbors reference
        obj_copy = deepcopy(obj)
        @test get_neighbor_array(obj.n._neighbors) === get_neighbor_array(obj_copy.n._neighbors)

        # Test 2: partialCopy preserves _neighbors reference
        obj_partial = CellBasedModels.partialCopy(obj, [(:n, :a)])
        @test get_neighbor_array(obj.n._neighbors) === get_neighbor_array(obj_partial.n._neighbors)

        # Test 3: CBProblem chain preserves _neighbors reference
        problem = CBProblem(model_ref, obj)
        @test get_neighbor_array(obj.n._neighbors) === get_neighbor_array(problem.u.n._neighbors)
    end

end