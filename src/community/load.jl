function loadCommunity(agentModel::Model, folder)
   
    files = readdir(folder)
    
    #Check all the files are in the system
    if ! ("local.csv" in files)
        error("local.csv has not been found in the folder.")
    elseif ! ("global.csv" in files)
        error("global.csv variables has not been found in the folder.")
    else
        for i in agentModel.declaredSymbArrays["glob"]
            if ! (string(i[1],".csv") in files)
                error(string(i[1],".csv has not been found in the folder. This is an global array required for the model."))
            end
        end
    end
    
    #Make community
    com = Community(agentModel)
        #Global
    d = DataFrame(CSV.File(string(folder,"/global.csv")))
    com.t = d.t[1]
    com.N = d.N[1]
    for i in names(d)[3:end]
        com[Symbol(i)] = d[!,i][1]
    end
    
        #Local
    d = DataFrame(CSV.File(string(folder,"/local.csv")))
    for i in names(d)
        com[Symbol(i)] = d[!,i][1]
    end

        #Global Array
    for i in agentModel.declaredSymbArrays["glob"]
        d = DataFrame(CSV.File(string(folder,"/",i[1],".csv"),header=false))
        com[Symbol(i[1])] = Array(d)
    end

    return com
end

function loadTimeSeries(agentModel::Model, folder)
    d = DataFrame()
    d.str = readdir(folder)
    d.t = [DataFrame(CSV.File(string(folder,"/",i,"/global.csv"))).t[1] for i in readdir(folder)]
    sort!(d,"t")

    com = CommunityInTime()
    for i in d.str
        push!(com,loadCommunity(agentModel,string(folder,"/",i)))
    end
    
    return com
end