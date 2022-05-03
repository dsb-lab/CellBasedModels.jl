"""
    function addIntegratorRungeKutta4_!(p::Program_, platform::String)

Adapts the code declared in `UpdateVariable` to be integrated as the Runge Kutta 4 method and adds the code generated to `Program_`.

# Args
 - **p::Program_**:  Program_ structure containing all the created code when compiling.
 - **platform::String**: Platform to adapt the code.

# Returns
 -  Nothing
"""
function addIntegratorRungeKutta4_!(p::Program_, platform::String)
    
    if "UpdateVariable" in keys(p.agent.declaredUpdates)

        #Add medium coupling
        code = addMediumCode(p)

        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])

        #Check SDE
        code = postwalk(x -> @capture(x,dW) ? error("RungeKutta4 method do not work with SDE.") : x, code)

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
            addInteraction = [:(interactionCompute_!(ARGS_))]
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