"""
    function integratorHeun_(abm, space, p, platform)

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

The algorithm can be reduced to four kernel invocations performing the following actions:
 - Compute interaction parameters at original position v₀  (if there are interaction parameters)
 - Compute K₂ and intermediate v₁
 - Compute interaction parameters at intermediate position vᵢₙₜ  (if there are interaction parameters)
 - Compute K₂ parameters and final position v₁
"""
function addIntegratorHeun_!(abm::Agent, space::SimulationFree, p::Program_, platform::String)
    
    if !emptyquote_(abm.declaredUpdates["Equation"])

        code = abm.declaredUpdates["Equation"]

        #Create first interaction parameter kernel if there is any interaction parameter updated
        if !emptyquote_(abm.declaredUpdates["UpdateInteraction"])

            k1 = loop_(abm,space,abm.declaredUpdates["UpdateInteraction"],platform)
            k1 = vectorize_(abm,k1)
            k1 = wrapInFunction_(:interactionStep1_,k1)
            push!(p.declareF.args,k1)

        end


        #Create first integration step kernel
        codeK1 = MacroTools.postwalk(x -> @capture(x,dW) ? :(dW-S_*sqrt(dt)) : x, code)
        for (i,j) in enumerate(abm.declaredSymbols["Variable"])
            s = Meta.parse(string(j,"̇ "))
            codeK1 = MacroTools.postwalk(x -> @capture(x,$s) ? :(K₁_[ic1_,$i]) : x, codeK1)
            #Saves intermediate step vᵢₙₜ in final pos varCopy_
            push!(codeK1.args,:(varCopy_[ic1_,$i] = var_[ic1_,$i] + K₁_[ic1_,$i]))
        end
        vectorize_(abm,code,update="Copy")
        k2 = simpleFirstLoopWrapInFunction_(platform,:integrationStep1_,codeK1) #First function declaration
        push!(p.declareF.args,k2)        
        push!(p.declareVar.args,:(K₁_ = copy(var_)))  
        push!(p.args,:K₁_ )  

        #Create second interaction parameter kernel using varCopy_ if there is any
        if !emptyquote_(abm.declaredUpdates["UpdateInteraction"])

            k3 = loop_(abm,space,abm.declaredUpdates["UpdateInteraction"],platform)
            for (i,j) in enumerate(abm.declaredSymbols["Variable"])
                codeK1 = MacroTools.postwalk(x -> @capture(x,$j) ? :(varCopy_[ic1_,$i]) : x, k3)
            end
            k3 = vectorize_(abm,k3)
            k3 = wrapInFunction_(:interactionStep2_,k3)
            push!(p.declareF.args,k3)

        end
        
        
        #Create second integration step kernel
        codeK2 = MacroTools.postwalk(x -> @capture(x,dW) ? :(dW-S_*sqrt(dt)) : x, code)
        for (i,j) in enumerate(abm.declaredSymbols["Variable"])
            s = Meta.parse(string(j,"̇ "))
            codeK2 = MacroTools.postwalk(x -> @capture(x,$j) ? :(($j+K₁_[ic1_,$i])) : x, codeK2)
            codeK2 = MacroTools.postwalk(x -> @capture(x,$s) ? :(varCopy_[ic1_,$i]) : x, codeK2) #Directly add to final point, saves an additional declaration
            
            #Add old pos, K2 (stored in final pos for now) and K1 to final pos
            push!(codeK2.args,:(varCopy_[ic1_,$i] = var_[ic1_,$i] + (varCopy_[ic1_,$i] + K₁_[ic1_,$i])/2))
        end
        vectorize_(abm,code,update="Copy")
        k4 = simpleFirstLoopWrapInFunction_(platform,:integrationStep2_,codeK2)
        push!(p.declareF.args,k4)


        #Create a function that puts all kernels together
        if MacroTools.inexpr(codeK1,:dW)
            push!(p.declareVar.args, #declare random variables for Stochastic integration
                :(begin
                    dW = 0.
                    S_ = 0.
                end)
            )
            addRandInitialisation = [:(dW = randn()*dt; S_ = round(rand()))]

            push!(p.args,:dW,:S_)
        else
            addRandInitialisation = []
        end
        if !emptyquote_(abm.declaredUpdates["UpdateInteraction"])
            addInteraction1 = [:(interactionStep1_(ARGS_))]
            addInteraction2 = [:(interactionStep2_(ARGS_))]
        else
            addInteraction1 = []
            addInteraction2 = []
        end
        push!(p.declareF.args,
            :(begin
                function integrationStep_!(ARGS_)
                    $(addRandInitialisation...)
                    $(addInteraction1...)
                    integrationStep1_(ARGS_)
                    $(addInteraction2...)
                    integrationStep1_(ARGS_)

                    return
                end
            end)
        )
        
        #Add integration step to the main function
        push!(p.execInloop.args,:(integrationStep_!(ARGS_)))

        updateVariables_!(abm,p)

    end
        
    return
end