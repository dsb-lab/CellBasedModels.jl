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

    ###################################################################################
    # Test addAgent!/removeAgent! with dynamic allocation
    ###################################################################################
    @testset "Dynamic add/remove agents" begin
        
        # Simple model for testing
        model_dynamic = AgentPoint(
            2,
            (
                value = AbstractFloat,
                count = Integer,
            ),
        )

        for backend in backends
            @testset "Backend: $(typeof(backend))" begin
                
                # Create object with initial agents and extra cache
                obj = createObject(model_dynamic, n=(5, 20))
                obj.n.x .= [1.0, 2.0, 3.0, 4.0, 5.0]
                obj.n.y .= [1.0, 2.0, 3.0, 4.0, 5.0]
                obj.n.value .= [10.0, 20.0, 30.0, 40.0, 50.0]
                obj.n.count .= [1, 2, 3, 4, 5]

                # Test initial state
                @test obj.n._N[1] == 5
                @test numberOfFree(obj.n) == 15

                # Test addAgent!
                pos1 = addAgent!(obj, (x=6.0, y=6.0, value=60.0, count=6))
                @test pos1 != 0
                @test obj.n._N[1] == 6
                @test numberOfFree(obj.n) == 14
                @test obj.n.x[pos1] == 6.0
                @test obj.n.value[pos1] == 60.0

                pos2 = addAgent!(obj, (x=7.0, y=7.0, value=70.0, count=7))
                @test pos2 != 0
                @test obj.n._N[1] == 7
                @test numberOfFree(obj.n) == 13

                # Test removeAgent!
                removeAgent!(obj, pos1)
                @test obj.n._N[1] == 6
                @test obj.n._FlagsSurvived[pos1] == false

                # After sync, position should be available for reuse
                CellBasedModels.synchronize(obj.n)
                @test numberOfFree(obj.n) == 14

                # Add again - should reuse freed position
                pos3 = addAgent!(obj, (x=8.0, y=8.0, value=80.0, count=8))
                @test pos3 == pos1  # Should reuse the freed position
                @test obj.n._N[1] == 7
                @test obj.n.x[pos3] == 8.0

            end
        end
    end

    ###################################################################################
    # Test add/remove inside kernels
    ###################################################################################
    @testset "Add/remove in kernels" begin
        
        model_kernel = AgentPoint(
            2,
            (
                value = AbstractFloat,
                parent_id = Integer,
            ),
        )

        # Test adding agents inside a kernel rule
        @addRule model=model_kernel function spawn_agents!(uNew, u, p, t)
            @kernel_launch ndrange=length(u.n.value) function spawn_kernel!(uNew, u, p, t)
                i = @index(Global)
                
                # Only agents with value > 50 spawn a new agent
                if u.n.value[i] > 50.0 && isAlive(u.n, i)
                    new_pos = getFreePos!(uNew.n)
                    if new_pos != 0
                        uNew.n.x[new_pos] = u.n.x[i] + 0.1
                        uNew.n.y[new_pos] = u.n.y[i] + 0.1
                        uNew.n.value[new_pos] = u.n.value[i] * 0.5
                        uNew.n.parent_id[new_pos] = u.n._id[i]
                    end
                end
            end
        end

        for backend in backends
            @testset "Spawn kernel - $(typeof(backend))" begin
                
                obj = createObject(model_kernel, n=(4, 20))
                obj.n.x .= [1.0, 2.0, 3.0, 4.0]
                obj.n.y .= [1.0, 2.0, 3.0, 4.0]
                obj.n.value .= [30.0, 60.0, 70.0, 40.0]  # 2 agents > 50
                obj.n.parent_id .= 0

                obj_backend = toBackend(obj, backend)

                problem = CBProblem(model_kernel, obj_backend)
                integrator = init(problem, dt=0.1)
                
                initial_N = Array(integrator.u.n._N)[1]
                @test initial_N == 4

                step!(integrator)
                CellBasedModels.synchronize(integrator.u.n)
                
                final_N = Array(integrator.u.n._N)[1]
                @test final_N == 6  # 2 new agents spawned

                # Check values of new agents
                values = Array(integrator.u.n.value)
                parent_ids = Array(integrator.u.n.parent_id)
                
                # New agents should have parent_id > 0
                new_agents = findall(parent_ids .> 0)
                @test length(new_agents) == 2
                
                # New agent values should be half of parent
                for idx in new_agents
                    @test values[idx] ≈ 30.0 || values[idx] ≈ 35.0  # 60*0.5 or 70*0.5
                end
            end
        end

        # Test removing agents inside a kernel rule
        model_kernel_die = AgentPoint(
            2,
            (
                value = AbstractFloat,
                parent_id = Integer,
            ),
        )

        @addRule model=model_kernel_die function die_agents!(uNew, u, p, t)
            @kernel_launch ndrange=length(u.n.value) function die_kernel!(uNew, u, p, t)
                i = @index(Global)
                
                # Agents with value < 20 die
                if isAlive(u.n, i) && u.n.value[i] < 20.0
                    releasePos!(uNew.n, i)
                end
            end
        end

        for backend in backends
            @testset "Die kernel - $(typeof(backend))" begin
                
                obj = createObject(model_kernel_die, n=(5, 20))
                obj.n.x .= [1.0, 2.0, 3.0, 4.0, 5.0]
                obj.n.y .= [1.0, 2.0, 3.0, 4.0, 5.0]
                obj.n.value .= [10.0, 25.0, 15.0, 50.0, 5.0]  # 3 agents < 20
                obj.n.parent_id .= 0

                obj_backend = toBackend(obj, backend)

                problem = CBProblem(model_kernel_die, obj_backend)
                integrator = init(problem, dt=0.1)
                
                initial_N = Array(integrator.u.n._N)[1]
                @test initial_N == 5

                step!(integrator)
                CellBasedModels.synchronize(integrator.u.n)
                
                # With no-compaction design, _N stays as max index (5)
                # but _FlagsSurvived tracks which positions are alive
                final_N = Array(integrator.u.n._N)[1]
                @test final_N == 5  # _N unchanged (no compaction)
                
                # Count surviving agents via _FlagsSurvived
                survived = Array(integrator.u.n._FlagsSurvived)
                N_cache = Array(integrator.u.n._NCache)[1]
                survived_count = count(survived[1:final_N])
                @test survived_count == 2  # 3 agents died, 2 survive

                # Access underlying property storage directly (not the view)
                values_raw = Array(getfield(getfield(integrator.u.n, :_p), :value))
                # Check that only surviving agents have value >= 20
                for i in 1:final_N
                    if survived[i]
                        @test values_raw[i] >= 20.0
                    end
                end
            end
        end
    end

    ###################################################################################
    # Test neighbors consistency with spawn/die in kernels
    ###################################################################################
    @testset "Neighbors with dynamic agents" begin
        
        model_neighbors = AgentPoint(
            2,
            (
                neighbor_count = Integer,
            ),
        )

        # Rule to count neighbors
        @addRule model=model_neighbors function count_neighbors!(uNew, u, p, t)
            @kernel_launch ndrange=length(u.n.neighbor_count) function count_kernel!(uNew, u, p, t)
                i = @index(Global)
                
                if isAlive(u.n, i)
                    count = 0
                    for j in iterateOverNeighbors(u.n, i)
                        if isAlive(u.n, j) && i != j
                            # Check distance
                            dx = u.n.x[i] - u.n.x[j]
                            dy = u.n.y[i] - u.n.y[j]
                            dist = sqrt(dx*dx + dy*dy)
                            if dist < 2.0
                                count += 1
                            end
                        end
                    end
                    uNew.n.neighbor_count[i] = count
                end
            end
        end

        for backend in backends
            @testset "Neighbors - $(typeof(backend))" begin
                
                # Create agents in a line: (0,0), (1,0), (2,0), (3,0), (4,0)
                # With distance < 2, each should see its immediate neighbors
                obj = createObject(model_neighbors, n=(5, 20), neighbors=NeighborsFull())
                obj.n.x .= [0.0, 1.0, 2.0, 3.0, 4.0]
                obj.n.y .= [0.0, 0.0, 0.0, 0.0, 0.0]
                obj.n.neighbor_count .= 0

                obj_backend = toBackend(obj, backend)

                problem = CBProblem(model_neighbors, obj_backend)
                integrator = init(problem, dt=0.1)
                
                step!(integrator)
                
                counts = Array(integrator.u.n.neighbor_count)
                # Agent 0: neighbor 1 (dist=1)
                @test counts[1] == 1
                # Agent 1: neighbors 0,2 (dist=1 each)
                @test counts[2] == 2
                # Agent 2: neighbors 1,3 (dist=1 each)
                @test counts[3] == 2
                # Agent 3: neighbors 2,4 (dist=1 each)
                @test counts[4] == 2
                # Agent 4: neighbor 3 (dist=1)
                @test counts[5] == 1
            end
        end
    end

    ###################################################################################
    # Test overflow handling inside kernel
    ###################################################################################
    @testset "Overflow handling" begin
        
        model_overflow = AgentPoint(2, (value = AbstractFloat,))

        # Rule that tries to spawn multiple agents (will overflow)
        @addRule model=model_overflow function overflow_spawn!(uNew, u, p, t)
            @kernel_launch ndrange=length(u.n.value) function overflow_kernel!(uNew, u, p, t)
                i = @index(Global)
                
                # Every surviving agent tries to spawn 3 children
                if isAlive(u.n, i)
                    for spawn_i in 1:3
                        pos = getFreePos!(uNew.n)
                        if pos != 0
                            uNew.n.x[pos] = u.n.x[i] + Float64(spawn_i)
                            uNew.n.y[pos] = u.n.y[i] + Float64(spawn_i)
                            uNew.n.value[pos] = u.n.value[i] * 0.5
                            uNew.n._FlagsSurvived[pos] = true
                        end
                    end
                end
            end
        end

        for backend in backends
            @testset "Overflow - $(typeof(backend))" begin
                
                # Create with minimal cache: 3 agents, cache of 5, so only 2 free slots
                obj = createObject(model_overflow, n=(3, 5))
                obj.n.x .= [1.0, 2.0, 3.0]
                obj.n.y .= [1.0, 2.0, 3.0]
                obj.n.value .= [1.0, 2.0, 3.0]

                @test obj.n._N[1] == 3
                @test numberOfFree(obj.n) == 2

                obj_backend = toBackend(obj, backend)

                problem = CBProblem(model_overflow, obj_backend)
                integrator = init(problem, dt=0.1)
                
                step!(integrator)
                CellBasedModels.synchronize(integrator.u.n)
                
                # Should have filled cache (original 3 + 2 free = 5)
                final_N = Array(integrator.u.n._N)[1]
                @test final_N == 5
                
                # Should have overflow (3 agents * 3 spawns = 9 needed, only 2 available)
                overflow = Array(integrator.u.n._NOverflow)[1]
                @test overflow >= 1
            end
        end
    end

end