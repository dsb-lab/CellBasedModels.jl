struct NeighborsFull{D, AN, AD} <: AbstractNeighbors{D, AN, AD}

end

NeighborsFull(agent::ABM{D, AN, AD}) where {D, AN, AD} = NeighborsFull{D, AN, AD}()

computeNeighbors!(neigh::NeighborsFull, comm::AbstractCommunity) = nothing

getPropertiesAsNamedTuple(neigh::NeighborsFull) = NamedTuple()
