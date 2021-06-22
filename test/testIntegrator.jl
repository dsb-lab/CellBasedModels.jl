@testset "model" begin

    if CUDA.has_cuda()
        testplatforms = ["cpu","gpu"]
    else
        testplatforms = ["cpu"]
    end

    for integrator in keys(AgentBasedModels.addIntegrator_!)
        for platform in testplatforms

            #Declare
            @test_nowarn begin
                m = @agent(
                    Hola,
                    
                    [x,y,z]::Local,
                    
                    Equation = 
                    begin
                        ∂x = x*dt 
                        ∂y = 0*dt 
                        ∂z = 1*dt
                    end
                )
                m = compile(m, integrator=integrator, platform=platform, debug=false)
            end
            
            #ODE
            m = @agent(
                Hola,
                
                [x,y,z]::Local,
                
                Equation = 
                begin
                    ∂x = -x*dt 
                    ∂z = 1*dt
                end
            )
            m = compile(m, integrator=integrator, platform=platform, debug=false)
            #println(m.program)

            @test_nowarn begin           
                com = Community(m,N = 10)

                com.x .= 1.
                com.y .= 2.
                com.z .= 0.
                comt = m.evolve(com,dt=0.01,tMax=5)

                if !prod(abs.(comt.x[1:end,1] .- exp.(-comt.t)) .< 0.02) error() end
                if !prod(comt.y[1:end,1] .≈ 2 ) error() end
                if !prod(comt.z[1:end,1] .≈ comt.t) error() end
            end

            #SDE
            m = @agent(
                Hola,
                
                [x,y,z]::Local,
                
                Equation = 
                begin
                    ∂x = -0*dt + dW
                end
            )
            m = compile(m, integrator=integrator, platform=platform, debug=false)
            #println(m.program)

            @test_nowarn begin           
                com = Community(m,N = 5000)

                com.x .= 0.
                comt = m.evolve(com,dt=0.01,tMax=5)

                v = [var(comt.x[i,:]) for i in 1:size(comt.x)[1]]
                if !prod(abs.(v .- comt.t) .< 0.8) error() end
            end

        end
    end

end