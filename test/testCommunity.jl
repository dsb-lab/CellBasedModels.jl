@testset "community" begin

    TESTPLATFORMS = [CPU(),GPU()]
    if CUDA.has_cuda()
        TESTPLATFORMS = [CPU(),GPU()]
    else
        TESTPLATFORMS = [CPU()]
    end

    #Create Community
    @test_nowarn Community()

    @test_nowarn begin
            abm = ABM(3,
            agent=OrderedDict(
                :li=>Int64,
                :lf=>Float64,
            ),
            model=OrderedDict(
                :gi=>Int64,
                :gf=>Float64,
                :ga=>Array{Float64}
            ),
            agentRule=quote 
                li += 1
            end,
        )

        com = Community(abm)
    end

    # ############################################################################
    # all step rules
    # ############################################################################
    for platform in TESTPLATFORMS
        @test begin
            #Create community
            abm = ABM(3,
                agent=OrderedDict(
                    :li=>Int64,
                    :lf=>Float64,
                    :ls=>Int64
                ),
                model=OrderedDict(
                    :gi=>Int64,
                    :gf=>Float64,
                    :ga=>Array{Float64},
                    :gdf=>Float64,
                    :gdf2=>Float64
                ),
                medium=OrderedDict(
                    :m=>Float64,
                    :m2=>Float64,
                    :mr=>Float64
                ),

                agentRule=quote 
                    li += m2
                    m2 += 1
                    ls = 0
                    @loopOverNeighbors for i2 in neighbors
                        if y[i2] ≈ 0.
                            ls += 1 
                        end
                    end
                    @loopOverNeighbors i2 begin
                        if y[i2] ≈ 0.
                            ls += 1 
                        end
                    end
                end,
                agentODE=quote
                    dt(x) = gf
                end,
                agentSDE=quote
                    dt(lf) = ga[1,1]
                end,

                modelRule=quote
                    ga[1,2] = 7
                    gi += 1
                end,
                modelODE=quote
                    dt(gf) = 1
                end,
                modelSDE=quote
                    dt(gf2) = 1
                end,

                mediumRule=quote
                    mr = 1
                end,
                mediumODE=quote
                    dt(m) = 1
                end,

                agentAlg = DifferentialEquations.EM(),
                modelAlg = DifferentialEquations.EM(),
                platform=platform
            )

            aa = Bool[]

            com = Community(abm,dt=.1,t=1.,N=10,id=1:10,NMedium=[5,5,5],simBox=[0 1;0 50;0 1])

            com.li = 0
            com.x = 0
            com.gf = 1
            com.m = 0
            com.mr = 0
            com.m2 = 1
            com.lf = ones(10)
            com.ga = [1 0; 0 1]

            push!(aa,all(com.li .== 0.))
            push!(aa,!(:li__ in keys(com.parameters)))
            push!(aa,all(com.ls .≈ .0))
            push!(aa,!(:ls__ in keys(com.parameters)))
            push!(aa,all(com.x .≈ .0))
            push!(aa,!(:x__ in keys(com.parameters)))
            push!(aa,all(com.ga .≈ [1 0;0 1]))
            push!(aa,!(:ga__ in keys(com.parameters)))
            push!(aa,all(com.m .≈ 0.))
            push!(aa,!(:m__ in keys(com.parameters)))
            push!(aa,all(com.mr .≈ 0.))
            push!(aa,!(:mr__ in keys(com.parameters)))
            push!(aa,com.dt == .1)
            push!(aa,com.t == 1.)
            push!(aa,com.N == 10)
            push!(aa,all(com.id .== 1:10))
            push!(aa,com.NMedium_ == [5,5,5])
            push!(aa,com.simBox == [0 1;0 50;0 1])

            loadToPlatform!(com)
            push!(aa,all(com.li .== 0.))
            push!(aa,all(com.li__ .== .0))
            push!(aa,all(com.ls .≈ 0))
            push!(aa,all(com.ls__ .≈ .0))
            push!(aa,all(com.x .≈ .0))
            push!(aa,all(com.x__ .≈ .0))
            push!(aa,all(Array(com.ga) .≈ [1 0;0 1]))
            push!(aa,all(Array(com.ga__) .≈ [1 0;0 1]))
            push!(aa,all(com.m .≈ 0.))
            push!(aa,all(com.m__ .≈ 0.))
            push!(aa,all(com.mr .≈ 0.))
            push!(aa,all(com.mr__ .≈ 0.))

            agentStepRule!(com)
            agentStepDE!(com)
            modelStepRule!(com)
            modelStepDE!(com)
            mediumStepRule!(com)
            mediumStepDE!(com)
            push!(aa,all(com.li .== 0.))
            push!(aa,all(com.li__ .== 1.))
            push!(aa,all(com.ls .≈ 0))
            push!(aa,all(com.ls__ .≈ 18))
            push!(aa,all(com.x .≈ .0))
            push!(aa,all(com.x__ .≈ .1))
            push!(aa,all(Array(com.ga) .≈ [1 0;0 1]))
            push!(aa,all(Array(com.ga__) .≈ [1 7;0 1]))
            push!(aa,all(com.m .≈ 0.))
            push!(aa,all(com.m__ .≈ .1))
            push!(aa,all(com.mr .≈ 0.))
            push!(aa,all(com.mr__ .≈ 1.))

            update!(com)
            push!(aa,all(com.li .== 1.))
            push!(aa,all(com.li__ .== 1.))
            push!(aa,all(com.ls .≈ 18))
            push!(aa,all(com.ls__ .≈ 18))
            push!(aa,all(com.x .≈ .1))
            push!(aa,all(com.x__ .≈ .1))
            push!(aa,all(Array(com.ga) .≈ [1 7;0 1]))
            push!(aa,all(Array(com.ga__) .≈ [1 7;0 1]))
            push!(aa,all(com.m .≈ .1))
            push!(aa,all(com.m__ .≈ .1))
            push!(aa,all(com.mr .≈ 1.))
            push!(aa,all(com.mr__ .≈ 1.))

            saveRAM!(com)
            saveJLD2("Hola.jld2",com, overwrite=true)

            push!(aa,all(com[end].li .== 1.))
            push!(aa,!(:li__ in keys(com[end].parameters)))
            push!(aa,all(com[end].ls .≈ 18))
            push!(aa,!(:ls__ in keys(com[end].parameters)))
            push!(aa,all(com[end].x .≈ .1))
            push!(aa,!(:x__ in keys(com[end].parameters)))
            push!(aa,all(Array(com[end].ga) .≈ [1 7;0 1]))
            push!(aa,!(:ga__ in keys(com[end].parameters)))
            push!(aa,all(com[end].m .≈ .1))
            push!(aa,!(:m__ in keys(com[end].parameters)))
            push!(aa,all(com[end].mr .≈ 1.))
            push!(aa,!(:mr__ in keys(com[end].parameters)))
            push!(aa,com[end].dt == .1)
            push!(aa,com[end].t == 1.1)
            push!(aa,com[end].N == 10)
            push!(aa,all(com[end].id .== 1:10))
            push!(aa,com[end].NMedium_ == [5,5,5])
            push!(aa,com[end].simBox == [0 1;0 50;0 1])

            bringFromPlatform!(com)

            push!(aa,all(com.li .== 1.))
            push!(aa,!(:li__ in keys(com.parameters)))
            push!(aa,all(com.ls .≈ 18))
            push!(aa,!(:ls__ in keys(com.parameters)))
            push!(aa,all(com.x .≈ .1))
            push!(aa,!(:x__ in keys(com.parameters)))
            push!(aa,all(Array(com.ga) .≈ [1 7;0 1]))
            push!(aa,!(:ga__ in keys(com.parameters)))
            push!(aa,all(com.m .≈ .1))
            push!(aa,!(:m__ in keys(com.parameters)))
            push!(aa,all(com.mr .≈ 1.))
            push!(aa,!(:mr__ in keys(com.parameters)))

            com = loadJLD2("Hola.jld2")
            push!(aa,all(com.li .== 1.))
            push!(aa,!(:li__ in keys(com.parameters)))
            push!(aa,all(com.ls .≈ 18))
            push!(aa,!(:ls__ in keys(com.parameters)))
            push!(aa,all(com.x .≈ .1))
            push!(aa,!(:x__ in keys(com.parameters)))
            push!(aa,all(Array(com.ga) .≈ [1 7;0 1]))
            push!(aa,!(:ga__ in keys(com.parameters)))
            push!(aa,all(com.m .≈ .1))
            push!(aa,!(:m__ in keys(com.parameters)))
            push!(aa,all(com.mr .≈ 1.))
            push!(aa,!(:mr__ in keys(com.parameters)))

            rm("Hola.jld2")

            all(aa)
        end
    end

    # ############################################################################
    # @addAgent, @removeAgent
    # ############################################################################
    for platform in TESTPLATFORMS
        @test begin
            abm = ABM(1,
                    agent=OrderedDict(
                        :lf=>Int64,
                    ),
                    agentRule = quote
                        x = x + 1.
                        if id%2 == 1
                            @removeAgent()
                        elseif id%2 == 0
                            @addAgent(lf = id)
                        end
                    end,
                    platform=platform
                    );
            N = 100
            com = Community(abm,N=N);
            loadToPlatform!(com,preallocateAgents=N÷2);
            agentStepRule!(com)
            aux = Bool[]
            if typeof(platform) <: CPU
            push!(aux,(com.N == N))
            push!(aux,(com.NAdd_[] .== N÷2))
            push!(aux,(com.NRemove_[] .== N÷2))
            push!(aux,(com.idMax_[] .== N+N÷2))
            push!(aux,(com.flagRecomputeNeighbors_[1] == 1))
            CUDA.@allowscalar push!(aux,all([i in com.lf[N+1:(N+N÷2)] for i in 2:2:N]))
            else 
            push!(aux,(com.N == N))
            push!(aux,all(com.NAdd_ .== N÷2))
            push!(aux,all(com.NRemove_ .== N÷2))
            push!(aux,all(com.idMax_ .== N+N÷2))
            push!(aux,all(com.flagRecomputeNeighbors_ .== 1))
            CUDA.@allowscalar push!(aux,all([i in com.lf[N+1:(N+N÷2)] for i in 2:2:N]))
            end
            update!(com)
            if typeof(platform) <: CPU
            push!(aux,(com.N == N))
            push!(aux,(com.NAdd_[] .== 0))
            push!(aux,(com.NRemove_[] .== 0))
            push!(aux,(com.idMax_[] .== N+N÷2))
            push!(aux,(com.flagRecomputeNeighbors_[1] == 1))
            push!(aux,all([i in com.lf[1:N] for i in 2:2:N]))
            else 
            push!(aux,(com.N == N))
            push!(aux,all(com.NAdd_ .== 0))
            push!(aux,all(com.NRemove_ .== 0))
            push!(aux,all(com.idMax_ .== N+N÷2))
            push!(aux,all(com.flagRecomputeNeighbors_ .== 1))
            CUDA.@allowscalar push!(aux,all([i in com.lf[1:N] for i in 2:2:N]))
            end
            all(aux)
        end
        @test begin
            result = false
            try
                model = ABM(3,
                    agentRule = quote
                        @removeAgent()
                    end,
                    platform=platform
                );
                
                com = Community(model, N=2, dt=0.1)
                
                evolve!(com, steps=10, preallocateAgents=10)    
                    
                result = true
            catch
                result = false
            end

            result
        end
    end
    
    # ############################################################################
    # Random
    # ############################################################################
    for platform in TESTPLATFORMS
        @test begin
            abm = ABM(1,
                    agent = Dict(
                        :norm => Float64,
                        :unif => Float64,
                        :expon => Float64
                    ),
        
                    agentRule = quote
                        norm = CBMDistributions.normal(1,2)
                        unif = CBMDistributions.uniform(1,2)
                        expon = CBMDistributions.exponential(3)
                    end,
                    platform=platform
                )
        
            N = 100000
            com = Community(abm,N=N)
        
            loadToPlatform!(com)
            agentStepRule!(com)
            update!(com)
            bringFromPlatform!(com)
        
            a = Bool[]
        
            push!(a, abs(sum(com.norm)/N - 1) < 0.05 )
            push!(a, abs(sum(com.norm.^2)/N-(sum(com.norm)/N)^2 - 4) < 0.05 )
            push!(a, abs(minimum(com.unif) - 1) < 0.05 )
            push!(a, abs(maximum(com.unif) - 2) < 0.05 )
            push!(a, abs(sum(com.expon)/N - 3) < 0.05 )
        
            all(a)
        end
    end

    # ############################################################################
    # Neighbors
    # ############################################################################
    for dims in [1,2,3]
        for neighbors in [
                            CBMNeighbors.Full(),
                            CBMNeighbors.VerletTime(skin=1.1,dtNeighborRecompute=1.,nMaxNeighbors=10),
                            CBMNeighbors.VerletDisplacement(skin=1.1,nMaxNeighbors=10),
                            CBMNeighbors.CellLinked(cellEdge=1),
                            CBMNeighbors.CLVD(skin=1.1,nMaxNeighbors=10,cellEdge=10)
                        ]
            for platform in TESTPLATFORMS
                @test begin 
                    abm = ABM(dims,
                        agent = OrderedDict(
                            :nn => Int64
                        ),
                        agentRule=
                            quote
                                nn = 0
                                @loopOverNeighbors i2_ begin 
                                    if CBMMetrics.@euclidean(i2_) < 1.1
                                        nn += 1 
                                    end
                                end
                            end,
                        neighborsAlg=neighbors
                    )
                    # println(abm.declaredUpdatesCode[:UpdateLocal])
                    com = Community(abm,
                                N=3^dims,
                                simBox=[.5 1.5;.5 1.5;.5 1.5][1:dims,:]);
                    v = zeros(3,27)
                    v[1,:] = repeat([repeat([0],1);repeat([1],1);repeat([2],1)],9)
                    v[2,:] = repeat([repeat([0],3);repeat([1],3);repeat([2],3)],3)
                    v[3,:] = repeat([repeat([0],9);repeat([1],9);repeat([2],9)],1)
                    for (j,sym) in enumerate([:x,:y,:z][1:dims])
                        getproperty(com,sym) .= v[j,1:3^(dims)]
                    end
                    loadToPlatform!(com);
                    computeNeighbors!(com);
                    agentStepRule!(com);
                    update!(com)
                    result = true
                    if dims == 1
                        result = all(Array(com.nn) .≈ [1,2,1])
                    elseif dims == 2
                        result = all(Array(com.nn) .≈ [2,3,2,3,4,3,2,3,2])
                    elseif dims == 3
                        result = all(Array(com.nn) .≈ [3,4,3,4,5,4,3,4,3,
                                                    4,5,4,5,6,5,4,5,4,
                                                    3,4,3,4,5,4,3,4,3])
                    end
                    result
                end
            end
        end
    end

    # ############################################################################
    # ODEs
    # ############################################################################
    for algorithm in [CBMIntegrators.Euler(),CBMIntegrators.Heun(),CBMIntegrators.RungeKutta4(),
                        DifferentialEquations.Euler(),DifferentialEquations.Heun()]
        for platform in TESTPLATFORMS
            @test begin
                abm = ABM(3,
                            agent = Dict(
                                :li => Int64,
                                :lii => Int64,
                                :lf => Float64,
                                :lfi => Float64,
                            ),
                            model = Dict(
                                :gf => Float64,
                                :gi => Int64,
                                :gfi => Float64,
                                :gii => Int64,
                            ),
                            medium = Dict(
                                :m => Float64
                            ),
                            agentODE=quote 
                                dt(x) = -0.5*x
                            end,

                            agentAlg=algorithm,
                            platform=platform
                        )
                com = Community(abm,N=3,NMedium=[2,2,2],
                                simBox=[0 1.;0 1;0 1],
                                x=1,
                                dt=.1);
                            
                loadToPlatform!(com);
            
                a = []
                for i in 1:100
                    agentStepDE!(com)
                    update!(com)
                    push!(a, all(abs.(com.agentDEProblem.u .- exp.(-.5 .* com.t)).<0.05))
                end
            
                all(a)
            end
        end
    end      
    
    # ############################################################################
    # SDEs
    # ############################################################################
    for algorithm in [CBMIntegrators.EM(),CBMIntegrators.EulerHeun(),DifferentialEquations.EM(),DifferentialEquations.EulerHeun()]
        for platform in TESTPLATFORMS
            @test begin
                abm = ABM(3,
                            agent = Dict(
                                :li => Int64,
                                :lii => Int64,
                                :lf => Float64,
                                :lfi => Float64,
                            ),
                            model = Dict(
                                :gf => Float64,
                                :gi => Int64,
                                :gfi => Float64,
                                :gii => Int64,
                            ),
                            medium = Dict(
                                :m => Float64
                            ),
                            agentSDE=quote 
                                dt(x) = 1
                            end,
                            agentAlg=algorithm
                        )
                N = 10000
                com = Community(abm,N=N,NMedium=[2,2,2],
                                simBox=[0 1.;0 1;0 1],
                                x=0,
                                dt=.1);
                            
                loadToPlatform!(com);
            
                a = []
                for i in 1:100
                    agentStepDE!(com)
                    update!(com)
                    # println( (com.t, com.dt, abs.( ( sum(com.x .^ 2)/N .- sum(com.x)/N .^ 2 ) ) ) )
                    push!(a, all(abs.( com.t .- ( sum(com.x .^ 2)/N .- sum(com.x)/N .^ 2 ) ) .< 0.5))
                end
            
                all(a)
            end
        end
    end
    
    # ############################################################################
    # PDEs
    # ############################################################################
    for algorithm in [DifferentialEquations.AutoTsit5(DifferentialEquations.Rosenbrock23())]
        for platform in TESTPLATFORMS
            @test begin
                abm = ABM(1,
                            agent = Dict(
                                :li => Int64,
                                :lii => Int64,
                                :lf => Float64,
                                :lfi => Float64,
                            ),
                            model = Dict(
                                :gf => Float64,
                                :gi => Int64,
                                :gfi => Float64,
                                :gii => Int64,
                            ),
                            medium = Dict(
                                :m => Float64,
                                :m2 => Float64
                            ),
                            mediumODE=quote 
                                if @mediumInside()
                                    dt(m) = @∂2(1,m)+@∂(1,xₘ*m)
                                    dt(m2) = @∂2(1,m2)
                                elseif @mediumBorder(1,-1)
                                    m2 = m2[2]
                                elseif @mediumBorder(1,1)
                                    m2 = m2[end-1]
                                end
                            end,
                            mediumAlg=algorithm
                        )
                N = 101
                simBox = [-10 10]
                com = Community(abm,N=1,NMedium=[N],simBox=simBox,dt=.1);
                            
                com.m = [pdf(Normal(0,2.),i) for i in range(simBox...,length=N)]
                com.m2 = [pdf(Normal(0,2.),i) for i in range(simBox...,length=N)]
    
                loadToPlatform!(com);        
    
                for i in 1:1:2000
                    mediumStepDE!(com)
                    update!(com)
                end
    
                all((com.m .- [pdf(Normal(0,1.),i) for i in range(simBox...,length=N)]) .< 0.01) &&
                        all((com.m2 .- 0.05) .< 0.001)
            end
        end
    end 
end