function updateFunction(agent)

    args = []
    for i in keys(agent.declaredSymbols)
        push!(args,:($i))        
    end

    args2 = [:(community.$i) for i in args]

    parameters = [(Meta.parse(string(sym)[1:end-4]),sym,prop) for (sym,prop) in pairs(agent.declaredSymbols) if :Update in prop]

    code = quote end
    if agent.platform == :CPU
        for (s,sNew,prop) in parameters
            if :Local in prop
                push!(code.args,:(@views $s[1:N[1]] .= $sNew[1:N[1]]))
            elseif :Global in prop
                push!(code.args,:(s .= $sNew))
            else
                error("Updating not implemented")
            end
        end
    else
        error("Not implemented yet.")
    end

    agent.declaredUpdatesCode[:Update] = code
    agent.declaredUpdatesFunction[:Update_] = Main.eval(:(($(args...),) -> $code))
    agent.declaredUpdatesFunction[:Update] = Main.eval(:((community,agent) -> agent.declaredUpdatesFunction[:Update_]($(args2...))))

    return
end

function update!(community,agent)

    agent.declaredUpdatesFunction[:Update](community,agent)

    return 

end