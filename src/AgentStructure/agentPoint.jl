######################################################################################################
# AGENT STRUCTURE
######################################################################################################

"""
    struct AgentPoint

Object containing the parameters of an agent.

    Parameters
    ----------

|Field|Description|
|:---|:---|
| name::Symbol | Name of the agent. |
| dims::Int | Number of dimensions of the agent (0, 1, 2, or 3). |
| parameters::NamedTuple{Symbol, Parameter} | Named Tuple with name => Parameter. Parameter.name corresponds with key.|

    Constructors
    ------------

Agent(dims::Int; name::Symbol, idType::Type=Int, posType::Type=Float64, parameters::Union{
            OrderedDict{Symbol,DataType}, 
            Dict{Symbol,DataType}, 
            Vector{Parameter}, 
            NamedTuple, 
        }=Dict())

|Field|Description|
|:---|:---|
| dims::Int | Number of dimensions of the agent (0, 1, 2, or 3). |
| name::Symbol | Name of the agent. Default is :agent |
| idType::DataType | Type of the agent's unique identifier. Default is Int |
| posType::DataType | Type of the agent's position. Default is Float64 |
| parameters::NamedTuple{Symbol, Parameter} | Named Tuple with name => Parameter. Parameter.name corresponds with key.|

    Examples
    --------

```julia
    agent = Agent(3, name=:cell, parameters=(mass=Float64, alive=Bool)) # Using NamedTuple
    agent = Agent(3, name=:cell, parameters=OrderedDict(:mass => Float64, :alive => Bool)) # Using OrderedDict
    agent = Agent(3, name=:cell, parameters=Dict(:mass => Float64, :alive => Bool)) # Using Dict
    agent = Agent(3, name=:cell, 
                    parameters=[
                        Parameter(:mass, Float64, defaultValue=10.0),
                        Parameter(:alive, Bool, defaultValue=true)
                    ]) # Using Vector{Parameter}
```
"""
mutable struct AgentPoint{D::Int} <: AgentType

    agentProperties::NamedTuple    # Dictionary to hold agent properties

end

function AgentPoint(
    dims::Int;
    agentProperties::NamedTuple = (;)
)
    if dims < 0 || dims > 3
        error("dims must be between 0 and 3. Found $dims")
    end
    defaultParameters = (
        x = dims >= 1 ? Parameter(Float64, description="Position in x (protected parameter)", dimensions=:L) : nothing,
        y = dims >= 2 ? Parameter(Float64, description="Position in y (protected parameter)", dimensions=:L) : nothing,
        z = dims >= 3 ? Parameter(Float64, description="Position in z (protected parameter)", dimensions=:L) : nothing,
        id = Parameter(Int, description="Unique identifier (protected parameter)"),
    )
    # Remove keys with value `nothing`
    defaultParameters = NamedTuple{Tuple(k for (k,v) in pairs(defaultParameters) if v !== nothing)}(
        (v for (k,v) in pairs(defaultParameters) if v !== nothing)
    )
    agentPropertiesNew = parameter_convert(agentProperties)
    for (k, v) in pairs(agentPropertiesNew)
        if haskey(defaultParameters, k)
            error("Parameter $k is already defined and cannot be used as agent property.")
        end
    end
    agentPropertiesNew = merge(defaultParameters, agentPropertiesNew)
    return AgentPoint{dims}(
        agentPropertiesNew
    )
end

Base.length(x::AgentPoint) = 1

function Base.show(io::IO, x::AgentPoint)
    println(io, "AgentPoint with dimensions $(x._dims): \n")
    println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-s", "Name", "DataType", "Dimensions", "Default_Value", "Description"))
    println(io, "\t" * repeat("-", 85))
    for (name, par) in pairs(x.agentProperties)
        println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-s", 
            name, 
            string(par.dataType), 
            par.dimensions,
            par.defaultValue, 
            par.description))
    end
    println(io)
end

function setAgentDimensions!(agent::AgentPoint, dims::Int)

    agentProperties = agent.agentProperties

    for name in (:x, :y, :z, :id)
        if haskey(agentProperties, name)
            agentProperties = 
                Base.structdiff(agentProperties, NamedTuple{(name,)}((nothing,)))
        end
    end

    return AgentPoint(dims; agentProperties=agentProperties)

end

function addAgentProperty!(agent::AgentPoint, name::Symbol, parameter::Union{DataType, Parameter})

    if haskey(agent.agentProperties, name)
        error("Property $name already exists in agent $(agent.name).")
    end

    if typeof(parameter) <: DataType
        parameter = Parameter(parameter, description="No description")
    end

    if name in (:x, :y, :z, :id)
        error("Property $name is a default property and cannot be added.")
    end

    agent.agentProperties = merge(agent.agentProperties, NamedTuple{(name,)}((parameter,)))

    return nothing

end

function addAgentProperties!(agent::AgentPoint, properties)

    for (name, parameter) in pairs(properties)
        addAgentProperty!(agent, name, parameter)
    end

    return nothing

end

function removeAgentProperty!(agent::AgentPoint, name::Symbol)

    if !haskey(agent.agentProperties, name)
        error("Property $name does not exist in agent $(agent.name).")
    end

    if name in (:x, :y, :z, :id)
        error("Property $name is a default property and cannot be removed.")
    end

    agent.agentProperties =
        Base.structdiff(agent.agentProperties, NamedTuple{(name,)}((nothing,)))

    return nothing

end

function removeAgentProperties!(agent::AgentPoint, names)

    for name in names
        removeAgentProperty!(agent, name)
    end

    return nothing

end

######################################################################################################
# COMMUNITY STRUCTURE
######################################################################################################

mutable struct CommunityPoint{D::Int} <: CommunityType

    _agent::AgentPoint
    _N::Int
    _NMax::Int
    _NNew::Int
    _idMax::Int
    _NFlag::Bool

    agentProperties::NamedTuple    # Dictionary to hold agent properties

end

function CommunityPoint(
    agent::AgentPoint;
    N::Int,
    NMax::Union{Nothing, Int}=nothing,
    agentProperties = Dict{Symbol,AbstractArray{<:Any, 1}}(),
)
    N = max(N, 0)
    NNew = N
    if NMax === nothing
        NMax = N
    elseif NMax < N
        error("NMax must be greater than or equal to N. Found NMax=$NMax and N=$N")
    end
    for (prop, arr) in pairs(agentProperties)
        if length(arr) != N
            error("Agent property $prop must be the same length as N. Found $(length(arr)) and $N")
        elseif !haskey(agent.agentProperties, prop)
            error("Agent property $prop is not defined in the agent. Available properties are: $(keys(agent.agentProperties))")
        end
    end
    for (prop, par) in pairs(agent.agentProperties)
        if !haskey(agentProperties, prop)
            agentProperties[prop] = zeros(par.dataType, NMax)
        end
    end
    agentProperties = NamedTuple(agentProperties)
    idMax = maximum(agentProperties.id)
    return CommunityPoint{D}(
        agent,
        N,
        NMax,
        NNew,
        idMax,
        false,
        agentProperties
    )
end

Base.length(x::CommunityPoint) = x._N
Base.lastindex(x::CommunityPoint) = length(x._N)
Base.firstindex(x::CommunityPoint) = 1
Base.show(io::IO, x::CommunityPoint) = print(io, "CommunityPoint: \n\n\t N=", x._N, " agents NMax=", x._NMax," preallocated agents.\n\n\t", x._agent)

# Base.getproperty(x::CommunityPoint, name::Symbol) = 
#     haskey(x.agentProperties, name) ? x.agentProperties[name] : getfield(x, name)

######################################################################################################
# ACTIONS FUNCTION
######################################################################################################

function preallocate!(model::CommunityPoint, NNewMax::Int)

    if NNewMax < 0
        error("NNewMax must be non-negative. Found $NNewMax")
    end

    NOld = model._NMax
    model._NMax += NNewMax

    for arr in model.agentProperties
        resize!(arr, model._NMax)
        arr[NOld+1:end] .= zero(eltype(arr))
    end

    return nothing

end

function freePreallocations!(model::CommunityPoint)

    if model._NMax == model._N
        return nothing
    end

    model._NMax = model._N

    for arr in model.agentProperties
        resize!(arr, model._NMax)
    end

    return nothing

end

function addAgent!(
        model::CommunityPoint; 
        agentProperties::NamedTuple = NamedTuple(;),
        preallocate::Union{Int, Float64}=1,
        verbose::Bool=false
    )

    if model._NNew + 1 > model._NMax
        if typeof(preallocate) <: Int && preallocate != 0
            if verbose
                @warn "Agent $(model.agent.name) is full. Preallocating more space. Current NMax is $(model._NMax). Increasing by $preallocate."
            end
            preallocate!(model, preallocate)
        elseif preallocate <= 0
            error("Agent $(model.agent.name) is full. Cannot add more agents. Current NMax is $(model._NMax). preallocate manually or set preallocate > 0 to automatically increase size.")
        else
            if verbose
                @warn "Agent $(model.agent.name) is full. Preallocating more space. Current NMax is $(model._NMax). Increasing by $(max(1, Int(preallocate*model._NMax)))"
            end
            preallocate!(model, max(1, Int(preallocate*model._NMax)))
        end
    end

    model._NNew += 1
    model._N += 1

    model.agentProperties.id[model._NNew] = model._idMax + 1
    model._idMax += 1

    for prop in keys(agentProperties)
        model.agentProperties[prop][model._NNew] = agentProperties[prop]
    end

    return nothing

end

function removeAgent!(model::CommunityPoint, agentPos::Int; removeAllocation::Bool=true, verbose::Bool=false)

    if model._N == 0
        if verbose
            @warn "No agents to remove."
        end
        return nothing
    end

    if agentPos < 1 || agentPos > model._NMax
        error("agentPos must be between 1 and $(model._NMax). Found $agentPos")
    end

    for arr in model.agentProperties
        arr[agentPos] = arr[model._NNew]
        if removeAllocation
            resize!(arr, model._NMax - 1)
        end
    end

    model._N -= 1
    model._NNew -= 1

    if removeAllocation
        model._NMax -= 1
    end

    return nothing

end

function update!(model::CommunityPoint)

    if model._NFlag
        @warn "Agent $(model.agent.name) exceeded NMax. Some agents were not added. Consider preallocating more space."
        model._NFlag = false
    end

    # TODO check for removed agents (id == -1) and compact the arrays

    return nothing

end

######################################################################################################
# MACROS
######################################################################################################

macro loopOverAgentsPointCPU(name::Symbol, iterator::Symbol, code::Expr)

    N__ = Symbol(name, "__N")

    return quote
        Threads.@inloops @inbounds for $iterator in 1:$N__
            $(code)
        end
    end

end

macro loopOverAgentsPointGPU(name::Symbol, iterator::Symbol, code::Expr)

    N = Symbol(name, "__N")

    return quote
        @inbounds for $iterator in stride_:stride_:$N
            $(code)
        end
    end

end

macro addAgentPointCPU(name::Symbol, iterator::Symbol, args...)

    N = Symbol(name, "__N")
    NMax = Symbol(name, "__NMax")
    NNew = Symbol(name, "__NNew")
    idMax = Symbol(name, "__idMax")
    NFlag = Symbol(name, "__NFlag")

    id = Symbol(name, "__id")

    return quote
            i1New_ = Threads.atomic_add!($NNew,1)
            idNew_ = Threads.atomic_add!($idMax,1)
            if $NNew > $NMax
                $NFlag = true
            else
                $id[i1New_] = idNew_
                $code
            end
        end

end

macro addAgentPointGPU(name::Symbol, iterator::Symbol, args...)

    NMax = Symbol(name, "__NMax")
    NNew = Symbol(name, "__NNew")
    idMax = Symbol(name, "__idMax")
    NFlag = Symbol(name, "__NFlag")

    id = Symbol(name, "__id")

    return quote
            i1New_ = CUDA.atomic_add!(CUDA.pointer($NNew,1),1)
            idNew_ = CUDA.atomic_add!(CUDA.pointer($idMax,1),1)
            if $NNew > $NMax
                $NFlag = true
            else
                $id[i1New_] = idNew_
                $code
            end
        end

end

macro removeAgentPointCPU(name::Symbol, iterator::Symbol, agentPos::Symbol)

    id = Symbol(name, "__id")

    return quote

        $id[$agentPos] = -1

    end

end

macro removeAgentPointGPU(name::Symbol, iterator::Symbol, agentPos::Symbol)

    id = Symbol(name, "__id")

    return quote

        $id[$agentPos] = -1

    end

end