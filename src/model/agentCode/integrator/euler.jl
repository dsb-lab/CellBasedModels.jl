"""
    function integratorEuler_(p, platform)

Adapter for the Euler integration step method.

```math
x(t+Δt) = x(t) + a*Δt +b*ΔW
```

The algorithm can be reduced to three kernel invocations performing the following actions:
 - Clean the interaction parameters array
 - Compute interaction parameters at original position v₀ (if there are interaction parameters)
 - Compute final position v₁
"""
function addIntegratorEuler_!(p::Program_, platform::String)
    
    if "UpdateVariable" in keys(p.agent.declaredUpdates)

        code = p.agent.declaredUpdates["UpdateVariable"]

        #Create interaction parameter kernel if there is any interaction parameter updated
        if "UpdateInteraction" in keys(p.agent.declaredUpdates)

            k1 = loop_[p.neighbors](p,p.agent.declaredUpdates["UpdateInteraction"],platform)
            k1 = vectorize_(p.agent,k1,p,interaction=true)
            k1 = wrapInFunction_(:interactionCompute_!,k1)
            push!(p.declareF.args,k1)

        end

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
            addInteraction = [:(@platformAdapt interactionCompute_!(ARGS_))]
            push!(p.execInit.args, :(@platformAdapt interactionCompute_!(ARGS_)))
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