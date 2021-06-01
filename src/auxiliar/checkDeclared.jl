"""
Function that checks if an Symbol has already been declared in the model and returns an error if it is duplicated.

# Arguments
 - **agentModel** (Model) Agent Model
 - **s** (Symbol, Array{Symbol}) Symbol(s) to be checked for duplicated declaration.

# Returns

nothing
"""
function checkDeclared_(agentModel::Model,s::Symbol)

    if string(s)[end] == "_" && !(s in RESERVEDVARS)
        error("Not possible to declare symbols with ending lower brace _. These symbols are reserved for the inner work of the module.")
    end

    if s in RESERVED
        error(s, " is a reserved symbol.\nListof reserved symbols: ", RESERVED)
    elseif isdefined(Base,s)
        error(s, " is a symbol from module Base.")
    end
    
    for k in keys(agentModel.declaredSymbols)
        if s in agentModel.declaredSymbols[k]
            error(s, " already defined in Agent Based model in ", k,".")
        end
    end

    for k in keys(agentModel.declaredUpdates)
        if s in agentModel.declaredUpdates[k]
            error(s, " already defined in Agent Based model in ", k,".")
        end
    end

    return
end

function checkDeclared_(agentModel::Model,s::Array{Symbol})

    for i in s #Check double declarations
        if length(findall(s.==i))>1
            error("Variable ", i, " declared more than once.")
        end
        #Check if already declared
        checkDeclared_(agentModel,i)
    end

    return
end

function checkIsDeclared_(agentModel::Model,s::Symbol)

    found =  false

    for k in keys(agentModel.declaredSymbols)
        if s in agentModel.declaredSymbols[k]
            found = true
            break
        end
    end

    if !found 
        error("Parameter ", s, " not found in the agent model.")
    end

    return Nothing
end

function checkIsDeclared_(agentModel::Model,s::Array{Symbol})

    for i in s #Check double declarations
        if length(findall(s.==i))>1
            error("Variable ", i, " declared more than once.")
        end
        checkIsDeclared_(agentModel,i)
    end

    return Nothing
end