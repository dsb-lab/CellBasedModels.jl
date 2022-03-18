"""
    function addUpdateLocal_!(p::Program_,platform::String)

Generate the functions related with Local Updates.
"""
function addUpdateLocal_!(p::Program_,platform::String)

    if "UpdateLocal" in keys(p.agent.declaredUpdates)

        push!(p.execInloop.args,
            :(@platformAdapt locStep_!(ARGS_)) 
        )

        #Add medium coupling
        code = addMediumCode(p)

        push!(code.args,p.agent.declaredUpdates["UpdateLocal"])

        #Add events 
        code = addEventAddAgent_(code, p, platform) 
        code = addEventRemoveAgent_(code, p, platform)

        #Construct functions
        f = simpleFirstLoopWrapInFunction_(platform,:locStep_!,code)
        f = vectorize_(p.agent,f,p)

        #Updates to localV
        f = postwalk(x->@capture(x,localVCopy[g__] = localVCopy[g2__]) ? :(localV[$(g...)] = localVCopy[$(g2...)]) : x, f)
        f = postwalk(x->@capture(x,identityVCopy[g__] = identityVCopy[g2__]) ? :(identityV[$(g...)] = identityVCopy[$(g2...)]) : x, f)

        push!(p.declareF.args,
            f)

    end

    return nothing
end