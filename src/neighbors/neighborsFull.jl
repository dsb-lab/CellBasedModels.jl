# NeighborsFull stores its own permTable and auxBuffers for compaction operations
struct NeighborsFull{P, PT, AB} <: AbstractNeighbors 
    permTable::PT
    auxBuffers::AB
end
Adapt.@adapt_structure NeighborsFull

NeighborsFull() = NeighborsFull{Nothing, Nothing, Nothing}(nothing, nothing)

# Constructor for creating NeighborsFull with allocated buffers and mesh properties
function NeighborsFull(::Type{P}, NCache::Int, meshProperties=nothing) where {P}
    permTable = Vector{Int}(undef, NCache)
    
    # Create auxBuffers as a NamedTuple matching the mesh properties
    auxBuffers = if meshProperties !== nothing && hasfield(typeof(meshProperties), :p)
        # Create auxiliary buffers matching property names and types
        propnames = keys(meshProperties.p)
        buffers = NamedTuple{propnames}(
            Vector{dtype(dt, isbits=true)}(undef, NCache) for dt in values(meshProperties.p)
        )
        buffers
    else
        nothing
    end
    
    return NeighborsFull{P, typeof(permTable), typeof(auxBuffers)}(permTable, auxBuffers)
end

# Set the default neighbors constructor to use NeighborsFull
DEFAULT_NEIGHBORS_CONSTRUCTOR[] = (NCache, meshProperties) -> NeighborsFull(KernelAbstractions.CPU, NCache, meshProperties)

# Initialize neighbors for NeighborsFull
# Specializes on UnstructuredMeshField with NeighborsFull type
function initNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}) where {P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsFull, FI}
    NCache = lengthCache(field)
    
    permTable = Vector{Int}(undef, NCache)
    
    # Create auxBuffers matching field properties
    propnames = keys(field._p)
    auxBuffers = NamedTuple{propnames}(
        Vector{eltype(p)}(undef, NCache) for p in values(field._p)
    )
    
    return NeighborsFull{P, typeof(permTable), typeof(auxBuffers)}(permTable, auxBuffers)
end

## Preallocate - resize internal buffers
function preallocate!(neighbors::NeighborsFull, newSize::Int)
    """
    Preallocate auxiliary buffers for neighbor operations.
    Resizes permutation table and auxiliary buffers.
    """
    if neighbors.permTable !== nothing
        resize!(neighbors.permTable, newSize)
    end
    
    if neighbors.auxBuffers !== nothing
        # auxBuffers is a NamedTuple of vectors
        for buffer in values(neighbors.auxBuffers)
            if buffer !== nothing
                resize!(buffer, newSize)
            end
        end
    end
    
    return nothing
end

# Fallback for nothing neighbors
function preallocate!(::Nothing, ::Int)
    return nothing
end

# Update function for UnstructuredMeshObject - calls update! on each field
function update!(mesh::UnstructuredMeshObject{P, D, S, DT, PAR}) where {P, D, S, DT, PAR}
    for (name, prop) in pairs(mesh._p)
        update!(prop)
    end
    renameElements!(mesh)
end

# Default no-op for fields without neighbors or with nothing neighbors
update!(::UnstructuredMeshField) = nothing

# NeighborsFull: with no-compaction design, just reset _NAdded counter
# The new getFreePos!/releasePos!/synchronize system manages free slots without compaction
function update!(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}) where {P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsFull, FI}
    # Reset NAdded counter (new agents are now fully committed)
    # Use fill! which is GPU-compatible
    fill!(field._NAdded, 0)
    return nothing
end

function fillPermTable!(perm, flags, N)

    count = 1
    @inbounds for i in 1:N
        if flags[i]
            perm[i] = count
            count += 1
        else
            perm[i] = 0
        end
        #reset flags
        flags[i] = true
    end
    return count - 1

end

# Field-level API: iterateOverNeighbors for NeighborsFull returns all elements
# Specializes on the NN type parameter of UnstructuredMeshField
@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}, index::Int) where {P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsFull, FI}
    return 1:lengthProperties(field)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}, ::Any) where {P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsFull, FI}
    return 1:lengthProperties(field)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}, ::Any, ::Any) where {P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsFull, FI}
    return 1:lengthProperties(field)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}, ::Any, ::Any, ::Any) where {P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsFull, FI}
    return 1:lengthProperties(field)
end