######################################################################################################
# Definition of structure
######################################################################################################
"""
Basic structure keeping the parameters of all the agents in the current simulation of a model.

# Elements

 - **agent::Agent**: Agent model dealing with the rule of the model.
 - **loaded::Bool**: Check if the model has been loaded into platform or not.
 - **Other parameters described in API**.

# Constructors

    function Community(abm::Agent; args...)

Function to construct a Community with a predefined number of agents and medium grid.

# Arguments

 - **abm::Agent**: Agent Based Model that defines the parameters of the agents.

# Keyword Arguments

 - **keyword arguments defined in API**

"""
mutable struct Community

    agent
    loaded
    platform
    pastTimes::Array{Community}

    t
    dt
    N
    NMedium
    nMax_
    id
    idMax_
    simBox
    NAdd_
    NRemove_
    NSurvive_
    flagSurvive_
    holeFromRemoveAt_
    repositionAgentInPos_
    skin
    dtNeighborRecompute
    nMaxNeighbors
    cellEdge
    flagRecomputeNeighbors_
    flagNeighbors_
    neighborN_
    neighborList_
    neighborTimeLastRecompute_
    posOld_
    accumulatedDistance_
    nCells_
    cellAssignedToAgent_
    cellNumAgents_
    cellCumSum_
    x
    y
    z
    xNew_
    yNew_
    zNew_
    varAux_
    varAuxΔW_
    liNM_
    liM_
    liMNew_
    lii_
    lfNM_
    lfM_
    lfMNew_
    lfi_
    gfNM_
    gfM_
    gfMNew_
    gfi_
    giNM_
    giM_
    giMNew_
    gii_
    mediumNM_
    mediumM_
    mediumMNew_

    # Constructors
    function Community(agent::Agent; args...)

        #Check args compulsory to be declared in the community given the agent model
        for (sym,prop) in pairs(BASEPARAMETERS)
            for i in prop.necessaryFor
                if i == agent.neighbors && !(sym in keys(args))
                    error("Parameter $sym has to be declared in the community for neighborhood style $i.")
                elseif i == :Medium && length(getSymbolsThat(agent.declaredSymbols,:basePar,:medium_)) > 0 && !(sym in keys(args))
                    error("Parameter $sym has to be declared in the community for models with medium parameters.")
                end
            end
        end

        #Creating the appropiate data matrices for the different parameters
        dict = OrderedDict()
        for (sym,prop) in pairs(BASEPARAMETERS)
            if sym in keys(args)
                checkFormat(sym,args,prop,dict,agent)
                dict[sym] = args[sym]
            else
                dict[sym] = prop.initialize(dict,agent)
            end
        end
    
        return new(agent, false, Platform(256,1),Community[], [j for (i,j) in pairs(dict)]...)

    end

    function Community()

        #Creating the appropiate data matrices for the different parameters
        dict = OrderedDict()
        for (sym,prop) in pairs(BASEPARAMETERS)
            dict[sym] = nothing
        end
    
        return new(nothing, nothing, nothing,Community[], [j for (i,j) in pairs(dict)]...)

    end

end

######################################################################################################
# Overloads from base to access, manipulate and show the structure
######################################################################################################

# Overload show
function Base.show(io::IO,com::Community)
    println("Community with ", com.N[1], " agents.")
end

# Overload ways of calling and assigning the parameters in community
function Base.getindex(community::Community,timePoint::Number)
    
    com = Community()

    #Assign base parameters
    if 1 > timePoint || timePoint > length(community.pastTimes)
        error("Only time points from 1 to $(length(community.pastTimes)) present in the Community.")
    elseif community.loaded 
        error("Community has to be in RAM before calling a time point saved in RAM. Execute `bringFromPlatform!` before using this.")
    else
        com = community.pastTimes[timePoint]
        for (sym,prop) in pairs(BASEPARAMETERS)
            if 0 == prop.saveLevel
                if :Atomic in prop.shape #Do nothing if CPU and atomic
                    setfield!(com,sym,getfield(community,sym))
                else
                    setfield!(com,sym,Array(getfield(community,sym)))
                end
            end
        end

        for (i,sym) in enumerate(POSITIONPARAMETERS[1:1:community.agent.dims])
            if !community.agent.posUpdated_[i]
                p = getfield(community,sym)
                setfield!(com,sym,p)
            end
        end
    end

    #Assign agent
    com.agent = community.agent
    setfield!(com,:loaded,community.loaded)
    com.platform = community.platform

    #Initializing parameters that were nothing before
    dict = OrderedDict()
    for (sym,prop) in pairs(BASEPARAMETERS)
        if getfield(com,sym) === nothing
            setfield!(com,sym,prop.initialize(dict,com.agent))
            dict[sym] = getfield(com,sym)
        else
            dict[sym] = getfield(com,sym)
        end
    end

    return com

end

function Base.lastindex(community::Community)
    return length(community.pastTimes)
end

function Base.firstindex(community::Community)
    return 1
end

function Base.getproperty(com::Community,var::Symbol)
    
    if var in fieldnames(Community)
        return getfield(com,var)
    else
        if var in keys(com.agent.declaredSymbols)
            x = com.agent.declaredSymbols[var].basePar
            pos = com.agent.declaredSymbols[var].position
            return @views getfield(com,x)[:,pos]
        else
            error("Parameter ", var, " not found in the community.")
        end
    end

end

function Base.getindex(com::Community,var::Symbol)
    
    if var in fieldnames(Community)
        return getfield(com,var)
    else
        if var in keys(com.agent.declaredSymbols)
            x = com.agent.declaredSymbols[var].basePar
            pos = com.agent.declaredSymbols[var].position
            return @views getfield(com,x)[:,pos]
        else
            error("Parameter ", var, " not found in the community.")
        end
    end

end

function Base.setproperty!(com::Community,var::Symbol,v::Array{<:Number})

    if !(var in keys(com.agent.declaredSymbols)) && !(var in fieldnames(Community))
        error(var," is not in community.")
    elseif var in fieldnames(Community)
        if var in keys(BASEPARAMETERS)
            if BASEPARAMETERS[var].protected
                error("Parameter of community $var is protected. If you really need to change it declare a new Community or use setfield! method (can be unstable).")
            else
                getfield(com,var) .= v
            end
        else
            error("Parameter of community $var is protected. If you really need to change it declare a new Community or use setfield! method (can be unstable).")
        end
    else
        x = com.agent.declaredSymbols[var].basePar
        pos = com.agent.declaredSymbols[var].position
        getfield(com,x)[:,pos] .= v
    end

end

function Base.setproperty!(com::Community,var::Symbol,v::Number)
    
    if !(var in keys(com.agent.declaredSymbols)) && !(var in fieldnames(Community))
        error(var," is not in community.")
    elseif var in fieldnames(Community)
        if var in keys(BASEPARAMETERS)
            if BASEPARAMETERS[var].protected
                error("Parameter of community $var is protected. If you really need to change it declare a new Community or use setfield! method (can be unstable).")
            else
                getfield(com,var) .= v
            end
        else
            error("Parameter of community $var is protected. If you really need to change it declare a new Community or use setfield! method (can be unstable).")
        end
    else
        x = com.agent.declaredSymbols[var].basePar
        pos = com.agent.declaredSymbols[var].position
        getfield(com,x)[:,pos] .= v
    end

end

function Base.setindex!(com::Community,v::Array{<:Number},var::Symbol)
    
    if !(var in keys(com.agent.declaredSymbols)) && !(var in fieldnames(Community))
        error(var," is not in community.")
    elseif var in fieldnames(Community)
        if var in keys(BASEPARAMETERS)
            if BASEPARAMETERS[var].protected
                error("Parameter of community $var is protected. If you really need to change it declare a new Community or use setfield! method (can be unstable).")
            else
                getfield(com,var) .= v
            end
        else
            error("Parameter of community $var is protected. If you really need to change it declare a new Community or use setfield! method (can be unstable).")
        end
    else
        x = com.agent.declaredSymbols[var].basePar
        pos = com.agent.declaredSymbols[var].position
        getfield(com,x)[:,pos] .= v
    end

end

function Base.setindex!(com::Community,v::Number,var::Symbol)
    
    if !(var in keys(com.agent.declaredSymbols)) && !(var in fieldnames(Community))
        error(var," is not in community.")
    elseif var in fieldnames(Community)
        if var in keys(BASEPARAMETERS)
            if BASEPARAMETERS[var].protected
                error("Parameter of community $var is protected. If you really need to change it declare a new Community or use setfield! method (can be unstable).")
            else
                getfield(com,var) .= v
            end
        else
            error("Parameter of community $var is protected. If you really need to change it declare a new Community or use setfield! method (can be unstable).")
        end
    else
        x = com.agent.declaredSymbols[var].basePar
        pos = com.agent.declaredSymbols[var].position
        getfield(com,x)[:,pos] .= v
    end

end

function Base.length(com::Community)
    return length(com.pastTimes)
end

######################################################################################################
# Load to platform
######################################################################################################
"""
    function loadToPlatform!(com::Community;preallocateAgents::Int=0)

Function that converts the Community data into the appropiate format to be executed in the corresponding platform.

# Arguments

 - **com::Community**: Comunity to be transformed.
 
# Keyword arguments

 - **preallocateAgents::Int=0**: Number of preallocated agent positions to add to the Community for situations in which more agents will be introduced in the model during the evolution of the system.

# Returns

Nothing
"""
function loadToPlatform!(com::Community;preallocateAgents::Int=0)

    #Add preallocated agents to maximum
    setfield!(com, :nMax_, com.N .+ preallocateAgents)

    #Start with the new parameters equal to the old positions just in case
    if com.agent.posUpdated_[1]
        setfield!(com,:xNew_,copy(com.x))
    end
    if com.agent.posUpdated_[2]
        setfield!(com,:yNew_,copy(com.y))
    end
    if com.agent.posUpdated_[3]
        setfield!(com,:yNew_,copy(com.y))
    end
    setfield!(com,:liMNew_,copy(com.liM_))
    setfield!(com,:lfMNew_,copy(com.lfM_))
    setfield!(com,:gfMNew_,copy(com.gfM_))
    setfield!(com,:giMNew_,copy(com.giM_))

    # Transform to the correct platform the parameters
    platform = com.agent.platform
    for (sym,prop) in pairs(BASEPARAMETERS)

        if :Atomic in prop.shape && platform == :CPU #Do nothing if CPU and atomic
            nothing
        elseif :Atomic in prop.shape && platform == :GPU #Convert atomic to matrix for CUDA
            setfield!(com,sym,ARRAY[platform]{DTYPE[prop.dtype][platform]}([getproperty(com,sym)[]]))
        elseif :Local in prop.shape
            p = getproperty(com,sym)
            if length(p) > 0
                setfield!(com,sym,ARRAY[platform]{DTYPE[prop.dtype][platform]}([p;zeros(eltype(p),preallocateAgents,size(p)[2:end]...)]))
            end
        else
            setfield!(com,sym,ARRAY[platform]{DTYPE[prop.dtype][platform]}(getproperty(com,sym)))
        end
    end            

    #Set loaded to true
    setfield!(com,:loaded,true)

    #Compute nieghbors and interactions for the first time
    computeNeighbors!(com)
    interactionStep!(com)

    return
end

function bringFromPlatform!(com::Community)

    N = Array(com.N)[1]
    # Transform to the correct platform the parameters
    platform = com.agent.platform
    for (sym,prop) in pairs(BASEPARAMETERS)
        type = DTYPE[prop.dtype][:CPU]
        if :Atomic in prop.shape && platform == :CPU #Do nothing if CPU and atomic
            nothing
        elseif :Atomic in prop.shape && platform == :GPU #Convert atomic to matrix for CUDA
            setfield!(com,sym,Threads.Atomic{type}(Array(getproperty(com,sym))[1]))
        elseif :Local in prop.shape
            p = getproperty(com,sym)
            if length(p) > 0
                setfield!(com,sym,ARRAY[:CPU]{type}(p[1:N,[1:x for x in size(p)[2:end]]...]))
            else
                setfield!(com,sym,ARRAY[:CPU]{type}(p))
            end
        else
            p = getproperty(com,sym)
            setfield!(com,sym,ARRAY[:CPU]{type}(p))
        end
    end            

    setfield!(com, :nMax_, com.N)

    #Set loaded to true
    setfield!(com,:loaded,false)

    return
end

"""
    function checkLoaded(com)

Function that give error if the Community has not been loaded. Called before any step function.
"""
function checkLoaded(com)
    if !com.loaded
        error("Community must be loaded to platform with `loadToPlatform!` before being able to compute any step.")
    end
end