@testset "agent" begin

    @test_nowarn Agent()
    @test_nowarn Agent(3)

    #Check you can declare agent of any size
    @test begin 
            agent = Agent(3,
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
                            d(x) += dt(-x)
                        end
                        )

            all([i in keys(agent.declaredSymbols) for i in [:x,:y,:z,:li,:lii,:lfi,:gi,:gii,:gfi,:m, :liNew_,:lfNew_,:giNew_,:gfNew_,:mNew_]])
        end

end
