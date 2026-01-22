######################################################################################################
# CSRCache - Fixed-size tuples (block size is a type parameter)
######################################################################################################
struct CSRCache{
            P, T, PR, AI, VI, VI2
        } <: AbstractCSR

    _map::PR
    _elementOffsets::VI

    _N::AI
    _NCache::AI
    _NAdded::AI
    _lAdded::AI

    _addOffsets::VI2
    _addElementOffsets::VI
    _childs::VI
end
Adapt.@adapt_structure CSRCache

function CSRCache(
    l::Int,
    NCache::Int=N;
    dtype::DataType=Int,
)

    @assert l > 0 "Length must be > 0"
    @assert NCache >= 0 "NCache must be >= 0"

    _map = zeros(dtype, l)
    _elementOffsets = zeros(Int, NCache+1)

    _N = SizedVector{1}(0)
    _NCache = SizedVector{1}(NCache)
    _NAdded = SizedVector{1}(0)
    _lAdded = SizedVector{1}(0)

    _addOffsets = zeros(Int, l+1)
    _addElementOffsets = zeros(Int, NCache+1)
    _childs = zeros(Int, NCache+1)

    P = platform()
    T = eltype(_map)
    PR = typeof(_map)
    AI = typeof(_N)
    VI = typeof(_childs)
    VI2 = typeof(_addOffsets)

    CSRCache{
            P, T, PR, AI, VI, VI2
        }(
            _map,
            _elementOffsets,
            _N,
            _NCache,
            _NAdded,
            _lAdded,
            _addOffsets,
            _addElementOffsets,
            _childs,
        )
end

function CSRCache(
            _map,
            _elementOffsets,
            _N,
            _NCache,
            _NAdded,
            _lAdded,
            _addOffsets,
            _addElementOffsets,
            _childs,
        )
    
    P = platform()
    T = eltype(_map)
    PR = typeof(_map)
    AI = typeof(_N)
    VI = typeof(_childs)
    VI2 = typeof(_addOffsets)

    CSRCache{
            P, T, PR, AI, VI, VI2
        }(
            _map,
            _elementOffsets,
            _N,
            _NCache,
            _NAdded,
            _lAdded,
            _addOffsets,
            _addElementOffsets,
            _childs,
        )
end

function CSRCache(data::AbstractVector{<:Int}; additionalNCache::Int=0, additionalL::Int=0, dtype::DataType=Int)

    @assert additionalNCache >= 0 "additionalNCache must be >= 0"
    @assert additionalL >= 0 "additionalL must be >= 0"

    N = length(data)
    NCache = N + additionalNCache
    offsets = cumsum([1,data...])
    l = offsets[end] + additionalL - 1

    # Create CSRCache with appropriate size
    csr = CSRCache(
        l,
        NCache,
        dtype=dtype,
    )

    csr._N[1] = N
    csr._elementOffsets[1:N+1] .= offsets    

    return csr
end

function CSRCache(data::AbstractVector{<:AbstractVector{T}}; additionalNCache::Int=0, additionalL::Int=0) where {T}

    csr = CSRCache(
        length.(data),
        additionalNCache=additionalNCache,
        additionalL=additionalL,
        dtype=T,
    )

    # Fill data, padding with zeros if necessary
    for i in 1:lengthElements(csr)
        for j in 1:length(data[i])
            linear_idx = csr._elementOffsets[i] + j - 1
            csr._map[linear_idx] = data[i][j]
        end
    end

    return csr
end

function Base.show(io::IO, x::CSRCache{
            P, PR, AI, VI, VI2
        }) where {
            P, PR, AI, VI, VI2
        } 
    
    println(io, "CSRCache{N=$(lengthElements(x)), NCache=$(lengthElementsCache(x)), l=$(fullLength(x))}")    
end

function Base.show(io::IO, x::Type{CSRCache{P, PR, AI, VI, VI2}}) where {P, PR, AI, VI, VI2}
    println(io, "CSRCache{$P, $PR, $AI, $VI, $VI2}")
end

Base.length(field::CSRCache{P}) where {P<:CPU} = field._elementOffsets[lengthElements(field)+1] - 1
Base.length(field::CSRCache{P}) where {P<:GPU} = Array(field._elementOffsets)[lengthElements(field)+1] - 1
fullLength(field::CSRCache) = length(field._map)
lengthElements(field::CSRCache{P}) where {P<:CPU} = field._N[1]
lengthElements(field::CSRCache{P}) where {P<:GPU} = Array(field._N)[1]
lengthElementsCache(field::CSRCache{P}) where {P<:CPU} = field._NCache[1]
lengthElementsCache(field::CSRCache{P}) where {P<:GPU} = Array(field._NCache)[1]
lengthElementsAdded(field::CSRCache{P}) where {P<:CPU} = field._NAdded[1]
lengthElementsAdded(field::CSRCache{P}) where {P<:GPU} = Array(field._NAdded)[1]
lengthAdded(field::CSRCache{P}) where {P<:CPU} = field._lAdded[1]
lengthAdded(field::CSRCache{P}) where {P<:GPU} = Array(field._lAdded)[1]

Base.size(field::CSRCache) = size(field._map)

Base.eltype(::CSRCache{P, T}) where {P, T} = T
Base.eltype(::Type{<:CSRCache{P, T}}) where {P, T} = T

Base.getindex(field::CSRCache, i::Int) = field._map[i]

# Specialized iterator for CSRCache - iterates over active elements only
function Base.iterate(field::CSRCache{P, T}, state=(1, 1)) where {P, T}
    blockId, elementId = state
    
    # Check if we've exhausted all blocks
    if blockId > lengthElements(field)
        return nothing
    end
    
    # Calculate block size and linear index in _map
    block_size = field._elementOffsets[blockId+1] - field._elementOffsets[blockId]
    linear_idx = field._elementOffsets[blockId] + elementId - 1
    map_value = field._map[linear_idx]
    
    # Calculate next state: move to next element in current block or next block
    next_state = if elementId < block_size
        (blockId, elementId + 1)
    else
        (blockId + 1, 1)
    end
    
    return ((blockId, map_value), next_state)
end

iterateOverElements(mesh::CSRCache) = 1:lengthElements(mesh)
function iterateOverElement(mesh::CSRCache{P, T}, element::Int) where {P, T}
    return field._elementOffsets[element]:field._elementOffsets[element+1]-1
end

# Helper function to calculate linear index in CSRCache
function getElementIndex(field::CSRCache{P, T}, ePos::Int, bPos::Int=1) where {P, T}
    return field._elementOffsets[ePos] + bPos - 1
end

function setElementIndex!(field::CSRCache{P}, ePos::Int, bPos::Int, value) where {P}
    pos = getElementIndex(field, ePos, bPos)
    field._map[pos] = value
end

function setElement!(field::CSRCache{P}, ePos::Int, value::T) where {P, T}
    index = getElementIndex(field, ePos)
    field._map[index] = value
end

function setElement!(field::CSRCache{P}, ePos::Int, value::NTuple{NBlock, T}) where {P, NBlock, T}
    index = getElementIndex(field, ePos) - 1
    for j in 1:NBlock
        field._map[index + j] = value[j]
    end
end

function preallocate!(field::CSRCache{P}, NAddCache::Int=0, lAddCache::Int=0) where {P}
    
    @assert NAddCache >= 0 "NAddCache must be >= 0"
    @assert lAddCache >= 0 "lAddCache must be >= 0"

    N = lengthElements(field)
    oldNCache = lengthElementsCache(field)
    newNCache = N + NAddCache + lengthElementsAdded(field)
    oldLCache = fullLength(field)
    newLCache = oldLCache + lAddCache + lengthAdded(field)

    if newNCache > oldNCache
        resize!(field._elementOffsets, newNCache + 1)
        resize!(field._childs, newNCache + 1)

        field._NCache .= newNCache
    end

    if newLCache > oldLCache
        resize!(field._map, newLCache)
        resize!(field._addOffsets, lengthElements(field) + 1)
    end

    return field
end

function remap!(field::CSRCache{P, NBlock, T}) where {P, NBlock, T}

    cumsum!(@view(field._addOffsets[1:length(field)+1]), @view(field._addOffsets[1:length(field)+1]))

    cumsum!(@view(field._addElementOffsets[1:lengthElements(field)+1]), @view(field._addElementOffsets[1:lengthElements(field)+1]))
    cumsum!(@view(field._childs[1:lengthElements(field)+1]), @view(field._childs[1:lengthElements(field)+1]))

    KernelAbstractions.@kernel function _kernel_remap!(map, addElementOffsets, addOffsets, auxiliar, N, NBlock)
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
    _kernel_remap!(device, threads)(field._map, field._addOffsets, auxiliar, lengthElements(field), NBlock, ndrange=lengthElements(field))
    KernelAbstractions.synchronize(device)

    @views field._map[1:lengthElements(field)*NBlock] .= auxiliar[1:lengthElements(field)*NBlock]

    return
end

function reset!(field::CSRCache{P, NBlock}) where {P, NBlock}
    field._NAdded .= 0
    field._addOffsets .= 0
    field._childs .= 0
    return
end

Base.@propagate_inbounds function memclaim_addElement!(field::CSRCache{P}, l::Int) where {P}

    @atomic field._lAdded[1] += l
    @atomic field._NAdded[1] += 1

    return
end

# Base.@propagate_inbounds function memclaim_addElement!(field::CSRCache{P}, i::Int; l::Int) where {P}

#     @atomic field._lAdded[1] += l
#     @atomic field._NAdded[1] += 1

#     return
# end

# Base.@propagate_inbounds function memclaim_addElement!(field::CSRCache{P}; l::NTuple{N,Int}) where {P, N}

#     s = sum(l)
#     @atomic field._lAdded[1] += s
#     @atomic field._NAdded[1] += N

#     return
# end

# Base.@propagate_inbounds function memclaim_addElement!(field::CSRCache{P}, i::Int; l::NTuple{N,Int}) where {P, N}

#     s = sum(l)
#     @atomic field._lAdded[1] += s
#     @atomic field._NAdded[1] += N

#     return
# end

Base.@propagate_inbounds function allocate_addElement!(field::CSRCache{P}, l::Int) where {P}

    @atomic field._childs[1] += 1
    @atomic field._addOffsets[1] += l

    return
end

# Base.@propagate_inbounds function allocate_addElement!(field::CSRCache{P}, i::Int; l::Int) where {P}

#     @atomic field._childs[i+1] += 1
#     @atomic field._addOffsets[i+1] += l

#     return
# end

# Base.@propagate_inbounds function allocate_addElement!(field::CSRCache{P}; l::NTuple{N,Int}) where {P, N}

#     s = sum(l)
#     @atomic field._childs[1] += N
#     @atomic field._addOffsets[1] += s

#     return
# end

# Base.@propagate_inbounds function allocate_addElement!(field::CSRCache{P}, i::Int; l::NTuple{N,Int}) where {P, N}

#     s = sum(l)
#     @atomic field._childs[i+1] += N
#     @atomic field._addOffsets[i+1] += s

#     return
# end

# Base.@propagate_inbounds function execute_addElement!(field::CSRCache{P}; l::Int) where {P}

#     if field._childs[1] > 0
#         field._elementOffsets[lengthElements(field)+2] += l
#         return field._N[1] + 1
#     else
#         return 0
#     end

# end

# Base.@propagate_inbounds function execute_addElement!(field::CSRCache{P}; l::NTuple{N,Int}) where {P, N}

#     if field._childs[1] > 0
#         for i in 1:N
#             field._elementOffsets[lengthElements(field)+2+i] += l[i]
#         end
#         return field._N[1] + 1
#     else
#         return 0
#     end

# end

# Base.@propagate_inbounds function execute_addElement!(field::CSRCache{P}, i::Int; l::Int) where {P}

#     if field._childs[i+1] > field._childs[i]
#         c = field._childs[i]
#         field._elementOffsets[lengthElements(field)+2+c] += l
#         return field._N[1] + field._childs[i] + 1
#     else
#         return 0
#     end

# end

# Base.@propagate_inbounds function memclaim_removeElement!(field::CSRCache{P, NBlock}, i::Int) where {P, NBlock}

#     return
# end

# Base.@propagate_inbounds function allocate_removeElement!(field::CSRCache{P, NBlock}, i::Int) where {P, NBlock}

#     @atomic field._NAdded[1] -= 1
#     @atomic field._addOffsets[i+1] -= 1

#     return
# end

# Base.@propagate_inbounds function execute_removeElement!(field::CSRCache{P, NBlock}, i::Int) where {P, NBlock}

#     return
# end

function KernelAbstractions.get_backend(field::CSRCache)
    KernelAbstractions.get_backend(field._map)
end

######################################################################################################
# toDevice - Device transfer functions for CSR structures
######################################################################################################

# CSRCache to CPU
function toDevice(field::CSRCache{P}, ::Type{CPU}) where {P<:GPU}
    CSRCache(
        Adapt.adapt(Array, field._map),
        Adapt.adapt(Array, field._elementOffsets),
        SizedVector{1}(Array(field._N)[1]),
        SizedVector{1}(Array(field._NCache)[1]),
        SizedVector{1}(Array(field._NAdded)[1]),
        SizedVector{1}(Array(field._lAdded)[1]),
        Adapt.adapt(Array, field._addOffsets),
        Adapt.adapt(Array, field._addElementOffsets),
        Adapt.adapt(Array, field._childs),
    )
end
function toDevice(field::CSRCache{P}, device::CPU) where {P<:CPU}
    toDevice(field, typeof(device))
end

toDevice(field::CSRCache{P}, ::Type{CPU}) where {P<:CPU} = field
toDevice(field::CSRCache{P}, ::CPU) where {P<:GPU} = toDevice(field, CPU)

function toDevice(field::CSRCache{P}, backend::Type{<:KernelAbstractions.GPU}) where {P<:CPU}
    CSRCache(
        Adapt.adapt(backend, field._map),
        Adapt.adapt(backend, field._elementOffsets),
        Adapt.adapt(backend, field._N),
        Adapt.adapt(backend, field._NCache),
        Adapt.adapt(backend, field._NAdded),
        Adapt.adapt(backend, field._lAdded),
        Adapt.adapt(backend, field._addOffsets),
        Adapt.adapt(backend, field._addElementOffsets),
        Adapt.adapt(backend, field._childs),
    )
end

function toDevice(field::CSRCache{P}, backend::KernelAbstractions.GPU) where {P<:CPU}
    toDevice(field, typeof(backend))
end

toDevice(field::CSRCache{P}, ::KernelAbstractions.GPU) where {P<:GPU} = field
toDevice(field::CSRCache{P}, ::Type{<:KernelAbstractions.GPU}) where {P<:GPU} = field