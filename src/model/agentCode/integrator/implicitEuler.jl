"""
    function integratorImplicitEuler_(p, platform)

Adapter for the Implicit Euler integration step method.

```math
x(t+Δt) = x(t) + a(t+Δt)*Δt
```

The solution is computed iteratively as,

```math
x_{k+1} = (1-lr)x_{k-1}+lr*x_{k}
```
where `lr` if the learning rate of the algorithm.

The algorithm can be reduced to a loop over four kernel invocations performing the following actions:
 - Clean the interaction parameters array.
 - Compute interaction parameters at original position v₀ (if there are interaction parameters).
 - Compute error of new update.
 - Assign new update.
"""
function addIntegratorImplicitEuler_!(p::Program_, platform::String)
    
    if "UpdateVariable" in keys(p.agent.declaredUpdates)

        #Add medium coupling
        code = addMediumCode(p)

        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])

        #Create interaction parameter kernel if there is any interaction parameter updated
        if "UpdateInteraction" in keys(p.agent.declaredUpdates)

            k1 = loop_[p.neighbors](p,p.agent.declaredUpdates["UpdateInteraction"],platform)
            k1 = vectorize_(p.agent,k1,p,interaction=true)
            k1 = wrapInFunction_(:interactionCompute_!,k1)
            push!(p.declareF.args,k1)

        end

        #Create integration step function
        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            if j in keys(p.update["Local"])
                pos = p.update["Local"][j]
            else
                pos = i
            end
            code = postwalk(x -> @capture(x,g_(s_)=v__) && g == DIFFSYMBOL && s == j ? :(predV[ic1_,$pos] = $j + $(v...)) : x, code)
            code = postwalk(x -> @capture(x,dW) ? error("Implicit Euler method do not work with SDE.") : x, code)
        end
        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            if j in keys(p.update["Local"])
                pos = p.update["Local"][j]
            else
                pos = i
            end
            code = postwalk(x -> @capture(x,s_) && s == j ? :(localVCopy[ic1_,$pos]) : x, code)
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

        append!(p.args,[:relativeErrorIntegrator,:learningRateIntegrator,:predV,:maxLearningStepsIntegrator])

        push!(p.declareVar.args, :(predV = copy(localVCopy)))

        push!(p.declareF.args,
            :(begin
                function integrationStep_!(ARGS_)

                    errorMax = Inf
                    count = 0

                    updateLocGlobInitialisation_!(ARGS_)
                    while errorMax > relativeErrorIntegrator && maxLearningStepsIntegrator > count
                        $(addInteraction...)
                        @platformAdapt integrationStep1_!(ARGS_)
                        errorMax = maximum(abs.(predV-localVCopy))
                        localVCopy .= (1-learningRateIntegrator).*localVCopy .+ learningRateIntegrator.*predV
                        
                        #println(localVCopy[1,:])
                        count += 1
                    end

                    if count >= maxLearningStepsIntegrator
                        #println("Implicit Euler integrator is not converging. Try reducing the learning rate.")
                    end

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