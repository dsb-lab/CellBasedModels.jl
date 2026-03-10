using KernelAbstractions
using Atomix: @atomic
using DifferentialEquations

@testset verbose=verbose "specializations - AgentPolyline" begin

    #Define the model
    model = AgentPolyline(
        3,
    )

    #v1
    @addRule model=model function model_length(uNew, u, p, t)
        @kernel_launch ndrange=CellBasedModels.lengthProperties(uNew.e) function edge_length(uNew, u, p, t)
            i = @index(Global)
            rel_e_n = u.topo[:e,:n]
            (n1, n2) = getRow(rel_e_n, i, Val(2))
            u.e.length[i] = sqrt((u.n.x[n1] - u.n.x[n2])^2 + (u.n.y[n1] - u.n.y[n2])^2 + (u.n.z[n1] - u.n.z[n2])^2)
        end

        @kernel_launch ndrange=CellBasedModels.lengthProperties(uNew.a) function agent_length(uNew, u, p, t)
            i = @index(Global)
            u.a.length[i] = 0.0
            for j in iterateRow(u.topo[:a,:e], i)
                u.a.length[i] += u.e.length[j]
            end
        end
    end

    for backend in backends

        #Initialize the object
        obj = createObject(model, [
            [(0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (1.0, 1.0, 0.0)],  # Agent 1: 2 edges of length 1
            [(0.0, 0.0, 0.0), (0.0, 1.0, 0.0)],  # Agent 2: 1 edge of length 1
        ])
        obj_device = toBackend(obj, backend)

        #Define the problem
        problem = CBProblem(
            model,
            obj_device
        )

        integrator = init(problem, dt=0.1)

        step!(integrator)

        @test all(isapprox.(toBackend(integrator.u.e.length, CPU()), 1.0; atol=1e-2))
        @test all(isapprox.(toBackend(integrator.u.a.length, CPU()), [2.0, 1.0]; atol=1e-2))
    
    end

    #v2
    model2 = AgentPolyline(
        3,
    )

    @addRule model=model2 function model_length2(uNew, u, p, t)
        @kernel_launch ndrange=CellBasedModels.lengthProperties(uNew.e) function edge_length(uNew, u, p, t)
            i = @index(Global)

            rel_e_n = u.topo[:e,:n]
            (n1, n2) = getRow(rel_e_n, i, Val(2))
            u.e.length[i] = sqrt((u.n.x[n1] - u.n.x[n2])^2 + (u.n.y[n1] - u.n.y[n2])^2 + (u.n.z[n1] - u.n.z[n2])^2)

            rel_e_a = u.topo[:e,:a]
            a = rel_e_a[i, 1]
            @atomic u.a.length[a] += u.e.length[i]
            
        end

        @kernel_launch ndrange=CellBasedModels.lengthProperties(uNew.n) function node_angle(uNew, u, p, t)
            i = @index(Global)

            rel_n_n = u.topo[:n,:n]
            (n1, n2) = getRow(rel_n_n, i, Val(2))
            if n1 != 0 && n2 != 0
                vx, vy, vz = @cross(u.n.x[n2] - u.n.x[i], u.n.y[n2] - u.n.y[i], u.n.z[n2] - u.n.z[i], u.n.x[n1] - u.n.x[i], u.n.y[n1] - u.n.y[i], u.n.z[n1] - u.n.z[i])
                u.n.angle[i] = @norm(vx, vy, vz)
            end
            
        end

    end

    for backend in backends

        #Initialize the object
        obj = createObject(model2, [
            [(0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (1.0, 1.0, 0.0)],  # Agent 1: 2 edges of length 1
            [(0.0, 0.0, 0.0), (0.0, 1.0, 0.0)],  # Agent 2: 1 edge of length 1
        ])
        obj_device = toBackend(obj, backend)

        #Define the problem
        problem = CBProblem(
            model2,
            obj_device
        )

        integrator = init(problem, dt=0.1)

        step!(integrator)

        @test all(isapprox.(toBackend(integrator.u.e.length, CPU()), 1.0; atol=1e-2))
        @test all(isapprox.(toBackend(integrator.u.a.length, CPU()), [2.0, 1.0]; atol=1e-2))
        @test all(isapprox.(toBackend(integrator.u.n.angle, CPU()), [0.0, 1.0, 0.0, 0.0, 0.0]; atol=1e-2))
    
    end

end