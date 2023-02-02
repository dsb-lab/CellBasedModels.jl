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

    f = jldopen(file, "a+")

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
    if "constants" in keys(f)
        t = length(f["constants"]) + 1
    end

    for (sym,prop) in pairs(BASEPARAMETERS)
        if 0 < prop.saveLevel <= saveLevel
            if :Atomic in prop.shape && platform == :CPU #Do nothing if CPU and atomic
                f["constants/$t/$sym"] = getfield(community,sym)
            elseif :Atomic in prop.shape && platform == :GPU #Convert atomic to matrix for CUDA
                f["constants/$t/$sym"] = Atomic.atomic(Array([getproperty(community,sym)[]])[1])
            elseif :Local in prop.shape
                p = getproperty(community,sym)
                if length(p) > 0
                    f["constants/$t/$sym"] = Array(@views p[1:N,size(p)[2:end]...])
                end
            else
                f["constants/$t/$sym"] = Array(getproperty(community,sym))
            end
        end
    end    

    close(f)

    return

end