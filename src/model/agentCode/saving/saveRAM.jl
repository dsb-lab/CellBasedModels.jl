function addSavingRAM_!(p::Program_,platform::String)
    
    #List of nonempty arrays
    l = []

    if length(keys(p.agent.declaredSymbols["Local"]))>0
        push!(l,:(Core.Array(view(localV,1:N,:))))
    else
        push!(l,:(Core.Array{Float64,2}(undef,0,2)))
    end

    if length(keys(p.agent.declaredSymbols["LocalInteraction"]))>0
        push!(l,:(Core.Array(view(localInteractionV,1:N,:))))
    else
        push!(l,:(Core.Array{Float64,2}(undef,0,2)))
    end

    if length(keys(p.agent.declaredSymbols["Identity"]))>0
        push!(l,:(Core.Array(view(identityV,1:N,:))))
    else
        push!(l,:(Core.Array{Int,2}(undef,0,2)))
    end

    if length(keys(p.agent.declaredSymbols["IdentityInteraction"]))>0
        push!(l,:(Core.Array(view(identityInteractionV,1:N,:))))
    else
        push!(l,:(Core.Array{Int,2}(undef,0,2)))
    end

    if length(keys(p.agent.declaredSymbols["Global"]))>0
        push!(l,:(Core.Array(globalV)))
    else
        push!(l,:(Core.Array{Float64,1}()))
    end

    if length(keys(p.agent.declaredSymbols["GlobalArray"])) > 0
        list = string("[",[string("copy(",i,")") for i in keys(p.agent.declaredSymbols["GlobalArray"])]...,"]")
        push!(l,Meta.parse(string("Core.Array(",list,")")))
    else
        push!(l,:(Core.Array{Core.Array{Float64},1}()))
    end

    if length(keys(p.agent.declaredSymbols["Medium"])) > 0
        if p.agent.dims == 1
            push!(l,:(Core.Array(mediumV)))
        elseif p.agent.dims == 2
            push!(l,:(Core.Array(mediumV)))
        elseif p.agent.dims == 3
            push!(l,:(Core.Array(mediumV)))
        end
    else
        push!(l,:(Core.Array{Float64,1}()))
    end

    push!(p.declareVar.args,:(commRAM_ = CommunityInTime()))

    push!(p.execInit.args,
        :(begin
            ob = Community($(p.agent.dims),t,N,com.mediumN,com.simulationBox,com.radiusInteraction,com.declaredSymbols_,$(l...))
            push!(commRAM_,ob)
        end)
    )

    if platform == "cpu"
        checkNMax = :(limNMax_[] == 1)
    else
        checkNMax = :(Core.Array(limNMax_)[1] == 1)
    end

    push!(p.execInloop.args,
        :(begin
            if t >= tSave && $checkNMax
                tSave += dtSave
                ob = Community($(p.agent.dims),t+dt,N,com.mediumN,com.simulationBox,com.radiusInteraction,com.declaredSymbols_,$(l...))
                push!(commRAM_,ob)
            end
        end)
    )

    # push!(p.execAfter.args,
    # :(begin
    #     ob = Community(t+dt,N,com.declaredSymbols_,$(l...))
    #     push!(commRAM_,ob)
    #     end)
    # )
    
    push!(p.returning.args,:(commRAM_))

    return
end