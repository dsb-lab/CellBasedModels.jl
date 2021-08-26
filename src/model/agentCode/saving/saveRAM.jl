function addSavingRAM_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)
    
    #List of nonempty arrays
    l = []

    if length(abm.declaredSymbols["Local"])>0
        push!(l,:(Core.Array(localV)[1:N,:]))
    else
        push!(l,:(Core.Array{Float64,2}(undef,0,2)))
    end

    if length(abm.declaredSymbols["Identity"])>0
        push!(l,:(Core.Array(identityV)[1:N,:]))
    else
        push!(l,:(Core.Array{Int,2}(undef,0,2)))
    end

    if length(abm.declaredSymbols["Global"])>0
        push!(l,:(Core.Array(globalV)))
    else
        push!(l,:(Core.Array{Float64,1}()))
    end

    if length(abm.declaredSymbols["GlobalArray"])>0
        list = string("[copy(",abm.declaredSymbols["GlobalArray"][1],")")
        for i in abm.declaredSymbols["GlobalArray"][2:end]
            list = string(list,",copy(",i,")")
        end
        list = string(list,"]")
        push!(l,:(Core.Array($list)))
    elseif length(abm.declaredSymbols["GlobalArray"]) > 0
        list = string("[copy(",abm.declaredSymbols["GlobalArray"][1],"")
        list = string(list,")]")
        push!(l,Meta.parse(string("Core.Array(",list,")")))
    else
        push!(l,:(Core.Array{Core.Array{Float64},1}()))
    end

    if length(abm.declaredSymbols["Medium"]) > 0
        g = []
        if abm.dims >= 1
            if space.medium[1].minBoundaryType == "Periodic"
                push!(g,:(2:Nx_-1))
            else
                push!(g,:(1:Nx_))
            end
        end
        if abm.dims >= 2
            if space.medium[2].minBoundaryType == "Periodic"
                push!(g,:(2:Ny_-1))
            else
                push!(g,:(1:Ny_))
            end
        end
        if abm.dims >= 3
            if space.medium[3].minBoundaryType == "Periodic"
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
            ob = Community($(abm.dims),t,N,com.declaredSymbols_,$(l...))
            push!(commRAM_,ob)
        end)
    )
    push!(p.execInloop.args,
        :(begin
            if t >= tSave
                tSave += dtSave
                ob = Community($(abm.dims),t+dt,N,com.declaredSymbols_,$(l...))
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