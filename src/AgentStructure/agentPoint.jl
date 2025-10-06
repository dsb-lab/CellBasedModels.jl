using Printf

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
struct AgentPoint{D} <: AbstractAgent

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