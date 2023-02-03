@testset "agent" begin

    @test_nowarn Agent()
    @test_nowarn Agent(3)

    #Check you can declare agent of any size
    @test begin 
            agent = Agent(3,
                        localInt=[:li,:li2],
                        localIntInteraction=[:lii],
                        localFloat=[:lf,:lf2],
                        localFloatInteraction=[:lfi],
                        globalFloat=[:gf,:gf2],
                        globalInt=[:gi,:gi2],
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
                        updateInteraction=quote 
                            lfi += 1
                            gii += 1
                        end,
                        updateMedium=quote 
                            m += 1
                        end,
                        updateMediumInteraction=quote
                            m -= 1
                        end,
                        updateVariable=quote 
                            d(x) = dt(-x)
                        end
                        )

            #Things that should be present
            a = all([i in keys(agent.declaredSymbols) for i in [:li,:lii,:lfi,:gi,:gii,:gfi,:m,:li2,:lf2,:gi2,:gf2]]) 
        
            a
        end

end
