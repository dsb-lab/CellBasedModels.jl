"""
    function updates_!(p)

Function that checks the variables in the model that are modified at each step in order to make appropiate copy vectors and add them to program.
"""
function updates_!(p::Program_)
    syms = []
    for i in keys(p.agent.declaredUpdates)
        if !(emptyquote_(p.agent.declaredUpdates[i])) && !(i in ["UpdateInteraction","UpdateLocalInteraction"])
            s = symbols_(p.agent,p.agent.declaredUpdates[i])
            append!(syms,s[Bool.(s[:,"updated"] .+ s[:,"assigned"]),"Symbol"])
        end
    end

    unique!(syms)

    ## Assign updates of variable types
    for t in keys(p.agent.declaredSymbols)
        dict = Dict{Symbol,Int}()
        counter = 1
        for i in syms
            if i in p.agent.declaredSymbols[t]
                dict[i] = counter
                counter += 1
            end
        end
        p.update[t] = dict
    end
    
    ## Check equations and their update variables
    dict = Dict{Symbol,Int}()
    counter = 1
    if "Equation" in keys(p.agent.declaredUpdates)
        s = symbols_(p.agent,p.agent.declaredUpdates["Equation"]).Symbol
        for i in p.agent.declaredSymbols["Local"]
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
    if "EventDivision" in keys(p.agent.declaredUpdates)
        s = symbols_(p.agent,p.agent.declaredUpdates["EventDivision"]).Symbol
        for place in ["Local","Identity"]
            for i in p.agent.declaredSymbols[place]
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

    ## Check bound updates
    for j in p.agent.boundary.addSymbols
        if !(j in keys(p.update["Local"]))
            p.update["Local"][j] = maximum(values(p.update["Local"])) + 1
        end
    end

    ## Check medium equations and their update variables
    dict = Dict{Symbol,Int}()
    counter = 1
    if "UpdateMedium" in keys(p.agent.declaredUpdates)
        s = symbols_(p.agent,p.agent.declaredUpdates["UpdateMedium"]).Symbol
        for i in p.agent.declaredSymbols["Medium"]
            ss = Meta.parse(string(MEDIUMSYMBOL,i))
            if ss in s
                dict[i] = counter
                counter += 1
                if !(i in keys(p.update["Medium"]))
                    if isempty(p.update["Medium"])
                        p.update["Medium"][i] = 1
                    else
                        p.update["Medium"][i] = maximum(values(p.update["Medium"])) + 1
                    end
                end
            end
        end
    end
    p.update["Medium"] = dict

    return
end