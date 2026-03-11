import CellBasedModels: DATATYPE
import CellBasedModels: lengthCache, lengthProperties, lengthPropertiesNew, sizeFull, sizeFullCache, nCopyProperties
import CellBasedModels: UnstructuredMeshField, UnstructuredMeshFieldStyle, UnstructuredMeshObject, UnstructuredMeshObjectStyle, unpack_voa
import CellBasedModels: toBackend, CPU
import CellBasedModels: initNeighbors
import KernelAbstractions
import RecursiveArrayTools

lengthCache(field::UnstructuredMeshField{P}) where {P<:GPUCuda} = CUDA.@allowscalar field._NCache[1]
lengthCache(field::UnstructuredMeshField{P}) where {P<:GPUCuDevice} = field._NCache[1]
lengthProperties(field::UnstructuredMeshField{P}) where {P<:GPUCuda} = CUDA.@allowscalar field._N[1]
lengthProperties(field::UnstructuredMeshField{P}) where {P<:GPUCuDevice} = field._N[1]
lengthPropertiesNew(field::UnstructuredMeshField{P}) where {P<:GPUCuda} = CUDA.@allowscalar field._N[1] + field._NAdded[1]
lengthPropertiesNew(field::UnstructuredMeshField{P}) where {P<:GPUCuDevice} = field._N[1] + field._NAdded[1]
Base.length(field::UnstructuredMeshField{P}) where {P<:GPUCuda} = nCopyProperties(field) * CUDA.@allowscalar field._N[1]
Base.length(field::UnstructuredMeshField{P}) where {P<:GPUCuDevice} = nCopyProperties(field) * field._N[1]

sizeFull(field::UnstructuredMeshField{P}) where {P<:GPUCuda} = (field._NP, CUDA.@allowscalar field._N[1])
sizeFull(field::UnstructuredMeshField{P}) where {P<:GPUCuDevice} = (field._NP, field._N[1])
sizeFullCache(field::UnstructuredMeshField{P}) where {P<:GPUCuda} = (field._NP, CUDA.@allowscalar field._NCache[1])
sizeFullCache(field::UnstructuredMeshField{P}) where {P<:GPUCuDevice} = (field._NP, field._NCache[1])
Base.size(field::UnstructuredMeshField{P}) where {P<:GPUCuda} = (nCopyProperties(field), lengthProperties(field))
Base.size(field::UnstructuredMeshField{P}) where {P<:GPUCuDevice} = (nCopyProperties(field), lengthProperties(field))

# Base.length(field::UnstructuredMeshField{P}) where {P<:GPUCuda} = CUDA.@allowscalar field._N[1]
# Base.length(field::UnstructuredMeshField{P}) where {P<:GPUCuDevice} = field._N[1]
# lengthCache(field::UnstructuredMeshField{P}) where {P<:GPUCuda} = CUDA.@allowscalar field._NCache[1]
# lengthCache(field::UnstructuredMeshField{P}) where {P<:GPUCuDevice} = field._NCache[1]

# ########################################################################################
# # to CPU / to GPU conversions
# ########################################################################################
toBackend(field::UnstructuredMeshField{P}, ::CUDA.CUDABackend) where {P<:GPUCuda} = field

function toBackend(field::UnstructuredMeshField{P}, backend::CUDA.CUDABackend) where {P<:CPU}
    UnstructuredMeshField(
        field._p              === nothing ? nothing : Adapt.adapt(CUDA.CuArray, field._p),
        field._NP             === nothing ? nothing : field._NP,
        field._pReference     === nothing ? nothing : tuple(field._pReference...),
        field._id             === nothing ? nothing : CUDA.CuArray(field._id),
        field._idMax          === nothing ? nothing : CUDA.CuArray(field._idMax),
        field._nodes          === nothing ? nothing : CUDA.CuArray(field._nodes),
        field._N              === nothing ? nothing : CUDA.CuArray(field._N),
        field._NCache         === nothing ? nothing : CUDA.CuArray(field._NCache),
        field._FlagsSurvived  === nothing ? nothing : CUDA.CuArray(field._FlagsSurvived),
        field._NAdded         === nothing ? nothing : CUDA.CuArray([0]),
        field._NOverflow      === nothing ? nothing : CUDA.CuArray([0]),
        field._neighbors      === nothing ? nothing : toBackend(field._neighbors, backend),
        field._NFree          === nothing ? nothing : CUDA.CuArray(field._NFree),
        field._entriesFree    === nothing ? nothing : CUDA.CuArray(field._entriesFree),
        field._NFreeNextInit  === nothing ? nothing : CUDA.CuArray(field._NFreeNextInit),
        field._NFreeNext      === nothing ? nothing : CUDA.CuArray(field._NFreeNext),
    )
end

toBackend(mesh::UnstructuredMeshObject{P, D}, ::CUDA.CUDABackend) where {P<:GPUCuda, D} = mesh

function toBackend(field::UnstructuredMeshObject{P, D, S, DT, PAR, TOPO, AB}, backend::CUDA.CUDABackend) where {P<:CPU, D, S, DT, PAR, TOPO, AB}

    PNew = GPUCuda
    DTNew = DT <: AbstractFloat ? Float32 : DT

    p = NamedTuple{keys(field._p)}(
        toBackend(p, backend) for p in values(field._p)
    )
    t = toBackend(field.topo, backend)
    _FlagOverflow = CUDA.CuArray([false])

    PARNew = typeof(p)
    TOPONew = typeof(t)
    ABNew = typeof(_FlagOverflow)

    UnstructuredMeshObject{PNew, D, S, DTNew, PARNew, TOPONew, ABNew}(
        p,
        t,
        _FlagOverflow
    )
end

function KernelAbstractions.get_backend(::UnstructuredMeshObject{P}) where {P<:GPUCuda}
    return CUDA.CUDABackend()
end

########################################################################################
# GPU-specific recursivefill! for random number generation
########################################################################################

# GPU-specific recursivefill! for randn function
function RecursiveArrayTools.recursivefill!(
    dest::UnstructuredMeshField{P, DT, PR, PRN, PRC},
    value::typeof(randn)) where {P<:GPUCuda, DT, PR, PRN, PRC}
    N = lengthProperties(dest)
    @inbounds for i in 1:PRN
        if !dest._pReference[i]
            # Use CUDA.randn! for GPU-compatible random number generation
            view_arr = @view dest._p[i][1:N]
            CUDA.randn!(view_arr)
        end
    end
    dest
end

# GPU-specific recursivefill! for non-function values (scalar fill)
function RecursiveArrayTools.recursivefill!(
    dest::UnstructuredMeshField{P, DT, PR, PRN, PRC},
    value) where {P<:GPUCuda, DT, PR, PRN, PRC}
    N = lengthProperties(dest)
    @inbounds for i in 1:PRN
        if !dest._pReference[i]
            view_arr = @view dest._p[i][1:N]
            fill!(view_arr, value)
        end
    end
    dest
end

# GPU kernel adaptation: convert CuArray fields to CuDeviceArray for kernel execution
function Adapt.adapt_structure(to::CUDA.KernelAdaptor, field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}) where {P<:GPUCuda, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}
    _p_adapted = field._p === nothing ? nothing : Adapt.adapt(to, field._p)
    _id_adapted = field._id === nothing ? nothing : Adapt.adapt(to, field._id)
    _idMax_adapted = field._idMax === nothing ? nothing : Adapt.adapt(to, field._idMax)
    _nodes_adapted = field._nodes === nothing ? nothing : Adapt.adapt(to, field._nodes)
    _N_adapted = field._N === nothing ? nothing : Adapt.adapt(to, field._N)
    _NCache_adapted = field._NCache === nothing ? nothing : Adapt.adapt(to, field._NCache)
    _FlagsSurvived_adapted = field._FlagsSurvived === nothing ? nothing : Adapt.adapt(to, field._FlagsSurvived)
    _NAdded_adapted = field._NAdded === nothing ? nothing : Adapt.adapt(to, field._NAdded)
    _NOverflow_adapted = field._NOverflow === nothing ? nothing : Adapt.adapt(to, field._NOverflow)
    _neighbors_adapted = field._neighbors === nothing ? nothing : Adapt.adapt(to, field._neighbors)
    _NFree_adapted = field._NFree === nothing ? nothing : Adapt.adapt(to, field._NFree)
    _entriesFree_adapted = field._entriesFree === nothing ? nothing : Adapt.adapt(to, field._entriesFree)
    _NFreeNextInit_adapted = field._NFreeNextInit === nothing ? nothing : Adapt.adapt(to, field._NFreeNextInit)
    _NFreeNext_adapted = field._NFreeNext === nothing ? nothing : Adapt.adapt(to, field._NFreeNext)
    
    return UnstructuredMeshField{
        GPUCuDevice, DT,
        typeof(_p_adapted),
        PRN, PRC,
        typeof(_id_adapted),
        typeof(_idMax_adapted),
        typeof(_nodes_adapted),
        typeof(_N_adapted),
        typeof(_FlagsSurvived_adapted),
        typeof(_NOverflow_adapted),
        typeof(_neighbors_adapted),
        typeof(_entriesFree_adapted)
    }(
        _p_adapted,
        PRN,
        field._pReference,
        _id_adapted,
        _idMax_adapted,
        _nodes_adapted,
        _N_adapted,
        _NCache_adapted,
        _FlagsSurvived_adapted,
        _NAdded_adapted,
        _NOverflow_adapted,
        _neighbors_adapted,
        _NFree_adapted,
        _entriesFree_adapted,
        _NFreeNextInit_adapted,
        _NFreeNext_adapted
    )
end

# GPU kernel adaptation for UnstructuredMeshObject  
function Adapt.adapt_structure(to::CUDA.KernelAdaptor, obj::UnstructuredMeshObject{P, D, S, DT, PAR, TOPO, AB}) where {P<:GPUCuda, D, S, DT, PAR, TOPO, AB}
    _p_adapted = NamedTuple{keys(obj._p)}(
        Adapt.adapt(to, p) for p in values(obj._p)
    )
    _topology_adapted = Adapt.adapt(to, obj.topo)
    _FlagOverflow_adapted = Adapt.adapt(to, obj._FlagOverflow)
    
    return UnstructuredMeshObject{
        GPUCuDevice, D, S, DT,
        typeof(_p_adapted),
        typeof(_topology_adapted),
        typeof(_FlagOverflow_adapted)
    }(
        _p_adapted,
        _topology_adapted,
        _FlagOverflow_adapted
    )
end