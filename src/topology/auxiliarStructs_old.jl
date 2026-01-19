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
            _ActiveSection,
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
            _ActiveSection,
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
    
    println(io, "CSRBlock{lengthElements=$(lengthElements(x)), lengthElementsCache=$(lengthElementsCache(x)), block=$(Array(x._NBlock)[1])}")
    
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

# Helper function to calculate linear index in CSRBlock
function getIndex(field::CSRBlock, ePos::Int, bPos::Int)
    return (ePos - 1) * field._NBlock[1] + bPos
end

function preallocate!(field::CSRBlock, NAddBlock::Int=0, NAddCache::Int=0)
    """
    Preallocate additional cache space in the CSRBlock.
    
    Args:
        field: CSRBlock to modify
        NAddCache: Number of additional cache blocks to allocate
    """
    if NAddCache <= 0
        error("NAddCache must be > 0")
    end

    oldNBlock = Array(field._NBlock)[1]
    newNBlock = oldNBlock + NAddBlock

    N = Array(field._N)[1]
    oldNCache = Array(field._NCache)[1]
    newNCache = oldNCache + NAddCache

    oldMap = copy(field._map)
    resize!(field._map, newNCache * newNBlock)

    KernelAbstractions.@kernel function _kernel_remap!(oldMap, newMap, oldNBlock, newNBlock)
        index = @index(Global)
        for j in 1:oldNBlock
            old_idx = (index - 1) * oldNBlock + j
            new_idx = (index - 1) * newNBlock + j
            newMap[new_idx] = oldMap[old_idx]
        end
    end
    backend = KernelAbstractions.get_backend(oldMap)
    threads = backend isa KernelAbstractions.CPU ? Base.Threads.nthreads() : 256
    _kernel_remap!(backend, threads)(oldMap, field._map, oldNBlock, newNBlock, ndrange=N)
    KernelAbstractions.synchronize(backend)

    if field._ActiveSection !== nothing
        resize!(field._ActiveSection, newNCache)
    end
    resize!(field._FlagsSurvived, newNCache * newNBlock)

    field._NBlock .= newNBlock
    field._NCache .= newNCache

end

function preallocateOverflow!(field::CSRBlock; NAdditionalCache::Int=0)

    NAddBlock = Array(field._NOverflowBlock)[1]
    NAddCache = Array(field._NOverflow)[1] + NAdditionalCache

    preallocate!(field, NAddBlock, NAddCache)

    field._NOverflow .= 0
    field._NOverflowBlock .= 0
end

function checkBounds(field::CSRBlock, pos::Int, nPos::Int, nActive::Int, nBlock::Int)
    newPos = pos
    if pos + nPos - 1 > field._NCache[1]
        @atomic field._NOverflow[1] += max(field._NOverflow[1], pos + nPos - 1 - field._NCache[1]) - field._NOverflow[1]
        newPos = 0
    end
    if nActive > field._NOverflowBlock[1]
        @atomic field._NOverflowBlock[1] += max(field._NOverflowBlock[1], nActive - field._NBlock[1]) - field._NOverflowBlock[1]
        newPos = 0
    end
    if nBlock > field._NBlock[1]
        @atomic field._NOverflowBlock[1] += max(field._NOverflowBlock[1], nBlock - field._NBlock[1]) - field._NOverflowBlock[1]
        newPos = 0
    end

    return newPos
end

function addElement!(field::CSRBlock; elementSize::Int=1)
    nAdd = @atomic field._NAdded[1] += 1
    pos = field._N[1] + nAdd
    pos = checkBounds(field, pos, 1, 0, elementSize)

    return pos
end

function addElement!(field::CSRBlock, N::Int; elementSize::Int=1)
    nAdd = @atomic field._NAdded[1] += N
    pos = field._N[1] + nAdd - N + 1
    pos = checkBounds(field, pos, field._NCache[1], 0, elementSize)
    return pos
end

@generated function addElement!(field::CSRBlock, value::NTuple{N, T}) where {N, T}
    quote
        pos = addElement!(field; elementSize=$N)
        if pos != 0
            field._ActiveSection[pos] = $N
            for i in 1:$N
                linear_idx = (pos - 1) * field._NBlock[1] + i
                field._map[linear_idx] = value[i]
            end
        end

        return pos
    end
end

function pushToElement!(field::CSRBlock, ePos::Int, value::Int)
    nAdd = @atomic field._ActiveSection[ePos] += 1
    if nAdd > field._NBlock[1]
        @atomic field._NOverflowBlock[1] += 1
    else
        pos = getIndex(field, ePos, nAdd)
        field._map[pos] = value
    end
end

function replaceIndexFromElement!(field::CSRBlock, ePos::Int, bPos::Int, value::Int)
    nActive = field._ActiveSection[ePos]
    if bPos > nActive
        @print "Cannot replace at index $bPos in element $ePos: only $nActive elements present."
    else
        pos = getIndex(field, ePos, bPos)
        field._map[pos] = value
    end
end

function insertIndexAtElement!(field::CSRBlock, ePos::Int, bPos::Int, value::Int)
    nAdd = @atomic field._ActiveSection[ePos] += 1
    if nAdd > field._NBlock[1]
        @atomic field._NOverflowBlock[1] += 1
    else
        posNew = getIndex(field, ePos, nAdd)
        posInsert = getIndex(field, ePos, bPos)
        # Shift elements backward to make space
        for i in posNew:-1:posInsert+1
            field._map[i] = field._map[i - 1]
        end
        field._map[posInsert] = value
    end
end

function removeIndexFromElement!(field::CSRBlock, ePos::Int, bPos::Int)
    nCurrent = field._ActiveSection[ePos]
    if bPos > nCurrent
        @print "Cannot remove at index $bPos in element $ePos: only $nCurrent elements present."
    else
        posRemove = getIndex(field, ePos, bPos)
        posLast = getIndex(field, ePos, nCurrent)
        # Shift elements forward to fill the gap
        for i in posRemove:posLast-1
            field._map[i] = field._map[i + 1]
        end
        @atomic field._ActiveSection[ePos] -= 1
    end
end

######################################################################################################
# CSRTuple - Fixed-size tuples (block size is a type parameter)
######################################################################################################
struct CSRTuple{
            P, NBlock, PR, AI, VB
        } <: AbstractCSR
    _map::PR

    _N::AI
    _NBlock::Int
    _NCache::AI

    _FlagsSurvived::VB

    _NAdded::AI
    _NOverflow::AI
    _NOverflowBlock::AI
end
Adapt.@adapt_structure CSRTuple

function CSRTuple(;
    dtype::DataType=Int,
    N::Int=0,
    NBlock::Int=0,
    NCache::Int=0
)

    _map = zeros(dtype, NCache*NBlock)

    _N = SizedVector{1}(N)
    _NCache = SizedVector{1}(NCache)

    _FlagsSurvived = zeros(Bool, NCache*NBlock)

    _NAdded = SizedVector{1}(0)
    _NOverflow = SizedVector{1}(0)
    _NOverflowBlock = SizedVector{1}(0)

    P = platform()
    PR = typeof(_map)
    AI = typeof(_N)
    VB = typeof(_FlagsSurvived)

    CSRTuple{
            P, NBlock, PR, AI, VB
        }(
            _map,
            _N,
            NBlock,
            _NCache,
            _FlagsSurvived,
            _NAdded,
            _NOverflow,
            _NOverflowBlock,
        )
end

function CSRTuple(
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
    VB = typeof(_FlagsSurvived)

    CSRTuple{
            P, _NBlock, PR, AI, VB
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

function Base.show(io::IO, x::CSRTuple{
            P, NBlock, PR, AI, VB
        }) where {
            P, NBlock, PR, AI, VB
        } 
    
    println(io, "CSRTuple{lengthElements=$(lengthElements(x)), lengthElementsCache=$(lengthElementsCache(x)), block=$NBlock}")
    
end

function Base.show(io::IO, x::Type{CSRTuple})
    println(io, "CSRTuple{")
    # CellBasedModels.show(io, x)
    println(io, "}")
end

Base.length(field::CSRTuple{P, NBlock}) where {P<:CPU, NBlock} = fullLength(field)
fullLength(field::CSRTuple{P, NBlock}) where {P<:CPU, NBlock} = length(field._map)
lengthElements(field::CSRTuple{P, NBlock}) where {P<:CPU, NBlock} = field._N[1]
lengthElementsCache(field::CSRTuple{P, NBlock}) where {P<:CPU, NBlock} = field._NCache[1]
lengthBlock(field::CSRTuple{P, NBlock}) where {P<:CPU, NBlock} = NBlock

Base.size(field::CSRTuple) = size(field._map)

Base.eltype(::CSRTuple{P, NBlock, DT}) where {P, NBlock, DT} = DT
Base.eltype(::Type{<:CSRTuple{P, NBlock, DT}}) where {P, NBlock, DT} = DT

Base.getindex(field::CSRTuple, i::Int) = field._map[i]

# Specialized iterator for CSRTuple - no active section checking
function Base.iterate(field::CSRTuple{P, NBlock}, state=(1, 1)) where {P, NBlock}
    blockId, elementId = state
    
    # Check if we've exhausted all blocks
    if blockId > lengthElements(field)
        return nothing
    end
    
    # Calculate linear index in _map
    linear_idx = (blockId - 1) * NBlock + elementId
    map_value = field._map[linear_idx]
    
    # Calculate next state
    next_state = if elementId < NBlock
        (blockId, elementId + 1)
    else
        (blockId + 1, 1)
    end
    
    return ((blockId, map_value), next_state)
end

iterateOverElements(mesh::CSRTuple) = 1:lengthElements(mesh)
function iterateOverBlocks(mesh::CSRTuple{P, NBlock}, block::Int) where {P, NBlock}
    pos = block - 1
    return pos*NBlock:(pos*NBlock+NBlock)
end

# Helper function to calculate linear index in CSRTuple
function getIndex(field::CSRTuple{P, NBlock}, ePos::Int, bPos::Int) where {P, NBlock}
    return (ePos - 1) * NBlock + bPos
end

function preallocate!(field::CSRTuple{P, NBlock}, NAddCache::Int=0) where {P, NBlock}
    """
    Preallocate additional cache space in the CSRTuple.
    Note: NBlock is fixed as a type parameter and cannot be changed.
    
    Args:
        field: CSRTuple to modify
        NAddCache: Number of additional cache blocks to allocate
    """
    if NAddCache <= 0
        error("NAddCache must be > 0")
    end

    N = Array(field._N)[1]
    oldNCache = Array(field._NCache)[1]
    newNCache = oldNCache + NAddCache

    resize!(field._map, newNCache * NBlock)
    resize!(field._FlagsSurvived, newNCache * NBlock)

    field._NCache .= newNCache
end

function preallocateOverflow!(field::CSRTuple{P, NBlock}; NAdditionalCache::Int=0) where {P, NBlock}
    NAddCache = Array(field._NOverflow)[1] + NAdditionalCache

    if NAddCache > 0
        preallocate!(field, NAddCache)
    end

    field._NOverflow .= 0
    field._NOverflowBlock .= 0
end

function checkBounds(field::CSRTuple{P, NBlock}, pos::Int, nPos::Int) where {P, NBlock}
    newPos = pos
    if pos + nPos - 1 > field._NCache[1]
        @atomic field._NOverflow[1] += max(field._NOverflow[1], pos + nPos - 1 - field._NCache[1]) - field._NOverflow[1]
        newPos = 0
    end

    return newPos
end

function addElement!(field::CSRTuple{P, NBlock}) where {P, NBlock}
    nAdd = @atomic field._NAdded[1] += 1
    pos = field._N[1] + nAdd
    pos = checkBounds(field, pos, 1)

    return pos
end

function addElement!(field::CSRTuple{P, NBlock}, N::Int) where {P, NBlock}
    nAdd = @atomic field._NAdded[1] += N
    pos = field._N[1] + nAdd - N + 1
    pos = checkBounds(field, pos, field._NCache[1])

    return pos
end

@generated function addElement!(field::CSRTuple{P, N}, value::NTuple{N, T}) where {P, N, T}
    quote
        pos = addElement!(field)
        if pos != 0
            for i in 1:$N
                linear_idx = (pos - 1) * $N + i
                field._map[linear_idx] = value[i]
            end
        end

        return pos
    end
end

function replaceIndexFromElement!(field::CSRTuple{P, NBlock}, ePos::Int, bPos::Int, value::Int) where {P, NBlock}
    if bPos > NBlock
        @print "Cannot replace at index $bPos in element $ePos: only $NBlock elements present."
    else
        pos = getIndex(field, ePos, bPos)
        field._map[pos] = value
    end
end

######################################################################################################
# CSRSlack - Variable-sized blocks with flexible starts/ends
######################################################################################################
struct CSRSlack{
            P, PR, AI, AF, VI, VI2, VB
        } <: AbstractCSR
    _map::PR

    _N::AI
    _NCache::AI

    _offsets::VI                # Array of length NCache+1 defining block boundaries
    _ActiveSection::VI2         # Array of length NCache tracking active elements per block

    _FlagsSurvived::VB

    _incProd::AF           # Coefficient for reallocation: ceil(Int, ActiveSection*incProd + incSum)
    _incSum::AF            # Coefficient for reallocation

    _NAdded::AI
    _NOverflow::AI
    _NOverflowBlock::AI
end
Adapt.@adapt_structure CSRSlack

function estimateCache(N, incProd, incSum)
    return ceil(Int, N * incProd + incSum)
end

function CSRSlack(;
    dtype::DataType=Int,
    sizes::Vector{Int}=Int[],
    NAddCache::Int=0,
    incProd::AbstractFloat=1.1,
    incSum::AbstractFloat=0.0
)
    """
    Create a CSRSlack structure with variable-sized blocks.
    
    Args:
        dtype: Data type for _map elements
        N: Initial number of blocks
        sizes: Array of initial sizes for each block
        NCache: Additional cache per block
        incProd: Production coefficient for reallocation
        incSum: Sum coefficient for reallocation
    """

    @assert NAddCache >= 0 "NAddCache must be >= 0"
    @assert incProd >= 1.0 "incProd must be >= 1.0"
    @assert incSum >= 0.0 "incSum must be >= 0.0"
    
    # Calculate total cache needed
    N = length(sizes)
    NCache = N + NAddCache

    _N = SizedVector{1}(N)
    _NCache = SizedVector{1}(NCache)

    # Offsets array: length NCache+1, defines block boundaries
    # Each block i goes from _offsets[i] to _offsets[i+1]-1
    _offsets = zeros(Int, NCache + 1)
    _offsets[1] = 1
    for i in 1:N
        _offsets[i+1] = _offsets[i] + estimateCache(sizes[i], incProd, incSum)
    end

    _map = zeros(dtype, _offsets[end] - 1)

    _ActiveSection = zeros(Int, NCache)
    _ActiveSection[1:N] .= sizes
    _FlagsSurvived = zeros(Bool, NCache)

    _incProd = SizedVector{1}(incProd)
    _incSum = SizedVector{1}(incSum)

    _NAdded = SizedVector{1}(0)
    _NOverflow = SizedVector{1}(0)
    _NOverflowBlock = SizedVector{1}(0)

    P = platform()
    PR = typeof(_map)
    AI = typeof(_N)
    AF = typeof(_incProd)
    VI = typeof(_offsets)
    VI2 = typeof(_ActiveSection)
    VB = typeof(_FlagsSurvived)

    CSRSlack{
            P, PR, AI, AF, VI, VI2, VB
        }(
            _map,
            _N,
            _NCache,
            _offsets,
            _ActiveSection,
            _FlagsSurvived,
            _incProd,
            _incSum,
            _NAdded,
            _NOverflow,
            _NOverflowBlock,
        )
end

function CSRSlack(
            _map,
            _N,
            _NCache,
            _offsets,
            _ActiveSection,
            _FlagsSurvived,
            _incProd,
            _incSum,
            _NAdded,
            _NOverflow,
            _NOverflowBlock,
        )
        
    P = platform()
    PR = typeof(_map)
    AI = typeof(_N)
    AF = typeof(_incProd)
    VI = typeof(_offsets)
    VI2 = typeof(_ActiveSection)
    VB = typeof(_FlagsSurvived)

    CSRSlack{
            P, PR, AI, AF, VI, VI2, VB
        }(
            _map,
            _N,
            _NCache,
            _offsets,
            _ActiveSection,
            _FlagsSurvived,
            _incProd,
            _incSum,
            _NAdded,
            _NOverflow,
            _NOverflowBlock,
        )
end

function CSRSlack(data::AbstractVector{<:AbstractVector}; NAddCache::Int=0, incProd::AbstractFloat=1.1, incSum::AbstractFloat=0.0)
    """
    Create a CSRSlack from an array of arrays.
    Each subarray can have a different length.
    
    Args:
        data: Vector of vectors containing the data (variable lengths allowed)
        NCache: Additional cache per block to allocate
        incProd: Production coefficient for reallocation
        incSum: Sum coefficient for reallocation
    
    Returns:
        CSRSlack containing all the data
    """
    N = length(data)

    @assert NAddCache >= 0 "NAddCache must be >= 0"
    
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
    
    # Create CSRSlack with appropriate sizes and cache per block
    csr = CSRSlack(dtype=dtype, sizes=sizes, NAddCache=NAddCache, incProd=incProd, incSum=incSum)
    
    # Fill the data
    for (i, j) in csr
        setIndex!(csr, i, j, data[i][j])
    end
    
    return csr
end

function Base.show(io::IO, x::CSRSlack{
            P, PR, AI, AF, VI, VI2, VB
        }) where {
            P, PR, AI, AF, VI, VI2, VB
        } 
    
    println(io, "CSRSlack{N=$(lengthElements(x)), totalCache=$(length(x._map))}")

end

function Base.show(io::IO, x::Type{CSRSlack})
    println(io, "CSRSlack{")
    println(io, "}")
end

Base.length(field::CSRSlack{P, PR, AI, AF, VI, VI2, VB}) where {P<:CPU, PR, AI, AF, VI<:AbstractVector, VI2<:AbstractVector, VB} = length(field._map)
lengthElements(field::CSRSlack{P}) where {P<:CPU} = field._N[1]
lengthElementsCache(field::CSRSlack{P}) where {P<:CPU} = field._NCache[1]

Base.size(field::CSRSlack) = size(field._map)

Base.eltype(::CSRSlack{P, DT}) where {P, DT} = DT
Base.eltype(::Type{<:CSRSlack{P, DT}}) where {P, DT} = DT

getIndex(field::CSRSlack, i::Int, j::Int) = field._offsets[i] + j - 1
function setIndex!(field::CSRSlack, i::Int, j::Int, value)
    pos = getIndex(field, i, j)
    field._map[pos] = value
end

function preallocate!(field::CSRSlack{P}, NAddBlocks::Int=1) where {P}
    """
    Reallocate CSRSlack to add more block capacity and additional cache per block.
    For each block, the additional space is: ceil(Int, activeSection*incProd + incSum)
    
    Args:
        field: CSRSlack to reallocate
        NAddBlocks: Number of additional blocks to allocate
    """
    if NAddBlocks <= 0
        error("NAddBlocks must be > 0")
    end

    N = field._N[1]
    oldNCache = field._NCache[1]
    oldTotalLength = length(field._map)

    # Calculate new cache per block based on overflow blocks
    newCachePerBlock = ceil(Int, field._ActiveSection[1] * field._incProd + field._incSum)
    newNCache = oldNCache + newCachePerBlock

    # Copy old map
    oldMap = copy(field._map)

    # Calculate new offsets with additional blocks and cache
    newOffsets = zeros(Int, N + NAddBlocks + 1)
    newOffsets[1] = 1
    for i in 1:N
        blockSize = field._offsets[i+1] - field._offsets[i]
        newOffsets[i+1] = newOffsets[i] + blockSize + newCachePerBlock - oldNCache
    end
    
    # Add new blocks
    for i in N+1:N+NAddBlocks
        blockSize = newNCache
        newOffsets[i+1] = newOffsets[i] + blockSize
    end

    newTotalLength = newOffsets[N + NAddBlocks + 1] - 1
    
    # Resize and copy map
    resize!(field._map, newTotalLength)
    
    # Copy old data with new spacing
    for i in 1:N
        oldBlockStart = field._offsets[i]
        oldBlockEnd = field._offsets[i+1] - 1
        newBlockStart = newOffsets[i]
        
        # Copy active elements
        nActive = field._ActiveSection[i]
        for j in 1:nActive
            field._map[newBlockStart + j - 1] = oldMap[oldBlockStart + j - 1]
        end
    end

    # Resize other structures
    resize!(field._offsets, N + NAddBlocks + 1)
    copyto!(field._offsets, newOffsets)

    newActiveSection = zeros(Int, N + NAddBlocks)
    copyto!(newActiveSection, field._ActiveSection)
    resize!(field._ActiveSection, N + NAddBlocks)
    copyto!(field._ActiveSection, newActiveSection)

    resize!(field._FlagsSurvived, newTotalLength)

    # Update sizes
    field._N .= N + NAddBlocks
    field._NCache .= newNCache
end

function preallocateOverflow!(field::CSRSlack; NAdditionalBlocks::Int=0)
    """
    Preallocate blocks based on overflow tracking.
    
    Args:
        field: CSRSlack to reallocate
        NAdditionalBlocks: Additional blocks beyond those marked as overflow
    """
    NAddBlocks = Array(field._NOverflowBlock)[1] + NAdditionalBlocks

    if NAddBlocks > 0
        preallocate!(field, NAddBlocks)
    end

    field._NOverflow .= 0
    field._NOverflowBlock .= 0
end

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

# Bounds check for CSRSlack
function checkBounds(field::CSRSlack, pos::Int, nActive::Int=0)
    newPos = pos

    # Check block capacity
    if pos > field._NCache[1]
        @atomic field._NOverflowBlock[1] += max(field._NOverflowBlock[1], pos - field._NCache[1]) - field._NOverflowBlock[1]
        newPos = 0
    elseif pos <= length(field._offsets)-1
        blockSize = field._offsets[pos+1] - field._offsets[pos]
        if nActive > blockSize
            @atomic field._NOverflowBlock[1] += max(field._NOverflowBlock[1], nActive - blockSize) - field._NOverflowBlock[1]
            newPos = 0
        end
    end

    return newPos
end

function addElement!(field::CSRSlack; elementSize::Int=1)
    nAdd = @atomic field._NAdded[1] += 1

    pos = field._N[1] + nAdd
    pos = checkBounds(field, pos, elementSize)

    return pos
end

function addElement!(field::CSRSlack, n::Int; elementSize::Int=1)
    nAdd = @atomic field._NAdded[1] += n
    pos = field._N[1] + nAdd - n + 1
    pos = checkBounds(field, pos, elementSize)

    return pos
end

function pushToElement!(field::CSRSlack, ePos::Int, value)
    nAdd = @atomic field._ActiveSection[ePos] += 1
    blockSize = field._offsets[ePos+1] - field._offsets[ePos]
    if nAdd > blockSize
        @atomic field._NOverflowBlock[1] += 1
    else
        pos = getIndex(field, ePos, nAdd)
        field._map[pos] = value
    end
end

function replaceIndexFromElement!(field::CSRSlack, ePos::Int, bPos::Int, value)
    nActive = field._ActiveSection[ePos]
    if bPos > nActive
        @print "Cannot replace at index $bPos in element $ePos: only $nActive elements present."
    else
        pos = getIndex(field, ePos, bPos)
        field._map[pos] = value
    end
end

function insertIndexAtElement!(field::CSRSlack, ePos::Int, bPos::Int, value)
    nAdd = @atomic field._ActiveSection[ePos] += 1
    blockSize = field._offsets[ePos+1] - field._offsets[ePos]
    if nAdd > blockSize
        @atomic field._NOverflowBlock[1] += 1
    else
        posInsert = getIndex(field, ePos, bPos)
        posNew = getIndex(field, ePos, nAdd)
        # Shift elements backward to make space
        for i in posNew:-1:posInsert+1
            field._map[i] = field._map[i - 1]
        end
        field._map[posInsert] = value
    end
end

function removeIndexFromElement!(field::CSRSlack, ePos::Int, bPos::Int)
    nCurrent = field._ActiveSection[ePos]
    if bPos > nCurrent
        @print "Cannot remove at index $bPos in element $ePos: only $nCurrent elements present."
    else
        posRemove = getIndex(field, ePos, bPos)
        posLast = getIndex(field, ePos, nCurrent)
        # Shift elements forward to fill the gap
        for i in posRemove:posLast-1
            field._map[i] = field._map[i + 1]
        end
        @atomic field._ActiveSection[ePos] -= 1
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
            P, PR, AI, AF, VI, VI2, VB
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

function Base.show(io::IO, x::CSRCache{
            P, PR, AI, AF, VI, VB
        }) where {
            P, PR, AI, AF, VI, VB
        } 
    
    println(io, "CSRCache{N=$(lengthElements(x)), totalCache=$(length(x._map))}")

end

function Base.show(io::IO, x::Type{CSRCache})
    println(io, "CSRCache{")
    println(io, "}")
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

function insertIndexAtElement!(field::CSRCache, ePos::Int, bPos::Int, value::Int)
    @print "Cannot insert into CSRCache: no active section tracking."
end

function removeIndexFromElement!(field::CSRCache, ePos::Int, bPos::Int)
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
            pushToElement!(inv_csr, value, blockId)
        end
    end
    
    return inv_csr
end