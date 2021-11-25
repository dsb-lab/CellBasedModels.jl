function addSavingRAM_!(p::Program_,platform::String)
    
    #List of nonempty arrays
    l = []

    if length(p.agent.declaredSymbols["Local"])>0
        push!(l,:(Core.Array(localV)[1:N,:]))
    else
        push!(l,:(Core.Array{Float64,2}(undef,0,2)))
    end

    if length(p.agent.declaredSymbols["Identity"])>0
        push!(l,:(Core.Array(identityV)[1:N,:]))
    else
        push!(l,:(Core.Array{Int,2}(undef,0,2)))
    end

    if length(p.agent.declaredSymbols["Global"])>0
        push!(l,:(Core.Array(globalV)))
    else
        push!(l,:(Core.Array{Float64,1}()))
    end

    if length(p.agent.declaredSymbols["GlobalArray"]) > 0
        list = string("[copy(",p.agent.declaredSymbols["GlobalArray"][1],"")
        list = string(list,")]")
        push!(l,Meta.parse(string("Core.Array(",list,")")))
    else
        push!(l,:(Core.Array{Core.Array{Float64},1}()))
    end

    if length(p.agent.declaredSymbols["Medium"]) > 0
        push!(l,:(Core.Array(mediumV)))
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
    push!(p.execInloop.args,
        :(begin
            if t >= tSave
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