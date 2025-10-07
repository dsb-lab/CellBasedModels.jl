using Printf

"""
    AgentGlobal <: AbstractAgent

A lightweight container for **global agent-level parameters** in a model.

`AgentGlobal` wraps a `NamedTuple` of property definitions.  
Each property is expected to be a structure (usually created by `parameterConvert`) containing metadata such as:

- `name` — identifier for the property.
- `dataType` — Julia type of the property value.
- `dimensions` — optional tuple describing array dimensions (or `nothing`).
- `defaultValue` — default numerical or object value.
- `description` — short human-readable explanation.

This type is typically used to hold parameters shared among all agents
or to define model-wide attributes.
"""
struct AgentGlobal{N,T} <: AbstractAgent
    _properties::NamedTuple
end

"""
    AgentGlobal(; properties::NamedTuple = (;))

Construct a new [`AgentGlobal`](@ref) object.

# Arguments
- `properties`: collection of parameter definitions.
  Each value is converted using `parameterConvert(properties; scope=nothing)`.

If no properties are given, an empty container is created.

# Example
```julia
props = (temperature = Parameter(dataType=Float64,
                                 defaultValue=37.0,
                                 description="environment temperature"),)
global_agent = AgentGlobal(properties = props)
```
"""
function AgentGlobal(; properties = (;))
    propertiesNew = parameterConvert(properties, scope = nothing)
    names = keys(propertiesNew)
    types = Tuple{[typeof(par).parameters[1] for par in values(propertiesNew)]...}
    return AgentGlobal{names, types}(propertiesNew)
end

function Base.show(io::IO, x::AgentGlobal)
    println(io, "AgentGlobal\n")
    println(io, @sprintf("\t%-15s %-15s %-15s %-15s %-20s %-s",
                         "Name", "Scope", "DataType", "Dimensions",
                         "Default_Value", "Description"))
    println(io, "\t" * repeat("-", 97))

    for (name, par) in pairs(x._properties)
        datatype = typeof(par).parameters[1]
        println(io, @sprintf("\t%-15s %-15s %-15s %-15s %-20s %-s",
                             name,
                             par.dimensions == nothing ? "" : string(par.dimensions),
                             string(datatype),
                             par.dimensions == nothing ? "" : string(par.dimensions),
                             par.defaultValue == nothing ? "" : string(par.defaultValue),
                             par.description))
    end
    println(io)
end

function Base.show(io::IO, ::Type{AgentGlobal{K,V}}) where {K,V}
    valtypes = V.parameters  # tuple of types
    print(io, "AgentGlobal{properties=(")
    for (i, (n, t)) in enumerate(zip(K, valtypes))
        i > 1 && print(io, ", ")
        print(io, n, "::", t)
    end
    print(io, ")}")
end

Base.getproperty(x::AgentGlobal, f::Symbol) = haskey(getfield(x, :_properties), f) ? x._properties[f] : getfield(x, f)
