using Printf

######################################################################################################
# AGENT STRUCTURE
######################################################################################################

struct AgentPoint{D} <: AbstractAgent

    propertiesAgent::NamedTuple    # Dictionary to hold agent properties

end

function AgentPoint(
    dims::Int;
    propertiesAgent::NamedTuple = (;)
)
    if dims < 0 || dims > 3
        error("dims must be between 0 and 3. Found $dims")
    end
    defaultParameters = (
        x = dims >= 1 ? Parameter(Float64, description="Position in x (protected parameter)", dimensions=:L, _scope=:agent) : nothing,
        y = dims >= 2 ? Parameter(Float64, description="Position in y (protected parameter)", dimensions=:L, _scope=:agent) : nothing,
        z = dims >= 3 ? Parameter(Float64, description="Position in z (protected parameter)", dimensions=:L, _scope=:agent) : nothing,
        id = Parameter(Int, description="Unique identifier (protected parameter)", _scope=:agent),
        _N = dims >= 0 ? Parameter(Int, description="Number of agents (protected parameter)") : nothing,
        _NMax = dims >= 0 ? Parameter(Int, description="Maximum number of preallocated agents (protected parameter)") : nothing,
        _NNew = dims >= 0 ? Parameter(Int, description="Number of new agents added in the current step (protected parameter)") : nothing,
        _idMax = dims >= 0 ? Parameter(Int, description="Maximum unique identifier assigned (protected parameter)") : nothing,
        _NFlag = dims >= 0 ? Parameter(Bool, description="Flag indicating if the number of agents exceeded the preallocated maximum (protected parameter)") : nothing,
    )

    # Remove keys with value `nothing`
    defaultParameters = NamedTuple{Tuple(k for (k,v) in pairs(defaultParameters) if v !== nothing)}(
        (v for (k,v) in pairs(defaultParameters) if v !== nothing)
    )
    propertiesAgentNew = parameter_convert(propertiesAgent, scope=:agent)
    for (k, v) in pairs(propertiesAgentNew)
        if haskey(defaultParameters, k)
            error("Parameter $k is already defined and cannot be used as agent property.")
        end
    end
    propertiesAgentNew = merge(defaultParameters, propertiesAgentNew)
    return AgentPoint{dims}(
        propertiesAgentNew
    )
end

Base.length(x::AgentPoint) = 1

function Base.show(io::IO, x::AgentPoint)
    println(io, "AgentPoint with dimensions $(x._dims): \n")
    println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-s", "Name", "DataType", "Dimensions", "Default_Value", "Description"))
    println(io, "\t" * repeat("-", 85))
    for (name, par) in pairs(x.propertiesAgent)
        println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-s", 
            name, 
            string(par.dataType), 
            par.dimensions == nothing ? "" : string(par.dimensions),
            par.defaultValue == nothing ? "" : string(par.defaultValue), 
            par.description))
    end
    println(io)
end

######################################################################################################
# MACROS
######################################################################################################
macro loopOverAgentPoint(name::Symbol, iterator::Symbol, code::Expr)

    N__ = Symbol(name, "__N")

    if COMPILE_PLATFORM == :CPU

        return quote
            Threads.@inloops @inbounds for $iterator in 1:$N__
                $(code)
            end
        end

    elseif COMPILE_PLATFORM == :GPU

        return quote
            @inbounds for $iterator in stride_:stride_:$N
                $(code)
            end
        end

    end

end

macro addAgentPoint(name::Symbol, args...)

    N = Symbol(name, "__N")
    NMax = Symbol(name, "__NMax")
    NNew = Symbol(name, "__NNew")
    idMax = Symbol(name, "__idMax")
    NFlag = Symbol(name, "__NFlag")

    id = Symbol(name, "__id")

    N__ = Symbol(name, "__N")

    if COMPILE_PLATFORM == :CPU

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

    elseif COMPILE_PLATFORM == :GPU

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

end

macro removeAgentPoint(name::Symbol, iterator::Symbol, agentPos::Symbol)

    id = Symbol(name, "__id")

    return quote

        $id[$agentPos] = -1

    end

end

macro loopOverAgentPointNeighbors(name::Symbol, iterator::Symbol, code::Expr)

    N__ = Symbol(name, "__N")

    if COMPILE_PLATFORM == :CPU

        return quote
            Threads.@inloops @inbounds for $iterator in 1:$N__
                for nbr in $neighbors[$iterator]
                    $(code)
                end
            end
        end

    elseif COMPILE_PLATFORM == :GPU

        return quote
            @inbounds for $iterator in stride_:stride_:$N
                for nbr in $neighbors[$iterator]
                    $(code)
                end
            end
        end

    end

end