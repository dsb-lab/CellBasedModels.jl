abstract type AbstractNeighbors end

# Stub function to be extended by specific neighbor implementations
function initNeighbors end

# Specialized no-op computeNeighbors! for Nothing
# computeNeighbors!(::Nothing, comm::AbstractCommunity) = nothing