######################################################################################################
# Definition of structure
######################################################################################################
"""
Basic structure keeping the parameters of all the agents in the current simulation of a model.

# Elements for internal use
|Field|Description|
|:---|:---|
| abm | ABM model dealing with the rule of the model. |
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
||id|Unique identifier of the com.abm.|
||idMax_|Maximum identifier that has been declared in the community.|
|**Simulation space**|||
||simBox|Simulation box in which cells are moving. This is necessary to define a region of space in which a medium will be simulated or for computing neighbors with CellLinked methods.|
|**ABM addition or removal**|||
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
||neighborN_|Number of neighbors for each com.abm. Used in Verlet-like algorithms.|
||neighborList_|Matrix containing the neighbors of each agent. Used in Verlet-like algorithms.|
||neighborTimeLastRecompute_|Time storing the information of last neighbor recomputation. Used in Verlet time algorithm.|
||posOld_|Stores the position of each agent in the last VerletDistance neighbor computation.|
||accumulatedDistance_|Stores the accumulated displaced distance of each agent in the last VerletDistance neighbor computation.|
||nCells_|Number of cells in each dimensions of the grid. Used in CellLinked algorithms.|
||cellAssignedToAgent_|Cell assigned to each com.abm. Used in CellLinked algorithms.|
||cellNumAgents_|Number of agents assigned to each cell. Used in CellLinked algorithms.|
||cellCumSum_|Cumulative number of agents in the cell list. Used in CellLinked algorithms.|

**Constructors**

    function Community(abm::ABM; args...)

Function to construct a Community with a predefined number of agents and medium grid.

|| Argument | Description |
|:---|:---|
|Args| abm::ABM | Agent Based Model that defines the parameters of the agents. |
|KwArgs| args... | Keys to define any of the other elements that will be visible by evolution functions (e.g. simBox, N...)

**Accessing and Modifying the Community**

All user defined parameters and base parameters are that are not protected can be accessed by indexing or property.
The same parameters are assigned by broadcasting. 

Accessible Base Parameters:
[:t,:dt,:simBox,:skin,:dtNeighborRecompute,:nMaxNeighbors,:cellEdge,:x,:y,:z]

```julia
model = ABM(1) #Defining a very basic agent with no rules.
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

    abm
    loaded
    fileSaving
    pastTimes

    t
    dt
    N
    NMedium
    simBox

    id

    nMax_
    idMax_
    NAdd_
    NRemove_
    NSurvive_
    flagSurvive_
    holeFromRemoveAt_
    repositionAgentInPos_
    flagRecomputeNeighbors_
    dx
    dy
    dz
    # flagNeighbors_

    # skin
    # dtNeighborRecompute
    # nMaxNeighbors
    # cellEdge
    # flagRecomputeNeighbors_
    # flagNeighbors_
    # neighborN_
    # neighborList_
    # neighborTimeLastRecompute_
    # posOld_
    # accumulatedDistance_
    # nCells_
    # cellAssignedToAgent_
    # cellNumAgents_
    # cellCumSum_

    parameters::OrderedDict{Symbol,AbstractArray}
    vars::AbstractArray
    varsMedium::AbstractArray

    neighbors

    platform

    deProblem
    agentAlg
    agentSolveArgs
    deProblemMedium
    mediumAlg
    mediumSolveArgs

    # Constructors
    function Community(
            abm::ABM; 
            dt,
            t = 0,
            N = 1,
            NMedium = nothing,
            simBox = nothing,
            agentAlg::Union{Symbol,DEAlgorithm} = :Euler,
            agentSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),
            mediumAlg::Union{Symbol,Any} = Euler(),
            mediumSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),
            neighborsAlg::Neighbors = Full(),       
            platform::Platform = CPU(),     
            args...
        )

        #Check args compulsory to be declared in the community given the agent model
        if length([i for (i,j) in pairs(abm.parameters) if j.scope == :medium]) > 0 && simBox === nothing
            error("simBox karguments must be defined when medium models are declared")
        end
        if length([i for (i,j) in pairs(abm.parameters) if j.scope == :medium]) > 0 && NMedium === nothing
            error("NMedium kargument must be defined when medium models are declared")
        end
        
        #Check algorithm
        if typeof(agentAlg) == Symbol
            if !(agentAlg in SOLVERS)
                error("solveAlgorithm $solveAlgorithm does not exist. Possible algorithms are: $(SOLVERS) or DifferentialEquations algorithms from ODE or SDE." )
            end
        end

        #Creating the appropiate data matrices for the different parameters
        dict = OrderedDict()
        for (sym,prop) in pairs(BASEPARAMETERS)
            if sym in keys(args)
                checkFormat(sym,args,prop,dict,abm)
                dict[sym] = args[sym]
            else
                dict[sym] = prop.initialize(dict,abm)
            end
        end

        #Creating the appropiate data arrays for parameters
        parameters = OrderedDict{Symbol,Array}()
        for (sym,struc) in pairs(abm.parameters)
            symUp = Meta.parse(string(sym,"__"))
            if struc.scope == :agent
                parameters[sym] = zeros(struc.dtype,N)
                if struc.update
                    parameters[symUp] = zeros(struc.dtype,N)
                end
            elseif struc.scope == :model
                parameters[sym] = zeros(struc.dtype,1)
                if struc.update
                    parameters[symUp] = zeros(struc.dtype,1)
                end
            else
                parameters[sym] = zeros(struc.dtype,NMedium...)
                if struc.update
                    parameters[symUp] = zeros(struc.dtype,NMedium...)
                end
            end
        end
    
        com = new(
            deepcopy(abm), 
            false, 
            nothing, 
            Community[], 
            t, 
            dt, 
            N, 
            NMedium, 
            simBox,
            1:N,
            [nothing for i in 1:12]...,
            parameters,
            zeros(0),
            zeros(0),
            neighborsAlg,
            platform,
            nothing,
            agentAlg,
            agentSolveArgs,
            nothing,
            mediumAlg,
            mediumSolveArgs)

        #Set GPU threads and blocks
        platformUpdate!(com.platform,com)

        for sym in keys(args)
            if sym in keys(com.abm.parameters)
                setproperty!(com,sym,args[sym])
            end
        end

        global COMUNITY = com

        #Make compiled functions
        agentRuleFunction(com)
        agentDEFunction(com)
        mediumDEFunction(com)

        return com

    end

    function Community()

        #Creating the appropiate data matrices for the different parameters
        dict = OrderedDict()
        for (sym,prop) in pairs(BASEPARAMETERS)
            dict[sym] = nothing
        end
    
        return new(nothing, nothing, nothing, nothing,Community[], [j for (i,j) in pairs(dict)]...,nothing,nothing,Full(),nothing,Euler(),Dict{Symbol,Any}(),nothing,Euler(),Dict{Symbol,Any}())

    end

end

"""
    function cudaAdapt(code,platform)

Adapt specific CPU forms of calling parameters (e.g. Atomic) to CUDA valid code (Atomic -> size 1 CuArray).
"""
function cuAdapt(array,com)

    if typeof(com.platform) <: GPU

        #Adapt atomic
        if typeof(array) <: Atomic
            return CUDA.ones(1).*array[]
        else
            return cu(array)
        end

    else
        return array
    end

    return code

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

        for (i,sym) in enumerate(POSITIONPARAMETERS[1:1:community.com.abm.dims])
            if !community.com.abm.posUpdated_[i]
                p = getfield(community,sym)
                setfield!(com,sym,p)
            end
        end
    end

    #Assign agent
    com.abm = community.abm
    setfield!(com,:loaded,community.loaded)
    com.platform = community.platform
    com.fileSaving = nothing

    #Initializing parameters that were nothing before
    dict = OrderedDict()
    for (sym,prop) in pairs(BASEPARAMETERS)
        if getfield(com,sym) === nothing
            setfield!(com,sym,prop.initialize(dict,com.abm))
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
        if var in keys(com.parameters)
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

    if !(var in keys(com.abm.parameters)) && !(var in fieldnames(Community))
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
        if var in keys(com.abm.declaredSymbols)
            x = com.abm.declaredSymbols[var].basePar
            pos = com.abm.declaredSymbols[var].position
            scope = com.abm.declaredSymbols[var].scope
            if x in NOTMODIFIABLEPARAMETERS
                return getfield(com,x)[:,pos]
            else
                if scope == :Local
                    return [@views getfield(i,x)[:,pos] for i in com.pastTimes]
                elseif scope == :Global
                    return [@views getfield(i,x)[pos:pos] for i in com.pastTimes]
                elseif scope == :Medium
                    if com.abm.dims == 1
                        return [@views getfield(i,x)[:,pos] for i in com.pastTimes]
                    elseif com.abm.dims == 2
                        return [@views getfield(i,x)[:,:,pos] for i in com.pastTimes]
                    elseif com.abm.dims == 3
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
function initializeAuxiliarParameters!(com::Community)

    setfield!(com, :id, cuAdapt([1:com.N;zeros(com.nMax_-com.N)],com))
    setfield!(com, :idMax_, cuAdapt(Threads.Atomic{Int64}(com.N),com))
    setfield!(com, :NAdd_, cuAdapt(Threads.Atomic{Int64}(0),com))
    setfield!(com, :NRemove_, cuAdapt(Threads.Atomic{Int64}(0),com))
    setfield!(com, :NSurvive_, cuAdapt(Threads.Atomic{Int64}(0),com))
    setfield!(com, :flagSurvive_, cuAdapt(if com.abm.removalOfAgents_; ones(Int64,com.nMax_); else ones(Int64,0); end,com))
    setfield!(com, :holeFromRemoveAt_, cuAdapt(if com.abm.removalOfAgents_; zeros(Int64,com.nMax_); else zeros(Int64,0); end,com))
    setfield!(com, :repositionAgentInPos_, cuAdapt(if com.abm.removalOfAgents_; zeros(Int64,com.nMax_); else zeros(Int64,0); end,com))
    setfield!(com, :flagRecomputeNeighbors_, cuAdapt([1],com))
    if com.abm.dims > 0
        setfield!(com, :dx, (com[:simBox][1,2] .- com[:simBox][1,1])./com.NMedium[1])
    end
    if com.abm.dims > 1
        setfield!(com, :dy, (com[:simBox][2,2] .- com[:simBox][2,1])./com.NMedium[2])
    end
    if com.abm.dims > 2
        setfield!(com, :dz, (com[:simBox][3,2] .- com[:simBox][3,1])./com.NMedium[3])
    end

    return 

end

"""
    function loadToPlatform!(com::Community;preallocateAgents::Int=0)

Function that converts the Community data into the appropiate format to be executed in the corresponding platform.
It locks the possibility of accessing and manipulating the data by indexing and propety.
If `preallocateAgents` is provided, it allocates that additional number of agents to the community. 
Preallocating is necesssary as if more agents will be added during the evolution of the model (Going over the number of preallocated agents will run into an error.).
"""
function loadToPlatform!(com::Community;preallocateAgents::Int=0)

    #Add preallocated agents to maximum
    N = com.N
    NMedium = copy(com.NMedium)
    dt = com.dt
    nMax = N + preallocateAgents
    setfield!(com, :nMax_, com.N + preallocateAgents)

    initializeAuxiliarParameters!(com)

    #Start with the new parameters equal to the old positions, just in case
    for (sym,prop) in pairs(com.abm.parameters)
        symNew = new(sym)
        if prop.update
            com.parameters[symNew] .= com.parameters[sym]
        end
    end

    for (sym,prop) in pairs(com.abm.parameters)
        p = getproperty(com,sym)
        if prop.scope == :agent
            com.parameters[sym] = Array{prop.dtype}([p;zeros(prop.dtype,preallocateAgents)])
            if prop.update
                com.parameters[new(sym)] = Array{prop.dtype}([p;zeros(prop.dtype,preallocateAgents)])
            end
        elseif prop.scope in [:model,:medium]
            com.parameters[sym] = Array{prop.dtype}(p)
            if prop.update
                com.parameters[new(sym)] = Array{prop.dtype}(p)
            end
        end
    end

    # Transform to the correct platform the parameters
    abm = com.abm
    vars = zeros(Float64,length([1 for (i,j) in pairs(com.abm.parameters) if j.variable]),nMax)
    varsMedium = zeros(Float64,length([1 for (i,j) in pairs(com.abm.parameters) if j.variableMedium]),NMedium...)

    for (sym,struc) in pairs(com.abm.parameters)
        if struc.scope == :agent && struc.variable
            vars[struc.pos,:] .= com.parameters[sym]
        elseif struc.scope == :medium && struc.variableMedium
            if com.abm.dims == 1
                varsMedium[struc.pos,:] .= com.parameters[sym]
            elseif com.abm.dims == 2
                varsMedium[struc.pos,:,:] .= com.parameters[sym]
            elseif com.abm.dims == 3
                varsMedium[struc.pos,:,:,:] .= com.parameters[sym]
            end
        end
    end

    #Transform to the correct platform
    if typeof(com.platform) <: GPU
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

    #Neighbors
    initialize!(com.neighbors,com)

    #Assign differential models
    params = agentArgs(com)
    paramsCom = agentArgs(com,sym=:com)
    paramsRemove = Tuple([sym for (sym,prop) in pairs(abm.parameters) if (prop.variable)])
    params = Tuple([if occursin("neighbors.", string(j)); getfield(com.neighbors,i); else com[i]; end for (i,j) in zip(params,paramsCom) if !(i in paramsRemove)])

    if isemptyupdaterule(abm,:agentSDE)

        problem = SDEProblem(
                com.abm.declaredUpdatesFunction[:agentODE], 
                com.abm.declaredUpdatesFunction[:agentSDE], 
                vars, 
                (0,10.), 
                params,
                dt=dt
            )

        # Overwrite dt
        com.agentSolveArgs[:dt] = dt
        # Add default parameters
        for (i,j) in DEFAULTSOLVEROPTIONS
            if !(i in keys(com.agentSolveArgs))
                com.agentSolveArgs[i] = j
            end
        end

        setfield!(com,:deProblem, DifferentialEquations.init( problem, com.agentAlg; com.agentSolveArgs... ) )

    elseif isemptyupdaterule(abm,:agentODE)
        
        problem = ODEProblem(
            com.abm.declaredUpdatesFunction[:agentODE], 
            vars, 
            (0,10.), 
            params
        )

        # Overwrite dt
        com.agentSolveArgs[:dt] = dt
        # Add default parameters
        for (i,j) in DEFAULTSOLVEROPTIONS
            if !(i in keys(com.agentSolveArgs))
                com.agentSolveArgs[i] = j
            end
        end

        setfield!(com,:deProblem, DifferentialEquations.init( problem, com.agentAlg; com.agentSolveArgs... ) )

    end

    params = agentArgs(com)
    paramsCom = agentArgs(com,sym=:com)
    paramsRemove = Tuple([sym for (sym,prop) in pairs(abm.parameters) if (prop.variableMedium)])
    params = Tuple([if occursin("neighbors.", string(j)); getfield(com.neighbors,i); else com[i]; end for (i,j) in zip(params,paramsCom) if !(i in paramsRemove)])

    if isemptyupdaterule(abm,:mediumODE)

        problem = ODEProblem(
                com.abm.declaredUpdatesFunction[:mediumODE], 
                varsMedium, 
                (0,10.), 
                params
            )

        # Overwrite dt
        com.mediumSolveArgs[:dt] = dt
        # Add default parameters
        for (i,j) in DEFAULTSOLVEROPTIONS
            if !(i in keys(com.mediumSolveArgs))
                com.mediumSolveArgs[i] = j
            end
        end

        setfield!(com,:deProblemMedium, DifferentialEquations.init(problem, com.mediumAlg; com.mediumSolveArgs... ))

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

    N = com.N
    # Transform to the correct platform the parameters
    for (sym,prop) in pairs(com.abm.parameters)
        p = com.parameters[sym]
        if prop.scope == :agent
            com.parameters[sym] = Array(p[1:N])
            if prop.update
                p = com.parameters[new(sym)]
                com.parameters[new(sym)] = Array(p[1:N])
            end
        elseif prop.scope in [:model,:medium]
            com.parameters[sym] = Array(p)
            if prop.update
                p = com.parameters[new(sym)]
                com.parameters[new(sym)] = Array(p)
            end
        end
    end

    # setfield!(com, :vars, zeros(Float64,0))
    # setfield!(com, :varsMedium, zeros(Float64,0))    

    # for i in fieldnames(Community)
    #     if string(i)[end:end] == "_"
    #         setfield!(com,i) = nothing
    #     end
    # end
    # neig = com.neighbors
    # for i in fieldnames(typeof(neig))
    #     if string(i)[end:end] == "_"
    #         setfield!(neig,i) = nothing
    #     end
    # end

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

    for (sym,struc) in pairs(com.abm.parameters)
        if struc.scope == :agent && struc.variable
            if struc.variable
                com.deProblem.u[struc.pos,:] .= com.parameters[sym]
                @views com.parameters[sym] = com.deProblem.u[struc.pos,:]
            end
        elseif struc.scope == :model
            nothing
        else
            if struc.variableMedium
                if com.abm.dims == 1
                    com.deProblemMedium.u[struc.pos,:] .= com.parameters[sym]
                    @views com.parameters[sym] = com.deProblemMedium.u[struc.pos,:]
                elseif com.abm.dims == 2
                    com.deProblemMedium.u[struc.pos,:,:] .= com.parameters[sym]
                    @views com.parameters[sym] = com.deProblemMedium.u[struc.pos,:,:]
                else
                    com.deProblemMedium.u[struc.pos,:,:,:] .= com.parameters[sym]
                    @views com.parameters[sym] = com.deProblemMedium.u[struc.pos,:,:,:]
                end
            end
        end
    end

end