@testset "model" begin

    if CUDA.has_cuda()
        testplatforms = ["cpu","gpu"]
    else
        testplatforms = ["cpu"]
    end

    for integrator in ["Heun"]#keys(AgentBasedModels.addIntegrator_!)
        for platform in testplatforms

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
            
            m = @agent(
                Hola,
                
                [x,y,z]::Local,
                
                Equation = 
                begin
                    ∂x = -x*dt 
                    ∂y = 0*dt 
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

                if !prod(abs.(comt.x[1,1:end] .- exp.(-comt.t)) .< 0.02) error() end
                if !prod(comt.y[1,1:end] .≈ 2 ) error() end
                if !prod(comt.z[1,1:end] .≈ comt.t) error() end
            end

        end
    end

end