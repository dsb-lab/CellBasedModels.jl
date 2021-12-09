@testset "integrators" begin

    for integrator in keys(AgentBasedModels.addIntegrator_!)
        for platform in testplatforms

            #Declare
            @test_nowarn begin
                m = @agent(
                    3,
                    
                    Equation = 
                    begin
                        d(x) = x*dt 
                        d(y) = 0*dt 
                        d(z) = 1*dt
                    end
                )
                m = compile(m, integrator=integrator, platform=platform, debug=false)
            end
            
            #ODE
            m = @agent(
                3,
                
                Equation = 
                begin
                    d(x) = -x*dt 
                    d(z) = 1*dt
                end
            )
            m = compile(m, integrator=integrator, platform=platform, debug=false)
            #println(m.program)
            com = Community(m,N = 10)
            com.x .= 1.
            com.y .= 2.
            com.z .= 0.
            comt = m.evolve(com,dt=0.01,tMax=5)

            @test all(abs.(comt.x[1:end,1] .- exp.(-comt.t)) .< 0.02)
            @test all(comt.y[1:end,1] .≈ 2 )
            @test all(abs.(comt.z[1:end,1] .- comt.t) .< 0.005)

            #SDE
            m = @agent(
                3,
                
                Equation = 
                begin
                    d(x) = -0*dt + dW
                    d(y) = -0*dt + dW
                end
            )
            m = compile(m, integrator=integrator, platform=platform, debug=false)
            #println(m.program)
            com = Community(m,N = 5000)
            com.x .= 0.
            com.y .= 0.
            comt = m.evolve(com,dt=0.01,tMax=5)

            @test begin
                v = [var(comt.x[i,:]) for i in 1:size(comt.x)[1]]
                all(abs.(v .- comt.t) .< 0.8)
            end
            @test comt.x[:,1] != comt.y[:,1]

        end
    end

end