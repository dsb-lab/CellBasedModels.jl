"""
    function updates_!(p,abm)

Function that checks the variables in the model that are modified at each step in order to make appropiate copy vectors and add them to program.
"""
function updates_!(p::Program_,abm::Agent,space::SimulationSpace)
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
    if "Equation" in keys(abm.declaredUpdates)
        s = symbols_(abm,abm.declaredUpdates["Equation"]).Symbol
        for i in abm.declaredSymbols["Local"]
            ss = Meta.parse(string(EQUATIONSYMBOL,i))
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

    ## Check division and their update variables
    dict = Dict{Symbol,Int}()
    counter = 1
    if "EventDivision" in keys(abm.declaredUpdates)
        s = symbols_(abm,abm.declaredUpdates["EventDivision"]).Symbol
        for place in ["Local","Identity"]
            for i in abm.declaredSymbols[place]
                for j in DIVISIONSYMBOLS
                    ss = Meta.parse(string(i,j))
                    if ss in s && !(i in keys(dict))
                        dict[i] = counter
                        counter += 1
                        if !(i in keys(p.update[place]))
                            if isempty(p.update[place])
                                p.update[place][i] = 1
                            else
                                p.update[place][i] = maximum(values(p.update[place])) + 1
                            end
                        end
                    end
                end
            end
        end
    end
    p.update["EventDivision"] = dict

    ## Check space and bound updates
    for i in space.box
        if i.s in keys(p.update["Local"])
            for j in keys(i.addSymbols)
                for k in i.addSymbols[j]
                    if !(k in keys(p.update["Local"]))
                        p.update["Local"][k] = maximum(values(p.update["Local"])) + 1
                    end
                end
            end
        end
    end

    return
end