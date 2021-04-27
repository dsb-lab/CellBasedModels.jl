function save(com::Community, folder::String; overwrite = false)
    
    if ! isdir(folder)
        mkdir(folder)
    end
    
    if length(readdir("./Hola")) != 0 && !overwrite
        error("Folder is not empty. Remove the content of the folder by hand or set overwrite to true. Be careful before doing this procedure as it will remove all the data in the folder.")
    end
    
    if overwrite
        for i in readdir("./Hola")
            rm(string("./Hola/",i), recursive=true)
        end
    end
    
    mkdir(string(folder,"/",com.t))   
    
    #Save local
    d = DataFrame()
    for (i,j) in enumerate(com.declaredSymb["var"])
        d[!,j] = com.var[:,i]
    end
    for (i,j) in enumerate(com.declaredSymb["inter"])
        d[!,j] = com.inter[:,i]
    end
    for (i,j) in enumerate(com.declaredSymb["loc"])
        d[!,j] = com.loc[:,i]
    end
    for (i,j) in enumerate(com.declaredSymb["locInter"])
        d[!,j] = com.locInter[:,i]
    end
    
    CSV.write(string(folder,"/",com.t,"/local",".csv"),d)

    #Save global
    d = DataFrame()
    d[!,:t] = [com.t]
    d[!,:N] = [com.N]
    for (i,j) in enumerate(com.declaredSymb["glob"])
        d[!,j] = com.glob[:,i]
    end
    CSV.write(string(folder,"/",com.t,"/global",".csv"),d)

    for (i,j) in enumerate(com.declaredSymb["globArray"])
        CSV.write(string(folder,"/",com.t,"/",j,".csv"),DataFrame(com[j]),header=false)
    end
    
    return
end

function save!(com::Community, folder::String)
    
    if ! isdir(folder)
        error("No folder with this name.")
    end

    if isdir(string(folder,"/",com.t))
        error("Time point already exist.")
    end
    
    #Save local
    d = DataFrame()
    for (i,j) in enumerate(com.declaredSymb["var"])
        d[!,j] = com.var[:,i]
    end
    for (i,j) in enumerate(com.declaredSymb["inter"])
        d[!,j] = com.inter[:,i]
    end
    for (i,j) in enumerate(com.declaredSymb["loc"])
        d[!,j] = com.loc[:,i]
    end
    for (i,j) in enumerate(com.declaredSymb["locInter"])
        d[!,j] = com.locInter[:,i]
    end
    
    CSV.write(string(folder,"/",com.t,"/local",".csv"),d)

    #Save global
    d = DataFrame()
    d[!,:t] = [com.t]
    d[!,:N] = [com.N]
    for (i,j) in enumerate(com.declaredSymb["glob"])
        d[!,j] = com.glob[:,i]
    end
    CSV.write(string(folder,"/",com.t,"/global",".csv"),d)

    for (i,j) in enumerate(com.declaredSymb["globArray"])
        CSV.write(string(folder,"/",com.t,"/",j,".csv"),DataFrame(com[j]),header=false)
    end
    
    return
end

function save(com::CommunityInTime, folder::String; overwrite = false)
    save(com[1],folder,overwrite=overwrite)
    
    for i in com[2:end]
        save!(i,folder)
    end
end