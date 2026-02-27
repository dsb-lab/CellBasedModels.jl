import CellBasedModels: fillPermTable!, iterateOverNeighbors

# toBackend for NeighborsFull - converts CPU NeighborsFull to GPU
function toBackend(neighbors::NeighborsFull{P, PT, AB}, backend::CUDA.CUDABackend) where {P<:CPU, PT, AB}
    permTable = neighbors.permTable === nothing ? nothing : CUDA.CuArray(neighbors.permTable)
    auxBuffers = neighbors.auxBuffers === nothing ? nothing : Adapt.adapt(CUDA.CuArray, neighbors.auxBuffers)
    return NeighborsFull{GPUCuda, typeof(permTable), typeof(auxBuffers)}(permTable, auxBuffers)
end

# Already on GPU - no conversion needed
toBackend(neighbors::NeighborsFull{P}, ::CUDA.CUDABackend) where {P<:GPUCuda} = neighbors

# toBackend for NeighborsFull - converts GPU NeighborsFull back to CPU
function toBackend(neighbors::NeighborsFull{P, PT, AB}, ::CPU) where {P<:GPU, PT, AB}
    permTable = neighbors.permTable === nothing ? nothing : Vector{Int}(neighbors.permTable)
    auxBuffers = neighbors.auxBuffers === nothing ? nothing : Adapt.adapt(Array, neighbors.auxBuffers)
    return NeighborsFull{CPU, typeof(permTable), typeof(auxBuffers)}(permTable, auxBuffers)
end

# Already on CPU - no conversion needed
toBackend(neighbors::NeighborsFull{P}, ::CPU) where {P<:CPU} = neighbors

# Fallback for nothing
toBackend(::Nothing, ::CUDA.CUDABackend) = nothing
toBackend(::Nothing, ::CPU) = nothing

function fillPermTable!(perm::CUDA.CuArray, flags::CUDA.CuArray, N::Int)
    # Parallelized version using prefix sum
    # Compute cumulative sum (parallel)
    @views CUDA.cumsum!(perm[1:N], flags[1:N])
    # Zero out removed elements (where original flag was false)
    @views perm[1:N] .*= flags[1:N]    
    # Reset flags in parallel
    @views flags[1:N] .= true
    
    # Return count of surviving elements
    return Array(perm[N:N])[1]
end

# GPU-compatible iterateOverNeighbors for NeighborsFull
# Specializes on fields with NeighborsFull{GPUCuda, ...} as the NN type parameter
@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN}, index::Int) where {P<:GPUCuda, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsFull}
    return 1:lengthProperties(field)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN}, ::Any) where {P<:GPUCuda, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsFull}
    return 1:lengthProperties(field)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN}, ::Any, ::Any) where {P<:GPUCuda, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsFull}
    return 1:lengthProperties(field)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN}, ::Any, ::Any, ::Any) where {P<:GPUCuda, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsFull}
    return 1:lengthProperties(field)
end

# GPU kernel adaptation: convert CuArray fields to CuDeviceArray for kernel execution
function Adapt.adapt_structure(to::CUDA.KernelAdaptor, neighbors::NeighborsFull{P, PT, AB}) where {P<:GPUCuda, PT, AB}
    permTable_adapted = neighbors.permTable === nothing ? nothing : Adapt.adapt(to, neighbors.permTable)
    auxBuffers_adapted = neighbors.auxBuffers === nothing ? nothing : Adapt.adapt(to, neighbors.auxBuffers)
    return NeighborsFull{GPUCuDevice, typeof(permTable_adapted), typeof(auxBuffers_adapted)}(
        permTable_adapted,
        auxBuffers_adapted
    )
end

# GPUCuDevice versions for use INSIDE kernels
@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN}, index::Int) where {P<:GPUCuDevice, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsFull}
    return 1:lengthProperties(field)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN}, ::Any) where {P<:GPUCuDevice, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsFull}
    return 1:lengthProperties(field)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN}, ::Any, ::Any) where {P<:GPUCuDevice, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsFull}
    return 1:lengthProperties(field)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN}, ::Any, ::Any, ::Any) where {P<:GPUCuDevice, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsFull}
    return 1:lengthProperties(field)
end
