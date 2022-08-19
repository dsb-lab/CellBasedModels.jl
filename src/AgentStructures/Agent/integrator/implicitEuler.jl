"""
    function addIntegratorImplicitEuler_!(p::AgentCompiled, platform::String)

Adapts the code declared in `UpdateVariable` to be integrated as the Implicit Euler method and adds the code generated to `AgentCompiled`.

```math
x(t+Δt) = x(t) + a(t+Δt)*Δt
```

The solution is computed iteratively as,

```math
x_{k+1} = (1-lr)x_{k-1}+lr*x_{k}
```
where `lr` if the learning rate of the algorithm.

# Args
 - **p::AgentCompiled**:  AgentCompiled structure containing all the created code when compiling.
 - **platform::String**: Platform to adapt the code.

# Returns
 -  Nothing
"""
function addIntegratorImplicitEuler_!(p::AgentCompiled, platform::String)
    
    if "UpdateVariable" in keys(p.agent.declaredUpdates)

        #Create initial integration step function
        code = addMediumCode(p) #Add medium coupling
        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])

        #Check SDE
        code = postwalk(x -> @capture(x,dW) ? error("Implicit Euler method do not work with SDE.") : x, code)

        function remove(code,p)
            for j in keys(p.update["Variables"])
                code = postwalk(x -> @capture(x,g_/s_) && inexpr(s,j) ? :(0) : x, code)
                code = postwalk(x -> @capture(x,s_) && s == j ? :(0) : x, code)
            end

            return code
        end
        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            if j in keys(p.update["Local"])
                pos = p.update["Local"][j]
            else
                pos = i
            end
            code = postwalk(x -> @capture(x,g_(s_)=v_) && g == DIFFSYMBOL && s == j ? :(localVCopy[ic1_,$pos] = localV[ic1_,$i] + $(remove(v,p))) : x, code)
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
            addInteraction = [:(interactionCompute_!(ARGS_))]
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