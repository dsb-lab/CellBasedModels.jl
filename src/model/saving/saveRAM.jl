function addSavingRAM_!(p::Program_,abm::Agent,Space::SimulationSpace,platform::String)
    
    #List of nonempty arrays
    l = []

    if length(abm.declaredSymbols["Local"])>0
        push!(l,:(Core.Array(localV)[1:N,:]))
    else
        push!(l,:(Core.Array{AbstractFloat,2}(undef,0,2)))
    end

    if length(abm.declaredSymbols["Identity"])>0
        push!(l,:(Core.Array(identityV)[1:N,:]))
    else
        push!(l,:(Core.Array{Int,2}(undef,0,2)))
    end

    if length(abm.declaredSymbols["Global"])>0
        push!(l,:(Core.Array(globalV)))
    else
        push!(l,:(Base.Array{AbstractFloat,1}[]))
    end

    if length(abm.declaredSymbols["GlobalArray"])>1
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
        push!(l,:(Core.Array{AbstractFloat,1}[]))
    end

    push!(p.declareVar.args,:(commRAM_ = CommunityInTime()))

    push!(p.execInit.args,
    :(begin
        ob = Community(t,N,com.declaredSymbols_,$(l...))
        push!(commRAM_,ob)
        end)
    )
    push!(p.execInloop.args,
    :(begin
        ob = Community(t+dt,N,com.declaredSymbols_,$(l...))
        push!(commRAM_,ob)
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