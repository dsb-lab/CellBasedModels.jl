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

macro testAllNeighbors(code,methods...)

    codeset = quote end
    for dim in [1]
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
    #         d(x) += dt(-x)
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
    #     globalFloat=[:gf],
    #     globalInt=[:gi],
    #     globalFloatInteraction=[:gfi],
    #     globalIntInteraction=[:gii],
    #     medium=[:m]
    #     )

    #     com = Community(agent,N=[10],NMedium=[10,10,10],simBox=[0. 1;0. 1;0 1]);
    #     com.li
    #     com[:li]
    #     com.agent
    #     com.loaded
    # end

    # #Set properties
    # @test_nowarn begin agent = Agent(3,
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

    #     com = Community(agent,N=[10],NMedium=[10,10,10],simBox=[0. 1;0. 1;0 1]);
    #     com.li = ones(Int64,10)
    #     com[:li] = ones(Int64,10)
    #     com.li .= 1.
    #     com.gi = 1
    #     com.gf = 1. 
    #     com.dt = 1
    # end

    # #loadToPlatform
    # @test_nowarn begin agent = Agent(3,
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

    #     com = Community(agent,N=[10],NMedium=[10,10,10],simBox=[0. 1;0. 1;0 1]);
    #     loadToPlatform!(com,preallocateAgents=10)
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
    #             com = Community(agent,N=1);
    #             com.x .= 1
    #             com.y .= 2
    #             loadToPlatform!(com,addAgents=9);
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
    #             com = Community(agent,N=1);
    #             loadToPlatform!(com,addAgents=31);
    #             for i in 1:5
    #                 localStep!(com)
    #                 update!(com)
    #             end

    #             all(com.N .== 32)
    #         end)
    #     )

    #     @testPlatform(
    #         (@test begin
    #             agent = Agent(2,platform=PLATFORM,  #Overpass agents limit
    #                         updateLocal = quote
    #                             addAgent()
    #                         end
    #                         );
    #             com = Community(agent,N=1);
    #             loadToPlatform!(com,addAgents=15);
    #             for i in 1:5
    #                 localStep!(com)
    #                 update!(com)
    #             end

    #             println(com.N)

    #             all(com.N .== 16)
    #         end)
    #     )

        # # Remove agent
        # @testPlatform(
        #     (@test begin
        #         agent = Agent(2,platform=PLATFORM, #Add agents one by one
        #                     updateLocal = quote
        #                         if id == N
        #                             removeAgent()
        #                         end
        #                     end
        #                     );
        #         com = Community(agent,N=10);
        #         com.x .= 1:10
        #         com.y .= 10:-1:1
        #         loadToPlatform!(com);

        #         passes = []
        #         for i in 1:9
        #             localStep!(com)
        #             update!(com)

        #             CUDA.@allowscalar push!(passes, all(com.N .== 10-i))
        #         end

        #         all(passes)
        #     end), CPU
        # )

    # end
    
    #global
    @testset "global" begin

        @testPlatform(
            (@test begin
                agent = Agent(1,platform=PLATFORM,
                            localInt=[:li],
                            localIntInteraction=[:lii],
                            localFloat=[:lf],
                            localFloatInteraction=[:lfi],
                            globalFloat=[:gf],
                            globalInt=[:gi],
                            globalFloatInteraction=[:gfi],
                            globalIntInteraction=[:gii],
                            updateGlobal = quote
                                t = 10.
                                addAgent(
                                    lf = 5,
                                    li = 2,
                                    x = 3.
                                )
                            end
                            );
                com = Community(agent,N=[10]);
                loadToPlatform!(com,preallocateAgents=1);
                globalStep!(com)

                aux = false
                if PLATFORM == :CPU
                    aux = (com.N[1] == 10) &
                            (com.NAdd_[] .== 1) &
                            (com.NRemove_[] .== 0) &
                            (com.idMax_[] .== 11) &
                            (com.flagNeighbors_[11] == 1) &
                            (com.lfMNew_[11,1] ≈ 5) &
                            (com.liMNew_[11,1] == 2) &
                            (com.xNew_[11,1] ≈ 3) &
                            (com.id[11] == 11)
                else 
                    aux = (CUDA.@allowscalar com.N[1] .== 10) &
                            (CUDA.@allowscalar com.NAdd_[1] .== 1) &
                            (CUDA.@allowscalar com.NRemove_[1] .== 0) &
                            (CUDA.@allowscalar com.idMax_[1] .== 11) &
                            (CUDA.@allowscalar com.flagNeighbors_[11] == 1) &
                            (CUDA.@allowscalar com.lfMNew_[11,1] ≈ 5) &
                            (CUDA.@allowscalar com.xNew_[11,1] ≈ 3) &
                            (CUDA.@allowscalar com.id[11] == 11)
                end

                aux
            end)
        )

    end

    # @testset "neighbors" begin
    #     #VerletTime VerletDisplacement neighbors
    #     @testAllNeighbors(            
    #         (@test begin 

    #         agent = Agent(DIM,neighbors=NEIGHBOR,platform=:CPU)
    #         com = Community(agent,N=3);
    #         com.skin = 1
    #         com.nMaxNeighbors = 2
    #         loadToPlatform!(com,addAgents=10);
    #         computeNeighbors!(com, agent);

    #         com.neighborList_ == [2 3;1 3;1 2]
    #         end), VerletTime, VerletDisplacement
    #     )

    #     #CellLinked neighbors
    #     @testAllNeighbors(            
    #         (@test begin 

    #         agent = Agent(DIM,neighbors=NEIGHBOR,platform=PLATFORM)
    #         com = Community(agent,N=3^DIM);
    #         v = zeros(3,27)
    #         v[1,:] = repeat([repeat([0],1);repeat([1],1);repeat([2],1)],9)
    #         v[2,:] = repeat([repeat([0],3);repeat([1],3);repeat([2],3)],3)
    #         v[3,:] = repeat([repeat([0],9);repeat([1],9);repeat([2],9)],1)
    #         for (j,sym) in enumerate([:x,:y,:z][1:DIM])
    #             com.values[sym] .= v[j,1:3^(DIM)]
    #         end
    #         com.cellEdge = 2.
    #         com.simulationBox .= [.5 1.5;.5 1.5;.5 1.5][1:DIM,:]
    #         loadToPlatform!(com,addAgents=10);
    #         computeNeighbors!(com, agent);

    #         all(com.cellNumAgents_ .== 1)
    #         end), CellLinked
    #     )

    # end

    # @testset "localInteractions" begin
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
    #             com = Community(agent,N=3^DIM);
    #             v = zeros(3,27)
    #             v[1,:] = repeat([repeat([0],1);repeat([1],1);repeat([2],1)],9)
    #             v[2,:] = repeat([repeat([0],3);repeat([1],3);repeat([2],3)],3)
    #             v[3,:] = repeat([repeat([0],9);repeat([1],9);repeat([2],9)],1)
    #             for (j,sym) in enumerate([:x,:y,:z][1:DIM])
    #                 com.values[sym] .= v[j,1:3^(DIM)]
    #             end
    #             if agent.neighbors in [:VerletTime,:VerletDisplacement]
    #                 com.skin = 2
    #                 com.nMaxNeighbors = 27
    #             elseif agent.neighbors in [:CellLinked]
    #                 com.cellEdge = 2.
    #                 com.simulationBox .= [.5 1.5;.5 1.5;.5 1.5][1:DIM,:]
    #             end
    #             loadToPlatform!(com,addAgents=0);
    #             computeNeighbors!(com, agent);
    #             updateInteractions!(com, agent);

    #             result = false
    #             if DIM == 1
    #                 result = all(com.nn .== [1,2,1])
    #             elseif DIM == 2
    #                 result = all(com.nn .== [2,3,2,3,4,3,2,3,2])
    #             elseif DIM == 2
    #                 result = all(com.nn .== [3,4,3,4,5,4,5,4,3,
    #                                 4,5,4,5,6,5,4,5,4,
    #                                 3,4,3,4,5,4,5,4,3])
    #             end

    #             result
    #         end), Full, VerletTime, VerletDisplacement
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
    #                             d(x) += dt(-x)
    #                         end,
    #                         platform=PLATFORM
    #                     )
    #             com = Community(agent,N=3,NMedium=[10,10,10]);
                            
    #             loadToPlatform!(com,addAgents=10);
    #             for i in [:li,:lf]
    #                 ii = Meta.parse(string(i,"New_"))
    #                 com[ii][1:3] .= 2
    #             end
    #             for i in [:gf,:gi,:m]
    #                 ii = Meta.parse(string(i,"New_"))
    #                 com[ii] .= 2
    #             end
                
    #             update!(com)
    #             passed = []
    #             for i in [:li,:lf,:gf,:gi,:m]
    #                 ii = Meta.parse(string(i,"New_"))
    #                 push!(passed,all(com[ii] .== com[i]))
    #             end
    #             all(passed)
    #         end), CPU
    #     )        
    # end

end