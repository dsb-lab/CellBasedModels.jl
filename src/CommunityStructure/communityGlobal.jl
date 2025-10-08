using StaticArrays

"""
    mutable struct CommunityGlobal{D} <: AbstractCommunity where D<:AgentGlobal

Represents a **global community** built from a single [`AgentGlobal`](@ref) definition.

`CommunityGlobal` aggregates the global agent-level parameters and provides a container
for environment-wide scalar properties, along with their derivative (`_envDt`)
and updated (`_envNew`) buffers.

This is typically used to manage the simulation’s global state — parameters that
are shared across all agents and updated each simulation step.

# Type Parameters
- `D<:AgentGlobal`: The specific type of the global agent definition associated with the community.

# Fields
- `_agent::D`: The global agent definition used to construct this community.
- `properties::NamedTuple`: Container holding:
  - `env` — a `NamedTuple` of scalar environment variables.
  - `_envNew` — a dictionary of updated values for variables marked as `_updated`.
  - `_envDt` — a dictionary of time-derivative buffers for variables marked as `_DE`.

# Notes
`CommunityGlobal` ensures that:
- Each environment property corresponds to a valid property of the associated agent.
- Global-scoped parameters missing from `envProperties` are automatically initialized with zeros.
"""
mutable struct CommunityGlobal{D} <: AbstractCommunity where D<:AgentGlobal
    _agent::D
    _properties::NamedTuple
    _propertiesNew::NamedTuple
    _propertiesDt::NamedTuple
end

"""
    CommunityGlobal(agent::D; envProperties::NamedTuple = NamedTuple()) where D<:AgentGlobal

Construct a [`CommunityGlobal`](@ref) from an [`AgentGlobal`](@ref).

Validates that all provided environment properties are:
1. Scalars (`length(arr) == 1`), and  
2. Defined in the corresponding agent.

Automatically initializes missing global-scoped parameters from the agent definition.

# Arguments
- `agent::D`: An [`AgentGlobal`](@ref) instance that defines the available global parameters.
- `envProperties::NamedTuple`: Optional named tuple mapping property symbols to scalar arrays.

# Throws
- `ErrorException` if an environment property is not scalar.
- `ErrorException` if an environment property is not defined in the agent.

# Returns
A new `CommunityGlobal{D}` instance with:
- `env`: all environment-level parameters,
- `_envNew`: updated buffers for parameters with `_updated = true`,
- `_envDt`: derivative buffers for parameters with `_DE = true`.

# Example
```julia
agent = AgentGlobal(properties = (
    temperature = Parameter(Float64; defaultValue=37.0, description="environment temperature"),
    pressure    = Parameter(Float64; defaultValue=1.0,  description="environment pressure"),
))

# Define environment properties for initialization
env = (temperature = [37.0], pressure = [1.0])

comm = CommunityGlobal(agent; envProperties = env)
```
"""
function CommunityGlobal(
    agent::D;
    properties::NamedTuple = NamedTuple(),
) where D<:AgentGlobal

    # Validate user-provided environment properties
    props = Dict{Symbol, Any}()
    propsNew = Dict{Symbol, Any}()
    propsDt = Dict{Symbol, Any}()
    for (prop, arr) in pairs(properties)
        if length(arr) != 1
            error("Environment property $prop must be a scalar. Found $(length(arr))")
        elseif !haskey(agent._properties, prop)
            error("Environment property $prop is not defined in the agent. Available properties are: $(keys(agent._properties))")
        elseif typeof(agent._properties[prop]).parameters[1] != eltype(arr)
            error("Environment property $prop has type $(eltype(arr)), but agent expects $(typeof(agent._properties[prop]).parameters[1])")
        end
        props[prop] = MVector{1, eltype(arr)}(arr)
    end

    # Add missing global-scoped parameters from agent definition
    for (prop, par) in pairs(agent._properties)
        if !haskey(properties, prop)
            props[prop] =  MVector{1, typeof(par).parameters[1]}(zeros(typeof(par).parameters[1], 1))
        end
    end

    for (prop, par) in pairs(agent._properties)
        if par._updated
            propsNew[prop] = MVector{1, typeof(par).parameters[1]}(zeros(typeof(par).parameters[1], 1))
        end
        if par._DE
            propsDt[prop] = MVector{1, typeof(par).parameters[1]}(zeros(typeof(par).parameters[1], 1))
        end
    end

    properties = NamedTuple(props)
    propertiesNew = NamedTuple(propsNew)
    propertiesDt = NamedTuple(propsDt)

    return CommunityGlobal(agent, properties, propertiesNew, propertiesDt)
end

Base.setproperty!(x::CommunityGlobal, f::Symbol, v) = throw(MethodError("Cannot set property $f directly. Modify the corresponding array element instead. For example, use x.$f[1] = value."))
Base.getproperty(x::CommunityGlobal, f::Symbol) = haskey(getfield(x, :_properties), f) ? x._properties[f] : getfield(x, f)

"""
    getPropertiesAsNamedTuple(comm::CommunityGlobal) -> NamedTuple

Return all properties of a [`CommunityGlobal`](@ref) as a single `NamedTuple`.

# Example
```julia
comm = CommunityGlobal(agent; envProperties=(temperature=[37.0],))
props = getPropertiesAsNamedTuple(comm)
@show props.env.temperature
```
"""
getPropertiesAsNamedTuple(comm::CommunityGlobal) = comm._properties, comm._propertiesNew, comm._propertiesDt
