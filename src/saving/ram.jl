function inRAMSave(agentModel::Model)
    
    varDeclare = [:(commRAM_ = Array{Community}([com]))]
    fDeclare = []
    execute = []

    #List of nonempty arrays
    l = []
    if length(agentModel.declaredSymb["var"])>0
        push!(l,:(Array(v_)[1:N_,:]))
    else
        push!(l,:(Array{AbstractFloat,2}(undef,0,2)))
    end
    if length(agentModel.declaredSymb["inter"])>0
        push!(l,:(Array(inter_)[1:N_,:]))
    else
        push!(l,:(Array{AbstractFloat,2}(undef,0,2)))
    end
    if length(agentModel.declaredSymb["loc"])>0
        push!(l,:(Array(loc_)[1:N_,:]))
    else
        push!(l,:(Array{AbstractFloat,2}(undef,0,2)))
    end
    if length(agentModel.declaredSymb["locInter"])>0
        push!(l,:(Array(locInter_)[1:N_,:]))
    else
        push!(l,:(Array{AbstractFloat,2}(undef,0,2)))
    end
    if length(agentModel.declaredSymb["glob"])>0
        push!(l,:(Array(glob_)))
    else
        push!(l,:(Vector{AbstractFloat}[]))
    end
    if length(agentModel.declaredIds)>0
        push!(l,:(Array(ids_)[1:N_,:]))
    else
        push!(l,:(Array{Int,2}(undef,0,2)))
    end
    
    push!(execute,
    :(
    if t_ >= tSave_
        ob = Community(t_,N_,com.declaredSymb,$(l...))
        push!(commRAM_,ob)
        tSave_ += tSaveStep_
    end
    )
    )
    
    return varDeclare,fDeclare,execute
end