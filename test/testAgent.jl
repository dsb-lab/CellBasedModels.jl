@testset "agent" begin

    @test_nowarn Agent()
    @test_nowarn Agent(3)

    #Check you can declare agent of any size
    @test begin 
            agent = Agent(3,
                        agentParameters=OrderedDict(
                            :li=>Int64,
                            :li2=>Int64,
                            :lii=>Int64,
                            :lf=>Float64,
                            :lf2=>Float64
                        ),
                        modelParameters=OrderedDict(
                            :gi=>Int64,
                            :gi2=>Int64,
                            :gii=>Int64,
                            :gf=>Float64,
                            :gf2=>Float64,
                            :gfi=>Float64
                        ),
                        mediumParameters=OrderedDict(
                            :m=>Float64
                        ),
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
                        end,
                        compile = false
                        )

            #Things that should be present
            a = all([i in keys(agent.parameters) for i in [:x,:y,:z,:id,:li,:lii,:li2,:lf2,:gi,:gii,:gfi,:gi2,:gf2,:m]]) 
        
            a
        end

    # @test_nowarn begin
    #     Agent(3,
    #         globalFloat = [:dist], #Maximum distance to compute neighbor distance
    #         localFloatInteraction = [:mDis], #Interaction variable where to store the mean distance
    #         localIntInteraction = [:nNeighs], #Number of neighbors that the agent has
    #         updateInteraction = quote
    #             d = euclideanMetric(x.i,x.j,y.i,y.j,z.i,z.j) 
    #             if euclideanMetric(x.i,x.j,y.i,y.j,z.i,z.j) < dist
    #                 nNeighs.i += 1 #Add 1 to neighbors
    #                 mDist.i = (mDist.i*(nNeighs.i-1) + d)/nNeighs.i
    #             end
    #         end
    #     )
    # end

    # @test_nowarn begin
    #     model1 = Agent(3,
    #         localFloat = [:l],
    #         updateLocal = quote
    #             l += 1
    #         end
    #     )

    #     model2 = Agent(3,
    #         updateLocal = quote
    #             l += 1
    #         end,
    #         baseModelInit = [model1]
    #     )
    # end

    # @test_throws ErrorException begin
    #     model1 = Agent(3,
    #         localFloat = [:l],
    #         updateLocal = quote
    #             l += 1
    #         end
    #     )
    #     model2 = Agent(3,
    #         localFloat = [:l],
    #         baseModelInit = [model1]
    #     )
    # end

    # @test_nowarn begin
    #     modelWalker = Agent(1, #Dimensions of the model
    #         globalFloat = [
    #             :σ2, 
    #         ],
    #         globalInt = [:freeze], #Add the constant freeze
    #         updateLocal = quote
    #             x += freeze*Normal(0,σ2) 
    #         end,
    #     )

    #     modelBoundaries = Agent(1, #Dimensions of the model
    #         localFloat = [:l],
    #         globalFloat = [
    #             :pDivision,
    #         ],
    #         updateLocal = quote
    #             if pDivision < Uniform(0,1)
    #                 addAgent(l = sin(Uniform(0,3*π)))
    #             elseif x.new > simBox[1,2]
    #                 removeAgent()
    #             end

    #         end,
    #     )

    #     modelFreeze = Agent(1, #Dimensions of the model
    #         updateGlobal = quote #Set freeze to zero at some point
    #             if t < 10.
    #                 freeze = 1
    #             else
    #                 freeze = 0
    #             end
    #         end
    #     )

    #     modelFull = Agent(1,
    #         baseModelInit = [
    #             modelWalker,
    #             modelBoundaries,
    #             modelFreeze
    #             ]
    #     )
    # end

end
