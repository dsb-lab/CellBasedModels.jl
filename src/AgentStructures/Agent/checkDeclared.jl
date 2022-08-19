"""
    function checkDeclared(abm::Agent,s::Symbol)

Checks if a symbol or array of symbols has already been declared in the agent and returns an errors if duplications are found. Returns nothing otherwise.

# Args
 - **abm::Agent**: Agent structure containing the high level code of the agents.
 - **s::Symbol(Array{Symbol})**: Symbol(s) to check if already declared.

# Returns
 - Nothing
"""
function checkDeclared(abm::Agent,s::Symbol)

    if endswith(string(s),"_") 
        error("Not possible to declare symbols with ending lower brace _. These symbols are reserved for the inner work of the package.")
    end

    if endswith(string(s),"New") 
        error("Not possible to declare symbols with ending with New. These symbols are reserved for the inner work of the package.")
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

    if s in abm.declaredSymbols.name
        error(s, " already defined in Agent Based model in Symbols.")
    end

    if s in abm.declaredSymbolsUpdated.name
        error(s, " already defined in Agent Based model in Update Symbols.")
    end

    if s in abm.additionalSymbols.name
        error(s, " already defined in Agent Based model in Additional Symbols.")
    end

    return
end

function checkDeclared(abm::Agent,s::Array{Symbol})

    for i in s #Check double declarations
        if length(findall(s.==i))>1
            error("Variable ", i, " declared more than once.")
        end
        #Check if already declared
        checkDeclared(abm,i)
    end

    return
end