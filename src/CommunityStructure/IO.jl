function saveRAM!(community::Community;saveLevel=1)

    N = 0
    if community.agent.platform == :CPU
        N = community.N[]
    else
        CUDA.@allowscalar N = community.N[1]
    end

    com = Community()
    for (sym,prop) in pairs(BASEPARAMETERS)
        type = DTYPE[prop.dtype][community.agent.platform]
        if (0 < prop.saveLevel && prop.saveLevel <= saveLevel)
            if :Atomic in prop.shape && community.agent.platform == :CPU #Do nothing if CPU and atomic
                setfield!(com,sym,deepcopy(getfield(community,sym)))
            elseif :Atomic in prop.shape && community.agent.platform == :GPU #Convert atomic to matrix for CUDA
                p = Array(getfield(community,sym))[1]
                setfield!(com,sym,deepcopy(Threads.Atomic{type}(p)))
            elseif :Local in prop.shape
                p = getfield(community,sym)
                if length(p) > 0
                    setfield!(com,sym,copy(Array{type}(@views p[1:N,[1:x for x in size(p)[2:end]]...])))
                else
                    setfield!(com,sym,copy(Array{type}(p)))
                end
            else
                setfield!(com,sym,copy(Array{type}(getfield(community,sym))))
            end
        end
    end

    for (i,sym) in enumerate(POSITIONPARAMETERS[1:1:community.agent.dims])
        prop = BASEPARAMETERS[sym]
        type = DTYPE[prop.dtype][community.agent.platform]
        if community.agent.posUpdated_[i]
            p = getfield(community,sym)
            setfield!(com,sym,copy(Array{type}(@views p[1:N])))
        end
    end

    push!(community.pastTimes,com)

    return

end

function saveJLD2!(file::String,community::Community;saveLevel=1)

    jldopen(file, "a+") do f

        if !( "saveLevel" in keys(f) )
            f["saveLevel"] = saveLevel
        end

        if !( "agent" in keys(f) )
            f["agent/dims"] = community.agent.dims
            f["agent/declaredSymbols"] = community.agent.declaredSymbols
            f["agent/declaredVariables"] = community.agent.declaredVariables
            f["agent/declaredUpdates"] = community.agent.declaredUpdates
            f["agent/neighbors"] = community.agent.neighbors
            f["agent/integrator"] = community.agent.integrator
            f["agent/platform"] = community.agent.platform
            f["agent/removalOfAgents_"] = community.agent.removalOfAgents_
            f["agent/posUpdated_"] = community.agent.posUpdated_
        end

        N = 0
        if community.agent.platform == :CPU
            N = community.N[]
        else
            CUDA.@allowscalar N = community.N[1]
        end

        if !( "constants" in keys(f) )
            for (sym,prop) in pairs(BASEPARAMETERS)
                if prop.saveLevel == 0
                    f["constants/$sym"] = getfield(community,sym)
                end
            end

            for (i,sym) in enumerate(POSITIONPARAMETERS[1:1:community.agent.dims])
                if !community.agent.posUpdated_[i]
                    p = getproperty(community,sym)
                    f["constants/$sym"] = Array(@views p[1:N])
                end
            end
        end

        t = 1
        if "times" in keys(f)
            t = length(f["times"]) + 1
        end

        for (sym,prop) in pairs(BASEPARAMETERS)
            type = DTYPE[prop.dtype][:CPU]
            if 0 < prop.saveLevel <= saveLevel
                if :Atomic in prop.shape && community.agent.platform == :CPU #Do nothing if CPU and atomic
                    f["times/$t/$sym"] = Array{type}([getfield(community,sym)[]])
                elseif :Atomic in prop.shape && community.agent.platform == :GPU #Convert atomic to matrix for CUDA
                    f["times/$t/$sym"] = Array{type}(getproperty(community,sym))
                elseif :Local in prop.shape
                    p = getproperty(community,sym)
                    if length(p) > 0
                        f["times/$t/$sym"] = Array{type}(@views p[1:N,[1:x for x in size(p)[2:end]]...])
                    else
                        f["times/$t/$sym"] = Array{type}(p)
                    end
                else
                    f["times/$t/$sym"] = Array{type}(getproperty(community,sym))
                end
            end

        end    

        for (i,sym) in enumerate(POSITIONPARAMETERS)
            type = DTYPE[:Float][:CPU]
            if community.agent.posUpdated_[i]
                p = getproperty(community,sym)
                f["times/$t/$sym"] = Array{type}(p[1:N])
            end
        end

    end

    return

end

function loadJLD2!(file::String)

    com = Community()

    jldopen(file, "r") do f

        #Agent
        agent = Agent()
        agent.dims = f["agent/dims"] 
        agent.declaredSymbols = f["agent/declaredSymbols"] 
        agent.declaredVariables = f["agent/declaredVariables"] 
        agent.declaredUpdates = f["agent/declaredUpdates"] 
        agent.neighbors = f["agent/neighbors"] 
        agent.integrator = f["agent/integrator"] 
        agent.platform = f["agent/platform"] 
        agent.removalOfAgents_ = f["agent/removalOfAgents_"] 
        agent.posUpdated_ = f["agent/posUpdated_"] 
        #Make compiled functions
        localFunction(agent)
        globalFunction(agent)
        neighborsFunction(agent)
        interactionFunction(agent)
        integratorFunction(agent)
        #Assign agent
        com.agent = agent

        for (sym,prop) in pairs(BASEPARAMETERS)
            if prop.saveLevel == 0
                setfield!(com,sym,f["constants/$sym"])
            end
        end

        for (i,sym) in enumerate(POSITIONPARAMETERS[1:1:agent.dims])
            if !agent.posUpdated_[i]
                setfield!(com,sym,f["constants/$sym"])
            end
        end

        times = sort([Meta.parse(i) for i in keys(f["times"])])
        for t in times
            community = Community()
            for (sym,prop) in pairs(BASEPARAMETERS)
                type = DTYPE[prop.dtype][:CPU]
                if 0 != prop.saveLevel && prop.saveLevel <= f["saveLevel"] && !(sym in POSITIONPARAMETERS)
                    if :Atomic in prop.shape
                        setfield!(community,sym,Threads.Atomic{type}(f["times/$t/$sym"][1]))
                    else
                        setfield!(community,sym,f["times/$t/$sym"])
                    end
                end
            end

            for (i,sym) in enumerate(POSITIONPARAMETERS[1:1:agent.dims])
                if agent.posUpdated_[i]
                    setfield!(community,sym,f["times/$t/$sym"])
                end
            end

            if t == times[end] #add a copy of the last element to the main Community object
                for (sym,prop) in pairs(BASEPARAMETERS)
                    type = DTYPE[prop.dtype][:CPU]
                    if 0 != prop.saveLevel && prop.saveLevel <= f["saveLevel"] && !(sym in POSITIONPARAMETERS)
                        if :Atomic in prop.shape
                            setfield!(com,sym,Threads.Atomic{type}(f["times/$t/$sym"][1]))
                        else
                            setfield!(com,sym,f["times/$t/$sym"])
                        end
                    end
                end

                for (i,sym) in enumerate(POSITIONPARAMETERS[1:1:agent.dims])
                    if agent.posUpdated_[i]
                        setfield!(com,sym,f["times/$t/$sym"])
                    end
                end
            end

            push!(com.pastTimes, community)
        end

        close(f)

    end

    setfield!(com,:loaded,false)

    return com

end