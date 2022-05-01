"""
    function addUpdateInteraction_!(p::Program_,platform::String)

Generate the functions related with Interaction Updates.
"""
function addUpdateInteraction_!(p::Program_,platform::String)

    #Create interaction parameter kernel if there is any interaction parameter updated
    if "UpdateInteraction" in keys(p.agent.declaredUpdates)
        k1 = loop_[p.neighbors](p,p.agent.declaredUpdates["UpdateInteraction"],platform)
        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            if j in keys(p.update["Local"])
                pos = p.update["Local"][j]
                k1 = postwalk(x -> @capture(x,s_) && s == j ? :(localVCopy[ic1_,$pos]) : x, k1)
            end
        end
        k1 = vectorize_(p.agent,k1,p,interaction=true)
        k1 = wrapInFunction_(:interactionCompute_!,k1)
        push!(p.declareF.args,k1)

        push!(p.execInit.args,
            :(@platformAdapt interactionCompute_!(ARGS_))
        )

        #declare it in the loop if there is no local or variable interactions
        if !("UpdateLocal" in keys(p.agent.declaredUpdates)) && !("UpdateVariable" in keys(p.agent.declaredUpdates))
            push!(p.execInloop.args,
                :(@platformAdapt interactionCompute_!(ARGS_))
            )
        end
    end

    return nothing
end