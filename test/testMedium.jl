fBoundary1D(x,t) = x > 0 ? 1 : 0
fBoundary2D_x(x,y,t) = 0
fBoundary2D_y(x,y,t) = y > 0.5 ? 1 : 0
fBoundary3D(x,y,z,t) = 1

@testset "Medium" begin

    #Test we can call the variable and the function
    @test_throws ErrorException try @eval @agent(1, u::Medium) catch err; throw(err.error) end
    @test begin m = @agent(1, u::Medium, Boundary = BoundaryFlat(1)); m.declaredSymbols["Medium"] == [:u] end
    @test begin m = @agent(1, [u,v]::Medium, Boundary = BoundaryFlat(1)); m.declaredSymbols["Medium"] == [:u,:v] end
    @test begin m = @agent(1, UpdateMedium = ∂t(u) = Δ(u) + δx(0.)*δy(0.)*1.); "UpdateMedium" in keys(m.declaredUpdates) end

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

        ########################################################################################################33
        #Dirichlet boundary
        ########################################################################################################33

        ## Default

        ###Dim 1
        m = @agent(1,
            [u,v]::Medium,

            UpdateMedium = ∂t(u) = Δx(u),

            Boundary = BoundaryFlat(1,
                            Bounded(medium=DirichletBoundaryCondition()),
                            )
            )
        mc = compile(m,platform=platform)
        # println(mc.program)

        @test begin #Test symmetric decay and loose of concentration
            com = Community(mc,N=10,mediumN=[10])
            com.u .= 1
            com.simulationBox .= [-10 10]
            comt = mc.evolve(com,dt=0.1,tMax=1000)
            all(comt[end].u .< 10E-8) && all(abs.(comt[100].u - reverse(comt[100].u)) .< 10E-8)
        end

        ###Dim 2
        m = @agent(2,
            [u,v]::Medium,

            UpdateMedium = ∂t(u) = Δx(u),

            Boundary = BoundaryFlat(2,
                            Bounded(medium=DirichletBoundaryCondition()),
                            Bounded(medium=DirichletBoundaryCondition()),
                            )
            )
        mc = compile(m,platform=platform)
        # println(mc.program)

        @test begin #Test symmetric decay and loose of concentration
            com = Community(mc,N=10,mediumN=[10,15])
            com.u .= 1
            com.simulationBox .= [-10 10;-20 20]
            comt = mc.evolve(com,dt=0.1,tMax=1000)
            all(comt[end].u .< 10E-8) && all(abs.(comt[100].u - reverse(comt[100].u)) .< 10E-8)
        end

        ###Dim 3
        m = @agent(3,
            [u,v]::Medium,

            UpdateMedium = ∂t(u) = Δx(u),

            Boundary = BoundaryFlat(3,
                            Bounded(medium=DirichletBoundaryCondition()),
                            Bounded(medium=DirichletBoundaryCondition()),
                            Bounded(medium=DirichletBoundaryCondition()),
                            )
            )
        mc = compile(m,platform=platform)
        # println(mc.program)

        @test begin #Test symmetric decay and loose of concentration
            com = Community(mc,N=10,mediumN=[5,10,15])
            com.u .= 1
            com.simulationBox .= [-10 10;-20 20;-30 30]
            comt = mc.evolve(com,dt=0.1,tMax=1000)
            all(comt[end].u .< 10E-8) && all(abs.(comt[100].u - reverse(comt[100].u)) .< 10E-8)
        end

        ## With a user defined function

        ###Dim 1
        m = @agent(1,
            [u,v]::Medium,

            UpdateMedium = ∂t(u) = Δx(u),

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

            UpdateMedium = ∂t(u) = Δx(u) + Δy(u),

            Boundary = BoundaryFlat(2,
                            Bounded(medium=DirichletBoundaryCondition(fBoundary2D_x)),
                            Bounded(medium=DirichletBoundaryCondition(fBoundary2D_y)),
                            )
            )
        mc = compile(m,platform=platform)
        # println(mc.program)

        @test begin #Test symmetric decay and loose of concentration
            Nx = 10; Ny = 10
            com = Community(mc,N=0,mediumN=[Nx,Ny])
            com.u .= 1
            com.simulationBox .= [0 1;0 1]
            comt = mc.evolve(com,dt=0.001,tMax=2000)
            m = zeros(Nx,Ny)
            for (i,x) in enumerate(range(1/Nx,(Nx-1)/Nx,length=Nx))
                for (j,y) in enumerate(range(1/Ny,(Ny-1)/Ny,length=Ny))
                    for n in 1:2:40
                        m[i,j] += 4/(π*n*sinh(π*n))*sinh(n*π*y)*sin(n*π*x)
                    end
                end
            end
            all(abs.(comt[end].u .- m) .< 10E-2)
        end

        ###Dim 3
        m = @agent(3,
            [u,v]::Medium,

            UpdateMedium = ∂t(u) = Δx(u),

            Boundary = BoundaryFlat(3,
                            Bounded(medium=DirichletBoundaryCondition(fBoundary3D)),
                            Bounded(medium=DirichletBoundaryCondition(fBoundary3D)),
                            Bounded(medium=DirichletBoundaryCondition(fBoundary3D)),
                            )
            )
        mc = compile(m,platform=platform)
        # println(mc.program)

        @test begin #Test symmetric decay and loose of concentration
            com = Community(mc,N=10,mediumN=[5,10,15])
            com.u .= 0
            com.simulationBox .= [-10 10;-20 20;-30 30]
            comt = mc.evolve(com,dt=0.1,tMax=1000)
            all(comt[end].u .- 1 .< 10E-8)
        end

        #######################################################################################################33
        #Newmann boundary
        #######################################################################################################33

        ## Default

        ###Dim 1
        m = @agent(1,
            [u,v]::Medium,

            UpdateMedium = ∂t(u) = Δx(u),

            Boundary = BoundaryFlat(1,
                            Bounded(medium=NewmannBoundaryCondition()),
                            )
            )
        mc = compile(m,platform=platform)
        # println(mc.program)

        @test begin #Test conservation of matter and homogeneization
            Nx = 10
            com = Community(mc,N=10,mediumN=[10])
            com.u .= exp.(- (range(0,Nx,length=Nx).-Nx/2).^2)
            com.simulationBox .= [-10 10]
            comt = mc.evolve(com,dt=0.1,tMax=1000)
            all( sum(comt[1].u) .- sum(comt[end].u) .< 0.02 ) && (abs(minimum(comt[end].u) - maximum(comt[end].u)) .< 10E-4)
        end

        ###Dim 2
        m = @agent(2,
            [u,v]::Medium,

            UpdateMedium = ∂t(u) = Δx(u) + Δy(u),

            Boundary = BoundaryFlat(2,
                            Bounded(medium=NewmannBoundaryCondition()),
                            Bounded(medium=NewmannBoundaryCondition())
                            )
            )
        mc = compile(m,platform=platform)
        # println(mc.program)

        @test begin #Test conservation of matter and homogeneization
            Nx = 10; Ny = 10
            com = Community(mc,N=10,mediumN=[Nx,Ny])
            for (i,x) in enumerate(range(0,Nx,length=Nx))
                for (j,y) in enumerate(range(0,Ny,length=Ny))
                    com.u[i,j] = exp.(- (i.-Nx/2).^2- (j.-Ny/2).^2)
                end
            end
            com.simulationBox .= [-10 10;-10 10]
            comt = mc.evolve(com,dt=0.1,tMax=1000)
            all( sum(comt[1].u) .- sum(comt[end].u) .< 10E-1 ) && (minimum(comt[end].u) - maximum(comt[end].u) .< 10E-2)
        end

        ###Dim 2
        m = @agent(3,
            [u,v]::Medium,

            UpdateMedium = ∂t(u) = Δx(u) + Δy(u) + Δz(u),

            Boundary = BoundaryFlat(3,
                            Bounded(medium=NewmannBoundaryCondition()),
                            Bounded(medium=NewmannBoundaryCondition()),
                            Bounded(medium=NewmannBoundaryCondition())
                            )
            )
        mc = compile(m,platform=platform)
        # println(mc.program)

        @test begin #Test conservation of matter and homogeneization
            Nx = 10; Ny = 10; Nz = 10
            com = Community(mc,N=10,mediumN=[Nx,Ny,Nz])
            for (i,x) in enumerate(range(0,Nx,length=Nx))
                for (j,y) in enumerate(range(0,Ny,length=Ny))
                    for (k,z) in enumerate(range(0,Nz,length=Nz))
                        com.u[i,j,k] = exp.(- (i.-Nx/2).^2 - (j.-Ny/2).^2 - (k.-Nz/2).^2)
                    end
                end
            end
            com.simulationBox .= [-10 10;-10 10;-10 10]
            comt = mc.evolve(com,dt=0.1,tMax=1000)
            all( sum(comt[1].u) .- sum(comt[end].u) .< 10E-1 ) && (minimum(comt[end].u) - maximum(comt[end].u) .< 10E-2)
        end

        ########################################################################################################33
        #Delta sources
        ########################################################################################################33

        ##1 dim
        m = @agent(1, 
                    [u,v]::Medium, 
                    # UpdateMedium = ∂t(u) = Δx(u) + δx(0.), 
                    Boundary = BoundaryFlat(1,Bounded())
                    )
        mc = compile(m,platform=platform)
        # println(prettify(mc.program))
        com = Community(mc,N=10,mediumN=[30])
        com.u .= 0
        com.simulationBox .= [-10 10]
        @test_nowarn mc.evolve(com,dt=0.1,tMax=.2)
        @test begin 
            comt = mc.evolve(com,dt=0.01,tMax=4000,dtSave=200)

            all(abs.(comt[end].u .- comt[10].u) .< 0.001)
        end

        ##2 dim
        m = @agent(2, [u,v]::Medium, UpdateMedium = ∂t(u) = Δx(u) + Δy(u) + δx(0.) + δy(0.), Boundary = BoundaryFlat(2,Bounded(),Bounded()))
        mc = compile(m,platform=platform)
        # println(mc.program)
        com = Community(mc,N=10,mediumN=[30,30])
        com.u .= 0
        com.simulationBox .= [-10 10; -10 10]
        @test_nowarn mc.evolve(com,dt=0.1,tMax=.2)
        @test begin 
            comt = mc.evolve(com,dt=0.01,tMax=4000,dtSave=200)

            all(abs.(comt[end].u .- transpose(comt[10].u)) .< 0.001)
        end

        ##3 dim
        m = @agent(3, 
                    [u,v]::Medium, 
                    UpdateMedium = ∂t(u) = Δx(u) + Δy(u) + Δz(u) + δx(0.) + δy(0.) + δz(0.),
                    Boundary = BoundaryFlat(3,Bounded(),Bounded(),Bounded()))
        mc = compile(m,platform=platform)
        # println(mc.program)
        com = Community(mc,N=10,mediumN=[5,5,5])
        com.u .= 0
        com.simulationBox .= [-10 10; -10 10; -10 10]
        @test_nowarn mc.evolve(com,dt=0.1,tMax=.2)
        @test begin 
            comt = mc.evolve(com,dt=0.01,tMax=4000,dtSave=200)

            all(abs.(comt[end].u .- comt[10].u) .< 0.001)
        end

        ########################################################################################################33
        #Coupling sources
        ########################################################################################################33


        ########################################################################################################33
        #Agents reading from medium
        ########################################################################################################33


    end

    # for i in testplatforms #Check coumpling agents with medium

    #     m = @agent(1,
    #             p::Local, 
    #             [u,v]::Medium, 
    #             UpdateMedium = begin
    #                 ∂t(u) = Δx(u)
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

    #             UpdateVariable = begin
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