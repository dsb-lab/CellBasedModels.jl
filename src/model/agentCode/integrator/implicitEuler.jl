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
        end

        #Create initial integration step function
        code = addMediumCode(p) #Add medium coupling
        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])
        function remove(code,j)
            code = postwalk(x -> @capture(x,g_/s_) && inexpr(s,j) ? :(0) : x, code)
            code = postwalk(x -> @capture(x,s_) && s == j ? :(0) : x, code)

            return code
        end
        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            if j in keys(p.update["Local"])
                pos = p.update["Local"][j]
            else
                pos = i
            end
            code = postwalk(x -> @capture(x,g_(s_)=v_) && g == DIFFSYMBOL && s == j ? :(localVCopy[ic1_,$pos] = localV[ic1_,$i] + $(remove(v,j))) : x, code)
            code = postwalk(x -> @capture(x,dW) ? error("Implicit Euler method do not work with SDE.") : x, code)
        end
        code = vectorize_(p.agent,code,p)
        f = simpleFirstLoopWrapInFunction_(platform,:integrationStep0_!,code)
        push!(p.declareF.args,f)

        #Create integration step function
        code = addMediumCode(p) #Add medium coupling
        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])
        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            if j in keys(p.update["Local"])
                pos = p.update["Local"][j]
            else
                pos = i
            end
            code = postwalk(x -> @capture(x,g_(s_)=v__) && g == DIFFSYMBOL && s == j ? :(predV[ic1_,$pos] = localV[ic1_,$i] + $(v...)) : x, code)
            code = postwalk(x -> @capture(x,dW) ? error("Implicit Euler method do not work with SDE.") : x, code)
        end
        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            if j in keys(p.update["Local"])
                pos = p.update["Local"][j]
                code = postwalk(x -> @capture(x,s_) && s == j ? :(localVCopy[ic1_,$pos]) : x, code)
            end
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

        append!(p.args,[:relativeErrorIntegrator,:learningRateIntegrator,:predV,:maxLearningStepsIntegrator])

        push!(p.declareVar.args, :(predV = copy(localVCopy)))

        push!(p.declareF.args,
            :(begin
                function integrationStep_!(ARGS_)

                    errorMax = Inf
                    count = 0

                    updateLocGlobInitialisation_!(ARGS_)
                    @platformAdapt integrationStep0_!(ARGS_)
                    while errorMax > relativeErrorIntegrator && maxLearningStepsIntegrator > count
                        $(addInteraction...)
                        predV .= localVCopy
                        @platformAdapt integrationStep1_!(ARGS_)
                        localVCopy .= (1-learningRateIntegrator).*localVCopy .+ learningRateIntegrator.*predV
                        errorMax = maximum(abs.(predV .- localVCopy))

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