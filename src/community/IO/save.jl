function saveCSV(com::Community, file::String)
    
    #Save local and identity
    d = DataFrame()
    for (i,j) in enumerate(com.declaredSymbols_["Local"])
        d[!,j] = com.local_[:,i]
    end
    for (i,j) in enumerate(com.declaredSymbols_["Identity"])
        d[!,j] = com.identity_[:,i]
    end

    
    CSV.write(string(file,"_local.csv"),d)

    #Save global and globalArray
    d = DataFrame()
    d[!,:t] = [com.t]
    d[!,:N] = [com.N]
    for (i,j) in enumerate(com.declaredSymbols_["Global"])
        d[!,j] = [com.global_[i]]
    end
    for (i,j) in enumerate(com.declaredSymbols_["GlobalArray"])
        dims = size(com.globalArray_[i])
        values = vcat(com.globalArray_[i]...)
        positions = vcat(CartesianIndices(com.globalArray_[i])...)
        name = string(j,"_")
        for (pos,p) in enumerate(positions)
            name2 = name
            for c in 1:length(dims)
                name2 = string(name2,"_",p[c])
            end
            d[!,Meta.parse(name2)] = [values[pos]]
        end  
    end
    CSV.write(string(file,"_global.csv"),d)
    
    return
end

function saveCSV(com::CommunityInTime, file::String)

    for (i,j) in enumerate(com.com)
        saveCSV(j,string(file,"_",i))
    end

    return
end