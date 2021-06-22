"""
    function integratorEuler_(p, abm, space, platform)

Adapter for the Euler integration step method.

```math
x(t+Δt) = x(t) + a*Δt +b*ΔW
```

The algorithm can be reduced to three kernel invocations performing the following actions:
 - Clean the interaction parameters array
 - Compute interaction parameters at original position v₀ (if there are interaction parameters)
 - Compute final position v₁
"""
function addIntegratorEuler_!(p::Program_, abm::Agent, space::SimulationSpace, platform::String)
    
    if "Equation" in keys(abm.declaredUpdates)

        code = abm.declaredUpdates["Equation"]

        #Create interaction parameter kernel if there is any interaction parameter updated
        if "UpdateInteraction" in keys(abm.declaredUpdates)

            k1 = loop_(p,abm,space,abm.declaredUpdates["UpdateInteraction"],platform)
            k1 = vectorize_(abm,k1,p)
            k1 = wrapInFunction_(:interactionCompute_!,k1)
            push!(p.declareF.args,k1)

        end

        #Create integration step function
        for (i,j) in enumerate(abm.declaredSymbols["Local"])
            s = Meta.parse(string("∂",j))
            code = postwalk(x -> @capture(x,$s=v__) ? :($j = $j + $(v...)) : x, code)
            # code = postwalk(x -> @capture(x,dW) ? :(rand()*sqrt(dt)) : x, code)
        end
        code = vectorize_(abm,code,p)
        pushfirst!(code.args,:(dW = Normal(0.,1.)*sqrt(dt)))
        f = simpleFirstLoopWrapInFunction_(platform,:integrationStep1_!,code)
        push!(p.declareF.args,f)

        #Create wrapped integration step function
        if "UpdateInteraction" in keys(abm.declaredUpdates)
            addInteraction = [:(@platformAdapt cleanInteraction_!(ARGS_);@platformAdapt interactionCompute_!(ARGS_))]
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