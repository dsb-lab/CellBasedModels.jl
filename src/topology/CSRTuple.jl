######################################################################################################
# CSRTuple - Fixed-size tuples (block size is a type parameter)
######################################################################################################
struct CSRTuple{
            P, NBlock, T, PR, AI, VI
        } <: AbstractCSR

    _NBlock::Int

    _map::PR

    _N::AI
    _NCache::AI
    _NAdded::AI

    _addElementOffsets::VI
    _childs::VI
end
Adapt.@adapt_structure CSRTuple

function CSRTuple(
    NBlock::Int,
    N::Int,
    NCache::Int=N;
    dtype::DataType=Int,
)

    @assert NBlock > 0 "NBlock must be > 0"
    @assert N >= 0 "N must be >= 0"
    @assert NCache >= N "NCache must be >= N"

    _NBlock = NBlock

    _map = zeros(dtype, NCache*NBlock)

    _N = SizedVector{1}(N)
    _NCache = SizedVector{1}(NCache)
    _NAdded = SizedVector{1}(0)

    _addElementOffsets = zeros(Int, NCache+1)
    _childs = zeros(Int, NCache+1)

    P = platform()
    T = eltype(_map)
    PR = typeof(_map)
    AI = typeof(_N)
    VI = typeof(_addElementOffsets)

    CSRTuple{
            P, NBlock, T, PR, AI, VI
        }(
            _NBlock,
            _map,
            _N,
            _NCache,
            _NAdded,
            _addElementOffsets,
            _childs,
        )
end

function CSRTuple(
            _NBlock,
            _map,
            _N,
            _NCache,
            _NAdded,
            _addElementOffsets,
            _childs,
        )
    
    P = platform()
    T = eltype(_map)
    PR = typeof(_map)
    AI = typeof(_N)
    VI = typeof(_addElementOffsets)

    CSRTuple{
            P, _NBlock, T, PR, AI, VI
        }(
            _NBlock,
            _map,
            _N,
            _NCache,
            _NAdded,
            _addElementOffsets,
            _childs,
        )
end

function CSRTuple(data::AbstractMatrix{T}; additionalCache::Int=0) where {T}

    @assert additionalCache >= 0 "additionalCache must be >= 0"

    _NBlock = size(data, 2)
    _N = size(data, 1)
    _NCache = _N + additionalCache
    
    # Create CSRTuple with appropriate size
    csr = CSRTuple(
        _NBlock,
        _N,
        _NCache;
        dtype=T,
    )
    
    csr._map[1:(_N*_NBlock)] .= reshape(data, _N*_NBlock)
    
    return csr
end

function CSRTuple(data::AbstractVector{<:AbstractVector{T}}; additionalCache::Int=0) where {T}

    maxl = maximum(length.(data))
    minl = minimum(length.(data))
    @assert maxl == minl "All subarrays must have the same length"
    @assert additionalCache >= 0 "additionalCache must be >= 0"

    N = length(data)
    NBlock = maximum(maxl)
    NCache = N + additionalCache

    # Create CSRTuple with appropriate size
    csr = CSRTuple(
        NBlock,
        N,
        NCache;
        dtype=T,
    )

    # Fill data, padding with zeros if necessary
    for i in 1:N
        for j in 1:length(data[i])
            linear_idx = (i - 1) * NBlock + j
            csr._map[linear_idx] = data[i][j]
        end
    end

    return csr
end

function Base.show(io::IO, x::CSRTuple{
            P, NBlock, PR, AI, VI
        }) where {
            P, NBlock, PR, AI, VI
        } 
    
    println(io, "CSRTuple{NBlock=$NBlock, N=$(lengthElements(x)), NCache=$(lengthElementsCache(x))}")    
end

function Base.show(io::IO, x::Type{CSRTuple{P, NBlock, PR, AI, VI}}) where {P, NBlock, PR, AI, VI}
    println(io, "CSRTuple{$P, NBlock=$NBlock, $PR, $AI, $VI}")
end

Base.length(field::CSRTuple{P, NBlock}) where {P, NBlock} = lengthElements(field) * NBlock
fullLength(field::CSRTuple{P, NBlock}) where {P, NBlock} = length(field._map)
lengthElements(field::CSRTuple{P, NBlock}) where {P<:CPU, NBlock} = field._N[1]
lengthElements(field::CSRTuple{P, NBlock}) where {P<:GPU, NBlock} = Array(field._N)[1]
lengthElementsCache(field::CSRTuple{P, NBlock}) where {P<:CPU, NBlock} = field._NCache[1]
lengthElementsCache(field::CSRTuple{P, NBlock}) where {P<:GPU, NBlock} = Array(field._NCache)[1]
lengthElementsAdded(field::CSRTuple{P, NBlock}) where {P<:CPU, NBlock} = field._NAdded[1]
lengthElementsAdded(field::CSRTuple{P, NBlock}) where {P<:GPU, NBlock} = Array(field._NAdded)[1]
lengthAdded(field::CSRTuple{P, NBlock}) where {P<:CPU, NBlock} = field._NAdded[1]*NBlock
lengthAdded(field::CSRTuple{P, NBlock}) where {P<:GPU, NBlock} = Array(field._NAdded)[1]*NBlock
lengthBlock(field::CSRTuple{P, NBlock}) where {P, NBlock} = NBlock

Base.size(field::CSRTuple) = size(field._map)

Base.eltype(::CSRTuple{P, NBlock, T}) where {P, NBlock, T} = T
Base.eltype(::Type{<:CSRTuple{P, NBlock, T}}) where {P, NBlock, T} = T

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
function iterateOverElement(mesh::CSRTuple{P, NBlock}, element::Int) where {P, NBlock}
    pos = element - 1
    return pos*NBlock:(pos*NBlock+NBlock)
end

# Helper function to calculate linear index in CSRTuple
function getElementIndex(field::CSRTuple{P, NBlock}, ePos::Int, bPos::Int=1) where {P, NBlock}
    return (ePos - 1) * NBlock + bPos
end

function setElementIndex!(field::CSRTuple{P, NBlock}, ePos::Int, bPos::Int, value) where {P, NBlock}
    pos = getElementIndex(field, ePos, bPos)
    field._map[pos] = value
end

function setElement!(field::CSRTuple{P, NBlock}, ePos::Int, value::T) where {P, NBlock, T}
    index = getElementIndex(field, ePos)
    field._map[index] = value
end

function setElement!(field::CSRTuple{P, NBlock}, ePos::Int, value::NTuple{NBlock, T}) where {P, NBlock, T}
    index = getElementIndex(field, ePos) - 1
    for j in 1:NBlock
        field._map[index + j] = value[j]
    end
end

function preallocate!(field::CSRTuple{P, NBlock}, NAddCache::Int=0) where {P, NBlock}
    
    @assert NAddCache >= 0 "NAddCache must be >= 0"

    N = lengthElements(field)
    oldNCache = lengthElementsCache(field)
    newNCache = N + NAddCache + lengthElementsAdded(field)

    if newNCache <= oldNCache
        return field
    else
        newSize = newNCache * NBlock

        resize!(field._map, newSize)
        resize!(field._addElementOffsets, newNCache + 1)
        resize!(field._childs, newNCache + 1)

        field._NCache .= newNCache

        return field
    end
end

function remap!(field::CSRTuple{P, NBlock, T}) where {P, NBlock, T}

    cumsum!(@view(field._addElementOffsets[1:lengthElements(field)+1]), @view(field._addElementOffsets[1:lengthElements(field)+1]))
    cumsum!(@view(field._childs[1:lengthElements(field)+1]), @view(field._childs[1:lengthElements(field)+1]))

    KernelAbstractions.@kernel function _kernel_remap!(map, addOffsets, auxiliar, N, NBlock)
        i = @index(Global)
        if addOffsets[i] > addOffsets[i+1]
            nothing
        else
            id = getElementIndex(field, i)
            idRemap = getElementIndex(field, i + addOffsets[i])
            for j in 0:NBlock-1
                auxiliar[idRemap + j] = map[id + j]
            end
        end
    end
    auxiliar = similar(field._map)
    device = KernelAbstractions.get_backend(field)
    threads = device === CPU ? Threads.nthreads() : 256
    _kernel_remap!(device, threads)(field._map, field._addElementOffsets, auxiliar, lengthElements(field), NBlock, ndrange=lengthElements(field))
    KernelAbstractions.synchronize(device)

    @views field._map[1:lengthElements(field)*NBlock] .= auxiliar[1:lengthElements(field)*NBlock]

    return
end

function reset!(field::CSRTuple{P, NBlock}) where {P, NBlock}
    field._NAdded .= 0
    field._addElementOffsets .= 0
    field._childs .= 0
    return
end

Base.@propagate_inbounds function memclaim_addElement!(field::CSRTuple{P, NBlock}; N::Int=1) where {P, NBlock}

    @atomic field._NAdded[1] += N

    return
end

Base.@propagate_inbounds function memclaim_addElement!(field::CSRTuple{P, NBlock}, i::Int; N::Int = 1) where {P, NBlock}

    @atomic field._NAdded[1] += N

    return
end

Base.@propagate_inbounds function allocate_addElement!(field::CSRTuple{P, NBlock}; N::Int=1) where {P, NBlock}

    @atomic field._childs[1] += N

    return
end

Base.@propagate_inbounds function allocate_addElement!(field::CSRTuple{P, NBlock}, i::Int; N::Int = 1) where {P, NBlock}

    @atomic field._childs[i+1] += N

    return
end

Base.@propagate_inbounds function execute_addElement!(field::CSRTuple{P, NBlock}) where {P, NBlock}

    if field._childs[1] > 0
        return field._N[1] + 1
    else
        return 0
    end

end

Base.@propagate_inbounds function execute_addElement!(field::CSRTuple{P, NBlock}, i::Int) where {P, NBlock}

    if field._childs[i+1] > field._childs[i]
        return field._N[1] + field._childs[i] + 1
    else
        return 0
    end

end

Base.@propagate_inbounds function memclaim_removeElement!(field::CSRTuple{P, NBlock}, i::Int) where {P, NBlock}

    return
end

Base.@propagate_inbounds function allocate_removeElement!(field::CSRTuple{P, NBlock}, i::Int) where {P, NBlock}

    @atomic field._NAdded[1] -= 1
    @atomic field._addElementOffsets[i+1] -= 1

    return
end

Base.@propagate_inbounds function execute_removeElement!(field::CSRTuple{P, NBlock}, i::Int) where {P, NBlock}

    return
end

function KernelAbstractions.get_backend(field::CSRTuple)
    KernelAbstractions.get_backend(field._map)
end

######################################################################################################
# toDevice - Device transfer functions for CSR structures
######################################################################################################

# CSRTuple to CPU
function toDevice(field::CSRTuple{P, NBlock}, ::Type{CPU}) where {P<:GPU, NBlock}
    CSRTuple(
        _NBlock,
        Adapt.adapt(Array, field._map),
        SizedVector{1}(Array(field._N)[1]),
        SizedVector{1}(Array(field._NCache)[1]),
        SizedVector{1}(Array(field._NAdded)[1]),
        Adapt.adapt(field._addElementOffsets),
        Adapt.adapt(field._childs),
    )
end
function toDevice(field::CSRTuple{P, NBlock}, device::CPU) where {P<:CPU, NBlock}
    toDevice(field, typeof(device))
end

toDevice(field::CSRTuple{P, NBlock}, ::Type{CPU}) where {P<:CPU, NBlock} = field
toDevice(field::CSRTuple{P, NBlock}, ::CPU) where {P<:GPU, NBlock} = toDevice(field, CPU)

function toDevice(field::CSRTuple{P,NBlock}, backend::Type{<:KernelAbstractions.GPU}) where {P<:CPU, NBlock}
    CSRTuple(
        field._NBlock,
        Adapt.adapt(backend, field._map),
        Adapt.adapt(backend, field._N),
        Adapt.adapt(backend, field._NCache),
        Adapt.adapt(backend, field._NAdded),
        Adapt.adapt(backend, field._addElementOffsets),
        Adapt.adapt(backend, field._childs),
    )
end

function toDevice(field::CSRTuple{P,NBlock}, backend::KernelAbstractions.GPU) where {P<:CPU, NBlock}
    toDevice(field, typeof(backend))
end

toDevice(field::CSRTuple{P,NBlock}, ::KernelAbstractions.GPU) where {P<:GPU,NBlock} = field
toDevice(field::CSRTuple{P,NBlock}, ::Type{<:KernelAbstractions.GPU}) where {P<:GPU,NBlock} = field