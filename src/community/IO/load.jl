function loadCommunityFromCSV(abm::Model, file::String)

    #Global Array
    d = DataFrame(CSV.File(string(file,"_global.csv")))
    com = Community(abm,N=d.N[1]) #Create Community
    com.t = d.t[1]
    for i in com.declaredSymbols_["Global"]
        setproperty!(com, i, d[!,i][1])
    end
    for i in com.declaredSymbols_["GlobalArray"]
        values = sort([j for j in names(d) if occursin(string(i,"__"),j)])
        indexes = [Meta.parse.(split(split(j,"__")[2],"_")) for j in values]
        m = zeros(indexes[end]...)
        for (v,ind) in zip(values,indexes)
            m[ind...] = d[1,v]
        end
        setproperty!(com, i, m)
    end

    #Local and Identity load
    d = DataFrame(CSV.File(string(file,"_local.csv")))
    for i in com.declaredSymbols_["Local"]
        setproperty!(com, i, d[!,i])
    end    
    for i in com.declaredSymbols_["Identity"]
        setproperty!(com, i, Int.(d[!,i]))
    end    
    
    return com
end

function loadCommunityInTimeFromCSV(abm::Model, file)

    out = false
    count = 1

    com = CommunityInTime()
    while !out
        fileName = string(file,"_",count)
        checkName = string(file,"_",count,"_local.csv")
        if isfile(checkName)
            push!(com,loadCommunityFromCSV(abm,fileName))
            count += 1
        else
            out = true
        end
    end
    
    return com
end

function loadCommunityInTimeFromJLD(file)

    com = CommunityInTime()
    m = JLD.load(file)
    for i in 1:length(keys(m))
        push!(com,m[string(i)])
    end
    
    return com
end