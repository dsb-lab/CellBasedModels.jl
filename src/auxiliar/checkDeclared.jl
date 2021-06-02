"""
Function that checks if an Symbol has already been declared in the model and returns an error if it is duplicated.

# Arguments
 - **abm** (Agent) Agent Agent
 - **s** (Symbol, Array{Symbol}) Symbol(s) to be checked for duplicated declaration.

# Returns

nothing
"""
function checkDeclared_(abm::Agent,s::Symbol)

    if string(s)[end] == "_" && 
        error("Not possible to declare symbols with ending lower brace _. These symbols are reserved for the inner work of the module.")
    end

    if s in RESERVEDSYMBOLS
        error(s, " is a reserved symbol.")
    end

    if isdefined(Base.Math,s)
        error(s, " is a symbol from module Base. Avoid defining symbols of that library.")
    end

    if isdefined(Distributions,s)
        global dist = false
        try AgentBasedModels.eval(:(dist = Distributions.$s <: Distribution))
        catch
            Nothing
        end
        if dist
            error(s, " is a symbol from module Distributions. Avoid defining symbols of that library.")
        end
    end

    for k in keys(abm.declaredSymbols)
        if s in abm.declaredSymbols[k]
            error(s, " already defined in Agent Based model in ", k,".")
        end
    end

    for k in keys(abm.declaredUpdates)
        if s in abm.declaredUpdates[k]
            error(s, " already defined in Agent Based model in ", k,".")
        end
    end

    return
end

function checkDeclared_(abm::Agent,s::Array{Symbol})

    for i in s #Check double declarations
        if length(findall(s.==i))>1
            error("Variable ", i, " declared more than once.")
        end
        #Check if already declared
        checkDeclared_(abm,i)
    end

    return
end

function checkIsDeclared_(abm::Agent,s::Symbol)

    found =  false

    for k in keys(abm.declaredSymbols)
        if s in abm.declaredSymbols[k]
            found = true
            break
        end
    end

    if !found 
        error("Parameter ", s, " not found in the agent model.")
    end

    return Nothing
end

function checkIsDeclared_(abm::Agent,s::Array{Symbol})

    for i in s #Check double declarations
        if length(findall(s.==i))>1
            error("Variable ", i, " declared more than once.")
        end
        checkIsDeclared_(abm,i)
    end

    return Nothing
end