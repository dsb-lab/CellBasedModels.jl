"""
Returns list of all vectorized parameters of the model added by basic functions.

# Arguments
 - **agentModel** (Model) Agent Model

# Optional keywork Arguments

 - **random** (Bool) If true (default), returns also symbols for the vectorized random variables.
 
# Return 

Array{Symbol}
"""
function commonArguments(agentModel::Model; random = true)
    l = [:dt,:t,:N]

    #Floats
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
    if length(agentModel.declaredSymbArrays["glob"])>0
        for i in agentModel.declaredSymbArrays["glob"]
            push!(l,Meta.parse(string(i[1],"_")))
        end
    end

    #Arrays
    if length(agentModel.declaredRandSymbArrays["glob"])>0
        for i in agentModel.declaredRandSymbArrays["glob"]
            push!(l,Meta.parse(string(i[1][1],"_")))
        end
    end

    #Number
    if length(agentModel.declaredIds)>0
        push!(l,:ids_)
    end

    #Random
    if length(agentModel.declaredRandSymb["loc"])>0
        for (i,j) in agentModel.declaredRandSymb["loc"]
            push!(l,Meta.parse(string(i,"_")))
        end
    end
    if length(agentModel.declaredRandSymb["locInter"])>0
        for (i,j) in agentModel.declaredRandSymb["locInter"]
            push!(l,Meta.parse(string(i,"_")))
        end
    end
    if length(agentModel.declaredRandSymb["glob"])>0
        for (i,j) in agentModel.declaredRandSymb["glob"]
            push!(l,Meta.parse(string(i,"_")))
        end
    end
    if length(agentModel.declaredRandSymb["var"])>0
        for (i,j) in agentModel.declaredRandSymb["var"]
            push!(l,Meta.parse(string(i,"_")))
        end
    end
    
    return l
end