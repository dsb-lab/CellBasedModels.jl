"""
    function saveRAM!(community::Community)

Function that stores the present configuration of community in the field `Community.pastTimes`.
"""
function saveRAM!(community::Community)
    
    com = Community()

    # Transform to the correct platform the parameters
    for (sym,prop) in pairs(community.abm.parameters)
        p = community.parameters[sym]
        if prop.scope == :agent
            com.parameters[sym] = copy(Array(p[1:community.N]))
        elseif prop.scope in [:model,:medium]
            com.parameters[sym] = copy(Array(p))
        end
    end

    for i in [:dt,:t,:N]
        setfield!(com,i,copy(getfield(community,i)))
    end
    #id
    setfield!(com,:id,copy(Array{Int64}(getfield(community,:id))[1:community.N]))
    setfield!(com,:NMedium,copy(Array{Int64}(getfield(community,:NMedium))))
    setfield!(com,:simBox,copy(Array{Float64}(getfield(community,:simBox))))
    setfield!(com,:abm,community.abm)

    push!(community.pastTimes,com)

    return

end

"""
    saveJLD2(file::String, community::Community; overwrite=false)

Save in `file` the current instance of the `community`. If some other community was being saved here, an error will raise. If `overwrite=true` is specified, it will remove the previous community.   
"""
function saveJLD2(file::String, community::Community; overwrite=false)

    #Check if file is open and assotiated with our community
    if file in keys(SAVING) && isfile(file)
        if SAVING[file].uuid == community.uuid.value
            if !haskey(JLD2.OPEN_FILES,SAVING[file].file.path)
                SAVING[file].file = jldopen(file, "a+")
            end
        elseif !overwrite
            error("File $file contains other community information inside it. If you want to overwrite it, set the key argument overwrite to true.")
        else
            if haskey(JLD2.OPEN_FILES,SAVING[file].file.path)
                close(SAVING[file].file)
            end
            f = jldopen(file, "w")   
            SAVING[file] = SavingFile(community.uuid.value,f)
        end
    elseif isfile(file)
        f = jldopen(file, "w")   
        if "uuid" in keys(f)
            if f["uuid"] == community.uuid.value
                close(file, "w")   
                f = jldopen(file, "a+")   
                SAVING[file] = SavingFile(community.uuid.value,f)
            elseif !overwrite
                error("File $file contains other community information inside it. If you want to overwrite it, set the key argument overwrite to true.")
            else
                SAVING[file] = SavingFile(community.uuid.value,f)
            end
        else
            SAVING[file] = SavingFile(community.uuid.value,f)
        end
    else
        f = jldopen(file, "w") 
        SAVING[file] = SavingFile(community.uuid.value,f)    
    end

    f = SAVING[file].file

    if !haskey(f,"uuid")
        f["uuid"] = community.uuid
    end

    if !( "abm" in keys(f) )
        f["abm/dims"] = community.abm.dims
        f["abm/parameters"] = community.abm.parameters
        f["abm/declaredUpdates"] = community.abm.declaredUpdates
        f["abm/removalOfAgents_"] = community.abm.removalOfAgents_
    end

    if !( "agentAlg" in keys(f) )
        f["agentAlg/alg"] = community.agentAlg
        f["agentAlg/args"] = community.agentSolveArgs
    end

    if !( "modelAlg" in keys(f) )
        f["modelAlg/alg"] = community.modelAlg
        f["modelAlg/args"] = community.modelSolveArgs
    end

    if !( "mediumAlg" in keys(f) )
        f["mediumAlg/alg"] = community.mediumAlg
        f["mediumAlg/args"] = community.mediumSolveArgs
    end

    if !( "platform" in keys(f) )
        f["platform/platform"] = community.platform
    end

    t = 1
    if "times" in keys(f)
        t = length(f["times"]) + 1
    end
    # Transform to the correct platform the parameters
    for (sym,prop) in pairs(community.abm.parameters)
        p = community.parameters[sym]
        if prop.scope == :agent
            f["times/$t/parameters/$sym"] = copy(Array(p[1:community.N]))
        elseif prop.scope in [:model,:medium]
            f["times/$t/parameters/$sym"] = copy(Array(p))
        end
    end

    for sym in [:N,:t,:dt]
        f["times/$t/$sym"] = copy(getfield(community,sym))
    end
    for sym in [:NMedium,:simBox]
        f["times/$t/$sym"] = copy(Array(getfield(community,sym)))
    end
    f["times/$t/id"] = copy(Array{Int64}(getfield(community,:id))[1:community.N])

    return

end

"""
    function loadJLD2(file::String)

Load the Community structure saved in file.
"""
function loadJLD2(file::String)

    if file in keys(SAVING) && isfile(file)
        close(SAVING[file].file)
        delete!(SAVING,file)
    end

    jldopen(file, "r") do f

        #Agent
        abm = ABM()
        abm.dims = f["abm/dims"] 
        abm.parameters = f["abm/parameters"] 
        abm.declaredUpdates = f["abm/declaredUpdates"] 
        abm.removalOfAgents_ = f["abm/removalOfAgents_"] 

        #Assign abm
        t = length(f["times"])
        community = Community(abm,
            id = f["times/$t/id"],
            N = f["times/$t/N"],
            NMedium = f["times/$t/NMedium"],
            t = f["times/$t/t"],
            dt = f["times/$t/dt"],
            simBox = f["times/$t/simBox"],
            platform = f["platform/platform"],#eval(Meta.parse("CellBasedModels.$(f["platform/platform"])()")),
            agentAlg = f["agentAlg/alg"],#eval(Meta.parse("CellBasedModels.$(f["agentAlg/alg"])()")),
            agentSolveArgs = f["agentAlg/args"],
            modelAlg = f["modelAlg/alg"],#eval(Meta.parse("CellBasedModels.$(f["modelAlg/alg"])()")),
            modelSolveArgs = f["modelAlg/args"],
            mediumAlg = f["mediumAlg/alg"],#eval(Meta.parse("CellBasedModels.$(f["mediumAlg/alg"])()")),
            mediumSolveArgs = f["mediumAlg/args"],
        )
        setfield!(community,:uuid,f["uuid"])
        for (sym,prop) in pairs(community.abm.parameters)
            community.parameters[sym] = f["times/$t/parameters/$sym"]
        end

        #Base parameters
        times = sort([Meta.parse(i) for i in keys(f["times"])])[1:end-1]
        for t in times
            com = Community(abm,
                id = f["times/$t/id"],
                N = f["times/$t/N"],
                NMedium = f["times/$t/NMedium"],
                t = f["times/$t/t"],
                dt = f["times/$t/dt"],
                simBox = f["times/$t/simBox"],
                platform = f["platform/platform"],#eval(Meta.parse("CellBasedModels.$(f["platform/platform"])()")),
                agentAlg = f["agentAlg/alg"],#eval(Meta.parse("CellBasedModels.$(f["agentAlg/alg"])()")),
                agentSolveArgs = f["agentAlg/args"],
                modelAlg = f["modelAlg/alg"],#eval(Meta.parse("CellBasedModels.$(f["modelAlg/alg"])()")),
                modelSolveArgs = f["modelAlg/args"],
                mediumAlg = f["mediumAlg/alg"],#eval(Meta.parse("CellBasedModels.$(f["mediumAlg/alg"])()")),
                mediumSolveArgs = f["mediumAlg/args"],
            )
            for (sym,prop) in pairs(community.abm.parameters)
                com.parameters[sym] = f["times/$t/parameters/$sym"]
            end
    
            push!(community.pastTimes, com)
        end

        setfield!(community,:loaded,false)

        return community
    end

end