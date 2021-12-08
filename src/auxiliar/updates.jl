"""
    function updates_!(p)

Function that checks the variables in the model that are modified at each step in order to make appropiate copy vectors and add them to program.
"""
function updates_!(p::Program_)

    ## Assign updates of variable types
    for t in keys(p.agent.declaredSymbols)
        dict = Dict{Symbol,Int}()
        counter = 1
        for i in p.agent.declaredSymbols[t]

            found = false
            for up in keys(p.agent.declaredUpdates)
                code =  postwalk(x->@capture(x, c_ = f_) && c == i ? :ARGS_ : x , p.agent.declaredUpdates[up])
                code =  postwalk(x->@capture(x, c_ += f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_ -= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_ *= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_ /= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_ \= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_ ÷= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_ %= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_ ^= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_ &= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_ |= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_ ⊻= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_ >>>= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_ >>= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_ <<= f_) && c == i ? :ARGS_ : x , code)

                if inexpr(code,:ARGS_)
                    found = true
                    break
                end
            end

            for up in keys(p.agent.declaredUpdates)
                code =  postwalk(x->@capture(x, c_[g__] = f_) && c == i ? :ARGS_ : x , p.agent.declaredUpdates[up])
                code =  postwalk(x->@capture(x, c_[g__] += f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_[g__] -= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_[g__] *= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_[g__] /= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_[g__] \= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_[g__] ÷= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_[g__] %= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_[g__] ^= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_[g__] &= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_[g__] |= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_[g__] ⊻= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_[g__] >>>= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_[g__] >>= f_) && c == i ? :ARGS_ : x , code)
                code =  postwalk(x->@capture(x, c_[g__] <<= f_) && c == i ? :ARGS_ : x , code)
                
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