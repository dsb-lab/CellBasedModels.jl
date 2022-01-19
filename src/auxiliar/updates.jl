"""
    function updates_!(p)

Function that checks the variables in the model that are modified at each step in order to make appropiate copy vectors and add them to program.
"""
function updates_!(p::Program_)

    ##Assign updates of variable types
    for t in UPDATINGTYPES
        dict = Dict{Symbol,Int}()
        counter = 1
        for i in p.agent.declaredSymbols[t]

            found = false
            for up in keys(p.agent.declaredUpdates)
                code =  postwalk(x->@capture(x, c_.new)  && c == i ? :ARGS_ : x , p.agent.declaredUpdates[up]) #remove agent updates

                if inexpr(code,:ARGS_)
                    found = true
                    break
                end
            end

            #Add symbols that are assigned
            for up in keys(p.agent.declaredUpdates)
                code =  postwalk(x->@capture(x, c_.g_.new = f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , p.agent.declaredUpdates[up])

                if inexpr(code,:ARGS_)
                    found = true
                    break
                end
            end
            
            for up in keys(p.agent.declaredUpdates)
                code =  postwalk(x->@capture(x, c_[g__].new) && c == i ? :ARGS_ : x , p.agent.declaredUpdates[up])
                
                if inexpr(code,:ARGS_)
                    found = true
                    break
                end
            end

            if "Equation" in keys(p.agent.declaredUpdates)
                code =  postwalk(x->@capture(x, g_(c_) = f_) && c == i && g == DIFFSYMBOL ? :ARGS_ : x , p.agent.declaredUpdates["Equation"])
                if inexpr(code,:ARGS_)
                    found = true
                end
            end

            if "UpdateMedium" in keys(p.agent.declaredUpdates)
                code =  postwalk(x->@capture(x, g_(c_) = f_) && c == i && g == DIFFMEDIUMSYMBOL ? :ARGS_ : x , p.agent.declaredUpdates["UpdateMedium"])
                if inexpr(code,:ARGS_)
                    found = true
                end
            end

            #Add symbols from boundaries
            if t == "Local"
                if i in p.agent.boundary.addSymbols
                    found = true
                end
            end

            if found
                dict[i] = counter
                counter += 1
            end
        end
        p.update[t] = dict
    end        

    dict = Dict{Symbol,Int}()
    counter = 1
    for i in p.agent.declaredSymbols["Local"]
        found = false
        if "Equation" in keys(p.agent.declaredUpdates)
            code =  postwalk(x->@capture(x, g_(c_) = f_) && c == i && g == DIFFSYMBOL ? :ARGS_ : x , p.agent.declaredUpdates["Equation"])
            if inexpr(code,:ARGS_)
                found = true
            end
        end

        if found
            dict[i] = counter
            counter += 1
        end
    end
    p.update["Variables"] = dict
    
    return
end