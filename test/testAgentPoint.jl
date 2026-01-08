using KernelAbstractions
using Atomix 

@testset verbose=verbose "specializations - AgentPoint" begin

    # #Define the model
    # model = AgentPoint(
    #     3,
    #     (
    #         a = AbstractFloat, 
    #         a2 = AbstractFloat,
    #         b = Integer
    #     ),
    # )

    # #v1
    # @addODE model=model function globalEvolution!(du, u, p, t)
    #     @kernel_launch function step(du, u, p, t)
    #         i = @index(Global)
    #         du.n.a[i] = -0.1 * u.n.a[i]
    #     end
    # end

    # #v2
    # @addODE model=model function globalEvolution2!(du, u, p, t)
    #     @. du.n.a2 = -0.1 * u.n.a2
    # end

    # @addRule model=model function globalReset!(uNew, u, p, t)
    #     @kernel_launch function global_reset_kernel!(uNew, u, p, t)
    #         i = @index(Global)
    #         uNew.n.b[i] += 2
    #         if uNew.n.b[i] > 10
    #             uNew.n.b[i] = 0
    #         end
    #     end
    # end

    # #Initialize the object
    # obj = createObject(model, n=(10,20))
    # obj.n.a .= 1.0
    # obj.n.a2 .= 1.0
    # obj.n.b .= 0

    # #Define the problem
    # problem = CBProblem(
    #     model,
    #     obj
    # )

    # integrator = init(problem, dt=0.1)

    # for i in 1:100
    #     step!(integrator)
    #     @test all(integrator.u.n.a .≈ exp(-0.1 * integrator.t))
    #     @test all(integrator.u.n.a2 .≈ exp(-0.1 * integrator.t))
    #     @test all(integrator.u.n.b .≤ 10)
    # end

    # if CUDA.has_cuda()

    #     #Initialize the object
    #     obj = createObject(model, n=(10,20))
    #     obj.n.a .= 1.0
    #     obj.n.a2 .= 1.0
    #     obj.n.b .= 0

    #     obj_gpu = toDevice(obj, CUDA.CUDABackend)
    #     problem = CBProblem(
    #         model,
    #         obj_gpu
    #     )
    #     integrator_gpu = init(problem, dt=0.1)

    #     for i in 1:100
    #         step!(integrator_gpu)
    #         @test all(isapprox.(Array(integrator_gpu.u.n.a), exp(-0.1 * integrator_gpu.t); atol=1e-5))
    #         @test all(isapprox.(Array(integrator_gpu.u.n.a2), exp(-0.1 * integrator_gpu.t); atol=1e-5))
    #         @test all(Array(integrator_gpu.u.n.b) .≤ 10)
    #     end

    # end

    # Add/Remove agents test
    model = AgentPoint(
        2,
        (
            w = Int,
        ),
    )

    @addRule model=model function addRemoveRule!(uNew, u, p, t)
        # CellBasedModels.sizeProperties(u.n)
        @kernel_launch ndrange=CellBasedModels.sizeProperties(u.n) function add_remove_kernel!(uNew, u, p, t)
            i = @index(Global)
            t = (u.n.w[i]-1) % 3 + 1
            if t == 1
                @addAgentPoint!(uNew, x=u.n.x[i], y=u.n.y[i], w=4)
            elseif t == 2
                @removeAgentPoint!(uNew, i)
            end
        end
        # println("W: ", uNew.n._p.w)
        # println("F: ", Int.(uNew.n._FlagsSurvived))
    end

    #Initialize the object
    obj = createObject(model, n=(10,20))
    obj.n.x .= rand(size(obj.n.x))
    obj.n.y .= rand(size(obj.n.y))
    obj.n.w .= rand(1:3, length(obj.n.w))

    #Define the problem
    problem = CBProblem(
        model,
        obj
    )
    integrator = init(problem, dt=0.1)
    initial_count = length(integrator.u.n.w)
    initial_count_1 = sum(integrator.u.n.w .== 1)
    initial_count_2 = sum(integrator.u.n.w .== 2)
    initial_count_3 = sum(integrator.u.n.w .== 3)
    ids = collect(1:initial_count)[integrator.u.n.w .!= 2]
    ids = [ids..., (initial_count+1):(initial_count+initial_count_1)...]

    # println("W: ", obj.n._p.w)
    step!(integrator)
    # println("W: ", integrator.u.n._p.w)

    @test sum(integrator.u.n.w .== 4) == initial_count_1
    @test sum(integrator.u.n.w .== 2) == 0
    @test sum(integrator.u.n.w .== 3) == initial_count_3
    @test length(integrator.u.n.w) == initial_count_1*2 + initial_count_3
    @test all(integrator.u.n._id[1:(initial_count_1*2 + initial_count_3)] .== ids)

    if CUDA.has_cuda()

        #Initialize the object
        obj = createObject(model, n=(10,20))
        obj.n.x .= rand(size(obj.n.x))
        obj.n.y .= rand(size(obj.n.y))
        obj.n.w .= rand(1:3, length(obj.n.w))

        obj_gpu = toDevice(obj, CUDA.CUDABackend)
        problem = CBProblem(
            model,
            obj_gpu
        )
        integrator_gpu = init(problem, dt=0.1)
        initial_count = length(integrator_gpu.u.n.w)
        initial_count_1 = sum(integrator_gpu.u.n.w .== 1)
        initial_count_2 = sum(integrator_gpu.u.n.w .== 2)
        initial_count_3 = sum(integrator_gpu.u.n.w .== 3)
        ids = collect(1:initial_count)[Array(integrator_gpu.u.n.w) .!= 2]
        ids = [ids..., (initial_count+1):(initial_count+initial_count_1)...]

        step!(integrator_gpu)

        @test sum(integrator_gpu.u.n.w .== 4) == initial_count_1
        @test sum(integrator_gpu.u.n.w .== 2) == 0
        @test sum(integrator_gpu.u.n.w .== 3) == initial_count_3
        @test length(integrator_gpu.u.n.w) == initial_count_1*2 + initial_count_3
        @test all(Array(integrator_gpu.u.n._id[1:(initial_count_1*2 + initial_count_3)]) .== ids)

    end

end