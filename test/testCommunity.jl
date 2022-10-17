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

end