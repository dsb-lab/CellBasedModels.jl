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
    )
end

toBackend(mesh::UnstructuredMeshObject{D, P}, ::CUDA.CUDABackend) where {D, P<:GPUCuda} = mesh

function toBackend(field::UnstructuredMeshObject{P, D, S, DT, NN, PAR, TOPO, AB}, backend::CUDA.CUDABackend) where {P<:CPU, D, S, DT, NN, PAR, TOPO, AB}

    PNew = GPUCuda
    DTNew = DT <: AbstractFloat ? Float32 : DT

    p = NamedTuple{keys(field._p)}(
        toBackend(p, backend) for p in values(field._p)
    )
    n = initNeighborsGPU(D, field._neighbors, p)
    t = toBackend(field._topology, backend)
    _FlagOverflow = CUDA.CuArray([false])

    PARNew = typeof(p)
    NNNew = typeof(n)
    TOPONew = typeof(t)
    ABNew = typeof(_FlagOverflow)

    UnstructuredMeshObject{PNew, D, S, DTNew, NNNew, PARNew, TOPONew, ABNew}(
        p,
        n,
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