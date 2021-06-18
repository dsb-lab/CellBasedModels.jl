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
function addIntegratorEuler_!(p::Program_, abm::Agent, space::SimulationFree, platform::String)
    
    if !emptyquote_(abm.declaredUpdates["Equation"])

        code = abm.declaredUpdates["Equation"]

        #Create interaction parameter kernel if there is any interaction parameter updated
        if !emptyquote_(abm.declaredUpdates["UpdateInteraction"])

            k1 = loop_(abm,space,abm.declaredUpdates["UpdateInteraction"],platform)
            k1 = vectorize_(abm,k1)
            k1 = wrapInFunction_(:interactionCompute_!,k1)
            push!(p.declareF.args,k1)

        end

        #Create integration step function
        for (i,j) in enumerate(abm.declaredSymbols["Local"])
            s = Meta.parse(string(j,"̇"))
            code = postwalk(x -> @capture(x,$s=v__) ? :($j = $j + $(v...)) : x, code)
            vectorize_(abm,code,update="Copy")
        end
        f = simpleFirstLoopWrapInFunction_(platform,:integrationStep1_!,code)
        push!(p.declareF.args,f)

        #Create wrapped integration step function
        if inexpr(code,:dW)
            push!(p.declareVar.args,:(dW = 0.)) #Declare variable for random initialisation
            push!(p.args,:dW)
            addRandInitialisation = [:(dW = rand()*dt)]
        else
            addRandInitialisation = []
        end
        if !emptyquote_(abm.declaredUpdates["UpdateInteraction"])
            addInteraction = [:(@platformAdapt cleanInteraction_!(ARGS_);@platformAdapt interactionCompute_!(ARGS_))]
        else
            addInteraction = []
        end
        push!(p.declareF.args,
            :(begin
                function integrationStep_!(ARGS_)
                    $(addRandInitialisation...)
                    $(addInteraction...)
                    @platformAdapt integrationStep1_(ARGS_)

                    return
                end
            end)
        )

        push!(p.execInloop.args,
            :(integrationStep_!(ARGS_))
        )

        updateVariables_!(abm,p)

    end
        
    return
end