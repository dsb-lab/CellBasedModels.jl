function checkDeclared(agentModel::Model,s::Symbol;eqs=false)

    if string(s)[end] == "_" && !(s in RESERVEDVARS)
        error("Not possible to declare symbols with ending lower brace _. These symbols are reserved for the inner work of the module.")
    end
    if eqs
        if s in [RESERVEDCALLS;RESERVEDSYMBOLS]
            error(s, " is a reserved symbol.\nListof reserved symbols: ", RESERVED)
        elseif isdefined(Base,s)
            error(s, " is a symbol from module Base.")
        end
    
        for k in keys(agentModel.declaredSymb)
            if s in agentModel.declaredSymb[k]
                error(s, " already defined in Agent Based model in ", k,".")
            end
        end
    else
        if s in RESERVED
            error(s, " is a reserved symbol.\nListof reserved symbols: ", RESERVED)
        elseif isdefined(Base,s)
            error(s, " is a symbol from module Base.")
        end
    
        for k in keys(agentModel.declaredSymb)
            if s in agentModel.declaredSymb[k]
                error(s, " already defined in Agent Based model in ", k,".")
            end
        end

        for k in keys(agentModel.declaredRandSymb)
            if s in [i[1] for i in agentModel.declaredRandSymb[k]]
                error(s, " already defined in Agent Based model in ", k,".")
            end
        end
    
    end

    return
end