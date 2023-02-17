using MacroTools

macro testPlatform(code)

    codeset = quote end
    for plat in TESTPLATFORMS
        addCode = MacroTools.postwalk(x->@capture(x,PLATFORM) ? :(Symbol($plat)) : x, code)
        codeset = quote
            $codeset
            $addCode
        end
    end

    return codeset

end

macro testPlatform(code,methods...)

    codeset = quote end
    for plat in [string(j) for j in methods]
        addCode = MacroTools.postwalk(x->@capture(x,PLATFORM) ? :(Symbol($plat)) : x, code)
        codeset = quote
            $codeset
            $addCode
        end
    end

    return codeset

end

macro testIntegrator(code,methods...)

    codeset = quote end
    for plat in [string(j) for j in methods]
        addCode = MacroTools.postwalk(x->@capture(x,INTEGRATOR) ? :(Symbol($plat)) : x, code)
        codeset = quote
            $codeset
            $addCode
        end
    end

    return codeset

end

macro testAllNeighbors(code,methods...)

    codeset = quote end
    for dim in 1:3
        for meth in [string(j) for j in methods]
            for plat in TESTPLATFORMS
                addCode = MacroTools.postwalk(x->@capture(x,NEIGHBOR) ? :(Symbol($meth)) : x, code)
                addCode = MacroTools.postwalk(x->@capture(x,DIM) ? dim : x, addCode)
                addCode = MacroTools.postwalk(x->@capture(x,PLATFORM) ? :(Symbol($plat)) : x, addCode)
                codeset = quote
                    $codeset
                    $addCode
                end
            end
        end
    end

    return codeset

end

@testset "community" begin

    # #Create community
    # @test_nowarn begin agent = Agent(3,
    #     localInt=[:li],
    #     localIntInteraction=[:lii],
    #     localFloat=[:lf],
    #     localFloatInteraction=[:lfi],
    #     globalFloat=[:gf],
    #     globalInt=[:gi],
    #     globalFloatInteraction=[:gfi],
    #     globalIntInteraction=[:gii],
    #     medium=[:m],
    #     updateGlobal=quote 
    #         gi += 1
    #         gf += 1
    #         gfi += 1
    #         gii += 1
    #     end,
    #     updateLocal=quote 
    #         li += 1
    #         lf += 1
    #         lfi += 1
    #         lii += 1     
    #         gii += 1       
    #     end,
    #     updateInteraction=quote 
    #         lfi += 1
    #     end,
    #     updateMedium=quote 
    #         m += 1
    #     end,
    #     updateMediumInteraction=quote
    #         m -= 1
    #     end,
    #     updateVariable=quote 
    #         d( x ) = dt( -x )
    #     end
    #     )

    #     com = Community(agent,N=[10],NMedium=[1,1,1],simBox=[0. 1;0. 1;0 1])
    # end

    # #Get properties
    # @test_nowarn begin agent = Agent(3,
    #     localInt=[:li],
    #     localIntInteraction=[:lii],
    #     localFloat=[:lf],
    #     localFloatInteraction=[:lfi],
    #     globalFloat=[:gf,:gf2],
    #     globalInt=[:gi,:gi2],
    #     globalFloatInteraction=[:gfi],
    #     globalIntInteraction=[:gii],
    #     medium=[:m]
    #     )

    #     com = Community(agent,N=[10],NMedium=[10,10,10],simBox=[0. 1;0. 1;0 1]);
    #     com.li
    #     com[:li]
    #     com.gf
    #     com[:gf]
    #     com.gf2
    #     com[:gf2]
    #     com.agent
    #     com.loaded
    # end

    # #Set properties
    # @test begin agent = Agent(3,
    #     localInt=[:li],
    #     localIntInteraction=[:lii],
    #     localFloat=[:lf],
    #     localFloatInteraction=[:lfi],
    #     globalFloat=[:gf,:gf2],
    #     globalInt=[:gi,:gi2],
    #     globalFloatInteraction=[:gfi],
    #     globalIntInteraction=[:gii],
    #     medium=[:m]
    #     )

    #     com = Community(agent,N=[10],NMedium=[10,10,10],simBox=[0. 1;0. 1;0 1]);
    #     com.li = ones(Int64,10)
    #     com[:li] = ones(Int64,10)
    #     com.li .= 1.
    #     com.gi = 1
    #     com.gf = 1. 
    #     com.gi2 = 1
    #     com.gf2 = 1. 
    #     com.dt = 1

    #     all( com.gi2 .== 1 )
    # end

    # #loadToPlatform
    # @test begin agent = Agent(3,
    #     localInt=[:li],
    #     localIntInteraction=[:lii],
    #     localFloat=[:lf],
    #     localFloatInteraction=[:lfi],
    #     globalFloat=[:gf],
    #     globalInt=[:gi],
    #     globalFloatInteraction=[:gfi],
    #     globalIntInteraction=[:gii],
    #     medium=[:m]
    #     )

    #     com = Community(agent,N=[100],NMedium=[10,10,10],simBox=[0. 1;0. 1;0 1]);
    #     loadToPlatform!(com,preallocateAgents=10)
    #     bringFromPlatform!(com)

    #     true
    # end

    # #local
    # @testset "local" begin

    #     @testPlatform(
    #         (@test begin
    #             agent = Agent(1,platform=PLATFORM,
    #                         localInt=[:li],
    #                         localIntInteraction=[:lii],
    #                         localFloat=[:lf],
    #                         localFloatInteraction=[:lfi],
    #                         globalFloat=[:gf],
    #                         globalInt=[:gi],
    #                         globalFloatInteraction=[:gfi],
    #                         globalIntInteraction=[:gii],
    #                         updateLocal = quote
    #                             x = x + 1.
    #                             if id == 3
    #                                 removeAgent()
    #                             elseif id == 5
    #                                 addAgent(lf = 5)
    #                             end
    #                         end
    #                         );
    #             com = Community(agent,N=[10]);
    #             loadToPlatform!(com,preallocateAgents=1);
    #             localStep!(com)

    #             aux = false
    #             if PLATFORM == :CPU
    #                 aux = (com.N[1] == 10) &
    #                         (com.NAdd_[] .== 1) &
    #                         (com.NRemove_[] .== 1) &
    #                         (com.idMax_[] .== 11) &
    #                         (com.flagNeighbors_[3] == 1)  &
    #                         (com.flagNeighbors_[11] == 1) &
    #                         (com.lfMNew_[11,1] ≈ 5) &
    #                         (com.id[11] == 11)
    #             else 
    #                 aux = (CUDA.@allowscalar com.N[1] .== 10) &
    #                         (CUDA.@allowscalar com.NAdd_[1] .== 1) &
    #                         (CUDA.@allowscalar com.NRemove_[1] .== 1) &
    #                         (CUDA.@allowscalar com.idMax_[1] .== 11) &
    #                         (CUDA.@allowscalar com.flagNeighbors_[3] == 1)  &
    #                         (CUDA.@allowscalar com.flagNeighbors_[11] == 1) &
    #                         (CUDA.@allowscalar com.lfMNew_[11,1] ≈ 5) &
    #                         (CUDA.@allowscalar com.id[11] == 11)
    #             end

    #             aux
    #         end)
    #     )

        @testPlatform(
            (@test begin
                agent = Agent(1,platform=PLATFORM,
                            localFloat=[:lf],
                            updateLocal = quote
                                addAgent(lf = 5)
                                addAgent(lf = 5)
                                removeAgent()
                            end
                            );
                com = Community(agent,N=[1]);
                loadToPlatform!(com,preallocateAgents=3);
                localStep!(com)
                println("NAdd_: ",com.NAdd_[])
                update!(com)

                true
            end)
        )

    # end
    
    # #global
    # @testset "global" begin

    #     @testPlatform(
    #         (@test begin
    #             agent = Agent(1,platform=PLATFORM,
    #                         localInt=[:li],
    #                         localIntInteraction=[:lii],
    #                         localFloat=[:lf],
    #                         localFloatInteraction=[:lfi],
    #                         globalFloat=[:gf],
    #                         globalInt=[:gi],
    #                         globalFloatInteraction=[:gfi],
    #                         globalIntInteraction=[:gii],
    #                         updateGlobal = quote
    #                             t = 10.
    #                             addAgent(
    #                                 lf = 5,
    #                                 li = 2,
    #                                 x = 3.
    #                             )
    #                         end
    #                         );
    #             com = Community(agent,N=[10]);
    #             loadToPlatform!(com,preallocateAgents=1);
    #             globalStep!(com)

    #             aux = false
    #             if PLATFORM == :CPU
    #                 aux = (com.N[1] == 10) &
    #                         (com.NAdd_[] .== 1) &
    #                         (com.NRemove_[] .== 0) &
    #                         (com.idMax_[] .== 11) &
    #                         (com.flagNeighbors_[11] == 1) &
    #                         (com.lfMNew_[11,1] ≈ 5) &
    #                         (com.liMNew_[11,1] == 2) &
    #                         (com.xNew_[11,1] ≈ 3) &
    #                         (com.id[11] == 11)
    #             else 
    #                 aux = (CUDA.@allowscalar com.N[1] .== 10) &
    #                         (CUDA.@allowscalar com.NAdd_[1] .== 1) &
    #                         (CUDA.@allowscalar com.NRemove_[1] .== 0) &
    #                         (CUDA.@allowscalar com.idMax_[1] .== 11) &
    #                         (CUDA.@allowscalar com.flagNeighbors_[11] == 1) &
    #                         (CUDA.@allowscalar com.lfMNew_[11,1] ≈ 5) &
    #                         (CUDA.@allowscalar com.xNew_[11,1] ≈ 3) &
    #                         (CUDA.@allowscalar com.id[11] == 11)
    #             end

    #             aux
    #         end)
    #     )

    # end

    # @testset "neighbors" begin

    #     #Full
    #     @testAllNeighbors(
    #         (@test_nowarn begin
    #             agent = Agent(DIM,neighbors=NEIGHBOR,platform=PLATFORM)
    #             com = Community(agent,N=[3]);
    #             computeNeighbors!(com);     
    #         end), Full
    #     )

    #     #VerletTime VerletDisplacement neighbors
    #     @testAllNeighbors(            
    #         (@test begin 

    #         agent = Agent(DIM,neighbors=NEIGHBOR,platform=PLATFORM)
    #         com = Community(agent,N=[3],skin=[1.],nMaxNeighbors=[2],dtNeighborRecompute=[1.]);
    #         loadToPlatform!(com,preallocateAgents=10);
    #         computeNeighbors!(com);

    #         x = Array(com.neighborList_[1:3,:])
    #         all([j in [2 3;1 3;1 2][i,:] for i in 1:3 for j in x[i,:]])
    #         end), VerletDisplacement, VerletTime,
    #     )

    #     #CellLinked neighbors
    #     @testAllNeighbors(            
    #         (@test begin 

    #         agent = Agent(DIM,neighbors=NEIGHBOR,platform=PLATFORM)
    #         com = Community(agent, N=[3^DIM], cellEdge=[2. for i in 1:DIM], simBox = [.5 1.5;.5 1.5;.5 1.5][1:DIM,:]);
    #         v = zeros(3,27)
    #         v[1,:] = repeat([repeat([0],1);repeat([1],1);repeat([2],1)],9)
    #         v[2,:] = repeat([repeat([0],3);repeat([1],3);repeat([2],3)],3)
    #         v[3,:] = repeat([repeat([0],9);repeat([1],9);repeat([2],9)],1)
    #         for (j,sym) in enumerate([:x,:y,:z][1:DIM])
    #             getproperty(com,sym) .= v[j,1:3^(DIM)]
    #         end
    #         loadToPlatform!(com);
    #         computeNeighbors!(com);

    #         all(com.cellNumAgents_ .== 1)
    #         end), CellLinked
    #     )

    # end

    # @testset "interactions" begin
    #     @testAllNeighbors(            
    #         (@test begin 

    #             agent = Agent(DIM,neighbors=NEIGHBOR,platform=PLATFORM,
    #                 localIntInteraction = [:nn],
    #                 updateInteraction=quote
    #                         if euclideanDistance() < 1.1
    #                             nn.i += 1 
    #                         end
    #                     end
    #             )
    #             # println(agent.declaredUpdatesCode[:UpdateInteraction])
    #             com = Community(agent,N=[3^DIM],dtNeighborRecompute=[1.],skin=[2.],nMaxNeighbors=[27],cellEdge=[2.,2.,2.][1:DIM],simBox=[.5 1.5;.5 1.5;.5 1.5][1:DIM,:]);
    #             v = zeros(3,27)
    #             v[1,:] = repeat([repeat([0],1);repeat([1],1);repeat([2],1)],9)
    #             v[2,:] = repeat([repeat([0],3);repeat([1],3);repeat([2],3)],3)
    #             v[3,:] = repeat([repeat([0],9);repeat([1],9);repeat([2],9)],1)
    #             for (j,sym) in enumerate([:x,:y,:z][1:DIM])
    #                 getfield(com,sym) .= v[j,1:3^(DIM)]
    #             end

    #             loadToPlatform!(com);
    #             computeNeighbors!(com);
    #             interactionStep!(com);
    #             interactionStep!(com);

    #             result = true
    #             if DIM == 1
    #                 result = all(Array(com.nn) .≈ [1,2,1])
    #             elseif DIM == 2
    #                 result = all(Array(com.nn) .≈ [2,3,2,3,4,3,2,3,2])
    #             elseif DIM == 3
    #                 result = all(Array(com.nn) .≈ [3,4,3,4,5,4,3,4,3,
    #                                                4,5,4,5,6,5,4,5,4,
    #                                                3,4,3,4,5,4,3,4,3])
    #             end

    #             result
    #         end), CellLinked, #VerletTime, VerletDisplacement, Full
    #     )
    # end

    # #Update
    # @testset "update" begin
    #     @testPlatform(
    #         (@test begin
    #             agent = Agent(3,
    #                         localInt=[:li],
    #                         localIntInteraction=[:lii],
    #                         localFloat=[:lf],
    #                         localFloatInteraction=[:lfi],
    #                         globalFloat=[:gf],
    #                         globalInt=[:gi],
    #                         globalFloatInteraction=[:gfi],
    #                         globalIntInteraction=[:gii],
    #                         medium=[:m],
    #                         updateGlobal=quote 
    #                             gi += 1
    #                             gf += 1
    #                             gfi += 1
    #                             gii += 1
    #                         end,
    #                         updateLocal=quote 
    #                             li += 1
    #                             lf += 1
    #                             lfi += 1
    #                             lii += 1            
    #                         end,
    #                         updateInteraction=quote 
    #                             lfi += 1
    #                             gii += 1
    #                         end,
    #                         updateMedium=quote 
    #                             m += 1
    #                         end,
    #                         updateMediumInteraction=quote
    #                             m -= 1
    #                         end,
    #                         updateVariable=quote 
    #                             d(x) = dt(-x)
    #                         end,
    #                         platform=PLATFORM
    #                     )
    #             com = Community(agent,N=[3],NMedium=[2,2,2]);
                            
    #             loadToPlatform!(com);
    #             for i in [:liM,:lfM]
    #                 ii = Meta.parse(string(i,"New_"))
    #                 com[ii][1:3] .= 2
    #             end
    #             for i in [:gfM,:giM,:mediumM]
    #                 ii = Meta.parse(string(i,"New_"))
    #                 com[ii] .= 2
    #             end
                
    #             update!(com)
    #             passed = []
    #             for i in [:liM,:lfM,:gfM,:giM,:mediumM]
    #                 ii = Meta.parse(string(i,"_"))
    #                 iii = Meta.parse(string(i,"New_"))
    #                 pass = all(com[ii] .== com[iii])
    #                 push!(passed,pass)
    #             end
    #             all(passed)
    #         end)
    #     )        

    #     # Add agent
    #     @testPlatform(
    #         (@test begin
    #             agent = Agent(2,platform=PLATFORM, #Add agents one by one
    #                         updateLocal = quote
    #                             if x == N
    #                                 addAgent(x=N+1)
    #                             end
    #                         end
    #                         );
    #             com = Community(agent,N=[1]);
    #             com.x .= 1
    #             com.y .= 2
    #             loadToPlatform!(com,preallocateAgents=9);
    #             for i in 1:9
    #                 localStep!(com)
    #                 update!(com)
    #             end

    #             CUDA.@allowscalar all(com.x .== 1:10) && all(com.nMax_[1] .== 10) && all(com.N[1] .== 10)  && all(com.y .== 2)
    #         end)
    #     )

    #     @testPlatform(
    #         (@test begin
    #             agent = Agent(2,platform=PLATFORM,  #Add agents several at the time
    #                         updateLocal = quote
    #                             addAgent()
    #                         end
    #                         );
    #             com = Community(agent,N=[1]);
    #             loadToPlatform!(com,preallocateAgents=31);
    #             for i in 1:5
    #                 localStep!(com)
    #                 update!(com)
    #             end

    #             all(com.N .== 32)
    #         end)
    #     )

    #     # Remove agent
    #     @testPlatform(
    #         (@test begin
    #             agent = Agent(2,platform=PLATFORM, #Add agents one by one
    #                         updateLocal = quote
    #                             if id == N
    #                                 removeAgent()
    #                             end
    #                         end
    #                         );
    #             com = Community(agent,N=[10]);
    #             com.x .= 1:10
    #             com.y .= 10:-1:1
    #             loadToPlatform!(com);

    #             passes = []
    #             for i in 1:9
    #                 localStep!(com)
    #                 update!(com)

    #                 push!(passes, all(com.N .== 10-i))
    #             end

    #             all(passes)
    #         end)
    #     )

    # end

    # #Integration
    # @testset "integration" begin
    #     @test begin
    #         agent = Agent(2,platform=:CPU, #Add agents one by one
    #                     integrator=:RungeKutta4,
    #                     updateVariable = quote

    #                         d(  x  ) = dt(  -x  )
    #                         d(  y  ) = dt(  -c  ) + dW( 2 )
                            
    #                     end
    #                     );
    #         com = Community(agent)
    #         # println(agent.declaredVariables)
    #         # println(size(com.varAuxdt_))
    #         # println(size(com.varAuxdW_))

    #         true
    #     end

    #     @testPlatform( #basic integration
    #     @testIntegrator(
    #         (@test begin
    #                 agent = Agent(2,platform=PLATFORM, #Add agents one by one
    #                             integrator=INTEGRATOR,
    #                             updateVariable = quote

    #                                 d(  x  ) = dt(  -x  )
                                    
    #                             end
    #                             );
    #                 com = Community(agent)
    #                 com.dt = .1
    #                 com.x .= 1
    #                 loadToPlatform!(com)
 
    #                 istrue = []
    #                 # println(INTEGRATOR, " ", PLATFORM)
    #                 for i in 1:10
    #                     integrationStep!(com)
    #                     update!(com)
    #                     # println(abs.(com.x.-exp.(-com.t)))
    #                     push!(istrue,all(abs.(com.x.-exp.(-com.t)).<0.05))
    #                 end
 
    #                 all(istrue)
    #         end), Euler, Heun, RungeKutta4
    #     )
    #     )
 
    #     @testPlatform( #basic integration
    #     @testIntegrator( #Stochastic term
    #         (@test begin
    #             agent = Agent(2,platform=PLATFORM, #Add agents one by one
    #                         integrator=INTEGRATOR,
    #                         globalFloat = [:D],
    #                         updateVariable = quote

    #                             d( x ) = dW( 1 )
                                
    #                         end
    #                         );
    #             N = 10000
    #             com = Community(agent,N=[N])
    #             com.dt = .1
    #             com.x .= 0
    #             loadToPlatform!(com)

    #             istrue = []
    #             for i in 1:10
    #                 integrationStep!(com)
    #                 update!(com)
    #                 push!(istrue, all(abs.( com.t .- ( sum(com.x .^ 2)/N .- sum(com.x)/N .^ 2 ) ) .< 0.5))
    #             end

    #             all(istrue)
    #         end), Euler, Heun, RungeKutta4
    #     )
    #     )

    # end

    # @testset "IO" begin

        # @testAllNeighbors( #basic integration
        #     (@test begin
        #             dim = DIM
        #             agent = Agent(dim,platform=PLATFORM, #Add agents one by one
        #                         localFloat=[:l],
        #                         neighbors=NEIGHBOR,
        #                         updateLocal = quote

        #                             l = t
                                
        #                         end,
        #                         updateVariable = quote

        #                             d(  x  ) = dt(  1  )
                                    
        #                         end
        #                         );
        #             com = Community(agent,skin=[2.],simBox=[0. .9;1 2;1 2][1:dim,:],nMaxNeighbors=[15],dtNeighborRecompute=[10.],cellEdge=[10.,10.,10.][1:dim])
        #             com.dt = .1
        #             com.x .= 1
        #             loadToPlatform!(com)
        #             bringFromPlatform!(com)
        #             comCheck = deepcopy(com)
        #             loadToPlatform!(com)
 
        #             for i in 1:5
        #                 step!(com)
        #                 saveRAM!(com,saveLevel=5)
        #             end
        #             bringFromPlatform!(com)

        #             isTrue = []
        #             for i in 1:5
        #                 comCheck.t = .1*i
        #                 comCheck.x .= .1*i+1
        #                 comCheck.xNew_ .= .1*i+1
        #                 comCheck.varAux_ .= .1*i+1
        #                 comCheck.lfM_ .= .1*i-.1
        #                 comCheck.lfMNew_ .= .1*i-.1
        #                 if NEIGHBOR == :VerletDisplacement
        #                     setfield!(comCheck, :accumulatedDistance_, [.1*i])
        #                 end

        #                 comt = com[i]
        #                 for (sym,prop) in pairs(AgentBasedModels.BASEPARAMETERS)
        #                     t = false
        #                     if :Atomic in prop.shape
        #                         t = getfield(comCheck,sym)[] == getfield(comt,sym)[]
        #                     else 
        #                         t = all(getfield(comCheck,sym) .≈ getfield(comt,sym))
        #                     end
        #                     if !t
        #                         println(sym," ",getfield(comCheck,sym), getfield(comt,sym))
        #                     end
        #                     push!(isTrue,t)
        #                 end
        #             end

        #             #Check evolution can be done again from any timepoint if saveLevel=5
        #             com = com[1]
        #             loadToPlatform!(com)
        #             step!(com)
        #             saveRAM!(com)
        #             bringFromPlatform!(com)
        #             #Check evolution can be done again from any timepoint if saveLevel=1
        #             com = com[end]
        #             com.t .= 0
        #             com.x .= 1
        #             com.l .= 0
        #             loadToPlatform!(com)
        #             for i in 1:5
        #                 step!(com)
        #                 saveRAM!(com)
        #             end
        #             bringFromPlatform!(com)

        #             all(isTrue)
        #     end), CellLinked, VerletTime, VerletDisplacement, Full
        # )

        # @testAllNeighbors( #basic integration
        #     (@test begin
        #             dim = DIM
        #             agent = Agent(dim,platform=PLATFORM, #Add agents one by one
        #                         localFloat=[:l],
        #                         neighbors=NEIGHBOR,
        #                         updateLocal = quote

        #                             l = t
                                
        #                         end,
        #                         updateVariable = quote

        #                             d(  x  ) = dt(  1  )
                                    
        #                         end
        #                         );
        #             com = Community(agent,skin=[2.],simBox=[0. .9;1 2;1 2][1:dim,:],nMaxNeighbors=[15],dtNeighborRecompute=[10.],cellEdge=[10.,10.,10.][1:dim])
        #             com.dt = .1
        #             com.x .= 1
        #             com.fileSaving = "testfiles/jld.jld2"
        #             loadToPlatform!(com)
        #             bringFromPlatform!(com)
        #             comCheck = deepcopy(com)

        #             if isfile("testfiles/jld.jld2")
        #                 rm("testfiles/jld.jld2")
        #             end

        #             loadToPlatform!(com)
        #             for i in 1:5
        #                 step!(com)
        #                 saveJLD2(com,saveLevel=5)
        #             end
        #             bringFromPlatform!(com)

        #             com = loadJLD2("testfiles/jld.jld2")
        #             isTrue = []
        #             for i in 1:5
        #                 comCheck.t = .1*i
        #                 comCheck.x .= .1*i+1
        #                 comCheck.xNew_ .= .1*i+1
        #                 comCheck.varAux_ .= .1*i+1
        #                 comCheck.lfM_ .= .1*i-.1
        #                 comCheck.lfMNew_ .= .1*i-.1
        #                 if NEIGHBOR == :VerletDisplacement
        #                     setfield!(comCheck, :accumulatedDistance_, [.1*i])
        #                 end

        #                 comt = com[i]
        #                 for (sym,prop) in pairs(AgentBasedModels.BASEPARAMETERS)
        #                     t = false
        #                     if :Atomic in prop.shape
        #                         t = getfield(comCheck,sym)[] == getfield(comt,sym)[]
        #                     else 
        #                         t = all(round.(getfield(comCheck,sym),digits=6) .≈ round.(getfield(comt,sym),digits=5))
        #                     end
        #                     if !t
        #                         println(sym," ",getfield(comCheck,sym), getfield(comt,sym))
        #                     end

        #                     push!(isTrue,t)
        #                 end
        #             end
 
        #             #Check evolution can be done again from any timepoint if saveLevel=5
        #             com = com[1]
        #             com.fileSaving = "testfiles/jld.jld2"

        #             # if isfile("testfiles/jld.jld2")
        #             #     rm("testfiles/jld.jld2")
        #             # end

        #             loadToPlatform!(com)
        #             step!(com)
        #             saveJLD2(com)
        #             bringFromPlatform!(com)
                    
        #             com = loadJLD2("testfiles/jld.jld2")
        #             #Check evolution can be done again from any timepoint if saveLevel=1
        #             com = com[end]
        #             com.fileSaving = "testfiles/jld.jld2"
        #             com.t .= 0
        #             com.x .= 1
        #             com.l .= 0
        #             loadToPlatform!(com)
        #             for i in 1:5
        #                 step!(com)
        #                 saveJLD2(com)
        #             end
        #             bringFromPlatform!(com)

        #             if isfile("testfiles/jld.jld2")
        #                 rm("testfiles/jld.jld2")
        #             end

        #             all(isTrue)
        #     end), CellLinked, VerletTime, VerletDisplacement, Full
        # )

    # end

    # @testset "Initializers" begin
        
    #     @test_nowarn begin
    #         agent = Agent(3,)
    #         com = initializeCommunity(agent,[0 1;0 1;0 1],.1,packaging=cubicPackaging)
    #     end

    #     @test_nowarn begin
    #         agent = Agent(3,)
    #         com = initializeCommunity(agent,[0 1;0 1;0 1],.1,packaging=compactHexagonalPackaging)
    #     end

    # end

end