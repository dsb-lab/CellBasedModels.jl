function commonArguments(agentModel::Model; random = true)
    l = [:dt_,:t_,:N_]
    if length(agentModel.declaredSymb["var"])>0
        push!(l,:v_)
    end
    if length(agentModel.declaredSymb["inter"])>0
        push!(l,:inter_)
    end
    if length(agentModel.declaredSymb["locInter"])>0
        push!(l,:locInter_)
    end
    if length(agentModel.declaredSymb["loc"])>0
        push!(l,:loc_)
    end
    if length(agentModel.declaredSymb["glob"])>0
        push!(l,:glob_)
    end
    if random
        if length(agentModel.declaredRandSymb["locRand"])>0
            push!(l,:locRand_)
        end
        if length(agentModel.declaredRandSymb["locInterRand"])>0
            push!(l,:locInterRand_)
        end
        if length(agentModel.declaredRandSymb["globRand"])>0
            push!(l,:globRand_)
        end
    end
    
    return l
end