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

    if !all([typeof(i) == LineNumberNode for i in agent.declaredUpdates[:UpdateInteraction].args])
        code = agent.declaredUpdates[:UpdateInteraction]

        code = vectorize(code,agent)
        #Custom functions
        code = postwalk(x->@capture(x,euclideanDistance()) ? :(euclideanDistance($(metricArgs...))) : x, code)
        code = postwalk(x->@capture(x,manhattanDistance()) ? :(manhattanDistance($(metricArgs...))) : x, code)
        #Put in loop
        code = neighborsLoop(code,agent)

        agent.declaredUpdatesCode[:UpdateInteraction] = code
        agent.declaredUpdatesFunction[:UpdateInteraction_] = Main.eval(:(($(args...),) -> $code))
        agent.declaredUpdatesFunction[:UpdateInteraction] = Main.eval(:((community,agent) -> agent.declaredUpdatesFunction[:UpdateInteraction_]($(args2...))))
    else
        agent.declaredUpdatesFunction[:UpdateInteraction] = Main.eval(:((community,agent) -> nothing))
    end

end

function updateInteractions!(community,agent)

    agent.declaredUpdatesFunction[:UpdateInteraction](community,agent)

    return 

end