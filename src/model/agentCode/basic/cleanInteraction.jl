"""
    function addCleanInteraction_!(p::Program_,platform::String)

Generate the functions related with Cleaning Interaction Updates.
"""
function addCleanInteraction_!(p::Program_,platform::String)

    if "UpdateLocalInteraction" in keys(p.agent.declaredUpdates)

        #Construct cleanup function
        up = quote end

        for i in p.agent.declaredSymbols["Local"]

            code =  postwalk(x->@capture(x, c_.g_ += f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , p.agent.declaredUpdates["UpdateLocalInteraction"])
            code =  postwalk(x->@capture(x, c_.g_ -= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ *= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ /= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ \= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ ÷= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ %= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ ^= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ &= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ |= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ ⊻= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ >>>= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ >>= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ <<= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)

            if inexpr(code,:ARGS_)
                pos = findfirst(p.agent.declaredSymbols["Local"] .== i)
                push!(up.args,:(localV[ic1_,$pos]=0))
            end

        end

        for i in p.agent.declaredSymbols["Identity"]

            code =  postwalk(x->@capture(x, c_.g_ += f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , p.agent.declaredUpdates["UpdateLocalInteraction"])
            code =  postwalk(x->@capture(x, c_.g_ -= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ *= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ /= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ \= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ ÷= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ %= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ ^= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ &= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ |= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ ⊻= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ >>>= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ >>= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ <<= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)

            if inexpr(code,:ARGS_)
                pos = findfirst(p.agent.declaredSymbols["Identity"] .== i)
                push!(up.args,:(identityV[ic1_,$pos]=0))
            end

        end

        if up != quote end
            fclean = simpleFirstLoopWrapInFunction_(platform,:cleanLocalInteraction_!,up)
            push!(p.declareF.args,fclean)
        end
    end

    if "UpdateInteraction" in keys(p.agent.declaredUpdates)

        #Construct cleanup function
        up = quote end

        for i in p.agent.declaredSymbols["Local"]

            code =  postwalk(x->@capture(x, c_.g_ += f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , p.agent.declaredUpdates["UpdateInteraction"])
            code =  postwalk(x->@capture(x, c_.g_ -= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ *= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ /= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ \= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ ÷= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ %= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ ^= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ &= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ |= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ ⊻= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ >>>= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ >>= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ <<= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)

            if inexpr(code,:ARGS_)
                pos = findfirst(p.agent.declaredSymbols["Local"] .== i)
                push!(up.args,:(localV[ic1_,$pos]=0))
            end

        end

        for i in p.agent.declaredSymbols["Identity"]

            code =  postwalk(x->@capture(x, c_.g_ += f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , p.agent.declaredUpdates["UpdateInteraction"])
            code =  postwalk(x->@capture(x, c_.g_ -= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ *= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ /= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ \= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ ÷= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ %= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ ^= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ &= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ |= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ ⊻= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ >>>= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ >>= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            code =  postwalk(x->@capture(x, c_.g_ <<= f_) && c == i && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)

            if inexpr(code,:ARGS_)
                pos = findfirst(p.agent.declaredSymbols["Identity"] .== i)
                push!(up.args,:(identityV[ic1_,$pos]=0))
            end

        end

        if up != quote end
            fclean = simpleFirstLoopWrapInFunction_(platform,:cleanInteraction_!,up)
            push!(p.declareF.args,fclean)
        end
    end

    return nothing
end