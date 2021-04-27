function saveCSVCompile(agentModel::Model; saveRAM = false)
    
    varDeclare = []
    fDeclare = []
    execute = []

    if !saveRAM

        push!(varDeclare,
        :(
            mkdir(folder)
        )
        )

        #List of nonempty arrays
        l = []
        if length(agentModel.declaredSymb["var"])>0
            push!(l,:(Array(v_)[1:N,:]))
        else
            push!(l,:(Array{AbstractFloat,2}(undef,0,2)))
        end
        if length(agentModel.declaredSymb["inter"])>0
            push!(l,:(Array(inter_)[1:N,:]))
        else
            push!(l,:(Array{AbstractFloat,2}(undef,0,2)))
        end
        if length(agentModel.declaredSymb["loc"])>0
            push!(l,:(Array(loc_)[1:N,:]))
        else
            push!(l,:(Array{AbstractFloat,2}(undef,0,2)))
        end
        if length(agentModel.declaredSymb["locInter"])>0
            push!(l,:(Array(locInter_)[1:N,:]))
        else
            push!(l,:(Array{AbstractFloat,2}(undef,0,2)))
        end
        if length(agentModel.declaredSymb["glob"])>0
            push!(l,:(Array(glob_)))
        else
            push!(l,:(Vector{AbstractFloat}[]))
        end
        if length(agentModel.declaredSymbArrays["glob"])>1
            list = string("[copy(",agentModel.declaredSymbArrays["glob"][1],"_)")
            for i in agentModel.declaredSymbArrays["glob"][2:end]
                list = string(list,",copy(",i[1],"_)")
            end
            list = string(list,"]")
            push!(l,:(Array($list)))
        elseif length(agentModel.declaredSymbArrays["glob"]) > 0
            list = string("[copy(",agentModel.declaredSymbArrays["glob"][1][1],"_")
            list = string(list,")]")
            push!(l,Meta.parse(string("Array(",list,")")))
        else
            push!(l,:(Vector{AbstractFloat}[]))
        end
        if length(agentModel.declaredIds)>0
            push!(l,:(Array(ids_)[1:N,:]))
        else
            push!(l,:(Array{Int,2}(undef,0,2)))
        end
        
        push!(execute,
        :(
            ob = Community(t,N,com.declaredSymb,$(l...))
        )
        )
        push!(execute,
        :(
            save!(ob,folder)
        )
        )

    else
        push!(varDeclare,
        :(
            mkdir(folder)
        )
        )
        push!(execute,
        :(
            save!(ob,folder)
        )
        )
    end

    return varDeclare,fDeclare,execute
end