######################################################################################################
# Definition of structure
######################################################################################################
"""
Basic structure keeping the parameters of all the agents in the current simulation of a model.

# Elements for internal use
|Field|Description|
|:---|:---|
| agent | Agent model dealing with the rule of the model. |
| loaded | Check if the model has been loaded into platform or not. |
| platform | Platform of the model. |
| fileSaving | File name where Community is saved when invoking saving functions not in RAM. |
| pastTimes | Vector saving the data of past times of the model every time we call to save in RAM. |

# Elements passed and seen by all the *Evolution functions*

These parameters are defined with all the properties in the constant BASEPARAMETERS.

|Topic|Symbol|Description|
|---|---|---|
|**Time**|||
||t|Absolute time of evolution of the community.|
||dt|Time increments in each step of the evolution.|
|**Size Community**|||
||N|The number of agents active in the community.|
||NMedium|Size of the grid in which the medium is being computed. This is necessary to be declared if medium parameters are declared by the user.|
||nMax_|Maximum number of agents that can be present in the community.|
|**Id tracking**|||
||id|Unique identifier of the com.agent.|
||idMax_|Maximum identifier that has been declared in the community.|
|**Simulation space**|||
||simBox|Simulation box in which cells are moving. This is necessary to define a region of space in which a medium will be simulated or for computing neighbors with CellLinked methods.|
|**Agent addition or removal**|||
||NAdd_|Number of agents added in a step.|
||NRemove_|Number of agents removed in a step.|
||NSurvive_|Number of agents survived in a step.|
||flagSurvive_|Flag agents that survived.|
||holeFromRemoveAt_|Keeps position of cells that where removed during a step.|
||repositionAgentInPos_|Keeps position of cells starting from the end that have survived. It helps to reassign cells in the end of the array into the holes.|
|**Neighbors**|||
||skin|Distance below which a cell is considered a neighbor in Verlet neighbor algorithms.|
||dtNeighborRecompute|Time before recomputing neighborhoods in VerletTime algorithm.|
||nMaxNeighbors|Maximum number of neighbors. Necessary for Verlet-like algorithms.|
||cellEdge|Distance of the grid used to compute neighbors.|
||flagRecomputeNeighbors_|Marked as 1 if recomputation of neighbors has to be performed.|
||neighborN_|Number of neighbors for each com.agent. Used in Verlet-like algorithms.|
||neighborList_|Matrix containing the neighbors of each com.Agent. Used in Verlet-like algorithms.|
||neighborTimeLastRecompute_|Time storing the information of last neighbor recomputation. Used in Verlet time algorithm.|
||posOld_|Stores the position of each agent in the last VerletDistance neighbor computation.|
||accumulatedDistance_|Stores the accumulated displaced distance of each agent in the last VerletDistance neighbor computation.|
||nCells_|Number of cells in each dimensions of the grid. Used in CellLinked algorithms.|
||cellAssignedToAgent_|Cell assigned to each com.agent. Used in CellLinked algorithms.|
||cellNumAgents_|Number of agents assigned to each cell. Used in CellLinked algorithms.|
||cellCumSum_|Cumulative number of agents in the cell list. Used in CellLinked algorithms.|
|**Position**|||
||x|Position of the agent in the x axis.|
||y|Position of the agent in the y axis.|
||z|Position of the agent in the z axis.|
||xNew_|Position of the agent in the x axis if updated during a step.|
||yNew_|Position of the agent in the y axis if updated during a step.|
||zNew_|Position of the agent in the z axis if updated during a step.|
|**User declared parameters**|||
||liNM_|Matrix storing user-defined Local Integer parameters that are not modifiable.|
||liM_|Matrix storing user-defined Local Integer parameters that are modifiable.|
||liMNew_|Matrix storing user-defined Local Integer parameters that are modifiable after a step.|
||lii_|Matrix storing user-defined Local Integer parameters that are reset to zero after every step.|
||lfNM_|Matrix storing user-defined Local Float parameters that are not modifiable.|
||lfM_|Matrix storing user-defined Local Float parameters that are not modifiable.|
||lfMNew_|Matrix storing user-defined Local Float parameters that are not modifiable after a step.|
||lfi_|Matrix storing user-defined Local Float parameters that are reset to zero after every step.|
||gfNM_|Matrix storing user-defined Global Integer parameters that are not modifiable.|
||gfM_|Matrix storing user-defined Global Integer parameters that are not modifiable.|
||gfMNew_|Matrix storing user-defined Global Integer parameters that are not modifiable after a step.|
||gfi_|Matrix storing user-defined Global Integer parameters that are reset to zero after every step.|
||giNM_|Matrix storing user-defined Global Integer parameters that are not modifiable.|
||giM_|Matrix storing user-defined Global Integer parameters that are not modifiable.|
||giMNew_|Matrix storing user-defined Global Integer parameters that are not modifiable after a step.|
||gii_|Matrix storing user-defined Global Integer parameters that are reset to zero after every step.|
||mediumNM_|Matrix storing user-defined Medium (Float) parameters that are not modifiable.|
||mediumM_|Matrix storing user-defined Medium (Float) parameters that are not modifiable.|
||mediumMNew_|Matrix storing user-defined Medium (Float) parameters that are not modifiable after a step.| 

**Constructors**

    function Community(abm::Agent; args...)

Function to construct a Community with a predefined number of agents and medium grid.

|| Argument | Description |
|:---|:---|
|Args| abm::Agent | Agent Based Model that defines the parameters of the agents. |
|KwArgs| args... | Keys to define any of the other elements that will be visible by evolution functions (e.g. simBox, N...)

**Accessing and Modifying the Community**

All user defined parameters and base parameters are that are not protected can be accessed by indexing or property.
The same parameters are assigned by broadcasting. 

Accessible Base Parameters:
[:t,:dt,:simBox,:skin,:dtNeighborRecompute,:nMaxNeighbors,:cellEdge,:x,:y,:z]

```julia
model = Agent(1) #Defining a very basic agent with no rules.
com = Community(model, N = [10]) #Constructing a community with 10 agents.
com[:x]         #indexing
com.x           #property
com[:x] = 1:10  #equivalent to .= for Community
com.x   = 1:10  #property
```

> **CONSTANT PARAMETERS**: Notice that constant parmaeters are Arrays of size (1,) (notice the example above when defining the number of agents N).

> **ACCESSING AND MODIFYING PROTECTED FIELDS.** 
> Protected fields of a Community structure can be accessed calling to `getfield`. However, these are rotected to prevent unexpected behavior in the evolution of the code. Use with caution and avoid modifying them.

**Accessing old times**
If some times have been saven in RAM using a function like `saveRAM!` or when loading from a file, you can access those times by indexing and the position of the time.

```julia
length(com) #Number of saved times in Community
com[10] #Return the community saved at position 10.
```

**Accessing specific parameters at all times**
If you just want to access specific parameters for all times, It is way more efficcient to call the function `getParameter`.

```julia
getParameter(com,:x) #Return the position :x of all agents at all stored times.
getParameter(com,[:dt,:x]) #Return the parameters dt and x of all agents at all stored times.
```
"""
mutable struct Community

    agent
    loaded
    threads_
    blocks_
    fileSaving
    pastTimes

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
    meshLateralSize_

    parameters::OrderedDict{Symbol,AbstractArray}
    parametersUpdated::OrderedDict{Symbol,AbstractArray}
    vars::AbstractArray
    varsMedium::AbstractArray

    deProblem
    deProblemMedium

    # Constructors
    function Community(agent::Agent; args...)

        #Check args compulsory to be declared in the community given the agent model
        for (sym,prop) in pairs(BASEPARAMETERS)
            for i in prop.necessaryFor
                if i == agent.neighbors && !(sym in keys(args))
                    error("Parameter $sym has to be declared in the community for neighborhood style $i.")
                elseif i == :Medium && length(getSymbolsThat(agent.parameters,:scope,:medium)) > 0 && !(sym in keys(args))
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

        #Creating the appropiate data arrays for parameters
        parameters = OrderedDict{Symbol,Array}()
        parametersUpdated = OrderedDict{Symbol,Array}()
        for (sym,struc) in pairs(agent.parameters)
            if struc.scope == :agent
                parameters[sym] = zeros(struc.dtype,dict[:N][1])
                if struc.update
                    parametersUpdated[sym] = zeros(struc.dtype,dict[:N][1])
                end
            elseif struc.scope == :model
                parameters[sym] = zeros(struc.dtype,1)
                if struc.update
                    parametersUpdated[sym] = zeros(struc.dtype,1)
                end
            else
                parameters[sym] = zeros(struc.dtype,dict[:NMedium]...)
                if struc.update
                    parametersUpdated[sym] = zeros(struc.dtype,dict[:NMedium]...)
                end
            end
        end
    
        com = new(agent, false, 256, 1, nothing, Community[], [j for (i,j) in pairs(dict)]...,parameters,parametersUpdated,zeros(0),zeros(0),nothing,nothing)

        #Set GPU threads and blocks
        setGPUParameters!(com)

        for sym in keys(args)
            if sym in keys(com.agent.parameters)
                setproperty!(com,sym,args[sym])
            end
        end

        return com

    end

    function Community()

        #Creating the appropiate data matrices for the different parameters
        dict = OrderedDict()
        for (sym,prop) in pairs(BASEPARAMETERS)
            dict[sym] = nothing
        end
    
        return new(nothing, nothing, nothing, nothing,Community[], [j for (i,j) in pairs(dict)]...,nothing,nothing,nothing,nothing,nothing)

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

        for (i,sym) in enumerate(POSITIONPARAMETERS[1:1:community.com.agent.dims])
            if !community.com.agent.posUpdated_[i]
                p = getfield(community,sym)
                setfield!(com,sym,p)
            end
        end
    end

    #Assign agent
    com.agent = community.agent
    setfield!(com,:loaded,community.loaded)
    com.platform = community.platform
    com.fileSaving = nothing

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
        if var in keys(com.agent.parameters)
            return com.parameters[var]
        else
            error("Parameter ", var, " not found in the community.")
        end
    end

end

function Base.getindex(com::Community,var::Symbol)
    
    getproperty(com,var)

end

function Base.setproperty!(com::Community,var::Symbol,v)

    if !(var in keys(com.agent.parameters)) && !(var in fieldnames(Community))
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
        com.parameters[var] .= v
    end

end

function Base.setindex!(com::Community,v,var::Symbol)
    
    setproperty!(com,var,v)

end

function Base.length(com::Community)
    return length(com.pastTimes)
end

######################################################################################################
# Functions to get parameters at all times
######################################################################################################
"""
    function getParameter(com,var)
    function getParameter(com,varList::Vector)

Funtion that gets all the parameter(s) at all times of a community. If a single parameter, returns the vector of the parameter at each time, If several parameters are asked, returns a dictionary with each parameter symbol as key.
"""
function getParameter(com,var)
    if var in fieldnames(Community)
        return [getfield(i,var) for i in com.pastTimes]
    else
        if var in keys(com.agent.declaredSymbols)
            x = com.agent.declaredSymbols[var].basePar
            pos = com.agent.declaredSymbols[var].position
            scope = com.agent.declaredSymbols[var].scope
            if x in NOTMODIFIABLEPARAMETERS
                return getfield(com,x)[:,pos]
            else
                if scope == :Local
                    return [@views getfield(i,x)[:,pos] for i in com.pastTimes]
                elseif scope == :Global
                    return [@views getfield(i,x)[pos:pos] for i in com.pastTimes]
                elseif scope == :Medium
                    if com.agent.dims == 1
                        return [@views getfield(i,x)[:,pos] for i in com.pastTimes]
                    elseif com.agent.dims == 2
                        return [@views getfield(i,x)[:,:,pos] for i in com.pastTimes]
                    elseif com.agent.dims == 3
                        return [@views getfield(i,x)[:,:,:,pos] for i in com.pastTimes]
                    end
                end
            end
        else
            error("Parameter ", var, " not found in the community.")
        end
    end
end

function getParameter(com,varList::Vector)
    d = Dict{Symbol,Vector}()
    for i in varList
        d[i] = getParameter(com,i)
    end

    return d
end

######################################################################################################
# Load to platform
######################################################################################################
"""
    function loadToPlatform!(com::Community;preallocateAgents::Int=0)

Function that converts the Community data into the appropiate format to be executed in the corresponding platform.
It locks the possibility of accessing and manipulating the data by indexing and propety.
If `preallocateAgents` is provided, it allocates that additional number of agents to the community. 
Preallocating is necesssary as if more agents will be added during the evolution of the model (Going over the number of preallocated agents will run into an error.).
"""
function loadToPlatform!(com::Community;preallocateAgents::Int=0)

    #Add preallocated agents to maximum
    N = com.N[1]
    nCells_ = copy(com.nCells_)
    dt = com.dt[1]
    setfield!(com, :nMax_, com.N .+ preallocateAgents)

    #Start with the new parameters equal to the old positions, just in case
    for i in keys(com.parametersUpdated)
        com.parametersUpdated[i] .= com.parameters[i]
    end

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
            else
                setfield!(com,sym,ARRAY[platform]{DTYPE[prop.dtype][platform]}(getproperty(com,sym)))
            end
        else
            setfield!(com,sym,ARRAY[platform]{DTYPE[prop.dtype][platform]}(getproperty(com,sym)))
        end

    end            

    for (sym,prop) in pairs(com.agent.parameters)
        p = getproperty(com,sym)
        if prop.scope == :agent
            com.parameters[sym] = Array{prop.dtype}([p;zeros(prop.dtype,preallocateAgents)])
            if prop.update
                com.parametersUpdated[sym] = Array{prop.dtype}([p;zeros(prop.dtype,preallocateAgents)])
            end
        elseif prop.scope in [:model,:medium]
            com.parameters[sym] = Array{prop.dtype}(p)
            if prop.update
                com.parametersUpdated[sym] = Array{prop.dtype}(p)
            end
        end
    end

    # Transform to the correct platform the parameters
    agent = com.agent
    vars = zeros(Float64,length([1 for (i,j) in pairs(com.agent.parameters) if j.variable]),N)
    varsMedium = zeros(Float64,length([1 for (i,j) in pairs(com.agent.parameters) if j.variableMedium]),nCells_...)

    for (sym,struc) in pairs(com.agent.parameters)
        if struc.scope == :agent && struc.variable
            if struc.variable
                vars[struc.pos,:] .= com.parameters[sym]
            end
        end
    end

    #Transform to the correct platform
    if platform == :GPU
        setfield!(com,:vars, cu(com.vars))
        setfield!(com,:varsMedium, cu(com.varsMedium))
        for sym in keys(com.parameters)
            com.parameters[sym] = cu(com.parameters[sym])
        end
        for sym in keys(com.parametersUpdated)
            com.parametersUpdated[sym] = cu(com.parametersUpdated[sym])
        end
        vars = cu(vars)
        varsMedium = cu(varsMedium)
    end

    params = agentArgs(agent)
    paramsRemove = Tuple([sym for (sym,prop) in pairs(agent.parameters) if (prop.variable)])
    params = Tuple([com[i] for i in params if !(i in paramsRemove)])

    if isemptyupdaterule(agent,:UpdateVariableStochastic)

        problem = SDEProblem(
                com.agent.declaredUpdatesFunction[:IntegratorODE], 
                com.agent.declaredUpdatesFunction[:IntegratorSDE], 
                vars, 
                (0,10.), 
                params,
                dt=0.1
            )
        setfield!(com,:deProblem, DifferentialEquations.init( problem, com.agent.solveAlgorithm, dt=dt, save_everystep=false, dense = false, saveat = false ) )

    elseif isemptyupdaterule(agent,:UpdateVariableDeterministic)
        
        problem = ODEProblem(
            com.agent.declaredUpdatesFunction[:IntegratorODE], 
            vars, 
            (0,10.), 
            params
        )
        setfield!(com,:deProblem, DifferentialEquations.init( problem, com.agent.solveAlgorithm, dt=dt, save_everystep=false, dense = false, saveat = false ) )

    end

    params = agentArgs(agent)
    paramsRemove = Tuple([sym for (sym,prop) in pairs(agent.parameters) if (prop.variableMedium)])
    params = Tuple([i for i in params if !(i in paramsRemove)])

    if isemptyupdaterule(agent,:UpdateVariableMedium)

        problem = SDEProblem(
                com.agent.declaredUpdatesFunction[:IntegratorODE], 
                com.agent.declaredUpdatesFunction[:IntegratorSDE], 
                vars, 
                (0,10.), 
                params
            )
        setfield!(com,:deProblemMedium, DifferentialEquations.init(problem, com.agent.solveAlgorithm, dt=CUDA.@allowscalar(com.t[1])))

    end

    linkVariables(com)

    #Set loaded to true
    setfield!(com,:loaded,true)

    #Compute neighbors and interactions for the first time
    # computeNeighbors!(com)

    if typeof(com.fileSaving) <: String
        com.fileSaving = jldopen(com.fileSaving, "a+")
    end

    return
end

"""
    function bringFromPlatform!(com::Community)

Return the Community object from the platform where it is being evolved. 
It locks the possibility of accessing and manipulating the data by indexing and propety.
"""
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

    # Transform to the correct platform the parameters
    for (sym,prop) in pairs(com.agent.parameters)
        p = com.parameters[sym]
        if prop.scope == :agent
            com.parameters[sym] = Array{prop.dtype}(p[1:N])
            if prop.update
                com.parametersUpdated[sym] = Array{prop.dtype}(p[1:N])
            end
        elseif prop.scope in [:model,:medium]
            com.parameters[sym] = Array{prop.dtype}(p)
            if prop.update
                com.parametersUpdated[sym] = Array{prop.dtype}(p)
            end
        end
    end

    CUDA.@allowscalar setfield!(com, :vars, zeros(Float64,0))
    CUDA.@allowscalar setfield!(com, :varsMedium, zeros(Float64,0))    

    setfield!(com, :nMax_, com.N)

    #Set loaded to false
    setfield!(com,:loaded,false)

    if typeof(com.fileSaving) <: JLD2.JLDFile
        close(com.fileSaving)
        com.fileSaving = com.fileSaving.path
    end

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

function linkVariables(com::Community)

    for (sym,struc) in pairs(com.agent.parameters)
        if struc.scope == :agent && struc.variable
            if struc.variable
                com.deProblem.u[struc.pos,:] .= com.parameters[sym]
                @views com.parameters[sym] = com.deProblem.u[struc.pos,:]
            end
        elseif struc.scope == :model
            nothing
        else
            if struc.variableMedium
                if com.agent.dims == 1
                    com.varsMedium[struc.pos,:] .= com.parameters[sym]
                    @views com.parameters[sym] = com.varsMedium[struc.pos,:]
                elseif com.agent.dims == 2
                    com.varsMedium[struc.pos,:,:] .= com.parameters[sym]
                    @views com.parameters[sym] = com.varsMedium[struc.pos,:,:]
                else
                    com.varsMedium[struc.pos,:,:,:] .= com.parameters[sym]
                    @views com.parameters[sym] = com.varsMedium[struc.pos,:,:,:]
                end
            end
        end
    end

end