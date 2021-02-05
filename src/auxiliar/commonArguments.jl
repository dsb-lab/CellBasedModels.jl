function commonArguments(agentModel::Model; random = true)
    l = [:dt,:t,:N]
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
            for (i,j) in agentModel.declaredRandSymb["locRand"]
                push!(l,i)
            end
        end
        if length(agentModel.declaredRandSymb["locInterRand"])>0
            for (i,j) in agentModel.declaredRandSymb["locInterRand"]
                push!(l,i)
            end
        end
        if length(agentModel.declaredRandSymb["globRand"])>0
            for (i,j) in agentModel.declaredRandSymb["globRand"]
                push!(l,i)
            end
        end
        if length(agentModel.declaredRandSymb["varRand"])>0
            for (i,j) in agentModel.declaredRandSymb["varRand"]
                push!(l,i)
            end
        end
    end
    if length(agentModel.declaredIds)>0
        push!(l,:ids_)
    end
    
    return l
end