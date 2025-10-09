using RecursiveArrayTools

struct CommunityABM{A, P<:AbstractPlatform, N<:AbstractNeighbors}

    _agentCommunities::ABM
    _communities::NamedTuple
    _parameters::NamedTuple
    _parametersNew::NamedTuple
    _parametersDt::NamedTuple
    _neighbors::N

    _pastTimes::Vector{NamedTuple}

end

function CommunityABM(agents::ABM{D, AN, AD}, neighbors::AbstractNeighbors{D, AN, AD}; kwargs...) where {D, AN, AD}

    communities = Dict{Symbol, AbstractCommunity}()
    parameters = Dict{Symbol, NamedTuple}()
    parametersNew = Dict{Symbol, NamedTuple}()
    parametersDt = Dict{Symbol, NamedTuple}()
    for (k,v) in pairs(kwargs)
        if !(k in keys(agents._agents))
            error("Parameter $k is not defined in the agent.")
        elseif typeof(v).parameters[1] != typeof(agents._agents[k])
            error("Parameter $k must be of type $(typeof(agents._agents[k]).parameters[1]), but got $(typeof(v)).")
        end
        communities[k] = v
        parameters[k], parametersNew[k], parametersDt[k] = getPropertiesAsNamedTuple(v)
    end

    return CommunityABM{typeof(agents), CPU, typeof(neighbors)}(
        agents,
        NamedTuple{keys(kwargs)}(values(communities)),
        NamedTuple{keys(kwargs)}(values(parameters)),
        NamedTuple{keys(kwargs)}(values(parametersNew)),
        NamedTuple{keys(kwargs)}(values(parametersDt)),
        neighbors,
        []
    )

end

function CommunityABM(agents::ABM{D,AN,AD},
                      ::Type{N}=NeighborsFull;
                      kwargs...) where {D,AN,AD,N}
    return CommunityABM(agents, N(agents); kwargs...)
end

Base.getproperty(x::CommunityABM, f::Symbol) = haskey(getfield(x, :_parameters), f) ? x._parameters[f] : getfield(x, f)

function update!(community::CommunityABM)

    for community in values(community._communities)
        update!(community)
    end
    
    return nothing

end