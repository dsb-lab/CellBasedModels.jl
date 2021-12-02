fBoundary1D(x,t) = x > 0 ? 1 : 0
fBoundary2D_x(x,y,t) = x > 0 ? 1 : 0
fBoundary2D_y(x,y,t) = y > 0 ? 1 : 0

@testset "Medium" begin

    #Test we can call the variable and the function
    @test_throws ErrorException try @eval @agent(1, u::Medium) catch err; throw(err.error) end
    @test begin m = @agent(1, u::Medium, Boundary = BoundaryFlat(1)); m.declaredSymbols["Medium"] == [:u] end
    @test begin m = @agent(1, [u,v]::Medium, Boundary = BoundaryFlat(1)); m.declaredSymbols["Medium"] == [:u,:v] end
    @test begin m = @agent(1, UpdateMedium = ∂t_u = Δ(u) + δx(0.)*δy(0.)*1.); "UpdateMedium" in keys(m.declaredUpdates) end

    #Medium access in Community
    m = @agent(3, 
        [u,v]::Medium,
        Boundary = BoundaryFlat(3,Bounded(),Bounded(),Bounded())            
        )
    mc = compile(m)
    # println(mc.program)
    com = Community(mc,N=10,mediumN=[10,10,10])

    #Check call and boundary
    @test_nowarn b = com.u #Read
    @test_nowarn com.v .= 1 #Assign scalar
    @test_nowarn com.v .= zeros(10,10,10) #Assign vector
    @test_nowarn com.v[1,2,3] = 1; #Assign single value

    @test begin 
        com.u .= 0
        com.simulationBox .= [-10 10;-10 10;-10 10]
        comt = mc.evolve(com,dt=0.1,tMax=1)
    
        all(comt[end].u .== zeros(10,10,10))
    end

    for platform in testplatforms

        #Dirichlet boundary

        # ## Default

        # ###Dim 1
        # m = @agent(1,
        #     [u,v]::Medium,

        #     UpdateMedium = ∂t_u = Δx(u),

        #     Boundary = BoundaryFlat(1,
        #                     Bounded(medium=Dirichlet()),
        #                     )
        #     )
        # mc = compile(m,platform=platform)
        # # println(mc.program)

        # @test begin #Test symmetric decay and loose of concentration
        #     com = Community(mc,N=10,mediumN=[10])
        #     com.u .= 1
        #     com.simulationBox .= [-10 10]
        #     comt = mc.evolve(com,dt=0.1,tMax=1000)
        #     all(comt[end].u .< 10E-8) && all(abs.(comt[100].u - reverse(comt[100].u)) .< 10E-8)
        # end

        # ###Dim 2
        # m = @agent(2,
        #     [u,v]::Medium,

        #     UpdateMedium = ∂t_u = Δx(u),

        #     Boundary = BoundaryFlat(2,
        #                     Bounded(medium=Dirichlet()),
        #                     Bounded(medium=Dirichlet()),
        #                     )
        #     )
        # mc = compile(m,platform=platform)
        # # println(mc.program)

        # @test begin #Test symmetric decay and loose of concentration
        #     com = Community(mc,N=10,mediumN=[10,15])
        #     com.u .= 1
        #     com.simulationBox .= [-10 10;-20 20]
        #     comt = mc.evolve(com,dt=0.1,tMax=1000)
        #     all(comt[end].u .< 10E-8) && all(abs.(comt[100].u - reverse(comt[100].u)) .< 10E-8)
        # end

        # ###Dim 3
        # m = @agent(3,
        #     [u,v]::Medium,

        #     UpdateMedium = ∂t_u = Δx(u),

        #     Boundary = BoundaryFlat(3,
        #                     Bounded(medium=Dirichlet()),
        #                     Bounded(medium=Dirichlet()),
        #                     Bounded(medium=Dirichlet()),
        #                     )
        #     )
        # mc = compile(m,platform=platform)
        # # println(mc.program)

        # @test begin #Test symmetric decay and loose of concentration
        #     com = Community(mc,N=10,mediumN=[5,10,15])
        #     com.u .= 1
        #     com.simulationBox .= [-10 10;-20 20;-30 30]
        #     comt = mc.evolve(com,dt=0.1,tMax=1000)
        #     all(comt[end].u .< 10E-8) && all(abs.(comt[100].u - reverse(comt[100].u)) .< 10E-8)
        # end

        ## With a user defined function

        ###Dim 1
        m = @agent(1,
            [u,v]::Medium,

            UpdateMedium = ∂t_u = Δx(u),

            Boundary = BoundaryFlat(1,
                            Bounded(medium=DirichletBoundaryCondition(fBoundary1D)),
                            )
            )
        mc = compile(m,platform=platform)
        # println(mc.program)

        @test begin #Test symmetric decay and loose of concentration
            com = Community(mc,N=10,mediumN=[10])
            com.u .= 1
            com.simulationBox .= [-10 10]
            comt = mc.evolve(com,dt=0.1,tMax=1000)
            all(abs.(comt[end].u .- range(0.1,.9, length=10)) .< 10E-3)
        end

        ###Dim 2
        m = @agent(2,
            [u,v]::Medium,

            UpdateMedium = ∂t_u = Δx(u),

            Boundary = BoundaryFlat(2,
                            Bounded(medium=DirichletBoundaryCondition(fBoundary2D_x)),
                            Bounded(medium=DirichletBoundaryCondition(fBoundary2D_y)),
                            )
            )
        mc = compile(m,platform=platform)
        # println(mc.program)

        @test begin #Test symmetric decay and loose of concentration
            com = Community(mc,N=10,mediumN=[5,5])
            com.u .= 1
            com.simulationBox .= [-10 10;-20 20]
            comt = mc.evolve(com,dt=0.1,tMax=1000)
            m = range(0.1,.9, length=5)*reshape(range(0.1,.9, length=5),1,5)
            println(comt[end].u)
            all(abs.(comt[end].u .- m) .< 10E-3)
        end

        # ###Dim 3
        # m = @agent(3,
        #     [u,v]::Medium,

        #     UpdateMedium = ∂t_u = Δx(u),

        #     Boundary = BoundaryFlat(3,
        #                     Bounded(medium=Dirichlet(fBoundary)),
        #                     Bounded(medium=Dirichlet(fBoundary)),
        #                     Bounded(medium=Dirichlet(fBoundary)),
        #                     )
        #     )
        # mc = compile(m,platform=platform)
        # # println(mc.program)

        # @test begin #Test symmetric decay and loose of concentration
        #     com = Community(mc,N=10,mediumN=[5,10,15])
        #     com.u .= 1
        #     com.simulationBox .= [-10 10;-20 20;-30 30]
        #     comt = mc.evolve(com,dt=0.1,tMax=1000)
        #     all(comt[end].u .< 10E-8) && all(abs.(comt[100].u - reverse(comt[100].u)) .< 10E-8)
        # end

    end

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

    #     #1D
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

    #     #2D
    #     m = @agent(2, [u,v]::Medium, UpdateMedium = ∂t_u = Δx(u) + Δy(u)) 
    #     s = SimulationFree(m,
    #                     box=[(:x,-20.,20.),(:y,-20.,20.)],
    #                     medium=[MediumFlat("Periodic",100),MediumFlat("Periodic",100)])
    #     mc = compile(m,s,platform=i)
    #     com = Community(mc,N=10)
    #     com.u .= 1
    #     # println(mc.program)
    #     @test_nowarn mc.evolve(com,dt=0.1,tMax=.2)
    #     @test begin 
    #         comt = mc.evolve(com,dt=0.01,tMax=10,dtSave=1)
    #         (sum(comt[end].u) .- sum(comt[1].u))/10000 < 0.01
    #     end

    #     #3D
    #     m = @agent(3, [u,v]::Medium, UpdateMedium = ∂t_u = Δx(u) + Δy(u) + Δz(u)) 
    #     s = SimulationFree(m,
    #                     box=[(:x,-20.,20.),(:y,-20.,20.),(:z,-20.,20.)],
    #                     medium=[MediumFlat("Periodic",100),MediumFlat("Periodic",100),MediumFlat("Periodic",100)])
    #     mc = compile(m,s,platform=i)
    #     com = Community(mc,N=10)
    #     com.u .= 1
    #     # println(mc.program)
    #     @test_nowarn mc.evolve(com,dt=0.1,tMax=.2)
    #     @test begin 
    #         comt = mc.evolve(com,dt=0.01,tMax=10,dtSave=1)

    #         (sum(comt[end].u) .- sum(comt[1].u))/1000000 < 0.01
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

    # for i in testplatforms #Check coumpling agents with medium

    #     m = @agent(1,
    #             p::Local, 
    #             [u,v]::Medium, 
    #             UpdateMedium = begin
    #                 ∂t_u = Δx(u)
    #                 ∂t_v = Δx(v) + δx(0.)
    #             end,
    #             UpdateMediumInteraction = u += p*dt
    #             )
    #     s = SimulationFree(m,
    #                     box=[(:x,-20.,20.)],
    #                     medium=[MediumFlat("Dirichlet",100)])
    #     mc = compile(m,s,platform=i)
    #     com = Community(mc,N=1)
    #     com.u .= 0.
    #     com.v .= 0.
    #     com.x .= 0.
    #     com.p .= 1.
    #     # println(mc.program)
    #     @test_nowarn mc.evolve(com,dt=0.1,tMax=.2)
    #     @test begin 
    #         comt = mc.evolve(com,dt=0.01,tMax=4000,dtSave=200)

    #         all(abs.(comt[end].u .- comt[end].v) .< 0.1)
    #     end

    # end

    # for i in testplatforms #Check agents reading from medium

    #     m = @agent(1,
    #             p::Local, 
    #             u::Medium, 
    #             k::Global,

    #             Equation = begin
    #                 d_p = (u-k*p)*dt 
    #             end
    #             )
    #     s = SimulationFree(m,
    #                     box=[(:x,0.,100.)],
    #                     medium=[MediumFlat("Dirichlet",100)])
    #     mc = compile(m,s,platform=i)
    #     com = Community(mc,N=100)
    #     com.x .= [Float64(i) for i in 0:1:99]
    #     com.u .= [Float64(i) for i in 0:99]
    #     com.k = 1.
    #     com.p .= 0.
    #     # println(mc.program)
    #     @test_nowarn mc.evolve(com,dt=0.1,tMax=.2)
    #     @test begin 
    #         comt = mc.evolve(com,dt=0.01,tMax=4000,dtSave=200)
    #         all(comt[end].p .<= [Float64(i) for i in 0:1:99])
    #     end

    # end

end