@testset "abm" begin

    @test_nowarn ABM()
    @test_nowarn ABM(3)

    #Basic parameters
    @test begin
        aa = []
        for dims in 1:3
            abm = ABM(dims)

            #check 1
            push!(aa, all([i in [:x,:y,:z][1:dims] for i in keys(abm.parameters)]))

        end
        all(aa)
    end

    #User parameters default
    @test begin
        aa = []
        for dims in 1:3
            abm = ABM(dims,
                    agent=Dict(
                        :ai => Int64,
                        :af => Float64
                    ),
                    medium=Dict(
                        :mi => Int64,
                        :mf => Float64
                    ),
                    model=Dict(
                        :gi => Int64,
                        :gf => Float64,
                        :ga => Array{Float64}
                    )
                )
        
            #check 1: all parameters are included
            append!(aa, all([(i in [[:x,:y,:z][1:dims];[:ai,:af,:gi,:gf,:ga,:mi,:mf]]) for (i,j) in pairs(abm.parameters)]))
            #check 2: scopes are well defined
            scope = [[:agent,:agent,:agent][1:dims];[:agent,:agent,:model,:model,:model,:medium,:medium]]
            append!(aa, [j.scope==scope[pos] for (pos,(i,j)) in enumerate(pairs(abm.parameters))])
            #check 3: all properties false or 0
            append!(aa, [j.update==false for (pos,(i,j)) in enumerate(pairs(abm.parameters))])
            append!(aa, [j.variable==false for (pos,(i,j)) in enumerate(pairs(abm.parameters))])
            append!(aa, [j.variableMedium==false for (pos,(i,j)) in enumerate(pairs(abm.parameters))])
            append!(aa, [j.pos==0 for (pos,(i,j)) in enumerate(pairs(abm.parameters))])

            #Remove agents false
            push!(aa,!abm.removalOfAgents_)

        end
        all(aa)
    end

    #User parameters default with rules
    @test begin
        aa = []
        for dims in 1:3
            abm = ABM(dims,
                    agent=Dict(
                        :ai => Int64,
                        :af => Float64
                    ),
                    medium=Dict(
                        :mi => Int64,
                        :mf => Float64
                    ),
                    model=Dict(
                        :gi => Int64,
                        :gf => Float64,
                        :ga => Array{Float64}
                    ),
                    agentRule = quote
                        ai += 1
                        @removeAgent()
                    end,
                    agentODE = quote
                        dt(x) = 0
                    end,
                    agentSDE = quote
                        dt(x) = 1
                    end,
                    mediumODE = quote
                        dt(mf) = 1 - mf
                    end
                )

            #check 1: update rules added
            append!(aa, [AgentBasedModels.isemptyupdaterule(abm,i) for i in [:agentRule,:agentODE,:agentSDE,:mediumODE]])
            #check 2: scopes are correctly assigned
            scope = [[false,false,false][1:dims];[true,false,false,false,false,false,false]]
            append!(aa, [j.update==scope[pos] for (pos,(i,j)) in enumerate(pairs(abm.parameters))])

            scope = [[true,false,false][1:dims];[false,false,false,false,false,false,false]]
            append!(aa, [j.variable==scope[pos] for (pos,(i,j)) in enumerate(pairs(abm.parameters))])

            scope = [[false,false,false][1:dims];[false,false,false,false,false,true,false]]
            append!(aa, [j.variableMedium==scope[pos] for (pos,(i,j)) in enumerate(pairs(abm.parameters))])

            scope = [[1,0,0][1:dims];[0,0,0,0,0,1,0]]
            append!(aa, [j.pos==scope[pos] for (pos,(i,j)) in enumerate(pairs(abm.parameters))])        

            #Remove agents true
            push!(aa,abm.removalOfAgents_)
        end
        all(aa)
    end

    #Error tests

    #Updateing in both agentRule and agentODE/agentSDE
    @test_throws ErrorException begin
        abm = ABM(1,
                agentRule = quote
                    x += 1
                end,
                agentODE = quote
                    dt(x) = 0
                end,
            )
    end

    #Updating agent in medium
    @test_throws ErrorException begin
        abm = ABM(1,
                mediumODE = quote
                    dt(x) = 0
                end,
            )
    end

    #Updating medium in agent
    @test_throws ErrorException begin
        abm = ABM(1,
                medium = Dict(:m => Float64),
                agentODE = quote
                    dt(m) = 0
                end,
            )
    end

end
