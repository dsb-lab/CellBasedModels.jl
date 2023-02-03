"""
    function addUpdateInteraction_!(p::AgentCompiled)

Generate the functions with the code declared in `UpdateInteraction` and adds the code generated to `AgentCompiled`.

# Args
 - **p::AgentCompiled**:  AgentCompiled structure containing all the created code when compiling.

# Returns
 -  Nothing
"""
function addUpdateInteraction_!(p::AgentCompiled)

    #Create interaction parameter kernel if there is any interaction parameter updated
    k1 = :()
    if "UpdateInteraction" in keys(p.agent.declaredUpdates)
        k1 = loop_[p.neighbors](p,p.agent.declaredUpdates["UpdateInteraction"],p.platform)
        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            if j in keys(p.update["Local"])
                pos = p.update["Local"][j]
                k1 = postwalk(x -> @capture(x,s_) && s == j ? :(localVCopy[ic1_,$pos]) : x, k1)
            end
        end
        k1 = vectorize_(p.agent,k1,p,interaction=true)
    end

    k2 = :()
    if "UpdateGlobalInteraction" in keys(p.agent.declaredUpdates)
        k2 = p.agent.declaredUpdates["UpdateGlobalInteraction"]
        k2 = vectorize_(p.agent,k2,p)
        k2 = postwalk(x->@capture(x,ic1_) && ic1 == :ic1_ ? :ic2_ : x, k2)
        k2 = :(if ic1_ == 1; for ic2_ in 1:1:N; $k2 end end)

        if k1 != :()
            k1 = postwalk(x->@capture(x,for ic1_ in g_:h_:j_ v__ end) && ic1 == :ic1_ ? :(for ic1_ in $g:$h:$j; $k2; $(v...) end) : x, k1)
        else
            k1 = simpleFirstLoop_(p.platform, k2)
        end
    end

    if "UpdateInteraction" in keys(p.agent.declaredUpdates) || "UpdateGlobalInteraction" in keys(p.agent.declaredUpdates)
        
        cleanLocal = :()
        if !isempty(p.agent.declaredSymbols["LocalInteraction"])
            cleanLocal = :(localInteractionV[1:com.NMax,:] .= 0.)
        end
        cleanIdentity = :()
        if !isempty(p.agent.declaredSymbols["IdentityInteraction"])
            cleanIdentity = :(identityInteractionV[1:com.NMax,:] .= 0)
        end
        cleanGlobal = :()
        if !isempty(p.agent.declaredSymbols["GlobalInteraction"])
            cleanGlobal = :(globalInteractionV[1:com.NMax,:] .= 0)
        end

        k1 = wrapInFunction_(:interactionStep_!,[ARGS;neighborsArguments[p.neighbors]],k1)
        p.AgentCompiledinteraction = :(function f(com) 
                                $k1; 
                                $cleanLocal; 
                                $cleanIdentity; 
                                $cleanGlobal; 
                                @platformAdapt interactionStep_!($([COMARGS;neighborsArgumentsCommunityLoop[p.neighbors]]...))
                            end)
        p.AgentCompiledinteraction = platformAdapt(p,p.AgentCompiledinteraction)
        p.f_interaction = Main.eval(p.AgentCompiledinteraction)

    end

    return nothing
end