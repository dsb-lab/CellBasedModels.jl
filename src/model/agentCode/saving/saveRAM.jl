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

    if length(p.agent.declaredSymbols["GlobalArray"])>0
        list = string("[copy(",p.agent.declaredSymbols["GlobalArray"][1],")")
        for i in p.agent.declaredSymbols["GlobalArray"][2:end]
            list = string(list,",copy(",i,")")
        end
        list = string(list,"]")
        push!(l,:(Core.Array($list)))
    elseif length(p.agent.declaredSymbols["GlobalArray"]) > 0
        list = string("[copy(",p.agent.declaredSymbols["GlobalArray"][1],"")
        list = string(list,")]")
        push!(l,Meta.parse(string("Core.Array(",list,")")))
    else
        push!(l,:(Core.Array{Core.Array{Float64},1}()))
    end

    if length(p.agent.declaredSymbols["Medium"]) > 0
        g = []
        if p.agent.dims >= 1
            if p.agent.boundary.boundaries[1].medium == "Periodic"
                push!(g,:(2:Nx_-1))
            else
                push!(g,:(1:Nx_))
            end
        end
        if p.agent.dims >= 2
            if p.agent.boundary.boundaries[2].medium == "Periodic"
                push!(g,:(2:Ny_-1))
                push!(g,:(1:Ny_))
            end
        end
        if p.agent.dims >= 3
            if p.agent.boundary.boundaries[3].medium == "Periodic"
                push!(g,:(2:Nz_-1))
            else
                push!(g,:(1:Nz_))
            end
        end

        push!(l,:(Core.Array(mediumV)[$(g...),:]))
    else
        push!(l,:(Core.Array{Float64,1}()))
    end

    push!(p.declareVar.args,:(commRAM_ = CommunityInTime()))

    push!(p.execInit.args,
        :(begin
            ob = Community($(p.agent.dims),t,N,com.mediumN,com.declaredSymbols_,$(l...))
            push!(commRAM_,ob)
        end)
    )
    push!(p.execInloop.args,
        :(begin
            if t >= tSave
                tSave += dtSave
                ob = Community($(p.agent.dims),t+dt,N,com.mediumN,com.declaredSymbols_,$(l...))
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