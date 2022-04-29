"""
    function integratorEuler_(p, platform)

Adapter for the VerletVelocity integration step method. Cosider a model like this.

```math
d^2x/dt^2 = b(v,x,t)
```
calling `̇ẋ=v`we solve the equations as,

```math
x(t+Δt) = x(t) + v(t)*Δt + b(x(t),v(t),t)*Δt^2/2  
v(t+Δt) = x(t) + (b(x(t),v(t),t)+b(x(t+Δt),v(t+Δt),t+Δt))*Δt/2 
```
"""
function addIntegratorVerletVelocity_!(p::Program_, platform::String)
    
    if "UpdateVariable" in keys(p.agent.declaredUpdates)

        #Add medium coupling
        code = addMediumCode(p)

        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])

        #Check SDE
        code = postwalk(x -> @capture(x,dW) ? error("Integrator VerletVelocity method do not work with SDE.") : x, code)

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

        vels = [p.velocities[i] for i in keys(p.velocities)]
        #Create integration half-velocity step function
        code = addMediumCode(p)
        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])
        for (i,j) in enumerate(keys(p.velocities)) #Remove positions of the computation
            vel = p.velocities[j]
            code = postwalk(x -> @capture(x,g_(s_)=v__) && g == DIFFSYMBOL && !(s in vels) ? :(nothing) : x, code)
        end
        for (i,j) in enumerate(keys(p.update["Variables"]))
            code = postwalk(x -> @capture(x,g_(s_)=v__) && g == DIFFSYMBOL && s == j ? :($j.new = $j + $(v...)) : x, code)
        end
        code = postwalk(x -> @capture(x,dW) ? :(Normal(0.,sqrt(dt/2))) : x, code)
        code = postwalk(x -> @capture(x,dt) ? :(dt/2) : x, code)
        code = vectorize_(p.agent,code,p)
        f = simpleFirstLoopWrapInFunction_(platform,:integrationStepVelHalf_!,code)
        push!(p.declareF.args,f)

        #Create integration position step function
        code = addMediumCode(p)
        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])
        for (i,j) in enumerate(keys(p.velocities)) #Remove positions of the computation
            vel = p.velocities[j]
            code = postwalk(x -> @capture(x,g_(s_)=v__) && g == DIFFSYMBOL && s == vel ? :(nothing) : x, code)
            code = postwalk(x -> @capture(x,v_) && v == vel ? :($v.new) : x, code)
        end
        for (i,j) in enumerate(keys(p.update["Variables"]))
            code = postwalk(x -> @capture(x,g_(s_)=v__) && g == DIFFSYMBOL && s == j ? :($j.new = $j + $(v...)) : x, code)
        end
        code = postwalk(x -> @capture(x,dW) ? :(Normal(0.,sqrt(dt))) : x, code)
        code = vectorize_(p.agent,code,p)
        f = simpleFirstLoopWrapInFunction_(platform,:integrationStepPos_!,code)
        push!(p.declareF.args,f)

        #Create integration velocity step function
        code = addMediumCode(p)
        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])
        for (i,j) in enumerate(keys(p.velocities)) #Remove positions of the computation
            vel = p.velocities[j]
            code = postwalk(x -> @capture(x,g_(s_)=v__) && g == DIFFSYMBOL && !(s in vels) ? :(nothing) : x, code)
        end
        for (i,j) in enumerate(keys(p.update["Variables"]))
            code = postwalk(x -> @capture(x,g_(s_)=v__) && g == DIFFSYMBOL && s == j ? :($j = $j + $(v...)) : x, code)
            code = postwalk(x -> @capture(x,v_) && v == j ? :($v.new) : x, code)
        end
        code = postwalk(x -> @capture(x,dW) ? :(Normal(0.,sqrt(dt/2))) : x, code)
        code = postwalk(x -> @capture(x,dt) ? :(dt/2) : x, code)
        code = postwalk(x -> @capture(x,t) ? :(t+dt) : x, code)
        code = vectorize_(p.agent,code,p)
        f = simpleFirstLoopWrapInFunction_(platform,:integrationStepVel_!,code)
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

                    updateLocGlobInitialisation_!(ARGS_)                    
                    $(addInteraction...)
                    @platformAdapt integrationStepVelHalf_!(ARGS_)
                    @platformAdapt integrationStepPos_!(ARGS_)
                    $(addInteraction...)
                    @platformAdapt integrationStepVel_!(ARGS_)
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