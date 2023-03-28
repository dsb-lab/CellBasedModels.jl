"""
    function saveRAM!(community::Community)

Function that stores the present configuration of community in the field `Community.pastTimes`.
The parameter `saveLevel` indicates which parameters should be saved.

|saveLevel|saved parameters|
|:---:|:---|
|1|User defined parameters and modifiable parameters. (t,N...) (default)|
|2|All auxiliar parameters of Community (for debugging)|
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

    for i in fieldnames(Community)
        if !(string(i)[end:end] == "_")
            setfield!(com,i,copy(getfield(community,i)))
        end
    end
    setfield!(com,:id,copy(Array(getfield(community,:id))[1:com.N]))

    push!(community.pastTimes,com)

    return

end

"""
    function saveJLD2(community::Community)

Function that stores the present configuration of community in the file defined in `Community.fileSaving`.
The behavior of the function is to append to the file if the file exists. If you want to restart the file, you will have to rename the exisiting file or delete it before running the function.
The parameter `saveLevel` indicates which parameters should be saved.

|saveLevel|saved parameters|
|:---:|:---|
|1|User defined parameters and modifiable parameters. (t,N...) (default)|
|2|All auxiliar parameters of Community (for debugging)|
"""
function saveJLD2(community::Community)

    f = nothing
    if typeof(community.fileSaving) <: JLD2.JLDFile
        f = community.fileSaving
    elseif typeof(community.fileSaving) <: String
        f = jldopen(community.fileSaving, "a+")
        community.fileSaving = f
    else
        error("fileSaving property has to be defined before executing saveJLD2.")
    end

    # jldopen(file, "a+") do f

        if !( "abm" in keys(f) )
            f["abm/dims"] = community.abm.dims
            f["abm/parameters"] = community.abm.parameters
            f["abm/declaredUpdates"] = community.abm.declaredUpdates
            f["abm/removalOfAgents_"] = community.abm.removalOfAgents_

        end

        if !( "agentAlg" in keys(f) )
            if typeof(community.fileSaving) <: JLD2.JLDFile
                f["fileSaving"] = community.fileSaving.path
            else
                f["fileSaving"] = community.fileSaving
            end
        end

        if !( "agentAlg" in keys(f) )
            f["agentAlg/alg"] = typeof(community.agentAlg)
            f["agentAlg/args"] = community.agentSolveArgs
        end

        if !( "mediumAlg" in keys(f) )
            f["mediumAlg/alg"] = typeof(community.mediumAlg)
            f["mediumAlg/args"] = community.mediumSolveArgs
        end

        if !( "platform" in keys(f) )
            f["platform/platform"] = typeof(community.platform)
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

        for sym in [:N,:NMedium,:t,:dt,:simBox]
            f["times/$t/$sym"] = copy(getfield(community,sym))
        end
        f["times/$t/id"] = copy(Array(getfield(community,:id))[1:community.N])

    # end

    return

end

"""
    function loadJLD2(file::String)

Load the Community structure saved in file.
"""
function loadJLD2(file::String)

    try
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
                N = f["times/$t/N"],
                NMedium = f["times/$t/NMedium"],
                t = f["times/$t/t"],
                dt = f["times/$t/dt"],
                simBox = f["times/$t/simBox"],
                platform = eval(:($(f["platform/platform"])())),
                agentAlg = eval(:($(f["agentAlg/alg"])())),
                agentSolveArgs = f["agentAlg/args"],
                mediumAlg = eval(:($(f["mediumAlg/alg"])())),
                mediumSolveArgs = f["mediumAlg/args"],
                fileSaving = f["fileSaving"]
            )
            community.id = f["times/$t/id"]
            community.N = f["times/$t/N"]
            community.NMedium = f["times/$t/NMedium"]
            community.t = f["times/$t/t"]
            community.dt = f["times/$t/dt"]
            community.simBox = f["times/$t/simBox"]

            for (sym,prop) in pairs(community.abm.parameters)
                community[sym] = f["times/$t/parameters/$sym"]
            end

            #Base parameters
            times = sort([Meta.parse(i) for i in keys(f["times"])])[1:end-1]
            for t in times
                com = Community()

                com.id = f["times/$t/id"]
                com.N = f["times/$t/N"]
                com.NMedium = f["times/$t/NMedium"]
                com.t = f["times/$t/t"]
                com.dt = f["times/$t/dt"]
                com.simBox = f["times/$t/simBox"]

                for (sym,prop) in pairs(community.abm.parameters)
                    com.parameters[sym] = f["times/$t/parameters/$sym"]
                end
        
                push!(community.pastTimes, com)
            end

            close(f)
            setfield!(community,:loaded,false)

            return community

        end

    catch

        filer = jldopen(file,"w")
        close(filer)

        loadJLD2(file)
    
    end


end