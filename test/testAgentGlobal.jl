using KernelAbstractions

@testset verbose=verbose "specializations - AgentGlobal" begin

    #Define the model
    model = AgentGlobal(
        (
            a = AbstractFloat, 
            a2 = AbstractFloat,
            b = Integer
        ),
    )

    #v1
    @addODE model=model function globalEvolution!(du, u, p, t)
        @kernel_launch function step(du, u, p, t)
            du.g.a[1] = -0.1 * u.g.a[1]
        end
    end

    #v2
    @addODE model=model function globalEvolution2!(du, u, p, t)
        @. du.g.a2 = -0.1 * u.g.a2
    end

    @addRule model=model function globalReset!(uNew, u, p, t)
        @kernel_launch function global_reset_kernel!(uNew, u, p, t)
            uNew.g.b[1] += 2
            if uNew.g.b[1] > 10
                uNew.g.b[1] = 0
            end
        end
    end

    #Initialize the object
    obj = createObject(model)
    obj.g.a .= 1.0
    obj.g.a2 .= 1.0
    obj.g.b .= 0

    #Define the problem
    problem = CBProblem(
        model,
        obj
    )

    integrator = init(problem, dt=0.1)

    for i in 1:100
        step!(integrator)
        @test integrator.u.g.a[1] ≈ exp(-0.1 * integrator.t)
        @test integrator.u.g.a2[1] ≈ exp(-0.1 * integrator.t)
        @test integrator.u.g.b[1] ≤ 10
    end

    if CUDA.has_cuda()

        #Initialize the object
        obj = createObject(model)
        obj.g.a .= 1.0
        obj.g.a2 .= 1.0
        obj.g.b .= 0

        obj_gpu = toBackend(obj, CUDA.CUDABackend)
        problem = CBProblem(
            model,
            obj_gpu
        )
        integrator_gpu = init(problem, dt=0.1)

        for i in 1:100
            step!(integrator_gpu)
            @test Array(integrator_gpu.u.g.a)[1] ≈ exp(-0.1 * integrator_gpu.t) atol=1e-5
            @test Array(integrator_gpu.u.g.a2)[1] ≈ exp(-0.1 * integrator_gpu.t) atol=1e-5
            @test Array(integrator_gpu.u.g.b)[1] ≤ 10
        end
    end

end