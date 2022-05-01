"""
    function addIntegratorEuler_!(p::Program_, platform::String)

Adapts the code declared in `UpdateVariable` to be integrated as the Euler method and adds the code generated to `Program_`.

```math
x(t+Δt) = x(t) + a*Δt +b*ΔW
```

# Args
 - **p::Program_**:  Program_ structure containing all the created code when compiling.
 - **platform::String**: Platform to adapt the code.

# Returns
 -  Nothing
"""
function addIntegratorEuler_!(p::Program_, platform::String)
    
    if "UpdateVariable" in keys(p.agent.declaredUpdates)

        #Add medium coupling
        code = addMediumCode(p)

        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])

        #Create integration step function
        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            code = postwalk(x -> @capture(x,g_(s_)=v__) && g == DIFFSYMBOL && s == j ? :($j.new = $j + $(v...)) : x, code)
            code = postwalk(x -> @capture(x,dW) ? :(Normal(0.,sqrt(dt))) : x, code)
        end
        code = vectorize_(p.agent,code,p)
        f = simpleFirstLoopWrapInFunction_(platform,:integrationStep1_!,code)
        push!(p.declareF.args,f)

        #Create wrapped integration step function
        if "UpdateInteraction" in keys(p.agent.declaredUpdates)
            cleanLocal = :()
            if !isempty(p.agent.declaredSymbols["LocalInteraction"])
                cleanLocal = :(localInteractionV .= 0)
            end
            cleanInteraction = :()
            if !isempty(p.agent.declaredSymbols["IdentityInteraction"])
                cleanInteraction = :(identityInteractionV .= 0)
            end
            addInteraction = [:($cleanLocal; $cleanInteraction ;@platformAdapt interactionCompute_!(ARGS_))]
        else
            addInteraction = []
        end
        push!(p.declareF.args,
            :(begin
                function integrationStep_!(ARGS_)
                    $(addInteraction...)
                    @platformAdapt integrationStep1_!(ARGS_)
                    #println(localVCopy[1,:])

                    return
                end
            end)
        )

        push!(p.execInloop.args,
            :(integrationStep_!(ARGS_))
        )

    end
        
    return
end