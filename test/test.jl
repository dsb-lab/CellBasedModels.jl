import Pkg
Pkg.activate("..")

using CellBasedModels
using Random
using DifferentialEquations
using Accessors
using BenchmarkTools
using KernelAbstractions
using Atomix: @atomic
using CUDA

backends = [CPU(), CUDA.CUDABackend()]

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

        obj = createObject(model, n=3)

        obj_gpu = toBackend(obj, backend)

        problem = CBProblem(
            model,
            obj_gpu
        )

        integrator = init(problem, dt=0.1, sde_f=EM())

        step!(integrator)

        println(integrator.integrators.sde_f.W.dW.n.a)
        println(integrator.integrators.sde_f.W.dW.n.b)

        step!(integrator)
        println(integrator.integrators.sde_f.W.dW.n.a)
        println(integrator.integrators.sde_f.W.dW.n.b)

        # @test all(length(unique(toBackend(integrator.integrators.sde_f.W.dW.n.a, CPU()))) == length(integrator.u.n.a))
    end