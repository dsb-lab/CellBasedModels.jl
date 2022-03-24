"""
    function integratorRungeKutta4_(p, platform)

Adapter for the RungeKutta4 integration step method as described in [Stochastic Improved Euler](https://en.wikipedia.org/wiki/Runge%E2%80%93Kutta_method_(SDE)) integrator in Îto prescription.

```math
K₁ = f(x(t),t)*Δt + g(x(t),t)(ΔW)
```
```math
K₂ = f(x(t)+K₁,t+Δt)*Δt + g(x(t)+K₁,t+Δt)(ΔW)
```
```math
x(t+Δt) = x(t) + (K₁+K₂)/2
```
where ``ΔW`` is a Wiener process with step proportional to ``Δt^{1/2}``. The integration considers the SDE Stratonovich.

The algorithm can be reduced to six kernels invocations performing the following actions:
 - Clean the interaction parameters array
 - Compute interaction parameters at original position v₀  (if there are interaction parameters)
 - Compute K₂ and intermediate v₁
 - Clean the interaction parameters array
 - Compute interaction parameters at intermediate position vᵢₙₜ  (if there are interaction parameters)
 - Compute K₂ parameters and final position v₁
"""
function addIntegratorRungeKutta4_!(p::Program_, platform::String)
    
    if "UpdateVariable" in keys(p.agent.declaredUpdates)

        #Add medium coupling
        code = addMediumCode(p)

        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])

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

        #Create integration step 1 function
        code = addMediumCode(p)
        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])
        code = postwalk(x -> @capture(x,dt) ? :(1) : x, code)
        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            if j in keys(p.update["Variables"])
                pos = p.update["Variables"][j]
            else
                pos = i
            end
            code = postwalk(x -> @capture(x,g_(s_)=v__) && g == DIFFSYMBOL && s == j ? :(K1_[ic1_,$pos] = $(v...); localVCopy[ic1_,$pos] = localV[ic1_,$i] + K1_[ic1_,$pos]*dt/2) : x, code)
            code = postwalk(x -> @capture(x,dW) ? :(Normal(0.,sqrt(dt))) : x, code)
        end
        code = vectorize_(p.agent,code,p)
        f = simpleFirstLoopWrapInFunction_(platform,:integrationStep1_!,code)
        push!(p.declareF.args,f)

        #Create integration step 2 function
        code = addMediumCode(p)
        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])
        code = postwalk(x -> @capture(x,dt) ? :(1) : x, code)
        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            if j in keys(p.update["Variables"])
                pos = p.update["Variables"][j]
            else
                pos = i
            end
            code = postwalk(x -> @capture(x,g_(s_)=v__) && g == DIFFSYMBOL && s == j ? :(K2_[ic1_,$pos] = $(v...); localVCopy[ic1_,$pos] = localV[ic1_,$i] + K2_[ic1_,$pos]*dt/2) : x, code)
            if j in keys(p.update["Variables"])
                code = postwalk(x -> @capture(x,v_) && v == j ? :($j + K1_[ic1_,$pos]*dt/2) : x, code)
            end
            code = postwalk(x -> @capture(x,dW) ? :(Normal(0.,sqrt(dt))) : x, code)
        end
        code = postwalk(x -> @capture(x,t) ? :(t+dt/2) : x, code)
        code = vectorize_(p.agent,code,p)
        f = simpleFirstLoopWrapInFunction_(platform,:integrationStep2_!,code)
        push!(p.declareF.args,f)

        #Create integration step 3 function
        code = addMediumCode(p)
        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])
        code = postwalk(x -> @capture(x,dt) ? :(1) : x, code)
        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            if j in keys(p.update["Variables"])
                pos = p.update["Variables"][j]
            else
                pos = i
            end
            code = postwalk(x -> @capture(x,g_(s_)=v__) && g == DIFFSYMBOL && s == j ? :(K3_[ic1_,$pos] = $(v...); localVCopy[ic1_,$pos] = localV[ic1_,$i] + K3_[ic1_,$pos]*dt/2) : x, code)
            if j in keys(p.update["Variables"])
                code = postwalk(x -> @capture(x,v_) && v == j ? :($j + K2_[ic1_,$pos]*dt/2) : x, code)
            end
            code = postwalk(x -> @capture(x,dW) ? :(Normal(0.,sqrt(dt))) : x, code)
        end
        code = postwalk(x -> @capture(x,t) ? :(t+dt/2) : x, code)
        code = vectorize_(p.agent,code,p)
        f = simpleFirstLoopWrapInFunction_(platform,:integrationStep3_!,code)
        push!(p.declareF.args,f)

        #Create integration step 4 function
        code = addMediumCode(p)
        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])
        code = postwalk(x -> @capture(x,dt) ? :(1) : x, code)
        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            if j in keys(p.update["Variables"])
                pos = p.update["Variables"][j]
            else
                pos = i
            end
            code = postwalk(x -> @capture(x,g_(s_)=v__) && g == DIFFSYMBOL && s == j ? :(K4_[ic1_,$pos] = $(v...); localVCopy[ic1_,$pos] = localV[ic1_,$i]) : x, code)
            if j in keys(p.update["Variables"])
                code = postwalk(x -> @capture(x,v_) && v == j ? :($j + K3_[ic1_,$pos]*dt) : x, code)
            end
            code = postwalk(x -> @capture(x,dW) ? :(Normal(0.,sqrt(dt))) : x, code)
        end
        code = postwalk(x -> @capture(x,t) ? :(t+dt) : x, code)
        code = vectorize_(p.agent,code,p)
        f = simpleFirstLoopWrapInFunction_(platform,:integrationStep4_!,code)
        push!(p.declareF.args,f)

        push!(p.declareVar.args,:(K1_ = zeros(size(localVCopy))))
        push!(p.declareVar.args,:(K2_ = zeros(size(localVCopy))))
        push!(p.declareVar.args,:(K3_ = zeros(size(localVCopy))))
        push!(p.declareVar.args,:(K4_ = zeros(size(localVCopy))))
        append!(p.args,[:K1_,:K2_,:K3_,:K4_])

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
                    $(addInteraction...)
                    @platformAdapt integrationStep2_!(ARGS_)
                    $(addInteraction...)
                    @platformAdapt integrationStep3_!(ARGS_)
                    $(addInteraction...)
                    @platformAdapt integrationStep4_!(ARGS_)
                    localVCopy .= localVCopy +(K1_+2 .*K2_+2 .*K3_+K4_).*dt./6
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