@testset "integrators" begin

    for integrator in ["Euler","Heun","RungeKutta4"]
        for platform in testplatforms

            #Declare
            @test_nowarn begin
                m = @agent(
                    3,
                    
                    UpdateVariable = 
                    begin
                        d(x) = x*dt 
                        d(y) = 0*dt 
                        d(z) = 1*dt
                    end
                )
                m = compile(m, integrator=integrator, platform=platform)
            end
            
            #ODE
            m = @agent(
                3,
                
                UpdateVariable = 
                begin
                    d(x) = -x*dt 
                    d(z) = 1*dt
                end
            )
            m = compile(m, integrator=integrator, platform=platform)
            # println(m.program)
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
                
                UpdateVariable = 
                begin
                    d(x) = -0*dt + dW
                    d(y) = -0*dt + dW
                end
            )
            if integrator in ["Euler","Heun"]
                m = compile(m, integrator=integrator, platform=platform)
                # println(m.program)
                com = Community(m,N = 5000)
                com.x .= 0.
                com.y .= 0.
                comt = m.evolve(com,dt=0.01,tMax=5,dtSave=1)

                @test begin
                    v = [sum(comt.x[i,:].^2)/com.N-(sum(comt.x[i,:])/com.N)^2 for i in 1:size(comt.x)[1]]
                    all(abs.(v .- comt.t) .< 0.8)
                end
                @test comt.x[:,1] != comt.y[:,1]
            else
                @test_throws ErrorException m = compile(m, integrator=integrator, platform=platform)
            end

            #Interactions
            m = @agent(
                3,

                f::LocalInteraction,
                
                UpdateVariable = 
                begin
                    d(x) = -f*dt 
                end,

                UpdateInteraction=begin
                   if abs(x.i-x.j) < 1
                        f.i += 1*sign(x.j-x.i)
                   end 
                end
            )
            m = compile(m, integrator=integrator, platform=platform)
            #println(m.program)
            com = Community(m,N = 2)
            com.x .= [-.1,.1]
            comt = m.evolve(com,dt=0.01,tMax=5)
            @test comt.x[1:40,2]-comt.x[1:40,2] != range(.1,1,length=40)
            @test all(comt.x[41:end,1]-comt.x[41:end,2] != 1)

        end
    end

    for integrator in ["VerletVelocity"]
        for platform in testplatforms

            #Declare
            @test_nowarn begin
                m = @agent(
                    3,
                    v::Local,
                    
                    UpdateVariable = 
                    begin
                        d(x) = x*dt 
                        d(y) = 0*dt 
                        d(z) = 1*dt
                    end
                )
                m = compile(m, integrator=integrator, platform=platform, velocities=Dict([:x=>:v]))
            end

            #ODE
            m = @agent(
                1,
                v::Local,
                UpdateVariable = 
                begin
                    d(x) = v*dt 
                    d(v) = -v*dt
                end
            )
            m = compile(m, integrator=integrator, platform=platform, velocities=Dict([:x=>:v]))
            # println(m.program)
            com = Community(m,N = 10)
            com.x .= 1.
            com.v .= 10.
            comt = m.evolve(com,dt=0.01,tMax=5)
            @test all(abs.(comt.v[1:end,1] .- 10*exp.(-comt.t)) .< 0.02)
        end
    end
end