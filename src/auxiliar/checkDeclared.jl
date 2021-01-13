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

        if s in agentModel.declaredIds
            error(s, " already defined in Agent Based model in Ids.")
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

        if s in agentModel.declaredIds
            error(s, " already defined in Agent Based model in Ids.")
        end

    end

    return
end

function checkDeclared(agentModel::Model,s::Array{Symbol};eqs=false)

    for i in randSymb #Check double declarations
        if length(findall(randSymb.==i))>1
            error("Random variable ", i, " declared more than once.")
        end
        #Check if already declared
        checkDeclared(agentModel,i,eqs=eqs)
    end

    return
end

function checkRandDeclared(agentModel::Model,randVar::Tuple)

    #Check if symbols has been declared
    checkDeclared(agentModel,randVar[1])
    #Check if distribution exists
    if !(randVar[2] in RESERVEDCALLS)
        error("Probabily distribution assigned to random variable ", randVar[1], " does not exist.")
    end

    return
end

function checkRandDeclared(agentModel::Model,randVar::Array)

    if length(randVar) > 0
        randSymb = [i[1] for i in randVar]
        for (j,i) in enumerate(randSymb) #Check double declarations
            if length(findall(randSymb.==i))>1
                error("Random variable ", i, " declared more than once.")
            end
            #Check if already declared
            checkRandDeclared(agentModel,randVar[j])
        end
    end

    return
end
