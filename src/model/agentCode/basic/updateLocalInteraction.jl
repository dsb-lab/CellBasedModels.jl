"""
    function addUpdateLocalInteraction_!(p::Program_,platform::String)

Generate the functions related with Local Interaction Updates.
"""
function addUpdateLocalInteraction_!(p::Program_,platform::String)

    if "UpdateLocalInteraction" in keys(p.agent.declaredUpdates)

        #Construct update computation function
        fcompute = loop_[p.neighbors](p,p.agent.declaredUpdates["UpdateLocalInteraction"],platform)
        fcompute = vectorize_(p.agent,fcompute,p,interaction=true)
        fcompute = wrapInFunction_(:locInterCompute_!,fcompute)
        push!(p.declareF.args,fcompute)

        #Wrap both functions in a clean step function
        if "UpdateLocalInteraction" in keys(p.agent.declaredUpdates)
            cleanLocal = :()
            if !isempty(p.agent.declaredSymbols["LocalInteraction"])
                cleanLocal = :(localInteractionV .= 0)
            end
            cleanInteraction = :()
            if !isempty(p.agent.declaredSymbols["IdentityInteraction"])
                cleanInteraction = :(identityInteractionV .= 0)
            end
            addInteraction = [:($cleanLocal; $cleanInteraction)]
        else
            addInteraction = []
        end
        f = push!(p.declareF.args,
                :(
                    function locInterStep_!(ARGS_)
                        $(addInteraction...)
                        @platformAdapt locInterCompute_!(ARGS_)
                        return
                    end
                )
                )
        push!(p.execInit.args,
                    :(locInterStep_!(ARGS_))
                )
        push!(p.execInloop.args,
                :(locInterStep_!(ARGS_))
                )
        push!(p.execAfter.args,
                    :(locInterStep_!(ARGS_))
                )
    end

    return nothing
end