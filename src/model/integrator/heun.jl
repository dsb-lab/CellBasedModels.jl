"""
    function integratorHeun_(p, abm, space, platform)

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
function addIntegratorHeun_!(p::Program_, abm::Agent, space::SimulationSpace, platform::String)
    
    if  "Equation" in keys(abm.declaredUpdates)

        code = abm.declaredUpdates["Equation"]

        #Create first interaction parameter kernel if there is any interaction parameter updated
        if "UpdateInteraction" in keys(abm.declaredUpdates)

            k1 = loop_(p,abm,space,abm.declaredUpdates["UpdateInteraction"],platform)
            k1 = vectorize_(abm,k1,p)
            k1 = wrapInFunction_(:interactionStep1_,k1)
            push!(p.declareF.args,k1)

        end


        #Create first integration step kernel
        codeK1 = postwalk(x -> @capture(x,dW) ? :(dW[ic1_]-S_[ic1_]) : x, code)
        for (i,j) in enumerate(abm.declaredSymbols["Local"])
            if j in keys(p.update["Variables"])
                ii = p.update["Local"][j]
                ki = p.update["Variables"][j]
                s = Meta.parse(string(EQUATIONSYMBOL,j))
                codeK1 = postwalk(x -> @capture(x,$s) ? :(K₁_[ic1_,$ki]) : x, codeK1)
                #Saves intermediate step vᵢₙₜ in final pos localVCopy
                push!(codeK1.args,:(localVCopy[ic1_,$ii] = localV[ic1_,$i] + K₁_[ic1_,$ki]))
            end
        end
        codeK1 = vectorize_(abm,codeK1,p)
        if inexpr(codeK1,:dW) #Add initialisation is necessary
            pushfirst!(codeK1.args,:(dW[ic1_] = Uniform(0,1)*sqrt(dt)))
            pushfirst!(codeK1.args,:(S_[ic1_] = 2*(round(rand())- .5)*sqrt(dt)))
        end
        k2 = simpleFirstLoopWrapInFunction_(platform,:integrationStep1_,codeK1) #First function declaration
        push!(p.declareF.args,k2)        
        push!(p.declareVar.args,:(K₁_ = copy(zeros(Float64,nMax,$(length(p.update["Variables"]))))))  
        push!(p.args,:K₁_ )  

        #Create second interaction parameter kernel using localVCopy if there is any
        if "UpdateInteraction" in keys(abm.declaredUpdates)

            k3 = loop_(p,abm,space,abm.declaredUpdates["UpdateInteraction"],platform)
            for (i,j) in enumerate(abm.declaredSymbols["Local"])
                codeK1 = postwalk(x -> @capture(x,$j) ? :(localVCopy[ic1_,$ii]) : x, k3)
            end
            k3 = vectorize_(abm,k3,p)
            k3 = wrapInFunction_(:interactionStep2_,k3)
            push!(p.declareF.args,k3)

        end
        
        
        #Create second integration step kernel
        codeK2 = postwalk(x -> @capture(x,dW) ? :(dW[ic1_]+S_[ic1_]) : x, code)
        for (i,j) in enumerate(abm.declaredSymbols["Local"])
            if j in keys(p.update["Variables"])
                ii = p.update["Local"][j]
                ki = p.update["Variables"][j]
                s = Meta.parse(string(EQUATIONSYMBOL,j))
                codeK2 = postwalk(x -> @capture(x,$j) ? :(($j+K₁_[ic1_,$ki])) : x, codeK2)
                codeK2 = postwalk(x -> @capture(x,t) ? :(t+dt) : x, codeK2)
                codeK2 = postwalk(x -> @capture(x,$s) ? :(localVCopy[ic1_,$ii]) : x, codeK2) #Directly add to final point, saves an additional declaration

                #Add old pos, K2 (stored in final pos for now) and K1 to final pos
                push!(codeK2.args,:(localVCopy[ic1_,$ii] = localV[ic1_,$i] + (localVCopy[ic1_,$ii] + K₁_[ic1_,$ki])/2))
            end
        end
        codeK2 = vectorize_(abm,codeK2,p)
        k4 = simpleFirstLoopWrapInFunction_(platform,:integrationStep2_,codeK2)
        push!(p.declareF.args,k4)


        #Create a function that puts all kernels together
        if inexpr(codeK1,:dW)
            push!(p.declareVar.args, #declare random variables for Stochastic integration
                :(begin
                    dW = zeros(Float64,nMax)
                    S_ = zeros(Float64,nMax)
                end)
            )

            push!(p.args,:dW,:S_)
        end
        if "UpdateInteraction" in keys(abm.declaredUpdates)
            addInteraction1 = [:(@platformAdapt cleanInteraction_!(ARGS_);@platformAdapt interactionStep1_(ARGS_))]
            addInteraction2 = [:(@platformAdapt cleanInteraction_!(ARGS_);@platformAdapt interactionStep2_(ARGS_))]
            push!(p.execInit.args, :(@platformAdapt cleanInteraction_!(ARGS_); @platformAdapt interactionCompute_!(ARGS_)))
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