abstract type AbstractNeighbors end

# Initialize neighbors for a field
# Takes the UnstructuredMeshField with neighbor type already set
# Returns the initialized neighbor structure
# Each neighbor type should specialize this function
function initNeighbors end

# Ref to hold the default neighbor constructor function
# This is set by neighborsFull.jl when it loads
const DEFAULT_NEIGHBORS_CONSTRUCTOR = Ref{Any}(nothing)

# Default neighbors creator - uses the constructor in DEFAULT_NEIGHBORS_CONSTRUCTOR if set
function createDefaultNeighbors(NCache::Int, meshProperties=nothing)
    if DEFAULT_NEIGHBORS_CONSTRUCTOR[] !== nothing
        return DEFAULT_NEIGHBORS_CONSTRUCTOR[](NCache, meshProperties)
    end
    return nothing
end

# Specialized no-op computeNeighbors! for Nothing
# computeNeighbors!(::Nothing, comm::AbstractCommunity) = nothing