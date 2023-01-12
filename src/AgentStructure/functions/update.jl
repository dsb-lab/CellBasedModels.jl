function updateFunction(agent)

    #Get parameters and make community
    args = []
    for i in keys(agent.declaredSymbols)
        push!(args,:($i))        
    end
    args2 = [:(community.$i) for i in args]

    #Get parameters that are updated and find its symbols
    parameters = [(Meta.parse(string(sym)[1:end-4]),sym,prop) for (sym,prop) in pairs(agent.declaredSymbols) if :Update in prop]

    code = quote end
    if agent.platform == :CPU
        for (s,sNew,prop) in parameters
            if :Local in prop
                push!(code.args,:(@views $s[1:N[1]] .= $sNew[1:N[1]]))
            elseif :Global in prop
                push!(code.args,:(s .= $sNew))
            elseif :Medium in prop
                push!(code.args,:(s .= $sNew))
            else
                error("Updating not implemented for ", s, " with type ", prop)
            end
        end
    else
        error("Not implemented yet.")
    end

    #Add generated code to the agents
    agent.declaredUpdatesCode[:Update] = code
    agent.declaredUpdatesFunction[:Update_] = Main.eval(:(($(args...),) -> $code))
    agent.declaredUpdatesFunction[:Update] = Main.eval(:((community,agent) -> agent.declaredUpdatesFunction[:Update_]($(args2...))))

    return
end

"""
    function update!(community,agent)

Function that it is required to be called after performing all the functions of an step (findNeighbors, localStep, integrationStep...).
"""
function update!(community,agent)

    checkLoaded(community)

    agent.declaredUpdatesFunction[:Update](community,agent)

    return 

end