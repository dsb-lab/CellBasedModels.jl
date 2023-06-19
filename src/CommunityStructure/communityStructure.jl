######################################################################################################
# Definition of structure
######################################################################################################
"""
Basic structure keeping the parameters of all the agents in the current simulation of a model.

Parameters to store information essential for Community simulation

|Symbol|Description|
|:---:|:---:|
|abm| ABM model of the community |
|uuid| Unique identifier of the community |
|loaded| If loaded into the platform CPU or GPU |
|pastTimes::Array{Community}| Store times when called to saveRAM! |
|parameters::OrderedDict{Symbol,AbstractArray}| Dictionary with the User Defined Parameters |
| agentDEProblem | ODEProblem or SDEProblem object of Agent |
| modelDEProblem | ODEProblem or SDEProblem object of Model |
| mediumDEProblem | ODEProblem or SDEProblem object of Medium |

Parameters seen in the kernels that may de used directly by the user

|Symbol|Description|
|:---:|:---:|
|t| Time of the community |
|dt| Stepping time of the community |
|N| Number of agents |
|NMedium| Size of medium mesh |
|simBox| Size of simulation box |
|dx| Size of the axis 1 in mesh medium |
|dy| Size of the axis 2 in mesh medium |
|dz| Size of the axis 3 in mesh medium |

Parameters seen in the kernels that are for internal use

|Symbol|Description|
|:---:|:---:|
|id| Identification of the agent |
|nMax_| Maximum number of agents when loading to platform |
|idMax_| Maximum id in the Community at all times |
|NAdd_| Number of added agents in the present step |
|NRemove_| Number of removed agents in the present step |
|NSurvive_| Number of agents survived in this step |
|flagSurvive_| 0 is agent survived this step, 1 if dead |
|holeFromRemoveAt_| Holes left from agents that are dead |
|repositionAgentInPos_| List the positions of the agents that have to be reubicated to empty spaces |
|flagRecomputeNeighbors_| 1 is neighbors have to be recomputed |

# Constructors

    function Community()

Creates fully empty community. Auxiliar method for the following method of declaration for the users.

    function Community(
        abm::ABM; 

        dt::Union{Nothing,AbstractFloat} = nothing,
        t::AbstractFloat = 0.,
        N::Int = 1,
        id::AbstractArray{Int} = 1:N,
        NMedium::Union{Nothing,Vector{<:Int}} = nothing,
        simBox::Union{Nothing,Matrix{<:Number}} = nothing,

        args...
    )

Function to construct a Community that accepts to provide integration algorithms, neighboring algorithms, the computing platform and setting parameters of the community.

For a more specific indication of the usage see the UserGuide.
"""
mutable struct Community

    abm
    uuid

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

    agentDEProblem
    modelDEProblem
    mediumDEProblem

    parameters::OrderedDict{Symbol,AbstractArray}

    loaded

    pastTimes::Array{Community}

    # Constructors
    function Community(
            abm::ABM; 

            dt::Union{Nothing,AbstractFloat} = nothing,
            t::AbstractFloat = 0.,
            N::Int = 1,
            id::AbstractArray{Int} = 1:N,
            NMedium::Union{Nothing,Vector{<:Int}} = nothing,
            simBox::Union{Nothing,Matrix{<:Number}} = nothing,

            args...
        )

        com = Community()
        setfield!(com,:abm,deepcopy(abm))

        #Check args compulsory to be declared in the community given the agent model
        setupBaseParameters!(com,dt,t,N,id,NMedium,simBox)

        #Creating the appropiate data arrays for parameters
        setupUserParameters!(com,args)

        setfield!(com,:loaded,false)
        setfield!(com,:uuid,uuid1())

        #Save global reference
        global COMUNITY = com

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
            nothing,
            nothing,
            nothing,
            nothing,
            OrderedDict{Symbol,AbstractArray}(),
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
    if !all(isemptyupdaterule(com.abm,rule) for rule in [:agentODE,:agentSDE,:mediumODE]) && dt === nothing
        error("dt key argument must be defined when models use differential equation rules.")
    elseif all([isemptyupdaterule(com.abm,rule) for rule in [:agentODE,:agentSDE,:modelODE,:modelSDE,:mediumODE,:mediumSDE]]) && dt === nothing
        setfield!(com,:dt, 1.)
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
    else
        setfield!(com,:NMedium,[0,0,0][1:com.abm.dims])
    end
    #simBox
    if ( length([i for (i,j) in pairs(com.abm.parameters) if j.scope == :medium]) > 0 && simBox === nothing ) ||
       ( typeof(com.abm.platform) in [CBMNeighbors.CLVD,CBMNeighbors.CellLinked] && simBox === nothing )
        error("simBox key argument must be defined when models with medium are declared.")
    elseif simBox !== nothing
        if size(simBox) != (com.abm.dims,2)
            error("simBox is expected to have shape ($(com.abm.dims),2)")
        else
            setfield!(com,:simBox,simBox)
        end
    else
        setfield!(com,:simBox,[0 1.;0 1;0 1][1:com.abm.dims,:])
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

    #dx dy dz and xₘ yₘ zₘ
    if com.abm.dims > 0 && com.simBox !== nothing && com.NMedium !== nothing && (:xₘ in keys(com.parameters))
        setfield!(com, :dx, (com.simBox[1,2] .- com.simBox[1,1])./com.NMedium[1])
        if com.abm.dims == 1
            com[:xₘ] = [com.dx*(i-.5)+com.simBox[1,1] for i = 1:com.NMedium[1]]
        elseif com.abm.dims == 2
            com[:xₘ] = [com.dx*(i-.5)+com.simBox[1,1] for i = 1:com.NMedium[1],  j = 1:com.NMedium[2]]
        elseif com.abm.dims == 3
            com[:xₘ] = [com.dx*(i-.5)+com.simBox[1,1] for i = 1:com.NMedium[1],  j = 1:com.NMedium[2],  k = 1:com.NMedium[3]]
        end
    else
        setfield!(com, :dx, 0.)
    end
    if com.abm.dims > 1 && com.simBox !== nothing && com.NMedium !== nothing && (:yₘ in keys(com.parameters))
        setfield!(com, :dy, (com.simBox[2,2] .- com.simBox[2,1])./com.NMedium[2])
        if com.abm.dims == 1
            com[:yₘ] = [com.dy*(j-.5)+com.simBox[2,1] for i = 1:com.NMedium[1]]
        elseif com.abm.dims == 2
            com[:yₘ] = [com.dy*(j-.5)+com.simBox[2,1] for i = 1:com.NMedium[1],  j = 1:com.NMedium[2]]
        elseif com.abm.dims == 3
            com[:yₘ] = [com.dy*(j-.5)+com.simBox[2,1] for i = 1:com.NMedium[1],  j = 1:com.NMedium[2],  k = 1:com.NMedium[3]]
        end
    else
        setfield!(com, :dy, 0.)
    end
    if com.abm.dims > 2 && com.simBox !== nothing && com.NMedium !== nothing && (:zₘ in keys(com.parameters))
        setfield!(com, :dz, (com.simBox[3,2] .- com.simBox[3,1])./com.NMedium[3])
        if com.abm.dims == 1
            com[:zₘ] = [com.dy*(k-.5)+com.simBox[3,1] for i = 1:com.NMedium[1]]
        elseif com.abm.dims == 2
            com[:zₘ] = [com.dy*(k-.5)+com.simBox[3,1] for i = 1:com.NMedium[1],  j = 1:com.NMedium[2]]
        elseif com.abm.dims == 3
            com[:zₘ] = [com.dy*(k-.5)+com.simBox[3,1] for i = 1:com.NMedium[1],  j = 1:com.NMedium[2],  k = 1:com.NMedium[3]]
        end
    else
        setfield!(com, :dz, 0.)
    end

    return
end

"""
    function cudaAdapt(code,platform)

Adapt specific CPU forms of calling parameters (e.g. Atomic) to CUDA valid code (Atomic -> size 1 CuArray).
"""
function cuAdapt(array,com)

    if typeof(com.abm.platform) <: GPU

        #Adapt atomic
        if typeof(array) <: Threads.Atomic
            return CUDA.ones(typeof(array).types[1],1).*array[]
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
        com = community.pastTimes[timePoint]
        setfield!(com,:loaded,false)
        setfield!(com.abm,:platform,community.abm.platform)
        setfield!(com.abm,:neighbors,community.abm.neighbors)
        setfield!(com.abm,:agentAlg,community.abm.agentAlg)
        setfield!(com.abm,:mediumAlg,community.abm.mediumAlg)
        setfield!(com.abm,:modelAlg,community.abm.modelAlg)
        setfield!(com.abm,:agentSolveArgs,community.abm.agentSolveArgs)
        setfield!(com.abm,:mediumSolveArgs,community.abm.mediumSolveArgs)
        setfield!(com.abm,:modelSolveArgs,community.abm.modelSolveArgs)
        return com
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
        if var in keys(com.abm.parameters)
            return [i[var] for i in com.pastTimes]
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

    return 

end

function createDEProblem(com,scope)

    vars = nothing
    if scope == :agent
        vars = cuAdapt(zeros(Float64,length([1 for (i,j) in pairs(com.abm.parameters) if j.variable && j.scope == :agent]),com.nMax_),com)
    elseif scope == :model
        vars = cuAdapt(zeros(Float64,length([1 for (i,j) in pairs(com.abm.parameters) if j.variable && j.scope == :model])),com)
    elseif scope == :medium
        CUDA.@allowscalar vars = cuAdapt(zeros(Float64,length([1 for (i,j) in pairs(com.abm.parameters) if j.variable && j.scope == :medium]),com.NMedium...),com)
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
    params = agentArgs(com.abm)
    paramsCom = agentArgs(com.abm,sym=:com)
    paramsRemove = [sym for (sym,prop) in pairs(com.abm.parameters) if prop.variable && (prop.scope==scope)]
    paramsRemove2 = [new(sym) for sym in paramsRemove if com.abm.parameters[sym].update] #remove news
    params = [if occursin("neighbors.", string(j)); getfield(com.abm.neighbors,i); elseif occursin("platform.", string(j)); getfield(com.abm.platform,i); elseif :platform == i; com.abm.platform; else com[i]; end for (i,j) in zip(params,paramsCom) if !(i in [paramsRemove;paramsRemove2])]

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
            )

        # Overwrite dt
        getfield(com.abm,arg)[:dt] = com.dt
        # Add default parameters
        for (i,j) in DEFAULTSOLVEROPTIONS
            if !(i in keys(getproperty(com.abm,arg)))
                getproperty(com.abm,arg)[i] = j
            end
        end

        return DifferentialEquations.init(problem, getproperty(com.abm,alg); getproperty(com.abm,arg)... )

    elseif !isemptyupdaterule(com.abm,ode)
        
        problem = ODEProblem(
            com.abm.declaredUpdatesFunction[ode], 
            vars, 
            (0,10.), 
            params
        )

        # Overwrite dt
        getfield(com.abm,arg)[:dt] = com.dt
        # Add default parameters
        for (i,j) in DEFAULTSOLVEROPTIONS
            if !(i in keys(getproperty(com.abm,arg)))
                getproperty(com.abm,arg)[i] = j
            end
        end

        return DifferentialEquations.init(problem, getproperty(com.abm,alg); getproperty(com.abm,arg)... )

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
        CBMNeighbors.initialize!(com.abm.neighbors,com)

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
        computeNeighbors!(com)

        platformSetup!(com.abm.platform,com)

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
    neig = com.abm.neighbors
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

    for (i,j) in pairs(SAVING)
        if j.uuid == com.uuid.value
            close(SAVING[i].file)
            delete!(SAVING,i)
        end
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