"""
    function integratorHeun_(p, platform)

Adapter for the Heun integration step method as described in [Stochastic Improved Euler](https://en.wikipedia.org/wiki/Runge%E2%80%93Kutta_method_(SDE)) integrator in Îto prescription.

```math
K₁ = f(x(t),t)*Δt + g(x(t),t)(ΔW-S Δt^{1/2} )
```
```math
K₂ = f(x(t)+K₁,t+Δt)*Δt + g(x(t)+K₁,t+Δt)(ΔW+SΔt^{1/2} )
```
```math
x(t+Δt) = x(t) + (K₁+K₂)/2
```
where ``S`` is a random variable chosen to be ±1 with probability 1/2 and
``ΔW`` is a Wiener process with step proportional to ``Δt^{1/2}``.

The algorithm can be reduced to six kernels invocations performing the following actions:
 - Clean the interaction parameters array
 - Compute interaction parameters at original position v₀  (if there are interaction parameters)
 - Compute K₂ and intermediate v₁
 - Clean the interaction parameters array
 - Compute interaction parameters at intermediate position vᵢₙₜ  (if there are interaction parameters)
 - Compute K₂ parameters and final position v₁
"""
function addIntegratorHeun_!(p::Program_, platform::String)
    
    if  "UpdateVariable" in keys(p.agent.declaredUpdates)

        #Add medium coupling
        code = addMediumCode(p)

        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])

        #Create first interaction parameter kernel if there is any interaction parameter updated
        if "UpdateInteraction" in keys(p.agent.declaredUpdates)

            k1 = loop_[p.neighbors](p,p.agent.declaredUpdates["UpdateInteraction"],platform)
            k1 = vectorize_(p.agent,k1,p,interaction=true)
            k1 = wrapInFunction_(:interactionStep1_,k1)
            push!(p.declareF.args,k1)

        end

        #Create first integration step kernel
        #Make the substitution dW -> (dW-S) and count number of calls to dW
        m1 = [i for i in split(string(gensym("dW")),"#") if i != ""]
        codeK1 = gensym_ids(postwalk(x->@capture(x,dW) ? :($(gensym("dW"))) : x, code))
        codeK1 = postwalk(x->@capture(x,v_) && (split(string(v),"_")[1] == "dW") ? :(dW[ic1_,$(Meta.parse(split(string(v),"_")[2]))]) : x, codeK1)
        codeK1 = postwalk(x->@capture(x,dW[ic1_,pos_]) ? :(dW[ic1_,$pos]-S_[ic1_,$pos]) : x, codeK1)
        m2 = [i for i in split(string(gensym("dW")),"#") if i != ""]
        m = Meta.parse(m2[2])-Meta.parse(m1[2])-1

        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            if j in keys(p.update["Variables"])
                ii = p.update["Local"][j]
                ki = p.update["Variables"][j]
                codeK1 = postwalk(x -> @capture(x,g_(s_)) && g == DIFFSYMBOL && s == j ? :(K₁_[ic1_,$ki]) : x, codeK1)
                #Saves intermediate step vᵢₙₜ in final pos localVCopy
                push!(codeK1.args,:(localVCopy[ic1_,$ii] = localV[ic1_,$i] + K₁_[ic1_,$ki]))
            end
        end
        codeK1 = vectorize_(p.agent,codeK1,p)
        if inexpr(codeK1,:dW) #Add initialisation is necessary
            for i in 1:m
                pushfirst!(codeK1.args,:(dW[ic1_,$i] = Uniform(0,1)*sqrt(dt)))
                pushfirst!(codeK1.args,:(S_[ic1_,$i] = 2*(round(rand())- .5)*sqrt(dt)))
            end
        end
        k2 = simpleFirstLoopWrapInFunction_(platform,:integrationStep1_,codeK1) #First function declaration
        push!(p.declareF.args,k2)        
        push!(p.declareVar.args,:(K₁_ = copy(zeros(Float64,nMax,$(length(p.update["Variables"]))))))  
        push!(p.args,:K₁_ )  

        #Create second interaction parameter kernel using localVCopy if there is any
        if "UpdateInteraction" in keys(p.agent.declaredUpdates)

            k3 = loop_[p.neighbors](p,p.agent.declaredUpdates["UpdateInteraction"],platform)
            for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
                codeK1 = postwalk(x -> @capture(x,$j) ? :(localVCopy[ic1_,$ii]) : x, k3)
            end
            k3 = vectorize_(p.agent,k3,p,interaction=true)
            k3 = wrapInFunction_(:interactionStep2_,k3)
            push!(p.declareF.args,k3)

        end
        
        #Create second integration step kernel
        codeK2 = gensym_ids(postwalk(x->@capture(x,dW) ? :($(gensym("dW"))) : x, code))
        codeK2 = postwalk(x->@capture(x,v_) && (split(string(v),"_")[1] == "dW") ? :(dW[ic1_,$(Meta.parse(split(string(v),"_")[2]))]) : x, codeK2)
        codeK2 = postwalk(x->@capture(x,dW[ic1_,pos_]) ? :(dW[ic1_,$pos]+S_[ic1_,$pos]) : x, codeK2)
        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            if j in keys(p.update["Variables"])
                ii = p.update["Local"][j]
                ki = p.update["Variables"][j]
                codeK2 = postwalk(x -> @capture(x,g_(s_)) && g == DIFFSYMBOL && s == j ? :(K₁[ic1_,$ii]) : x, codeK2) #Save second point in first vector, saves an additional declaration
                codeK2 = postwalk(x -> @capture(x,s_) && s == j ? :((localVCopy_[ic1_,$ki])) : x, codeK2)
                codeK2 = postwalk(x -> @capture(x,t) ? :(t+dt) : x, codeK2)

                #Add old pos, K2 (stored in final pos for now) and K1 to final pos
                push!(codeK2.args,:(localVCopy[ic1_,$ii] = (localVCopy[ic1_,$ii] + localV[ic1_,$i] + K₁_[ic1_,$ki])/2))
            end
        end
        codeK2 = vectorize_(p.agent,codeK2,p)
        k4 = simpleFirstLoopWrapInFunction_(platform,:integrationStep2_,codeK2)
        push!(p.declareF.args,k4)

        #Create a function that puts all kernels together
        if inexpr(codeK1,:dW)
            push!(p.declareVar.args, #declare random variables for Stochastic integration
                :(begin
                    dW = zeros(Float64,nMax,$m)
                    S_ = zeros(Float64,nMax,$m)
                end)
            )

            push!(p.args,:dW,:S_)
        end
        if "UpdateInteraction" in keys(p.agent.declaredUpdates)
            cleanLocal = :()
            if !isempty(p.agent.declaredSymbols["LocalInteraction"])
                cleanLocal = :(localInteractionV .= 0)
            end
            cleanInteraction = :()
            if !isempty(p.agent.declaredSymbols["IdentityInteraction"])
                cleanInteraction = :(identityInteractionV .= 0)
            end
            addInteraction1 = [:($cleanLocal;$cleanInteraction;@platformAdapt interactionStep1_(ARGS_))]
            addInteraction2 = [:($cleanLocal;$cleanInteraction;@platformAdapt interactionStep2_(ARGS_))]
        else
            addInteraction1 = []
            addInteraction2 = []
        end
        push!(p.declareF.args,
            :(begin
                function integrationStep_!(ARGS_)
                    $(addInteraction1...)
                    @platformAdapt integrationStep1_(ARGS_)
                    $(addInteraction2...)
                    @platformAdapt integrationStep1_(ARGS_)

                    return
                end
            end)
        )
        
        #Add integration step to the main function
        push!(p.execInit.args,:(integrationStep_!(ARGS_)))
        push!(p.execInloop.args,:(integrationStep_!(ARGS_)))

    end
        
    return
end