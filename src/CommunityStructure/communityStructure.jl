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

    parameters::OrderedDict{Symbol,AbstractArray}

    neighbors

    platform

    agentDEProblem
    agentAlg
    agentSolveArgs
    modelDEProblem
    modelAlg
    modelSolveArgs
    mediumDEProblem
    mediumAlg
    mediumSolveArgs

    loaded
    fileSaving

    pastTimes::Array{Community}

    # Constructors
    function Community(
            abm::ABM; 

            dt::Union{Nothing,AbstractFloat} = nothing,
            t::AbstractFloat = 0.,
            N::Int = 1,
            id::AbstractArray{Int} = 1:N,
            fileSaving = nothing,
            NMedium::Union{Nothing,Vector{<:Int}} = nothing,
            simBox::Union{Nothing,Matrix{<:Number}} = nothing,

            agentAlg::Union{CustomAlgorithm,DEAlgorithm} = CustomEuler(),
            agentSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),

            modelAlg::DEAlgorithm = Euler(),
            modelSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),

            mediumAlg::DEAlgorithm = Tsit5(),
            mediumSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),

            neighborsAlg::Neighbors = Full(),       
            platform::Platform = CPU(),     
            args...
        )

        com = Community()
        setfield!(com,:abm,deepcopy(abm))

        #Check args compulsory to be declared in the community given the agent model
        setupBaseParameters!(com,dt,t,N,id,NMedium,simBox)

        #Creating the appropiate data arrays for parameters
        setupUserParameters!(com,args)

        #Assign other key arguments
        setfield!(com,:neighbors,neighborsAlg)
        setfield!(com,:platform,platform)
        setfield!(com,:agentAlg,agentAlg)
        setfield!(com,:agentSolveArgs,agentSolveArgs)
        setfield!(com,:modelAlg,modelAlg)
        setfield!(com,:modelSolveArgs,modelSolveArgs)
        setfield!(com,:mediumAlg,mediumAlg)
        setfield!(com,:mediumSolveArgs,mediumSolveArgs)
        setfield!(com,:fileSaving,fileSaving)
        setfield!(com,:loaded,false)

        #Make compiled functions
        for (scope,type) in zip(
            [:agent,:agent,:model,:model,:medium,:medium],
            [:ODE,:SDE,:ODE,:SDE,:ODE,:SDE]
        )
            functionDE(com,scope,type)
        end
        for scope in [:agent,:model,:medium]
            functionRule(com,scope)
        end

        #Save global reference
        global COMUNITY = com

        return com

    end

    function Community()
    
        return new(
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            OrderedDict{Symbol,AbstractArray}(),
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            Community[],            
            )

    end

end

"""
Function to setup the base parameters (t,dt,simBox...) of the Community object.
"""
function setupBaseParameters!(com,dt,t,N,id,NMedium,simBox)
    #dt
    if !all(!isemptyupdaterule(com.abm,rule) for rule in [:agentODE,:agentSDE,:mediumODE]) && dt === nothing
        error("dt key argument must be defined when models use differential equation rules.")
    elseif all([!isemptyupdaterule(com.abm,rule) for rule in [:agentODE,:agentSDE,:modelODE,:modelSDE,:mediumODE,:mediumSDE]]) && dt === nothing
        setfield!(com,:dt, 1)
    else
        setfield!(com,:dt,dt)
    end
    #t
    setfield!(com,:t,t)
    #N
    setfield!(com,:N,Int(N))
    #id
    if length(id) != N
        error("id has to be a Int Array of the same length as the number of agents N.")
    else
        setfield!(com,:id,id)
    end
    #NMedium
    if length([i for (i,j) in pairs(com.abm.parameters) if j.scope == :medium]) > 0 && NMedium === nothing
        error("NMedium key argument must be defined when models with medium are declared.")
    elseif NMedium !== nothing
        if length(NMedium) != com.abm.dims
            error("NMedium is expected to be a vector of length $(com.abm.dims)")
        else
            setfield!(com,:NMedium,NMedium)
        end
    end
    #simBox
    if length([i for (i,j) in pairs(com.abm.parameters) if j.scope == :medium]) > 0 && simBox === nothing
        error("simBox key argument must be defined when models with medium are declared.")
    elseif simBox !== nothing
        if size(simBox) != (com.abm.dims,2)
            error("simBox is expected to have shape ($(com.abm.dims),2)")
        else
            setfield!(com,:simBox,simBox)
        end
    end
end

"""
Function that initializes the user parameters in the Community and assigns the arguments if initialized inside Community args.
"""
function setupUserParameters!(com,args)
    #Create dictionary
    parameters = OrderedDict{Symbol,AbstractArray}()
    #Go over parameters
    for (sym,struc) in pairs(com.abm.parameters)
        if struc.scope == :agent
            parameters[sym] = zeros(struc.dtype,com.N)
        elseif struc.scope == :model
            if struc.dtype <: Number
                parameters[sym] = zeros(struc.dtype,1)
            elseif !(sym in keys(args))
                parameters[sym] = zeros(1)
            else #Initialize as an array
                parameters[sym] = copy(args[sym])
            end
        elseif struc.scope == :medium
            parameters[sym] = zeros(struc.dtype,com.NMedium...)
        end
        #Initialize the parameters that have been declared
        if sym in keys(args)
            try
                parameters[sym] .= args[sym]
            catch
                error("Provided initialization for parameter $sym is incorrect. Expected type $(com.abm.parameters[sym].dtype) and size $(size(params[sym])); got size $(size(args[sym])).")
            end
        end
    end

    setfield!(com,:parameters,parameters)

    return
end

"""
    function cudaAdapt(code,platform)

Adapt specific CPU forms of calling parameters (e.g. Atomic) to CUDA valid code (Atomic -> size 1 CuArray).
"""
function cuAdapt(array,com)

    if typeof(com.platform) <: GPU

        #Adapt atomic
        if typeof(array) <: Threads.Atomic
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
    if com.N === nothing
        println("Empty Community.")
    else
        println("Community with ", com.N, " agents.")
    end
end

# Overload ways of calling and assigning the parameters in community
function Base.getindex(community::Community,timePoint::Number)
    
    com = Community()

    #Assign base parameters
    if 1 > timePoint || timePoint > length(community.pastTimes)
        error("Only time points from 1 to $(length(community.pastTimes)) present in the Community.")
    else
        return com = community.pastTimes[timePoint]
    end

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

    if var in fieldnames(Community)
        error("$var is a field of Community. In general you shouldn't touch them as you can break the behavior of the simulations, if you really need to do it, use setfield! instead.")
    elseif !(var in keys(com.parameters))
        error(var," is not in community.")
    else
        if com.abm.parameters[old(var)].scope != :model
            com.parameters[var] .= v
        elseif com.abm.parameters[old(var)].scope == :model
            if typeof(v) <: Number
                com.parameters[var] .= v
            elseif !(typeof(v) <: Number) && com.abm.parameters[old(var)].variable
                error("Model parameter is described with a differential equation. Only scalar parameters can be described with differential equations. Trying to assing a non-scalar.")
            else
                com.parameters[var] = copy(v)
            end
        end
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
function loadBaseParameters!(com::Community,preallocateAgents::Int)

    setfield!(com, :id, cuAdapt([com.id;zeros(preallocateAgents)],com))
    setfield!(com, :NMedium, cuAdapt(com.NMedium,com))
    setfield!(com, :simBox, cuAdapt(com.simBox,com))
    setfield!(com, :nMax_, com.N + preallocateAgents)
    setfield!(com, :idMax_, cuAdapt(Threads.Atomic{Int64}(com.N),com))
    setfield!(com, :NAdd_, cuAdapt(Threads.Atomic{Int64}(0),com))
    setfield!(com, :NRemove_, cuAdapt(Threads.Atomic{Int64}(0),com))
    setfield!(com, :NSurvive_, cuAdapt(Threads.Atomic{Int64}(0),com))
    setfield!(com, :flagSurvive_, cuAdapt(if com.abm.removalOfAgents_; ones(Int64,com.nMax_); else ones(Int64,0); end,com))
    setfield!(com, :holeFromRemoveAt_, cuAdapt(if com.abm.removalOfAgents_; zeros(Int64,com.nMax_); else zeros(Int64,0); end,com))
    setfield!(com, :repositionAgentInPos_, cuAdapt(if com.abm.removalOfAgents_; zeros(Int64,com.nMax_); else zeros(Int64,0); end,com))
    setfield!(com, :flagRecomputeNeighbors_, cuAdapt([1],com))
    if com.abm.dims > 0
        setfield!(com, :dx, (com.simBox[1,2] .- com.simBox[1,1])./com.NMedium[1])
    else
        setfield!(com, :dx, 0.)
    end
    if com.abm.dims > 1
        setfield!(com, :dy, (com.simBox[2,2] .- com.simBox[2,1])./com.NMedium[2])
    else
        setfield!(com, :dy, 0.)
    end
    if com.abm.dims > 2
        setfield!(com, :dz, (com.simBox[3,2] .- com.simBox[3,1])./com.NMedium[3])
    else
        setfield!(com, :dz, 0.)
    end

    return 

end

function createDEProblem(com,scope)

    vars = nothing
    if scope == :agent
        vars = cuAdapt(zeros(Float64,length([1 for (i,j) in pairs(com.abm.parameters) if j.variable && j.scope == :agent]),com.nMax_),com)
    elseif scope == :model
        vars = cuAdapt(zeros(Float64,length([1 for (i,j) in pairs(com.abm.parameters) if j.variable && j.scope == :model])),com)
    elseif scope == :medium
        vars = cuAdapt(zeros(Float64,length([1 for (i,j) in pairs(com.abm.parameters) if j.variable && j.scope == :medium]),com.NMedium...),com)
    end

    for (sym,struc) in pairs(com.abm.parameters)
        if scope == :agent && struc.variable && struc.scope == :agent
            vars[struc.pos,:] .= com.parameters[sym]
        elseif scope == :model && struc.variable && struc.scope == :model
            vars[struc.pos:struc.pos] .= com.parameters[sym]
        elseif scope == :medium && struc.variable && struc.scope == :medium
            if com.abm.dims == 1
                vars[struc.pos,:] .= com.parameters[sym]
            elseif com.abm.dims == 2
                vars[struc.pos,:,:] .= com.parameters[sym]
            elseif com.abm.dims == 3
                vars[struc.pos,:,:,:] .= com.parameters[sym]
            end
        end
    end

    #Assign differential models
    params = agentArgs(com)
    paramsCom = agentArgs(com,sym=:com)
    paramsRemove = Tuple([sym for (sym,prop) in pairs(com.abm.parameters) if prop.variable && (prop.scope==scope)])
    params = Tuple([if occursin("neighbors.", string(j)); getfield(com.neighbors,i); elseif occursin("platform.", string(j)); getfield(com.platform,i); else com[i]; end for (i,j) in zip(params,paramsCom) if !(i in paramsRemove)])

    ode = addSymbol(scope,"ODE")
    sde = addSymbol(scope,"SDE")
    alg = addSymbol(scope,"Alg")
    arg = addSymbol(scope,"SolveArgs")

    if !isemptyupdaterule(com.abm,sde)

        problem = SDEProblem(
                com.abm.declaredUpdatesFunction[ode], 
                com.abm.declaredUpdatesFunction[sde], 
                vars, 
                (0,10.), 
                params,
                # dt=dt
            )

        # Overwrite dt
        getfield(com,arg)[:dt] = com.dt
        # Add default parameters
        for (i,j) in DEFAULTSOLVEROPTIONS
            if !(i in keys(getproperty(com,arg)))
                getproperty(com,arg)[i] = j
            end
        end

        return DifferentialEquations.init( problem, getproperty(com,alg); getproperty(com,arg)... )

    elseif !isemptyupdaterule(com.abm,ode)
        
        problem = ODEProblem(
            com.abm.declaredUpdatesFunction[ode], 
            vars, 
            (0,10.), 
            params
        )

        # Overwrite dt
        getfield(com,arg)[:dt] = com.dt
        # Add default parameters
        for (i,j) in DEFAULTSOLVEROPTIONS
            if !(i in keys(getproperty(com,arg)))
                getproperty(com,arg)[i] = j
            end
        end

        return DifferentialEquations.init(problem, getproperty(com,alg); getproperty(com,arg)... )

    end    

end

"""
    function loadToPlatform!(com::Community;preallocateAgents::Int=0)

Function that converts the Community data into the appropiate format to be executed in the corresponding platform.
It locks the possibility of accessing and manipulating the data by indexing and propety.
If `preallocateAgents` is provided, it allocates that additional number of agents to the community. 
Preallocating is necesssary as if more agents will be added during the evolution of the model (Going over the number of preallocated agents will run into an error.).
"""
function loadToPlatform!(com::Community;preallocateAgents::Int=0)

    if com.loaded
        println("WARNING: Community already loaded. Ignoring operation.")
    else
        #Add preallocated agents to maximum
        loadBaseParameters!(com,preallocateAgents)

        #Adapt user parameters
        for (sym,prop) in pairs(com.abm.parameters)
            p = getproperty(com,sym)
            if prop.scope == :agent
                com.parameters[sym] = cuAdapt(Array{prop.dtype}([p;zeros(prop.dtype,preallocateAgents)]),com)
            elseif prop.scope in [:model,:medium]
                if prop.dtype <: Number
                    com.parameters[sym] = cuAdapt(Array{prop.dtype}(p),com)
                else
                    com.parameters[sym] = cuAdapt((prop.dtype)(p),com)
                end
            end
            if prop.update && !prop.variable
                com.parameters[new(sym)] = copy(com.parameters[sym])
            elseif prop.variable
                com.parameters[new(sym)] = cuAdapt(zeros(0),com)
            end
        end

        #Neighbors
        initialize!(com.neighbors,com)

        # Transform to the correct platform the parameters
        setfield!(com,:agentDEProblem,createDEProblem(com,:agent))
        linkVariables(com,:agent)
        setfield!(com,:modelDEProblem,createDEProblem(com,:model))
        linkVariables(com,:model)
        setfield!(com,:mediumDEProblem,createDEProblem(com,:medium))
        linkVariables(com,:medium)

        #Set loaded to true
        setfield!(com,:loaded,true)

        #Compute neighbors and interactions for the first time
        # computeNeighbors!(com)

        if typeof(com.fileSaving) <: String
            com.fileSaving = jldopen(com.fileSaving, "a+")
        end
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
        #Remove auxiliar
        if prop.update
            delete!(com.parameters,new(sym))
        end
        if prop.scope == :agent
            com.parameters[sym] = Array{prop.dtype}(p)[1:N]
        elseif prop.scope in [:model,:medium]
            if prop.dtype <: Number
                com.parameters[sym] = Array{prop.dtype}(p)
            else
                com.parameters[sym] = prop.dtype(p)
            end
        end
    end

    for i in fieldnames(Community)
        if string(i)[end:end] == "_"
            setfield!(com,i,nothing)
        end
    end
    setfield!(com,:id, Array{Int64}(com.id)[1:N])
    neig = com.neighbors
    for i in fieldnames(typeof(neig))
        if string(i)[end:end] == "_"
            setfield!(neig,i, nothing)
        end
    end
    setfield!(com,:agentDEProblem, nothing)
    setfield!(com,:modelDEProblem, nothing)
    setfield!(com,:mediumDEProblem, nothing)

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

function linkVariables(com::Community,scope)

    var2 = addSymbol(scope,"DEProblem")

    for (sym,struc) in pairs(com.abm.parameters)
        if struc.scope == :agent && scope == :agent && struc.variable
            @views com.parameters[new(sym)] = getfield(com,var2).u[struc.pos,:]
        elseif struc.scope == :model && scope == :model && struc.variable
            @views com.parameters[new(sym)] = getfield(com,var2).u[struc.pos:struc.pos]
        elseif struc.scope == :medium && scope == :medium && struc.variable
            if com.abm.dims == 1
                @views com.parameters[new(sym)] = getfield(com,var2).u[struc.pos,:]
            elseif com.abm.dims == 2
                @views com.parameters[new(sym)] = getfield(com,var2).u[struc.pos,:,:]
            else
                @views com.parameters[new(sym)] = getfield(com,var2).u[struc.pos,:,:,:]
            end
        end
    end

end