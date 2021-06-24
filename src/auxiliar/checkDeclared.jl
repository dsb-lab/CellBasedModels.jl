"""
    function checkDeclared_(abm,s)

Checks if an symbol or array of symbols has already been declared in the agent and returns an errors if duplications are found. Returns nothing otherwise.
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

    # for k in keys(abm.declaredUpdates)
    #     if s in abm.declaredUpdates[k]
    #         error(s, " already defined in Agent Based model in ", k,".")
    #     end
    # end

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

"""
    function checkIsDeclared_(abm,s)

Checks if an symbol or array of symbols has already been declared in the agent and returns an errors if it is not found. Returns true otherwise.
"""
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

"""
    function whereDeclared_(abm::Agent,s::Symbol)

Finds where the symbol s is declared, returns nothing if not found.
"""
function whereDeclared_(abm::Agent,s::Symbol)

    place =  (:NotDefined,:None)

    if isdefined(Base.Math,s)
        return (:Math,:None)
    elseif s in VALIDDISTRIBUTIONSCUDA
        return (:Distributions,:CUDAcompatible)
    elseif s in VALIDDISTRIBUTIONS
        return (:Distributions,:CPUcompatible)
    elseif isdefined(Main,s)
        return (:Main,:GPU)
    else
        if string(s)[end] == '₂'
            ss = Meta.parse(string(s)[1:end-1])
            for k in keys(abm.declaredSymbols)
                if ss in abm.declaredSymbols[k]
                    place = (:Model,Meta.parse(string(k,"2")))
                    break
                end
            end
        elseif string(s)[end] == '₁'
            ss = Meta.parse(string(s)[1:end-1])
            for k in keys(abm.declaredSymbols)
                if ss in abm.declaredSymbols[k]
                    place = (:Model,Meta.parse(string(k,"1")))
                    break
                end
            end
        else
            for k in keys(abm.declaredSymbols)
                if s in abm.declaredSymbols[k]
                    place = (:Model,Meta.parse(string(k)))
                    break
                end
            end        
        end
    end

    return place
end

# function checkConsistency(amb::Agent,code::Expr,subsetDeclared)

#     #Check updated in the wrong place
#     updated,assigned,ref,symbol = symbols_(code)
#     use,declaration = validSymbolsAgent_(abm,subsetDeclared)

#     for i in symbol
#         #Check if symbol exists
#         if !(isdefined(Base.Math,i) || isdefined(Main,i) || isdefined(Distributions,j) || i in allSymbols) || isdefined(AgentBasedModels,i)
#             error("Symbol ", i, " declared in \n", code, " has not been declared of the scopes.")
#         end
#         #Check if symbol 

#     for i in updated
#         place = whereDeclared_(abm,i)
#         if place == "Global" || place == "GlobalArray" || place === nothing
#             nothing
#         else
#             error(i, " has been updated in Global but was declared as ", place, " in code:\n", abm.declaredUpdates["UpdateGlobal"])
#         end
#     end
# end

