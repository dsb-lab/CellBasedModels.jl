"""
    function updates_!(p,abm)

Function that checks the variables in the model that are modified at each step in order to make appropiate copy vectors and add them to program.
"""
function updates_!(p::Program_,abm::Agent)
    syms = []
    for i in keys(abm.declaredUpdates)
        if !(emptyquote_(abm.declaredUpdates[i])) && !(i in ["UpdateInteraction","UpdateLocalInteraction"])
            s = symbols_(abm,abm.declaredUpdates[i])
            append!(syms,s[Bool.(s[:,"updated"] .+ s[:,"assigned"]),"Symbol"])
        end
    end

    unique!(syms)

    ## Assign updates of variable types
    for t in keys(abm.declaredSymbols)
        dict = Dict{Symbol,Int}()
        counter = 1
        for i in syms
            if i in abm.declaredSymbols[t]
                dict[i] = counter
                counter += 1
            end
        end
        p.update[t] = dict
    end
    
    ## Check equations and their update variables
    dict = Dict{Symbol,Int}()
    counter = 1
    if !(emptyquote_(abm.declaredUpdates["Equation"]))
        s = symbols_(abm,abm.declaredUpdates["Equation"]).Symbol
        for i in abm.declaredSymbols["Local"]
            ss = Meta.parse(string("∂",i))
            if ss in s
                dict[i] = counter
                counter += 1
                if !(i in keys(p.update["Local"]))
                    if isempty(p.update["Local"])
                        p.update["Local"][i] = 1
                    else
                        p.update["Local"][i] = maximum(values(p.update["Local"])) + 1
                    end
                end
            end
        end
    end
    p.update["Variables"] = dict

    return
end