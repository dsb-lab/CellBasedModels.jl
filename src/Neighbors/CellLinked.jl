include("../auxiliar/indexing.jl")

mutable struct CellLinked{D::Int, IndexingType<:IndexingType} <: Neighbors

    _communities::NamedTuple
    _agentCell::NamedTuple
    _NAgentsCell::NamedTuple
    _NAgentsCellCum::NamedTuple
    _simBox::Matrix{<:Number}
    _edgeSize::NTuple{D, Number}
    _cellShape::Matrix{Int}

end

function CellLinked(
        dims::Int,
        indexingType::Type{<:IndexingType}=MortonIndexing
    )

    if dims < 1 || dims > 3
        error("dims must be 1, 2, or 3. Found $dims.")
    end

    neighbors = CellLinked{dims, indexingType}(
        (;), # _communities
        (;), # _agentCell
        (;), # _NAgentsCell
        (;), # _NAgentsCellCum
        zeros(dims, 2), # _simBox
        ntuple(_ -> 0.0, dims), # _edgeSize
        zeros(Int, dims) # _cellShape
    )
    
    return neighbors
end

function setup!(neighbors::CellLinked{D::Int, Indexing<:Any}, communities::Community{D}, simBox::AbstractArray, edgeSize::Union{AbstractArray{<:Any, 2}, AbstractFloat}) where D, Indexing

    for (name, community) in pairs(communities)
        if !(type(community) <: Community{D})
            error("Community $name must be of type Community. Found $(typeof(community))")
        end
    end

    if size(simBox, 1) != dims[1] || size(simBox, 2) != 2
        error("simBox must be a $dims[1] x 2 array.")
    end

    if isa(edgeSize, AbstractFloat)
        if edgeSize <= 0
            error("edgeSize must be positive. Found $edgeSize.")
        end
        edgeSize = fill(edgeSize, dims[1])
    elseif length(edgeSize) != dims[1]
        error("edgeSize must be a scalar or a vector of length $dims[1]. Found length $(length(edgeSize)).")
    elseif any(edgeSize .<= 0)
        error("All edge sizes must be positive. Found $edgeSize.")
    end

    neighbors._communities = communities
    neighbors._simBox = simBox
    neighbors._edgeSize = edgeSize
    neighbors._cellShape = (simBox[:, 2] .- simBox[:, 1]) .÷ edgeSize .+ 2

    if Indexing == LinearIndexing
        neighbors._NCells = prod(neighbors._cellShape)
    elseif Indexing == MortonIndexing
        neighbors._NCells = mortonToLinear(neighbors._cellShape...)
    end
    neighbors._NCells = mortonToLinear(neighbors._cellShape...)
    neighbors._NAgentsCell = zeros(Int, neighbors._NCells)
    neighbors._agentCell = NamedTuple(map(c -> zeros(Int, c._N), pairs(communities)))
    neighbors._NAgentsCellCum = zeros(Int, neighbors._NCells)

    return nothing

end

function computeNeighbors!(neighbors::CellLinked{2, LinearIndexing}, agent::Symbol)

    #Reset
    fill!(neighbors._NAgentsCell, 0)

    #Assign cells
    x = neighbors._communities[agent].x
    y = neighbors._communities[agent].y
    @inbounds for pos in 1:neighbors._communities[agent]._N

        posToCartesian = positionToCartesian2D(x[pos], y[pos], neighbors._simBox, neighbors._edgeSize, neighbors._cellShape)
        cellIdx = cartesianToLinear2D(posToCartesian, Tuple(neighbors._cellShape))

        neighbors._NAgentsCell[agent][cellIdx] += 1
        neighbors._agentCell[agent][pos] = cellIdx

    end

    #Cumulative sum
    @views cumsum!(neighbors._NAgentsCellCum[1:neighbors._communities[agent]._N], neighbors._NAgentsCell[1:neighbors._communities[agent]._N])

    return nothing

end

macro loopOverNeighborsCPU(AgentType::Symbol, neighborName::Symbol, code::Expr)

    code = loopOverNeighborsCode(model.agents[AgentType], neighborName, code)

    return code

end