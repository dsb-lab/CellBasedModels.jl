abstract type AbstractCSR end

######################################################################################################
# CSRBlock
######################################################################################################
struct CSRBlock{
            P, PR, AI, VI, VB
        } <: AbstractCSR
    _map::PR

    _N::AI
    _NBlock::AI
    _NCache::AI

    _ActiveSection::VI

    _FlagsSurvived::VB

    _NAdded::AI
    _NOverflow::AI
    _NOverflowBlock::AI
end
Adapt.@adapt_structure CSRBlock

function CSRBlock(;
    dtype::DataType=Int,
    N::Int=0,
    NBlock::Int=0,
    NCache::Int=0
)

    _map = zeros(dtype, NCache*NBlock)

    _N = SizedVector{1}(N)
    _NBlock = SizedVector{1}(NBlock)
    _NCache = SizedVector{1}(NCache)

    _ActiveSection = zeros(Int, NCache)
    _FlagsSurvived = zeros(Bool, NCache*NBlock)

    _NAdded = SizedVector{1}(0)
    _NOverflow = SizedVector{1}(0)
    _NOverflowBlock = SizedVector{1}(0)

    P = platform()
    PR = typeof(_map)
    AI = typeof(_N)
    VI = typeof(_ActiveSection)
    VB = typeof(_FlagsSurvived)

    CSRBlock{
            P, PR, AI, VI, VB
        }(
            _map,
            _N,
            _NBlock,
            _NCache,
            _ActiveSection,
            _FlagsSurvived,
            _NAdded,
            _NOverflow,
            _NOverflowBlock,
        )
end

function CSRBlock(
            _map,
            _N,
            _NBlock,
            _NCache,
            _FlagsSurvived,
            _NAdded,
            _NOverflow,
            _NOverflowBlock,
        )
        
    P = platform()
    PR = typeof(_map)
    AI = typeof(_N)
    VI = typeof(_ActiveSection)
    VB = typeof(_FlagsSurvived)

    CSRBlock{
            P, PR, AI, VI, VB
        }(
            _map,
            _N,
            _NBlock,
            _NCache,
            _FlagsSurvived,
            _NAdded,
            _NOverflow,
            _NOverflowBlock,
        )
end

function CSRBlock(data::AbstractVector{<:AbstractVector}, NBlock::Int; NAddCache::Int=0)
    """
    Create a CSRBlock from an array of arrays.
    
    Args:
        data: Vector of vectors containing the data
        NBlock: Block size (must be >= length of largest subarray)
    
    Returns:
        CSRBlock containing all the data
    """
    N = length(data)
    
    # Check that NBlock is large enough
    max_length = maximum(length(arr) for arr in data)
    if NBlock < max_length
        error("NBlock ($NBlock) must be >= the length of the largest subarray ($max_length)")
    end

    # Check cache
    if NAddCache <= 0
        error("NAddCache must be > 0")
    end
    
    # Determine the most general dtype
    dtype = Union{}
    for arr in data
        for elem in arr
            dtype = promote_type(dtype, typeof(elem))
        end
    end
    
    # If no elements, default to Int
    if dtype == Union{}
        dtype = Int
    end
    
    # Create CSRBlock with appropriate size
    csr = CSRBlock(dtype=dtype, N=N, NBlock=NBlock, NCache=N+NAddCache)
    
    # Fill the data
    for (blockId, arr) in enumerate(data)
        csr._ActiveSection[blockId] = length(arr)
        for (elementId, value) in enumerate(arr)
            linear_idx = (blockId - 1) * NBlock + elementId
            csr._map[linear_idx] = value
        end
    end
    
    return csr
end

function CSRBlock(data::AbstractVector{<:AbstractVector}; NAddCache::Int=0)
    """
    Create a CSRBlock from an array of arrays.
    
    Args:
        data: Vector of vectors containing the data
        NBlock: Block size (must be >= length of largest subarray)
    
    Returns:
        CSRBlock containing all the data
    """
    N = length(data)
    
    # Check that NBlock is large enough
    max_length = maximum(length(arr) for arr in data)

    CSRBlock(data, max_length, NAddCache=NAddCache)

end

function Base.show(io::IO, x::CSRBlock{
            P, PR, AI, VI, VB
        }) where {
            P, PR, AI, VI, VB
        } 
    
    println(io, "CSRBlock{length=$(length(x)), lengthCache=$(lengthCache(x)), block=$(Array(x._ActiveSection)[1])}\n")

end

function Base.show(io::IO, x::Type{CSRBlock})
    println(io, "CSRBlock{")
    # CellBasedModels.show(io, x)
    println(io, "}")
end

Base.length(field::CSRBlock{P}) where {P<:CPU} = fullLength(field)
fullLength(field::CSRBlock{P}) where {P<:CPU} = length(field._map)
lengthElements(field::CSRBlock{P}) where {P<:CPU} = field._N[1]
lengthElementsCache(field::CSRBlock{P}) where {P<:CPU} = field._NCache[1]
lengthBlock(field::CSRBlock{P}) where {P<:CPU} = field._NBlock[1]

Base.size(field::CSRBlock) = size(field._map)

Base.eltype(::CSRBlock{P, DT}) where {P, DT} = DT
Base.eltype(::Type{<:CSRBlock{P, DT}}) where {P, DT} = DT

Base.getindex(field::CSRBlock, i::Int) = field._map[i]

function Base.iterate(field::CSRBlock, state=(1, 1))
    blockId, elementId = state
    
    # Find next valid (blockId, elementId)
    while blockId <= lengthElements(field)
        if elementId <= field._ActiveSection[blockId]
            # Calculate linear index in _map
            linear_idx = (blockId - 1) * field._NBlock[1] + elementId
            map_value = field._map[linear_idx]
            
            next_state = if elementId < field._ActiveSection[blockId]
                (blockId, elementId + 1)
            else
                (blockId + 1, 1)
            end
            return ((blockId, map_value), next_state)
        else
            blockId += 1
            elementId = 1
        end
    end
    
    return nothing
end

iterateOverElements(mesh::CSRBlock) = 1:lengthElements(mesh)
function iterateOverBlocks(mesh::CSRBlock, block::Int)
    _NBlock = field._NBlock[1]
    pos = block - 1
    active_section = field._ActiveSection[block]
    return pos*_NBlock:(pos*_NBlock+active_section)
end

function add!(field::CSRBlock)
    nAdd = @atomic field._NAdded[1] += 1
    pos = field._N[1] + nAdd
    if pos > field._NCache[1]
        @atomic field._NOverflow[1] += 1
        return 0
    end

    return pos
end

function push!(field::CSRBlock, blockId::Int, value::Int)
    nAdd = @atomic field._ActiveSection[blockId] += 1
    if nAdd > field._NBlock[1]
        @atomic field._NOverflowBlock[1] += 1
    else
        pos = (blockId - 1) * field._NBlock[1] + nAdd
        field._map[pos] = value
    end
end

function replace!(field::CSRBlock, blockId::Int, index::Int, value::Int)
    nAdd = field._ActiveSection[blockId]
    if index > nAdd
        @print "Cannot replace at index $index in block $blockId: only $nAdd elements present."
    else
        pos = (blockId - 1) * field._NBlock[1] + index
        field._map[pos] = value
    end
end

function insert!(field::CSRBlock, blockId::Int, index::Int, value::Int)
    nAdd = @atomic field._ActiveSection[blockId] += 1
    if nAdd > field._NBlock[1]
        @atomic field._NOverflowBlock[1] += 1
    else
        pos = (blockId - 1) * field._NBlock[1] + nAdd
        posInsert = (blockId - 1) * field._NBlock[1] + index
        # Shift elements to make space
        for i in pos:-1:pos-index+2
            field._map[i] = field._map[i - 1]
        end
        field._map[posInsert] = value
    end
end

function remove!(field::CSRBlock, blockId::Int, index::Int)
    nAdd = field._ActiveSection[blockId]
    if index > nAdd
        @print "Cannot remove at index $index in block $blockId: only $nAdd elements present."
    else
        posRemove = (blockId - 1) * field._NBlock[1] + index
        # Shift elements to fill the gap
        for i in posRemove:nAdd-1 + (blockId - 1) * field._NBlock[1]
            field._map[i] = field._map[i + 1]
        end
        @atomic field._ActiveSection[blockId] -= 1
    end
end

######################################################################################################
# CSRTuple - Specialized version without active section tracking
######################################################################################################
const CSRTuple{P, PR, AI, VB} = CSRBlock{P, PR, AI, Nothing, VB}

function CSRTuple(;
    dtype::DataType=Int,
    N::Int=0,
    NBlock::Int=0,
    NCache::Int=0
)

    _map = zeros(dtype, NCache*NBlock)

    _N = SizedVector{1}(N)
    _NBlock = SizedVector{1}(NBlock)
    _NCache = SizedVector{1}(NCache)

    _ActiveSection = nothing
    _FlagsSurvived = zeros(Bool, NCache*NBlock)

    _NAdded = SizedVector{1}(0)
    _NOverflow = SizedVector{1}(0)
    _NOverflowBlock = SizedVector{1}(0)

    P = platform()
    PR = typeof(_map)
    AI = typeof(_N)
    VI = Nothing
    VB = typeof(_FlagsSurvived)

    CSRBlock{
            P, PR, AI, VI, VB
        }(
            _map,
            _N,
            _NBlock,
            _NCache,
            _ActiveSection,
            _FlagsSurvived,
            _NAdded,
            _NOverflow,
            _NOverflowBlock,
        )
end

function CSRTuple(data::AbstractVector{<:AbstractVector}; NAddCache::Int=0)
    """
    Create a CSRTuple from an array of arrays.
    All subarrays must have the same length (tuples).
    
    Args:
        data: Vector of vectors containing the data (all must be same length)
        NAddCache: Additional cache blocks to allocate
    
    Returns:
        CSRTuple containing all the data
    """
    N = length(data)
    
    if N == 0
        error("Cannot create CSRTuple from empty data")
    end
    
    # Check that all subarrays have the same length
    NBlock = length(data[1])
    for (i, arr) in enumerate(data)
        if length(arr) != NBlock
            error("All subarrays must have the same length for CSRTuple. " *
                  "Subarray 1 has length $NBlock, but subarray $i has length $(length(arr))")
        end
    end

    # Check cache
    if NAddCache < 0
        error("NAddCache must be >= 0")
    end
    
    # Determine the most general dtype
    dtype = Union{}
    for arr in data
        for elem in arr
            dtype = promote_type(dtype, typeof(elem))
        end
    end
    
    # If no elements, default to Int
    if dtype == Union{}
        dtype = Int
    end
    
    # Create CSRTuple with appropriate size
    csr = CSRTuple(dtype=dtype, N=N, NBlock=NBlock, NCache=N+NAddCache)
    
    # Fill the data
    for (blockId, arr) in enumerate(data)
        for (elementId, value) in enumerate(arr)
            linear_idx = (blockId - 1) * NBlock + elementId
            csr._map[linear_idx] = value
        end
    end
    
    return csr
end

# Specialized iterator for CSRTuple - no active section checking
function Base.iterate(field::CSRTuple, state=(1, 1))
    blockId, elementId = state
    
    nBlock = field._NBlock[1]
    nCache = field._NCache[1]
    
    # Check if we've exhausted all blocks
    if blockId > lengthElements(field)
        return nothing
    end
    
    # Calculate linear index in _map
    linear_idx = (blockId - 1) * nBlock + elementId
    map_value = field._map[linear_idx]
    
    # Calculate next state
    next_state = if elementId < nBlock
        (blockId, elementId + 1)
    else
        (blockId + 1, 1)
    end
    
    return ((blockId, map_value), next_state)
end

function insert!(field::CSRTuple, blockId::Int, index::Int, value::Int)
    @print "Cannot insert into CSRTuple: no active section tracking."
end

function remove!(field::CSRTuple, blockId::Int, index::Int)
    @print "Cannot remove from CSRTuple: no active section tracking."
end

######################################################################################################
# CSRSlack - Variable-sized blocks with flexible starts/ends
######################################################################################################
struct CSRSlack{
            P, PR, AI, VI, VI2, VB
        } <: AbstractCSR
    _map::PR

    _N::AI
    _offsets::VI

    _ActiveSection::VI2

    _FlagsSurvived::VB

    _NAdded::AI
    _NOverflow::AI
    _NOverflowBlock::AI
end
Adapt.@adapt_structure CSRSlack

function CSRSlack(;
    dtype::DataType=Int,
    N::Int=0,
    sizes::Vector{Int}=Int[],
    NCache::Int=0,
    totalCache::Int=sum(sizes) + NCache
)
    # If sizes not provided, create empty structure
    if isempty(sizes) && N > 0
        sizes = zeros(Int, N)
    end
    
    @assert length(sizes) == N "Number of sizes must match N"
    
    _map = zeros(dtype, totalCache)

    _N = SizedVector{1}(N)
    
    # Calculate offsets for each block (size N+1)
    # Each block gets its specified size, plus NCache at the end
    _offsets = zeros(Int, N+1)
    _offsets[1] = 1
    for i in 1:N
        _offsets[i+1] = _offsets[i] + sizes[i]
    end
    # Add NCache space at the very end
    _offsets[N+1] += NCache

    _ActiveSection = zeros(Int, N)
    _FlagsSurvived = zeros(Bool, totalCache)

    _NAdded = SizedVector{1}(0)
    _NOverflow = SizedVector{1}(0)
    _NOverflowBlock = SizedVector{1}(0)

    P = platform()
    PR = typeof(_map)
    AI = typeof(_N)
    VI = typeof(_offsets)
    VI2 = typeof(_ActiveSection)
    VB = typeof(_FlagsSurvived)

    CSRSlack{
            P, PR, AI, VI, VI2, VB
        }(
            _map,
            _N,
            _offsets,
            _ActiveSection,
            _FlagsSurvived,
            _NAdded,
            _NOverflow,
            _NOverflowBlock,
        )
end

function CSRSlack(
            _map,
            _N,
            _offsets,
            _ActiveSection,
            _FlagsSurvived,
            _NAdded,
            _NOverflow,
            _NOverflowBlock,
        )
        
    P = platform()
    PR = typeof(_map)
    AI = typeof(_N)
    VI = typeof(_offsets)
    VI2 = typeof(_ActiveSection)
    VB = typeof(_FlagsSurvived)

    CSRSlack{
            P, PR, AI, VI, VI2, VB
        }(
            _map,
            _N,
            _offsets,
            _ActiveSection,
            _FlagsSurvived,
            _NAdded,
            _NOverflow,
            _NOverflowBlock,
        )
end

function CSRSlack(data::AbstractVector{<:AbstractVector}; NAddCache::Int=0)
    """
    Create a CSRSlack from an array of arrays.
    Each subarray can have a different length.
    
    Args:
        data: Vector of vectors containing the data (variable lengths allowed)
        NAddCache: Additional total cache space to allocate
    
    Returns:
        CSRSlack containing all the data
    """
    N = length(data)
    
    if N == 0
        error("Cannot create CSRSlack from empty data")
    end

    # Check cache
    if NAddCache < 0
        error("NAddCache must be >= 0")
    end
    
    # Get sizes of each subarray
    sizes = [length(arr) for arr in data]
    
    # Determine the most general dtype
    dtype = Union{}
    for arr in data
        for elem in arr
            dtype = promote_type(dtype, typeof(elem))
        end
    end
    
    # If no elements, default to Int
    if dtype == Union{}
        dtype = Int
    end
    
    # Create CSRSlack with appropriate sizes
    totalCache = sum(sizes) + NAddCache
    csr = CSRSlack(dtype=dtype, N=N, sizes=sizes, NCache=NAddCache, totalCache=totalCache)
    
    # Fill the data
    for (blockId, arr) in enumerate(data)
        start_idx = csr._offsets[blockId]
        csr._ActiveSection[blockId] = length(arr)
        for (elementId, value) in enumerate(arr)
            csr._map[start_idx + elementId - 1] = value
        end
    end
    
    return csr
end

function Base.show(io::IO, x::CSRSlack{
            P, PR, AI, VI, VI2, VB
        }) where {
            P, PR, AI, VI, VI2, VB
        } 
    
    println(io, "CSRSlack{N=$(lengthElements(x)), totalCache=$(length(x._map))}\n")

end

function Base.show(io::IO, x::Type{CSRSlack})
    println(io, "CSRSlack{")
    println(io, "}")
end

Base.length(field::CSRSlack{P, PR, AI, VI, VI2, VB}) where {P<:CPU, PR, AI, VI<:AbstractVector, VI2<:AbstractVector, VB} = length(field._map)
lengthElements(field::CSRSlack{P}) where {P<:CPU} = field._N[1]
lengthElementsCache(field::CSRSlack{P}) where {P<:CPU} = field._N[1]

Base.size(field::CSRSlack) = size(field._map)

Base.eltype(::CSRSlack{P, DT}) where {P, DT} = DT
Base.eltype(::Type{<:CSRSlack{P, DT}}) where {P, DT} = DT

Base.getindex(field::CSRSlack, i::Int) = field._map[i]

function Base.iterate(field::CSRSlack, state=(1, 1))
    blockId, elementId = state
    
    # Find next valid (blockId, elementId)
    while blockId <= lengthElements(field)
        if elementId <= field._ActiveSection[blockId]
            # Calculate linear index in _map using offsets
            linear_idx = field._offsets[blockId] + elementId - 1
            map_value = field._map[linear_idx]
            
            next_state = if elementId < field._ActiveSection[blockId]
                (blockId, elementId + 1)
            else
                (blockId + 1, 1)
            end
            return ((blockId, map_value), next_state)
        else
            blockId += 1
            elementId = 1
        end
    end
    
    return nothing
end

iterateOverElements(mesh::CSRSlack) = 1:lengthElements(mesh)
function iterateOverBlock(field::CSRSlack, blockId::Int)
    start_pos = field._offsets[blockId]
    active = field._ActiveSection[blockId]
    return start_pos:(start_pos + active - 1)
end

function push!(field::CSRSlack, blockId::Int, value::Int)
    nAdd = @atomic field._ActiveSection[blockId] += 1
    nBlock = field._offsets[blockId+1] - field._offsets[blockId]
    if nAdd > nBlock
        @atomic field._NOverflowBlock[1] += 1
    else
        pos = field._offsets[blockId] + nAdd - 1
        field._map[pos] = value
    end
end

function replace!(field::CSRSlack, blockId::Int, index::Int, value::Int)
    nAdd = field._ActiveSection[blockId]
    nBlock = field._offsets[blockId+1] - field._offsets[blockId]
    if index > nBlock
        @print "Cannot replace at index $index in block $blockId: only $nAdd elements present."
    else
        pos = field._offsets[blockId] + index - 1
        field._map[pos] = value
    end
end

function insert!(field::CSRSlack, blockId::Int, index::Int, value::Int)
    nAdd = @atomic field._ActiveSection[blockId] += 1
    nBlock = field._offsets[blockId+1] - field._offsets[blockId]
    if nAdd > nBlock
        @atomic field._NOverflowBlock[1] += 1
    else
        pos = field._offsets[blockId] + nAdd - 1
        posInsert = field._offsets[blockId] + index - 1
        # Shift elements to make space
        for i in pos:-1:pos-index+2
            field._map[i] = field._map[i - 1]
        end
        field._map[posInsert] = value
    end
end

function remove!(field::CSRSlack, blockId::Int, index::Int)
    nAdd = field._ActiveSection[blockId]
    nBlock = field._offsets[blockId+1] - field._offsets[blockId]
    if index > nAdd
        @print "Cannot remove at index $index in block $blockId: only $nAdd elements present."
    else
        posRemove = field._offsets[blockId] + index - 1
        # Shift elements to fill the gap
        for i in posRemove:nAdd-1 + (blockId - 1) * field._NBlock[1]
            field._map[i] = field._map[i + 1]
        end
        @atomic field._ActiveSection[blockId] -= 1
    end
end

######################################################################################################
# CSRCache - Specialized version of CSRSlack without active section tracking
######################################################################################################
const CSRCache{P, PR, AI, VI, VB} = CSRSlack{P, PR, AI, VI, Nothing, VB}

function CSRCache(;
    dtype::DataType=Int,
    N::Int=0,
    sizes::Vector{Int}=Int[],
    totalCache::Int=sum(sizes)
)
    # If sizes not provided, create empty structure
    if isempty(sizes) && N > 0
        sizes = zeros(Int, N)
    end
    
    @assert length(sizes) == N "Number of sizes must match N"
    
    _map = zeros(dtype, totalCache)

    _N = SizedVector{1}(N)
    
    # Calculate offsets for each block (size N+1)
    _offsets = zeros(Int, N+1)
    _offsets[1] = 1
    for i in 1:N
        _offsets[i+1] = _offsets[i] + sizes[i]
    end

    _ActiveSection = nothing
    _FlagsSurvived = zeros(Bool, totalCache)

    _NAdded = SizedVector{1}(0)
    _NOverflow = SizedVector{1}(0)
    _NOverflowBlock = SizedVector{1}(0)

    P = platform()
    PR = typeof(_map)
    AI = typeof(_N)
    VI = typeof(_offsets)
    VI2 = typeof(_ActiveSection)
    VB = typeof(_FlagsSurvived)

    CSRSlack{
            P, PR, AI, VI, VI2, VB
        }(
            _map,
            _N,
            _offsets,
            _ActiveSection,
            _FlagsSurvived,
            _NAdded,
            _NOverflow,
            _NOverflowBlock,
        )
end

# Iterator protocol for CSRCache - returns total number of elements (all elements in all blocks)
Base.length(field::CSRCache) = length(field._map)

# Specialized iterator for CSRCache - no active section checking
function Base.iterate(field::CSRCache, state=(1, 1))
    blockId, elementId = state
    
    # Check if we've exhausted all blocks
    if blockId > lengthElements(field)
        return nothing
    end
    
    block_size = field._offsets[blockId+1] - field._offsets[blockId]
    
    # Calculate linear index in _map using offsets
    linear_idx = field._offsets[blockId] + elementId - 1
    map_value = field._map[linear_idx]
    
    # Calculate next state
    next_state = if elementId < block_size
        (blockId, elementId + 1)
    else
        (blockId + 1, 1)
    end
    
    return ((blockId, map_value), next_state)
end

function iterateOverBlock(field::CSRCache, blockId::Int)
    start_pos = field._offsets[blockId]
    end_pos = field._offsets[blockId+1] - 1
    return start_pos:end_pos
end

function insert!(field::CSRCache, blockId::Int, index::Int, value::Int)
    @print "Cannot insert into CSRCache: no active section tracking."
end

function remove!(field::CSRCache, blockId::Int, index::Int)
    @print "Cannot remove from CSRCache: no active section tracking."
end

######################################################################################################
# invertMap - Invert relationships in AbstractCSR
######################################################################################################

"""
    invertMap(csr::AbstractCSR; returnType=CSRSlack, NAddCache::Int=0)

Inverts the relationship stored in a CSR structure.

If the input CSR represents a mapping A -> B (e.g., node 1 -> [2, 3, 5], node 2 -> [1, 4]),
the output will represent the inverted mapping B -> A (e.g., 1 -> [2], 2 -> [1], 3 -> [1], 4 -> [2], 5 -> [1]).

# Arguments
- `csr::AbstractCSR`: The CSR structure to invert
- `returnType`: The type of CSR to return (default: CSRSlack). Can be CSRSlack, CSRBlock, CSRTuple, or CSRCache
- `NAddCache::Int`: Additional cache space to allocate (default: 0)

# Returns
An AbstractCSR of the specified return type containing the inverted mapping

# Example
```julia
# Create a CSR with mapping: 1 -> [2, 3], 2 -> [1, 4]
csr = CSRSlack([[2, 3], [1, 4]])
# Invert to get: 1 -> [2], 2 -> [1], 3 -> [1], 4 -> [2]
inv_csr = invertMap(csr)
```
"""
function invertMap(csr::AbstractCSR; returnType=CSRSlack, NAddCache::Int=0)
    # Find the maximum value in the CSR to determine the size of the inverted map
    max_value = 0
    for (blockId, value) in csr
        max_value = max(max_value, value)
    end
    
    if max_value == 0
        # Empty CSR or all zeros
        if returnType == CSRSlack
            return CSRSlack(dtype=eltype(csr), N=0, sizes=Int[], NCache=NAddCache)
        elseif returnType == CSRBlock
            return CSRBlock(dtype=eltype(csr), N=0, NBlock=0, NCache=NAddCache)
        elseif returnType == CSRTuple
            return CSRTuple(dtype=eltype(csr), N=0, NBlock=0, NCache=NAddCache)
        elseif returnType == CSRCache
            return CSRCache(dtype=eltype(csr), N=0, sizes=Int[])
        else
            error("Unsupported return type: $returnType")
        end
    end
    
    # Count occurrences of each value to determine sizes
    counts = zeros(Int, max_value)
    for (blockId, value) in csr
        if value > 0  # Skip zeros if present
            counts[value] += 1
        end
    end
    
    # Create the inverted structure based on return type
    if returnType == CSRSlack
        inv_csr = CSRSlack(dtype=Int, N=max_value, sizes=counts, NCache=NAddCache)
    elseif returnType == CSRBlock
        # For CSRBlock, use the maximum count as NBlock
        max_count = maximum(counts)
        inv_csr = CSRBlock(dtype=Int, N=max_value, NBlock=max_count, NCache=max_value + NAddCache)
    elseif returnType == CSRTuple
        # For CSRTuple, all blocks must have the same size
        if !all(c -> c == counts[1], counts)
            error("CSRTuple requires all inverted blocks to have the same size. " *
                  "Use CSRSlack or CSRBlock instead, or ensure the input CSR has uniform connectivity.")
        end
        inv_csr = CSRTuple(dtype=Int, N=max_value, NBlock=counts[1], NCache=max_value + NAddCache)
    elseif returnType == CSRCache
        inv_csr = CSRCache(dtype=Int, N=max_value, sizes=counts)
    else
        error("Unsupported return type: $returnType. Supported types are: CSRSlack, CSRBlock, CSRTuple, CSRCache")
    end
    
    # Fill the inverted mapping
    for (blockId, value) in csr
        if value > 0  # Skip zeros if present
            push!(inv_csr, value, blockId)
        end
    end
    
    return inv_csr
end