"""
    function interactionFunction(agent)

Creates the final code provided to Agent in `updateInteraction` as a function and adds it to the Agent.
"""
function interactionFunction(agent)

        #Metric args
        metricArgs = []
        for i in POSITIONPARAMETERS[1:agent.dims]
            append!(metricArgs,[:($i[i1_]),:($i[i2_])])
        end

    if !all([typeof(i) == LineNumberNode for i in agent.declaredUpdates[:UpdateInteraction].args])
        code = agent.declaredUpdates[:UpdateInteraction]

        #Vectorize
        code = vectorize(code,agent)
        #Custom metrics
        code = postwalk(x->@capture(x,euclideanDistance()) ? :(euclideanDistance($(metricArgs...))) : x, code)
        code = postwalk(x->@capture(x,manhattanDistance()) ? :(manhattanDistance($(metricArgs...))) : x, code)

        #Put in loop
        code = neighborsLoop(code,agent)

        agent.declaredUpdatesCode[:UpdateInteraction] = code

        clearCode = quote end
        if agent.platform == :CPU
            for (s,prop) in pairs(BASEPARAMETERS)
                if (prop.reset==true) && (length(getSymbolsThat(agent.declaredSymbols,:basePar, s)) > 0)
                    push!(clearCode.args, :(@views community.$s[1:community.N[1],:] .= 0))
                end
            end
        else
            for (s,prop) in pairs(BASEPARAMETERS)
                if (prop.reset==true) && (length(getSymbolsThat(agent.declaredSymbols,:basePar, s)) > 0)
                    push!(clearCode.args, :(community.$s .= 0))
                end
            end
        end

        agent.declaredUpdatesFunction[:UpdateInteraction_] = Main.eval(:(($(agentArgs()...),) -> $(quote $code; nothing end)))
        aux = addCuda(:(community.agent.declaredUpdatesFunction[:UpdateInteraction_]($(agentArgs(:community)...))),agent,oneThread=true) #Add code to execute kernel in cuda if GPU
        agent.declaredUpdatesFunction[:UpdateInteraction] = Main.eval(
            :(function (community)
                $clearCode
                $aux
                return 
            end)
        )
    else
        agent.declaredUpdatesFunction[:UpdateInteraction] = Main.eval(:((community) -> nothing))
    end

end

"""
    function interactionStep!(community)

Function that computes a interaction step of the community a time step `dt`.
"""
function interactionStep!(community)

    checkLoaded(community)

    community.agent.declaredUpdatesFunction[:UpdateInteraction](community)

    return 

end