######################################################################################################
# COMMUNITY STRUCTURE
######################################################################################################

mutable struct CommunityAgentPoint{D} <: CommunityType

    _agent::AgentPoint
    properties::NamedTuple    # Dictionary to hold agent properties

end

function CommunityAgentPoint(
    agent::AgentPoint;
    N::Int,
    NMax::Union{Nothing, Int}=nothing,
    agentProperties::NamedTuple = NamedTuple(),
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
        if !haskey(agentProperties, prop) && par._scope == :agent
            agentProperties[prop] = zeros(par.dataType, NMax)
        end
    end
    dNew = Dict{Symbol, Any}()
    dDt = Dict{Symbol, Any}()
    for (prop, arr) in pairs(agent.agentProperties)
        if par._updated
            dNew[prop] = copy(agentProperties[prop])
        end
        if par._DE
            dDt[prop] = copy(agentProperties[prop])
        end
    end
    agentProperties = NamedTuple(agentProperties)
    idMax = maximum(agentProperties.id)

    properties = (
        _N = UInt[N],
        _NMax = UInt[NMax],
        _NNew = UInt[NNew],
        _idMax = UInt[idMax],
        _NFlag = Bool[false],
        agent = agentProperties,
        _agentNew = dNew,
        _agentDt = dDt,
    )

    return CommunityAgentPoint{D}(
        agent,
        properties
    )
end

Base.length(x::CommunityAgentPoint) = x.properties._N
Base.lastindex(x::CommunityAgentPoint) = length(x.properties._N)
Base.firstindex(x::CommunityAgentPoint) = 1
Base.show(io::IO, x::CommunityAgentPoint) = print(io, "CommunityAgentPoint: \n\n\t N=", x.properties._N, " agents NMax=", x.properties._NMax," preallocated agents.\n\n\t", x._agent)

getPropertiesAsNamedTuple(comm::CommunityAgentPoint) = comm.properties

######################################################################################################
# ACTIONS FUNCTION
######################################################################################################
function preallocate!(model::CommunityAgentPoint, NNewMax::Int)

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

function freePreallocations!(model::CommunityAgentPoint)

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
        model::CommunityAgentPoint; 
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

function removeAgent!(model::CommunityAgentPoint, agentPos::Int; removeAllocation::Bool=true, verbose::Bool=false)

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

function update!(model::CommunityAgentPoint)

    if model._NFlag
        @warn "Agent $(model.agent.name) exceeded NMax. Some agents were not added. Consider preallocating more space."
        model._NFlag = false
    end

    # TODO check for removed agents (id == -1) and compact the arrays

    return nothing

end
