import CellBasedModels: DATATYPE
import CellBasedModels: lengthCache, lengthProperties, lengthPropertiesNew, sizeFull, sizeFullCache, nCopyProperties
import CellBasedModels: UnstructuredMeshField, UnstructuredMeshFieldStyle, UnstructuredMeshObject, UnstructuredMeshObjectStyle, unpack_voa
import CellBasedModels: toDevice, CPU
import CellBasedModels: initNeighbors
import KernelAbstractions

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
toDevice(field::UnstructuredMeshField{P}, ::CUDA.CUDABackend) where {P<:CPU} = field

function toDevice(field::UnstructuredMeshField{P}, ::Type{CUDA.CUDABackend}) where {P<:CPU}
    UnstructuredMeshField(
        field._p              === nothing ? nothing : Adapt.adapt(CUDA.CuArray, field._p),
        field._NP             === nothing ? nothing : field._NP,
        field._pReference     === nothing ? nothing : tuple(field._pReference...),
        field._id             === nothing ? nothing : CUDA.CuArray(field._id),
        field._idMax          === nothing ? nothing : CUDA.CuArray(field._idMax),
        field._nodes1         === nothing ? nothing : CUDA.CuArray(field._nodes1),
        field._nodes2         === nothing ? nothing : CUDA.CuArray(field._nodes2),
        field._nodes3         === nothing ? nothing : CUDA.CuArray(field._nodes3),
        field._nodes4         === nothing ? nothing : CUDA.CuArray(field._nodes4),
        field._N              === nothing ? nothing : CUDA.CuArray(field._N),
        field._NCache         === nothing ? nothing : CUDA.CuArray(field._NCache),
        field._FlagsSurvived  === nothing ? nothing : CUDA.CuArray(field._FlagsSurvived),
        field._NRemoved       === nothing ? nothing : CUDA.CuArray([0]),
        field._NRemovedThread === nothing ? nothing : CUDA.zeros(0),
        field._NAdded         === nothing ? nothing : CUDA.CuArray([0]),
        field._NAddedThread   === nothing ? nothing : CUDA.zeros(0),
        field._AddedAgents    === nothing ? nothing : CUDA.zeros(0),
        field._FlagOverflow   === nothing ? nothing : CUDA.CuArray([false]),
    )
end

toDevice(mesh::UnstructuredMeshObject{D, P}, ::CUDA.CUDABackend) where {D, P<:GPUCuda} = mesh

function toDevice(field::UnstructuredMeshObject{P, D, S, DT, NN, PAR}, ::Type{CUDA.CUDABackend}) where {P<:CPU, D, S, DT, NN, PAR}

    PNew = GPUCuda
    DTNew = DT <: AbstractFloat ? Float32 : DT

    p = NamedTuple{keys(field._p)}(
        toDevice(p, CUDA.CUDABackend) for p in values(field._p)
    )
    n = initNeighborsGPU(D, field._neighbors, p)

    PARNew = typeof(p)
    NNNew = typeof(n)

    UnstructuredMeshObject{PNew, D, S, DTNew, NNNew, PARNew}(
        p,
        n
    )
end

function KernelAbstractions.get_backend(::UnstructuredMeshObject{P}) where {P<:GPUCuda}
    return CUDA.CUDABackend()
end