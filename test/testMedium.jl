@testset "Medium" begin

    # #Test we can call the variable and the function
    # @test begin m = @agent(1, u::Medium); m.declaredSymbols["Medium"] == [:u] end
    # @test begin m = @agent(1, [u,v]::Medium); m.declaredSymbols["Medium"] == [:u,:v] end
    # @test begin m = @agent(1, UpdateMedium = ∂t_u = Δ(u) + δx(0.)*δy(0.)*1.); "UpdateMedium" in keys(m.declaredUpdates) end

    # # Declaration of Mediums
    # for j in ["Newmann",
    #     "Dirichlet",
    #     "Periodic",
    #     "Newmann-Newmann",
    #     "Dirichlet-Dirichlet",
    #     "Periodic-Periodic",
    #     "Newmann-Dirichlet",
    #     "Dirichlet-Newmann"]

    #     @test_nowarn MediumFlat(j,10)
    # end

    # for j in ["Newmann-Periodic",
    #     "Dirichlet-Periodic",
    #     "Periodic-Dirichlet",
    #     "Periodic-Newmann"]

    #     @test_throws ErrorException MediumFlat(j,10)
    # end

    # @test_throws ErrorException MediumFlat("k",10)

    # # Declaration of MediumFlat in spaces
    # for i in 1:3

    #     if i == 1
    #         m = @agent(1, u::Medium)
    #     elseif i == 2
    #         m = @agent(2, u::Medium)
    #     else
    #         m = @agent(3, u::Medium)
    #     end

    #     box = [(:x,-10.,10.),(:y,-10.,10.),(:z,-10.,10.)][1:i]
    #     medium = [MediumFlat("Newmann",10) for k in 1:i]
            
    #     @test_nowarn SimulationFree(m,box=box,medium=medium)
    #     @test_nowarn SimulationGrid(m,box,1.,medium=medium)
    # end

    # m = @agent(3, u::Medium)
    # @test_throws ErrorException SimulationFree(m,box=[(:x,0,1)],medium=[MediumFlat("Dirichlet",10)])
    # @test_throws ErrorException SimulationFree(m,box=[(:x,0,1)],medium=[MediumFlat("Dirichlet",10),MediumFlat("Dirichlet",10)])

    # # Compilation
    # for i in testplatforms
    #     @test_nowarn begin
    #         m = @agent(3, u::Medium)
    #         s = SimulationFree(m,
    #                         box=[(:x,-10.,10.),(:y,-10.,10.),(:z,-10.,10.)],
    #                         medium=[MediumFlat("Dirichlet",10),MediumFlat("Dirichlet",10),MediumFlat("Dirichlet",10)])
    #         compile(m,s,platform=i)
    #     end
    # end

    # # Community construction
    # @test_nowarn begin
    #     m = @agent(3, u::Medium)
    #     s = SimulationFree(m,
    #                     box=[(:x,-10.,10.),(:y,-10.,10.),(:z,-10.,10.)],
    #                     medium=[MediumFlat("Dirichlet",10),MediumFlat("Dirichlet",10),MediumFlat("Dirichlet",10)])
    #     mc = compile(m,s)

    #     Community(mc,N=10)
    # end

    # # Medium access in Community
    # @test_nowarn begin
    #     m = @agent(3, [u,v]::Medium)
    #     s = SimulationFree(m,
    #                     box=[(:x,-10.,10.),(:y,-10.,10.),(:z,-10.,10.)],
    #                     medium=[MediumFlat("Dirichlet",10),MediumFlat("Dirichlet",10),MediumFlat("Dirichlet",10)])
    #     mc = compile(m,s)

    #     com = Community(mc,N=10)

    #     b = com.u #Read
    #     com.v .= 1 #Assign scalar
    #     com.v .= zeros(10,10,10) #Assign vector
    #     com.v[1,2,3] = 1 #Assign single value
    # end

    # # Evolve Community Save Working
    # for i in testplatforms
    #     for j in ["RAM","CSV"]
    #         for medium in [[MediumFlat("Dirichlet",10),MediumFlat("Dirichlet",10),MediumFlat("Dirichlet",10)],
    #                 [MediumFlat("Periodic",10),MediumFlat("Dirichlet",10),MediumFlat("Dirichlet",10)],
    #                 [MediumFlat("Dirichlet",10),MediumFlat("Periodic",10),MediumFlat("Dirichlet",10)],
    #                 [MediumFlat("Dirichlet",10),MediumFlat("Dirichlet",10),MediumFlat("Periodic",10)],
    #                 [MediumFlat("Periodic",10),MediumFlat("Periodic",10),MediumFlat("Dirichlet",10)],
    #                 [MediumFlat("Periodic",10),MediumFlat("Dirichlet",10),MediumFlat("Periodic",10)],
    #                 [MediumFlat("Dirichlet",10),MediumFlat("Periodic",10),MediumFlat("Periodic",10)],
    #                 [MediumFlat("Periodic",10),MediumFlat("Periodic",10),MediumFlat("Periodic",10)]
    #                         ]

    #             m = @agent(3, [u,v]::Medium)
    #             s = SimulationFree(m,
    #                             box=[(:x,-10.,10.),(:y,-10.,10.),(:z,-10.,10.)],
    #                             medium=medium)
    #             mc = compile(m,s,platform=i,save=j)
    #             com = Community(mc,N=10)
    #             @test_nowarn mc.evolve(com,dt=0.1,tMax=10.)
    #         end

    #         dir = readdir("./")
    #         for i in dir
    #             if occursin(".csv",i)
    #                 rm(i)
    #             end
    #         end
    #     end
    # end

    # # Test appropiate Update working
    # for i in testplatforms
    #     m = @agent(3, [u,v]::Medium, UpdateMedium = ∂t_u = 1)
    #     s = SimulationFree(m,
    #                     box=[(:x,-1.,1.),(:y,-1.,1.),(:z,-1.,1.)],
    #                     medium=[MediumFlat("Newmann",10),MediumFlat("Newmann",10),MediumFlat("Newmann",10)])
    #     mc = compile(m,s,platform=i)
    #     com = Community(mc,N=10)
    #     com.u .= 0
    #     com.v .= 1
    #     @test_nowarn mc.evolve(com,dt=0.1,tMax=.2)
    #     @test begin 
    #         comt = mc.evolve(com,dt=0.1,tMax=.2)

    #         all(comt[end].u .≈ 0.2)
    #     end
    #     @test begin 
    #         comt = mc.evolve(com,dt=0.1,tMax=.2)

    #         all(comt[end].v .≈ 1.)
    #     end
    # end

    # for i in testplatforms #Test single deltas working
    #     m = nothing
    #     for j in 1:3
    #         if j == 1
    #             m = @agent(3, [u,v]::Medium, UpdateMedium = ∂t_u = δx(0.)*1)
    #         elseif j == 2
    #             m = @agent(3, [u,v]::Medium, UpdateMedium = ∂t_u = δy(0.)*1)
    #         elseif j == 3
    #             m = @agent(3, [u,v]::Medium, UpdateMedium = ∂t_u = δz(0.)*1)
    #         end
        
    #         s = SimulationFree(m,
    #                         box=[(:x,-1.,1.),(:y,-2.,2.),(:z,-3.,3.)],
    #                         medium=[MediumFlat("Newmann",10),MediumFlat("Newmann",100),MediumFlat("Newmann",1000)])
    #         mc = compile(m,s,platform=i)
    #         com = Community(mc,N=10)
    #         com.u .= 0
    #         com.v .= 1
    #         comt = mc.evolve(com,dt=0.1,tMax=.2)
    #         @test_nowarn mc.evolve(com,dt=0.1,tMax=.2)
    #         if j == 1
    #             @test sum(comt[end].u[5,:,:] .≈ 0.2) == 100000
    #         elseif j == 2
    #             @test sum(comt[end].u[:,50,:] .≈ 0.2) == 10000
    #         elseif j == 3
    #             @test sum(comt[end].u[:,:,500] .≈ 0.2) == 1000
    #         end
    #     end
    # end

    # for i in testplatforms #Test joint deltas working
    #     m = @agent(3, [u,v]::Medium, UpdateMedium = ∂t_u = δx(0.)*δy(0.)*δz(0.)*1)
    #     s = SimulationFree(m,
    #                     box=[(:x,-1.,1.),(:y,-1.,1.),(:z,-1.,1.)],
    #                     medium=[MediumFlat("Newmann",10),MediumFlat("Newmann",10),MediumFlat("Newmann",10)])
    #     mc = compile(m,s,platform=i)
    #     com = Community(mc,N=10)
    #     com.u .= 0
    #     com.v .= 1
    #     @test_nowarn mc.evolve(com,dt=0.1,tMax=.2)
    #     @test begin 
    #         comt = mc.evolve(com,dt=0.1,tMax=.2)

    #         sum(comt[end].u .≈ 0.2) == 1
    #     end
    # end

    # for i in testplatforms #Check diffussion is conservative Periodic

    #     m = @agent(1, [u,v]::Medium, UpdateMedium = ∂t_u = Δx(u))
    #     s = SimulationFree(m,
    #                     box=[(:x,-20.,20.)],
    #                     medium=[MediumFlat("Periodic",100)])
    #     mc = compile(m,s,platform=i)
    #     com = Community(mc,N=10)
    #     com.u .= pdf.(Normal(0,0.5),range(-20,20,length=100))
    #     # println(mc.program)
    #     @test_nowarn mc.evolve(com,dt=0.1,tMax=.2)
    #     @test begin 
    #         comt = mc.evolve(com,dt=0.01,tMax=1000,dtSave=100)

    #         sum(comt[end].u) .≈ sum(comt[1].u)
    #     end
    #     @test begin 
    #         comt = mc.evolve(com,dt=0.01,tMax=1000,dtSave=100)

    #         maximum(comt[end].u) .≈ minimum(comt[end].u)
    #     end
    # end

    # for i in testplatforms #Check diffussion disappears Dirichlet

    #     m = @agent(1, [u,v]::Medium, UpdateMedium = ∂t_u = Δx(u))
    #     s = SimulationFree(m,
    #                     box=[(:x,-20.,20.)],
    #                     medium=[MediumFlat("Dirichlet",100)])
    #     mc = compile(m,s,platform=i)
    #     com = Community(mc,N=10)
    #     com.u .= pdf.(Normal(0,0.5),range(-20,20,length=100))
    #     # println(mc.program)
    #     @test_nowarn mc.evolve(com,dt=0.1,tMax=.2)
    #     @test begin 
    #         comt = mc.evolve(com,dt=0.01,tMax=2000,dtSave=100)

    #         sum(comt[end].u) < 0.001
    #     end

    # end

    # for i in testplatforms #Check diffussion conservative when Newmann

    #     m = @agent(1, [u,v]::Medium, UpdateMedium = ∂t_u = Δx(u))
    #     s = SimulationFree(m,
    #                     box=[(:x,-20.,20.)],
    #                     medium=[MediumFlat("Newmann",100)])
    #     mc = compile(m,s,platform=i)
    #     com = Community(mc,N=10)
    #     com.u .= pdf.(Normal(0,0.5),range(-20,20,length=100))
    #     # println(mc.program)
    #     @test_nowarn mc.evolve(com,dt=0.1,tMax=.2)
    #     @test begin 
    #         comt = mc.evolve(com,dt=0.01,tMax=2000,dtSave=100)

    #         sum(comt[end].u)-sum(comt[1].u) < 0.1
    #     end

    # end

    # for i in testplatforms #Check steady state with source

    #     m = @agent(1, [u,v]::Medium, UpdateMedium = ∂t_u = Δx(u) + δx(0.))
    #     s = SimulationFree(m,
    #                     box=[(:x,-20.,20.)],
    #                     medium=[MediumFlat("Dirichlet",100)])
    #     mc = compile(m,s,platform=i)
    #     com = Community(mc,N=10)
    #     com.u .= 0
    #     # println(mc.program)
    #     @test_nowarn mc.evolve(com,dt=0.1,tMax=.2)
    #     @test begin 
    #         comt = mc.evolve(com,dt=0.01,tMax=4000,dtSave=200)

    #         all(abs.(comt[end].u .- comt[10].u) .< 0.001)
    #     end

    # end

    for i in testplatforms #Check steady state with source

        m = @agent(1,
                p::Local, 
                [u,v]::Medium, 
                UpdateMedium = begin
                    ∂t_u = Δx(u)
                    ∂t_v = Δx(v) + δx(0.)
                end,
                UpdateMediumInteraction = u += p*dt
                )
        s = SimulationFree(m,
                        box=[(:x,-20.,20.)],
                        medium=[MediumFlat("Dirichlet",100)])
        mc = compile(m,s,platform=i)
        com = Community(mc,N=1)
        com.u .= 0.
        com.v .= 0.
        com.x .= 0.
        com.p .= 1.
        # println(mc.program)
        @test_nowarn mc.evolve(com,dt=0.1,tMax=.2)
        @test begin 
            comt = mc.evolve(com,dt=0.01,tMax=4000,dtSave=200)

            all(abs.(comt[end].u .- comt[end].v) .< 0.1)
        end

    end

end