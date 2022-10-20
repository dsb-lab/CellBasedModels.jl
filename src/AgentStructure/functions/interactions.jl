function localInteractionsFunction(agent)

    args = []
    for i in keys(BASESYMBOLS)
        push!(args,:($i))        
    end
    for i in [:x,:y,:z][1:agent.dims]
        push!(args,:($i))
    end
    for (sym,prop) in pairs(NEIGHBORSYMBOLS[agent.neighbors])
        if :NeighborLoop in prop
            push!(args,:($sym))
        end
    end
    for (sym,prop) in pairs(agent.declaredSymbols)
        if prop[3] in [:UserUpdatable,:UserResetable]
            push!(args,:($sym))
        end
    end

    args2 = [:(community.$i) for i in args]

    #Metric args
    metricArgs = []
    for i in [:x,:y,:z][1:agent.dims]
        append!(metricArgs,[:($i[i1_]),:($i[i2_])])
    end

    if :UpdateLocalInteraction in keys(agent.declaredUpdates)
        code = agent.declaredUpdates[:UpdateLocalInteraction]

        code = vectorize(code,agent)
        #Custom functions
        code = postwalk(x->@capture(x,euclideanDistance()) ? :(euclideanDistance($(metricArgs...))) : x, code)
        code = postwalk(x->@capture(x,manhattanDistance()) ? :(manhattanDistance($(metricArgs...))) : x, code)
        code = neighborsLoop(code,agent)

        agent.declaredUpdatesCode[:UpdateLocalInteraction] = code
        agent.declaredUpdatesFunction[:UpdateLocalInteraction_] = Main.eval(:(($(args...),) -> $code))
        agent.declaredUpdatesFunction[:UpdateLocalInteraction] = Main.eval(:((community,agent) -> agent.declaredUpdatesFunction[:UpdateLocalInteraction_]($(args2...))))
    else
        agent.declaredUpdatesFunction[:UpdateLocalInteraction] = Main.eval(:((community,agent) -> nothing))
    end

end

function updateLocalInteractions!(community,agent)

    agent.declaredUpdatesFunction[:UpdateLocalInteraction](community,agent)

    return 

end