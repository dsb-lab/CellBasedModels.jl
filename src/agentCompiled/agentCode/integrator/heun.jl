function countdW(code)
    x = gensym()
    code = postwalk(x->@capture(x,dW) ? gensym() : x, code)
    y = gensym()
    
    return Meta.parse(string(split(string(y),"#")[end]))-Meta.parse(string(split(string(x),"#")[end]))-1
end

function substitutedW(code;sym=:K1_)
    x = gensym()
    code = postwalk(x->@capture(x,dW) ? gensym() : x, code)
    y = gensym()
    d = Meta.parse(string(split(string(y),"#")[end]))-Meta.parse(string(split(string(x),"#")[end]))
    for i in 1:d
        for j in ["#","##","###","####","#####","######"]
            s = Symbol(string(j,Meta.parse(string(split(string(x),"#")[end]))+i))
            code = postwalk(x->@capture(x,g_) && g == s ? :(sqrt(dt)*$sym[ic1_,$i]) : x, code)
        end
    end
    code
end

"""
    function addIntegratorHeun_!(p::Program_, platform::String)

Adapts the code declared in `UpdateVariable` to be integrated as the Heun method and adds the code generated to `Program_`.

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

# Args
 - **p::Program_**:  Program_ structure containing all the created code when compiling.
 - **platform::String**: Platform to adapt the code.

# Returns
 -  Nothing
"""
function addIntegratorHeun_!(p::Program_, platform::String)
    
    if "UpdateVariable" in keys(p.agent.declaredUpdates)

        #Add medium coupling
        code = addMediumCode(p)

        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])

        #Create integration step 1 function
        code = addMediumCode(p)
        for i in 1:countdW(p.agent.declaredUpdates["UpdateVariable"])
            push!(code.args,:(K1_[ic1_,$i]=Normal(0,1)))
        end
        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])
        for (i,j) in enumerate(p.agent.declaredSymbols["Local"])
            code = postwalk(x -> @capture(x,g_(s_)=v__) && g == DIFFSYMBOL && s == j ? :($j.new = $j + $(v...)) : x, code)
        end
        code = substitutedW(code)
        code = vectorize_(p.agent,code,p)
        f = simpleFirstLoopWrapInFunction_(platform,:integrationStep1_!,code)
        push!(p.declareF.args,f)

        #Create integration step 2 function
        code = addMediumCode(p)
        push!(code.args,p.agent.declaredUpdates["UpdateVariable"])
        for (i,j) in enumerate(keys(p.update["Variables"]))
            code = postwalk(x -> @capture(x,g_(s_)=v__) && g == DIFFSYMBOL && s == j ? :($j = $j/2 + $(v...)/2) : x, code)
            code = postwalk(x -> @capture(x,v_) && v == j ? :($v.new) : x, code)
            code = postwalk(x -> @capture(x,s_.new=s_.new/2+v__)&& s == j ? :($j.new = ($j+$j.new)/2 + $(v...)) : x, code)
        end
        code = substitutedW(code)
        code = postwalk(x -> @capture(x,t) ? :(t+dt) : x, code)
        code = vectorize_(p.agent,code,p)
        f = simpleFirstLoopWrapInFunction_(platform,:integrationStep2_!,code)
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

        # g = :()
        if countdW(p.agent.declaredUpdates["UpdateVariable"]) > 0
            c = countdW(p.agent.declaredUpdates["UpdateVariable"])
             push!(p.declareVar.args,:(K1_ = zeros(nMax,$c)))
             push!(p.args,:K1_)
        #     if platform == "cpu"
        #         g = :(K1_ .= randn(size(K1_)...))
        #     else
        #         g = :(randn!(K1_))
        #     end
        end

        push!(p.declareF.args,
            :(begin
                function integrationStep_!(ARGS_)
                    $(addInteraction...)
                    @platformAdapt integrationStep1_!(ARGS_)
                    $(addInteraction...)
                    @platformAdapt integrationStep2_!(ARGS_)

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