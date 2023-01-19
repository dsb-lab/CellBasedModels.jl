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

    agent::Agent
    loaded::Bool
    t
    dt
    N
    NMedium
    nMax_
    id
    idMax_
    simulationBox
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
    
        return new(agent, false, [j for (i,j) in pairs(dict)]...)

    end

end

# Overload show
function Base.show(io::IO,com::Community)
    println("Community with ", com.N[1], " agents.")
end

# Overload ways of calling and assigning the parameters in community
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

"""
    function loadToPlatform!(com::Community;addAgents::Int=0)

Function that converts the Community data into the appropiate format to be executed in the corresponding platform.

# Arguments

 - **com::Community**: Comunity to be transformed.
 
# Keyword arguments

 - **addAgents::Int=0**: Number of preallocated agent positions to add to the Community for situations in which more agents will be introduced in the model during the evolution of the system.

# Returns

Nothing
"""
function loadToPlatform!(com::Community;addAgents::Int=0)

    # Transform to the correct platform
    for (sym,prop) in pairs(BASEPARAMETERS)
        dtype = Float64
        if :Float in prop
            dtype = FLOAT[com.agent.platform]
        elseif :Int in prop
            dtype = INT[com.agent.platform]
        end

        if :Local in prop
            com.values[sym] = ARRAY[com.agent.platform]([com.values[sym]; zeros(dtype,addAgents)])
        elseif :VerletList in prop
            com.values[sym] = ARRAY[com.agent.platform](zeros(dtype,com.nMax_[1],com.nMaxNeighbors[1]))
        elseif :SimulationBox in prop
            com.values[sym] = ARRAY[com.agent.platform](com.values[sym])
        elseif :Global in prop
            com.values[sym] = ARRAY[com.agent.platform](com.values[sym])
        elseif :Medium in prop
            com.values[sym] = ARRAY[com.agent.platform](com.values[sym])
        elseif :Dims in prop
            com.values[sym] = ARRAY[com.agent.platform](com.values[sym])
        elseif :Cells in prop
            com.values[sym] = ARRAY[com.agent.platform](com.values[sym])
        elseif :Atomic in prop
            if com.agent.platform == :CPU
                com.values[sym] = com.values[sym]
            else
                com.values[sym] = ARRAY[com.agent.platform](dtype[com.values[sym][]])
            end
        else
            error("Parameter type ",prop[2], " is not defined.")
        end

        if :Update in prop #Initialize update paremters
            sym2 = Meta.parse(string(sym)[1:end-4])

            com.values[sym] .= com.values[sym2]
        end
    end            

    #Add limit of agents
    com.nMax_ .= com.N .+ addAgents

    setfield!(com,:loaded,true)

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

"""
Structure that basically stores an array of Coomunities at different time points.

# Elements

 - **com** (Array{Community}) Array where the communities are stored

# Constructors

    function CommunityInTime()

Instantiates an empty CommunityInTime folder.

# Base extended methods

    function Base.push!(com::CommunityInTime,c::Community)

Adds one Community element to the CommunityInTime object.

    function Base.length(com::CommunityInTime)

Returns the number of time points of the Community in time.

    function Base.getindex(com::CommunityInTime,var::Int)
    function Base.firstindex(com::CommunityInTime,var::Int)
    function Base.lastindex(com::CommunityInTime,var::Int)

Returns the Community of the corresponding entry.

    function Base.getindex(com::CommunityInTime,var::Symbol)

Returns a 2D array with rows being the agents and the rows the timepoints. If the agent did not existed for certain time point, the extry is filled with a NaN value.
"""
mutable struct CommunityInTime
    com::Array{Community,1}

    function CommunityInTime()
        
        return new(Community[])
    end
end

function Base.push!(comT::CommunityInTime,c::Community)
    
    push!(comtT.com,c)
    
    return
end

function Base.length(comT::CommunityInTime)
    
    return length(comtT.com)
end

function Base.getindex(comT::CommunityInTime,var::Int)
    
    return comtT.com[var]

end

Base.first(comT::CommunityInTime) = 1
Base.lastindex(comT::CommunityInTime) = length(comT)