using MacroTools

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

    #Create community
    @test_nowarn begin agent = Agent(3,
        localInt=[:li],
        localIntInteraction=[:lii],
        localFloat=[:lf],
        localFloatInteraction=[:lfi],
        globalFloat=[:gf],
        globalInt=[:gi],
        globalFloatInteraction=[:gfi],
        globalIntInteraction=[:gii],
        medium=[:m],
        updateGlobal=quote 
            gi += 1
            gf += 1
            gfi += 1
            gii += 1
        end,
        updateLocal=quote 
            li += 1
            lf += 1
            lfi += 1
            lii += 1            
        end,
        updateLocalInteraction=quote 
            lfi += 1
        end,
        updateGlobalInteraction=quote 
            gii += 1
        end,
        updateMedium=quote 
            m += 1
        end,
        updateMediumInteraction=quote
            m -= 1
        end,
        updateVariable=quote 
            d(x) += dt(-x)
        end
        )

        com = Community(agent,N=10,NMedium=[10,10,10])
    end

    #Get properties
    @test_nowarn begin agent = Agent(3,
        localInt=[:li],
        localIntInteraction=[:lii],
        localFloat=[:lf],
        localFloatInteraction=[:lfi],
        globalFloat=[:gf],
        globalInt=[:gi],
        globalFloatInteraction=[:gfi],
        globalIntInteraction=[:gii],
        medium=[:m]
        )

        com = Community(agent,N=10,NMedium=[10,10,10]);
        com.li
        com[:li]
        com.declaredSymbols
        com.values
        com.dims
    end

    #Set properties
    @test_nowarn begin agent = Agent(3,
        localInt=[:li],
        localIntInteraction=[:lii],
        localFloat=[:lf],
        localFloatInteraction=[:lfi],
        globalFloat=[:gf],
        globalInt=[:gi],
        globalFloatInteraction=[:gfi],
        globalIntInteraction=[:gii],
        medium=[:m]
        )

        com = Community(agent,N=10,NMedium=[10,10,10]);
        com.li = ones(Int64,10)
        com[:li] = ones(Int64,10)
        com.li .= 1.
        com.gi = 1
        com.gf = 1. 
    end

    #loadToPlatform
    @test_nowarn begin agent = Agent(3,
        localInt=[:li],
        localIntInteraction=[:lii],
        localFloat=[:lf],
        localFloatInteraction=[:lfi],
        globalFloat=[:gf],
        globalInt=[:gi],
        globalFloatInteraction=[:gfi],
        globalIntInteraction=[:gii],
        medium=[:m]
        )

        com = Community(agent,N=10,NMedium=[10,10,10]);
        loadToPlatform!(com,addAgents=10)
    end

    @testset "neighbors" begin
        #VerletTime VerletDisplacement neighbors
        @testAllNeighbors(            
            (@test begin 

            agent = Agent(DIM,neighbors=NEIGHBOR,platform=PLATFORM)
            com = Community(agent,N=3);
            com.skin = 1
            com.nMaxNeighbors = 2
            loadToPlatform!(com,addAgents=10);
            computeNeighbors!(com, agent);

            com.neighborList_ == [2 3;1 3;1 2]
            end), VerletTime, VerletDisplacement
        )

        #CellLinked neighbors
        @testAllNeighbors(            
            (@test begin 

            agent = Agent(DIM,neighbors=NEIGHBOR,platform=PLATFORM)
            com = Community(agent,N=3^DIM);
            v = zeros(3,27)
            v[1,:] = repeat([repeat([0],1);repeat([1],1);repeat([2],1)],9)
            v[2,:] = repeat([repeat([0],3);repeat([1],3);repeat([2],3)],3)
            v[3,:] = repeat([repeat([0],9);repeat([1],9);repeat([2],9)],1)
            for (j,sym) in enumerate([:x,:y,:z][1:DIM])
                com.values[sym] .= v[j,1:3^(DIM)]
            end
            com.cellEdge = 2.
            com.simulationBox .= [.5 1.5;.5 1.5;.5 1.5][1:DIM,:]
            loadToPlatform!(com,addAgents=10);
            computeNeighbors!(com, agent);

            all(com.cellNumAgents_ .== 1)
            end), CellLinked
        )

    end

    @testset "localInteractions" begin
        @testAllNeighbors(            
            (@test begin 

                agent = Agent(DIM,neighbors=NEIGHBOR,platform=PLATFORM,
                    localIntInteraction = [:nn],
                    updateLocalInteraction=quote
                            if euclideanDistance() < 1.1
                                nn.i += 1 
                            end
                        end
                )
                com = Community(agent,N=3^DIM);
                v = zeros(3,27)
                v[1,:] = repeat([repeat([0],1);repeat([1],1);repeat([2],1)],9)
                v[2,:] = repeat([repeat([0],3);repeat([1],3);repeat([2],3)],3)
                v[3,:] = repeat([repeat([0],9);repeat([1],9);repeat([2],9)],1)
                for (j,sym) in enumerate([:x,:y,:z][1:DIM])
                    com.values[sym] .= v[j,1:3^(DIM)]
                end
                if agent.neighbors in [:VerletTime,:VerletDisplacement]
                    com.skin = 2
                    com.nMaxNeighbors = 27
                elseif agent.neighbors in [:CellLinked]
                    com.cellEdge = 2.
                    com.simulationBox .= [.5 1.5;.5 1.5;.5 1.5][1:DIM,:]
                end
                loadToPlatform!(com,addAgents=0);
                computeNeighbors!(com, agent);
                updateLocalInteractions!(com, agent);

                result = false
                if DIM == 1
                    result = all(com.nn .== [1,2,1])
                elseif DIM == 2
                    result = all(com.nn .== [2,3,2,3,4,3,2,3,2])
                elseif DIM == 2
                    result = all(com.nn .== [3,4,3,4,5,4,5,4,3,
                                    4,5,4,5,6,5,4,5,4,
                                    3,4,3,4,5,4,5,4,3])
                end

                result
            end), Full, VerletTime, VerletDisplacement
        )
    end

end