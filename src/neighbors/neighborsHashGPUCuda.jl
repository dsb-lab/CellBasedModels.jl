import CellBasedModels: positionToCell, mortonEncode, getNeighborCells1D, getNeighborCells2D, getNeighborCells3D
import CellBasedModels: getNeighborCells1DPeriodic, getNeighborCells2DPeriodic, getNeighborCells3DPeriodic
import CellBasedModels: CurveType, CURVE_MORTON, CURVE_HILBERT
import CellBasedModels: iterateOverNeighbors, update!, lengthProperties, toBackend

"""
GPU implementation of NeighborsHash using sorted Morton codes instead of hash tables.

On GPU, we use a different approach than CPU:
1. Compute Morton code for each particle
2. Sort particles by Morton code
3. Build segment offsets (like CellLinked but sparse)
4. Use binary search or segment lookup for neighbor iteration
"""

# toBackend for NeighborsHash - converts CPU field-level to GPU
# For GPU, we convert the pre-allocated arrays from initFieldNeighbors to CuArrays
function toBackend(neighbors::NeighborsHash{D, P, UM, CS, HT, Per}, backend::CUDA.CUDABackend) where {D, P<:CPU, UM, CS, HT, Per}
    # For field-level neighbors, HT is a NamedTuple with arrays
    # Convert them to CuArrays for GPU
    if neighbors.hashTable isa NamedTuple
        hashTable_gpu = (
            mortonCodes = CUDA.CuArray(neighbors.hashTable.mortonCodes),
            sortedIndices = CUDA.CuArray(neighbors.hashTable.sortedIndices),
            sortPerm = CUDA.CuArray(neighbors.hashTable.sortPerm),
            uniqueCodes = CUDA.CuArray(neighbors.hashTable.uniqueCodes),
            codeOffsets = CUDA.CuArray(neighbors.hashTable.codeOffsets),
            numUniqueCodes = CUDA.CuArray(neighbors.hashTable.numUniqueCodes),
            # cpuDict is not used on GPU
        )
        return NeighborsHash{
            D, GPUCuda,
            Nothing,
            CS,
            typeof(hashTable_gpu),
            Per,
        }(
            nothing,
            neighbors.cellSize,
            hashTable_gpu,
            neighbors.periodic,
            neighbors.curveType,
        )
    else
        # Old-style Dict or nothing - create empty GPU structure
        # This path is for backwards compatibility or mesh-level conversion
        return NeighborsHash{
            D, GPUCuda,
            Nothing,
            CS,
            Nothing,
            Per,
        }(
            nothing,
            neighbors.cellSize,
            nothing,
            neighbors.periodic,
            neighbors.curveType,
        )
    end
end

# Already on GPU - no conversion needed
toBackend(neighbors::NeighborsHash{D, P}, ::CUDA.CUDABackend) where {D, P<:GPUCuda} = neighbors

# toBackend for NeighborsHash - converts GPU field-level back to CPU
function toBackend(neighbors::NeighborsHash{D, P, UM, CS, HT, Per}, ::CPU) where {D, P<:GPU, UM, CS, HT, Per}
    # Convert GPU arrays back to CPU arrays if present
    if neighbors.hashTable isa NamedTuple
        N = length(neighbors.hashTable.mortonCodes)
        hashTable_cpu = (
            mortonCodes = Array(neighbors.hashTable.mortonCodes),
            sortedIndices = Array(neighbors.hashTable.sortedIndices),
            sortPerm = Array(neighbors.hashTable.sortPerm),
            uniqueCodes = Array(neighbors.hashTable.uniqueCodes),
            codeOffsets = Array(neighbors.hashTable.codeOffsets),
            numUniqueCodes = Array(neighbors.hashTable.numUniqueCodes),
            cpuDict = Dict{UInt64, Vector{Int}}(),  # Fresh dict for CPU iteration
        )
        return NeighborsHash{
            D, CPU,
            Nothing,
            CS,
            typeof(hashTable_cpu),
            Per,
        }(
            nothing,
            neighbors.cellSize,
            hashTable_cpu,
            neighbors.periodic,
            neighbors.curveType,
        )
    else
        # Old-style nothing - create empty CPU structure
        return NeighborsHash{
            D, CPU,
            Nothing,
            CS,
            Dict{UInt64, Vector{Int}},
            Per,
        }(
            nothing,
            neighbors.cellSize,
            Dict{UInt64, Vector{Int}}(),
            neighbors.periodic,
            neighbors.curveType,
        )
    end
end

# Already on CPU - no conversion needed
toBackend(neighbors::NeighborsHash{D, P}, ::CPU) where {D, P<:CPU} = neighbors

# GPU kernel adaptation: convert NeighborsHash for use inside GPU kernels
function Adapt.adapt_structure(to::CUDA.KernelAdaptor, neighbors::NeighborsHash{D, P, UM, CS, HT, Per}) where {D, P<:GPUCuda, UM, CS, HT, Per}
    # Adapt the hashTable arrays for kernel use
    adapted_hashTable = if neighbors.hashTable isa NamedTuple
        (
            mortonCodes = Adapt.adapt(to, neighbors.hashTable.mortonCodes),
            sortedIndices = Adapt.adapt(to, neighbors.hashTable.sortedIndices),
            sortPerm = Adapt.adapt(to, neighbors.hashTable.sortPerm),
            uniqueCodes = Adapt.adapt(to, neighbors.hashTable.uniqueCodes),
            codeOffsets = Adapt.adapt(to, neighbors.hashTable.codeOffsets),
            numUniqueCodes = Adapt.adapt(to, neighbors.hashTable.numUniqueCodes),
        )
    else
        nothing
    end
    return NeighborsHash{D, GPUCuDevice, Nothing, CS, typeof(adapted_hashTable), Per}(
        nothing,
        neighbors.cellSize,
        adapted_hashTable,  # Use adapted hashTable for kernels
        neighbors.periodic,
        neighbors.curveType,
    )
end

# GPU-specific field-level iterateOverNeighbors for NeighborsHash
# Uses HashNeighborIteratorGPU for actual neighbor iteration
@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}, x) where {P<:GPUCuda, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsHash{1}, FI}
    n = field._neighbors
    if n.hashTable === nothing
        return 1:lengthProperties(field)  # Fallback
    end
    ht = n.hashTable
    
    ix = floor(Int, x / n.cellSize[1])
    neighborCodes = if n.periodic !== nothing
        # Wrap current cell index to match assignment
        ix = mod(ix, n.periodic[1])
        neighborMortonCodes1DPeriodic(ix, n.periodic[1])
    else
        neighborMortonCodes1D(ix)
    end
    numUnique = ht.numUniqueCodes[1]
    
    return HashNeighborIteratorGPU(ht.uniqueCodes, ht.codeOffsets, ht.sortedIndices, neighborCodes, numUnique)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}, x, y) where {P<:GPUCuda, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsHash{2}, FI}
    n = field._neighbors
    if n.hashTable === nothing
        return 1:lengthProperties(field)  # Fallback
    end
    ht = n.hashTable
    
    ix = floor(Int, x / n.cellSize[1])
    iy = floor(Int, y / n.cellSize[2])
    neighborCodes = if n.periodic !== nothing
        # Wrap current cell indices to match assignment
        ix = mod(ix, n.periodic[1])
        iy = mod(iy, n.periodic[2])
        neighborMortonCodes2DPeriodic(ix, iy, n.periodic[1], n.periodic[2])
    else
        neighborMortonCodes2D(ix, iy)
    end
    numUnique = ht.numUniqueCodes[1]
    
    return HashNeighborIteratorGPU(ht.uniqueCodes, ht.codeOffsets, ht.sortedIndices, neighborCodes, numUnique)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}, x, y, z) where {P<:GPUCuda, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsHash{3}, FI}
    n = field._neighbors
    if n.hashTable === nothing
        return 1:lengthProperties(field)  # Fallback
    end
    ht = n.hashTable
    
    ix = floor(Int, x / n.cellSize[1])
    iy = floor(Int, y / n.cellSize[2])
    iz = floor(Int, z / n.cellSize[3])
    neighborCodes = if n.periodic !== nothing
        # Wrap current cell indices to match assignment
        ix = mod(ix, n.periodic[1])
        iy = mod(iy, n.periodic[2])
        iz = mod(iz, n.periodic[3])
        neighborMortonCodes3DPeriodic(ix, iy, iz, n.periodic[1], n.periodic[2], n.periodic[3])
    else
        neighborMortonCodes3D(ix, iy, iz)
    end
    numUnique = ht.numUniqueCodes[1]
    
    return HashNeighborIteratorGPU(ht.uniqueCodes, ht.codeOffsets, ht.sortedIndices, neighborCodes, numUnique)
end

# GPUCuDevice versions (inside kernels)
@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}, x) where {P<:GPUCuDevice, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsHash{1}, FI}
    n = field._neighbors
    if n.hashTable === nothing
        return 1:lengthProperties(field)  # Fallback
    end
    ht = n.hashTable
    
    ix = floor(Int, x / n.cellSize[1])
    neighborCodes = if n.periodic !== nothing
        # Wrap current cell index to match assignment
        ix = mod(ix, n.periodic[1])
        neighborMortonCodes1DPeriodic(ix, n.periodic[1])
    else
        neighborMortonCodes1D(ix)
    end
    numUnique = ht.numUniqueCodes[1]
    
    return HashNeighborIteratorGPU(ht.uniqueCodes, ht.codeOffsets, ht.sortedIndices, neighborCodes, numUnique)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}, x, y) where {P<:GPUCuDevice, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsHash{2}, FI}
    n = field._neighbors
    if n.hashTable === nothing
        return 1:lengthProperties(field)  # Fallback
    end
    ht = n.hashTable
    
    ix = floor(Int, x / n.cellSize[1])
    iy = floor(Int, y / n.cellSize[2])
    neighborCodes = if n.periodic !== nothing
        # Wrap current cell indices to match assignment
        ix = mod(ix, n.periodic[1])
        iy = mod(iy, n.periodic[2])
        neighborMortonCodes2DPeriodic(ix, iy, n.periodic[1], n.periodic[2])
    else
        neighborMortonCodes2D(ix, iy)
    end
    numUnique = ht.numUniqueCodes[1]
    
    return HashNeighborIteratorGPU(ht.uniqueCodes, ht.codeOffsets, ht.sortedIndices, neighborCodes, numUnique)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}, x, y, z) where {P<:GPUCuDevice, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsHash{3}, FI}
    n = field._neighbors
    if n.hashTable === nothing
        return 1:lengthProperties(field)  # Fallback
    end
    ht = n.hashTable
    
    ix = floor(Int, x / n.cellSize[1])
    iy = floor(Int, y / n.cellSize[2])
    iz = floor(Int, z / n.cellSize[3])
    neighborCodes = if n.periodic !== nothing
        # Wrap current cell indices to match assignment
        ix = mod(ix, n.periodic[1])
        iy = mod(iy, n.periodic[2])
        iz = mod(iz, n.periodic[3])
        neighborMortonCodes3DPeriodic(ix, iy, iz, n.periodic[1], n.periodic[2], n.periodic[3])
    else
        neighborMortonCodes3D(ix, iy, iz)
    end
    numUnique = ht.numUniqueCodes[1]
    
    return HashNeighborIteratorGPU(ht.uniqueCodes, ht.codeOffsets, ht.sortedIndices, neighborCodes, numUnique)
end

# GPU-specific field-level update for NeighborsHash
# Computes Morton codes, sorts particles, and builds segment offsets
function update!(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}) where {P<:GPUCuda, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsHash, FI}
    neighbors = field._neighbors
    
    # Check if we have the required arrays
    if neighbors.hashTable === nothing
        return nothing  # Fallback - no arrays available
    end
    
    ht = neighbors.hashTable
    D = length(neighbors.cellSize)
    N = lengthProperties(field)
    
    if N == 0
        ht.numUniqueCodes[1] = 0
        return nothing
    end
    
    # Step 1: Compute Morton codes (with periodic wrapping if needed)
    if D == 1
        computeMortonCodes1D!(ht.mortonCodes, field._p.x, N, neighbors.cellSize[1], neighbors.periodic)
    elseif D == 2
        computeMortonCodes2D!(ht.mortonCodes, field._p.x, field._p.y, N, neighbors.cellSize, neighbors.periodic)
    else
        computeMortonCodes3D!(ht.mortonCodes, field._p.x, field._p.y, field._p.z, N, neighbors.cellSize, neighbors.periodic)
    end
    
    # Step 2: Sort particles by Morton code
    # Get sort permutation (on GPU using sortperm_view)
    sortPerm = sortperm(view(ht.mortonCodes, 1:N))
    ht.sortPerm[1:N] .= sortPerm
    
    # Create sorted indices (original particle indices in Morton order)
    ht.sortedIndices[1:N] .= 1:N
    ht.sortedIndices[1:N] .= ht.sortedIndices[sortPerm]
    
    # Step 3: Build segment offsets for unique Morton codes
    sortedCodes = ht.mortonCodes[sortPerm]
    buildSegmentOffsets!(ht.uniqueCodes, ht.codeOffsets, ht.numUniqueCodes, sortedCodes, N)

    return nothing
end

function initNeighborsGPU(
        dims, 
        neighbors::NeighborsHash,
        meshParameters::NamedTuple
    )

    D = dims

    if dims < 1 || dims > 3
        error("NeighborsHash only supports 1D, 2D, or 3D. Found dims=$dims")
    end

    cellSize = neighbors.cellSize
    if cellSize isa Number
        cellSize = ntuple(_ -> cellSize, D)
    elseif cellSize isa Tuple
        if length(cellSize) != D
            error("Cell size mismatch. Expected length $(D), found length $(length(cellSize))")
        end
    elseif cellSize isa AbstractVector
        cellSize = Tuple(cellSize)
        if length(cellSize) != D
            error("Cell size mismatch. Expected length $(D), found length $(length(cellSize))")        
        end
    else
        error("Cell size must be a Number, Tuple, or Vector. Found type $(typeof(cellSize))")
    end

    # GPU-specific data structures for sorted Morton approach
    # mortonCodes: Morton code for each particle
    # sortedIndices: particle indices sorted by Morton code
    # uniqueCodes: unique Morton codes (sparse cell list)
    # codeOffsets: start index in sortedIndices for each unique code
    
    hashTables = Dict()
    
    for (name, prop) in pairs(meshParameters)
        N = lengthCache(prop)
        hashTables[name] = (
            mortonCodes = CUDA.zeros(UInt64, N),
            sortedIndices = CUDA.zeros(Int, N),
            sortPerm = CUDA.zeros(Int, N),
            # For segment-based lookup
            uniqueCodes = CUDA.zeros(UInt64, N),  # Worst case: all unique
            codeOffsets = CUDA.zeros(Int, N + 1),
            numUniqueCodes = CUDA.zeros(Int, 1),
        )
    end
    
    hashTableNamed = NamedTuple{tuple(keys(hashTables)...)}(values(hashTables))

    NeighborsHash{
        D, GPUCuda, 
        typeof(meshParameters), 
        typeof(cellSize),
        typeof(hashTableNamed),
        typeof(neighbors.periodic),
    }(meshParameters, cellSize, hashTableNamed, neighbors.periodic, neighbors.curveType)

end

# GPU kernel to compute Morton codes for 1D
function computeMortonCodes1D!(mortonCodes, x, N, cellSize, periodic)
    function kernel(mortonCodes, x, N, cellSize, periodic)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            ix = floor(Int, x[i] / cellSize)
            # Wrap for periodic boundaries
            if periodic !== nothing
                ix = mod(ix, periodic[1])
            end
            # Shift to positive range for Morton encoding
            mortonCodes[i] = UInt64(ix + (1 << 30))
        end
        return nothing
    end
    
    threads = 256
    blocks = cld(N, threads)
    CUDA.@cuda threads=threads blocks=blocks kernel(mortonCodes, x, N, cellSize, periodic)
    CUDA.synchronize()
end

# GPU kernel to compute Morton codes for 2D
function computeMortonCodes2D!(mortonCodes, x, y, N, cellSize, periodic)
    function kernel(mortonCodes, x, y, N, cellSize, periodic)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            ix = floor(Int, x[i] / cellSize[1])
            iy = floor(Int, y[i] / cellSize[2])
            
            # Wrap for periodic boundaries
            if periodic !== nothing
                ix = mod(ix, periodic[1])
                iy = mod(iy, periodic[2])
            end
            
            # Shift to positive range
            ux = UInt64(ix + (1 << 30))
            uy = UInt64(iy + (1 << 30))
            
            # Interleave bits for Morton code
            ux = (ux | (ux << 16)) & 0x0000FFFF0000FFFF
            ux = (ux | (ux << 8))  & 0x00FF00FF00FF00FF
            ux = (ux | (ux << 4))  & 0x0F0F0F0F0F0F0F0F
            ux = (ux | (ux << 2))  & 0x3333333333333333
            ux = (ux | (ux << 1))  & 0x5555555555555555
            
            uy = (uy | (uy << 16)) & 0x0000FFFF0000FFFF
            uy = (uy | (uy << 8))  & 0x00FF00FF00FF00FF
            uy = (uy | (uy << 4))  & 0x0F0F0F0F0F0F0F0F
            uy = (uy | (uy << 2))  & 0x3333333333333333
            uy = (uy | (uy << 1))  & 0x5555555555555555
            
            mortonCodes[i] = ux | (uy << 1)
        end
        return nothing
    end
    
    threads = 256
    blocks = cld(N, threads)
    CUDA.@cuda threads=threads blocks=blocks kernel(mortonCodes, x, y, N, cellSize, periodic)
    CUDA.synchronize()
end

# GPU kernel to compute Morton codes for 3D
function computeMortonCodes3D!(mortonCodes, x, y, z, N, cellSize, periodic)
    function kernel(mortonCodes, x, y, z, N, cellSize, periodic)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            ix = floor(Int, x[i] / cellSize[1])
            iy = floor(Int, y[i] / cellSize[2])
            iz = floor(Int, z[i] / cellSize[3])
            
            # Wrap for periodic boundaries
            if periodic !== nothing
                ix = mod(ix, periodic[1])
                iy = mod(iy, periodic[2])
                iz = mod(iz, periodic[3])
            end
            
            # Shift to positive range
            ux = UInt64(ix + (1 << 20))
            uy = UInt64(iy + (1 << 20))
            uz = UInt64(iz + (1 << 20))
            
            # Interleave bits for 3D Morton code
            ux = (ux | (ux << 32)) & 0x1f00000000ffff
            ux = (ux | (ux << 16)) & 0x1f0000ff0000ff
            ux = (ux | (ux << 8))  & 0x100f00f00f00f00f
            ux = (ux | (ux << 4))  & 0x10c30c30c30c30c3
            ux = (ux | (ux << 2))  & 0x1249249249249249
            
            uy = (uy | (uy << 32)) & 0x1f00000000ffff
            uy = (uy | (uy << 16)) & 0x1f0000ff0000ff
            uy = (uy | (uy << 8))  & 0x100f00f00f00f00f
            uy = (uy | (uy << 4))  & 0x10c30c30c30c30c3
            uy = (uy | (uy << 2))  & 0x1249249249249249
            
            uz = (uz | (uz << 32)) & 0x1f00000000ffff
            uz = (uz | (uz << 16)) & 0x1f0000ff0000ff
            uz = (uz | (uz << 8))  & 0x100f00f00f00f00f
            uz = (uz | (uz << 4))  & 0x10c30c30c30c30c3
            uz = (uz | (uz << 2))  & 0x1249249249249249
            
            mortonCodes[i] = ux | (uy << 1) | (uz << 2)
        end
        return nothing
    end
    
    threads = 256
    blocks = cld(N, threads)
    CUDA.@cuda threads=threads blocks=blocks kernel(mortonCodes, x, y, z, N, cellSize, periodic)
    CUDA.synchronize()
end

# Build segment offsets from sorted Morton codes
function buildSegmentOffsets!(uniqueCodes, codeOffsets, numUniqueCodes, sortedCodes, N)
    # Mark segment boundaries
    function mark_boundaries_kernel(boundaries, sortedCodes, N)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            if i == 1 || sortedCodes[i] != sortedCodes[i-1]
                boundaries[i] = 1
            else
                boundaries[i] = 0
            end
        end
        return nothing
    end
    
    boundaries = CUDA.zeros(Int, N)
    threads = 256
    blocks = cld(N, threads)
    CUDA.@cuda threads=threads blocks=blocks mark_boundaries_kernel(boundaries, sortedCodes, N)
    CUDA.synchronize()
    
    # Prefix sum to get segment IDs
    segmentIds = CUDA.cumsum(boundaries)
    numUnique = Array(segmentIds[N:N])[1]
    
    # Store number of unique codes (use fill! to avoid scalar indexing)
    fill!(numUniqueCodes, numUnique)
    
    # Extract unique codes and their offsets
    function extract_segments_kernel(uniqueCodes, codeOffsets, sortedCodes, segmentIds, N)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            segId = segmentIds[i]
            if i == 1 || sortedCodes[i] != sortedCodes[i-1]
                uniqueCodes[segId] = sortedCodes[i]
                codeOffsets[segId] = i
            end
            # Mark end of last segment
            if i == N
                codeOffsets[segId + 1] = N + 1
            end
        end
        return nothing
    end
    
    CUDA.@cuda threads=threads blocks=blocks extract_segments_kernel(
        uniqueCodes, codeOffsets, sortedCodes, segmentIds, N)
    CUDA.synchronize()
    
    return numUnique
end

# Update function for GPU NeighborsHash
function update!(mesh::UnstructuredMeshObject{GPUCuda, D, S, DT, NN, PAR}) where {D, S, DT, NN<:NeighborsHash, PAR}
    neighbors = mesh._neighbors
    
    for (name, prop) in pairs(mesh._p)
        N = lengthProperties(prop)
        ht = neighbors.hashTable[name]
        
        # Step 1: Compute Morton codes
        if D == 1
            computeMortonCodes1D!(ht.mortonCodes, prop.x, N, neighbors.cellSize[1])
        elseif D == 2
            computeMortonCodes2D!(ht.mortonCodes, prop.x, prop.y, N, neighbors.cellSize)
        else
            computeMortonCodes3D!(ht.mortonCodes, prop.x, prop.y, prop.z, N, neighbors.cellSize)
        end
        
        # Step 2: Sort particles by Morton code
        # Get sort permutation
        sortPerm = sortperm(ht.mortonCodes[1:N])
        ht.sortPerm[1:N] .= sortPerm
        
        # Create sorted indices (original particle indices in Morton order)
        ht.sortedIndices[1:N] .= 1:N
        ht.sortedIndices[1:N] .= ht.sortedIndices[sortPerm]
        
        # Step 3: Build segment offsets for unique Morton codes
        sortedCodes = ht.mortonCodes[sortPerm]
        buildSegmentOffsets!(ht.uniqueCodes, ht.codeOffsets, ht.numUniqueCodes, sortedCodes, N)
    end

    return nothing
end

# GPU iterator for hash-based neighbors using sorted Morton approach
struct HashNeighborIteratorGPU{UC, CO, SI, NC, NU}
    uniqueCodes::UC      # Sorted unique Morton codes
    codeOffsets::CO      # Offsets into sortedIndices
    sortedIndices::SI    # Particle indices sorted by Morton code
    neighborCodes::NC    # Morton codes of neighbor cells to search
    numUnique::NU        # Number of unique codes
end

# Binary search for Morton code in sorted unique codes array
@inline function binarySearchCode(uniqueCodes, code, numUnique)
    lo = 1
    hi = numUnique
    while lo <= hi
        mid = (lo + hi) ÷ 2
        @inbounds midCode = uniqueCodes[mid]
        if midCode == code
            return mid
        elseif midCode < code
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    return 0  # Not found
end

# GPU-compatible Morton encode (inlined, no allocation)
@inline function mortonEncode3D_GPU(ix::Int, iy::Int, iz::Int)
    x = UInt64(ix + (1 << 20))
    y = UInt64(iy + (1 << 20))
    z = UInt64(iz + (1 << 20))
    
    x = (x | (x << 32)) & 0x1f00000000ffff
    x = (x | (x << 16)) & 0x1f0000ff0000ff
    x = (x | (x << 8))  & 0x100f00f00f00f00f
    x = (x | (x << 4))  & 0x10c30c30c30c30c3
    x = (x | (x << 2))  & 0x1249249249249249
    
    y = (y | (y << 32)) & 0x1f00000000ffff
    y = (y | (y << 16)) & 0x1f0000ff0000ff
    y = (y | (y << 8))  & 0x100f00f00f00f00f
    y = (y | (y << 4))  & 0x10c30c30c30c30c3
    y = (y | (y << 2))  & 0x1249249249249249
    
    z = (z | (z << 32)) & 0x1f00000000ffff
    z = (z | (z << 16)) & 0x1f0000ff0000ff
    z = (z | (z << 8))  & 0x100f00f00f00f00f
    z = (z | (z << 4))  & 0x10c30c30c30c30c3
    z = (z | (z << 2))  & 0x1249249249249249
    
    return x | (y << 1) | (z << 2)
end

@inline function mortonEncode2D_GPU(ix::Int, iy::Int)
    x = UInt64(ix + (1 << 30))
    y = UInt64(iy + (1 << 30))
    
    x = (x | (x << 16)) & 0x0000FFFF0000FFFF
    x = (x | (x << 8))  & 0x00FF00FF00FF00FF
    x = (x | (x << 4))  & 0x0F0F0F0F0F0F0F0F
    x = (x | (x << 2))  & 0x3333333333333333
    x = (x | (x << 1))  & 0x5555555555555555
    
    y = (y | (y << 16)) & 0x0000FFFF0000FFFF
    y = (y | (y << 8))  & 0x00FF00FF00FF00FF
    y = (y | (y << 4))  & 0x0F0F0F0F0F0F0F0F
    y = (y | (y << 2))  & 0x3333333333333333
    y = (y | (y << 1))  & 0x5555555555555555
    
    return x | (y << 1)
end

@inline function mortonEncode1D_GPU(ix::Int)
    return UInt64(ix + (1 << 30))
end

# Generate explicit 27-tuple of neighbor Morton codes for 3D (no ntuple closure)
@inline function neighborMortonCodes3D(ix::Int, iy::Int, iz::Int)::NTuple{27, UInt64}
    @inline m(dx, dy, dz) = mortonEncode3D_GPU(ix + dx, iy + dy, iz + dz)
    return (
        m(-1,-1,-1), m( 0,-1,-1), m( 1,-1,-1),
        m(-1, 0,-1), m( 0, 0,-1), m( 1, 0,-1),
        m(-1, 1,-1), m( 0, 1,-1), m( 1, 1,-1),
        
        m(-1,-1, 0), m( 0,-1, 0), m( 1,-1, 0),
        m(-1, 0, 0), m( 0, 0, 0), m( 1, 0, 0),
        m(-1, 1, 0), m( 0, 1, 0), m( 1, 1, 0),
        
        m(-1,-1, 1), m( 0,-1, 1), m( 1,-1, 1),
        m(-1, 0, 1), m( 0, 0, 1), m( 1, 0, 1),
        m(-1, 1, 1), m( 0, 1, 1), m( 1, 1, 1),
    )
end

# Generate explicit 27-tuple of neighbor Morton codes for 3D with periodic wrapping
@inline function neighborMortonCodes3DPeriodic(ix::Int, iy::Int, iz::Int, nx::Int, ny::Int, nz::Int)::NTuple{27, UInt64}
    @inline m(dx, dy, dz) = mortonEncode3D_GPU(mod(ix + dx, nx), mod(iy + dy, ny), mod(iz + dz, nz))
    return (
        m(-1,-1,-1), m( 0,-1,-1), m( 1,-1,-1),
        m(-1, 0,-1), m( 0, 0,-1), m( 1, 0,-1),
        m(-1, 1,-1), m( 0, 1,-1), m( 1, 1,-1),
        
        m(-1,-1, 0), m( 0,-1, 0), m( 1,-1, 0),
        m(-1, 0, 0), m( 0, 0, 0), m( 1, 0, 0),
        m(-1, 1, 0), m( 0, 1, 0), m( 1, 1, 0),
        
        m(-1,-1, 1), m( 0,-1, 1), m( 1,-1, 1),
        m(-1, 0, 1), m( 0, 0, 1), m( 1, 0, 1),
        m(-1, 1, 1), m( 0, 1, 1), m( 1, 1, 1),
    )
end

# Generate explicit 9-tuple of neighbor Morton codes for 2D
@inline function neighborMortonCodes2D(ix::Int, iy::Int)::NTuple{9, UInt64}
    @inline m(dx, dy) = mortonEncode2D_GPU(ix + dx, iy + dy)
    return (
        m(-1,-1), m( 0,-1), m( 1,-1),
        m(-1, 0), m( 0, 0), m( 1, 0),
        m(-1, 1), m( 0, 1), m( 1, 1),
    )
end

# Generate explicit 9-tuple of neighbor Morton codes for 2D with periodic wrapping
@inline function neighborMortonCodes2DPeriodic(ix::Int, iy::Int, nx::Int, ny::Int)::NTuple{9, UInt64}
    @inline m(dx, dy) = mortonEncode2D_GPU(mod(ix + dx, nx), mod(iy + dy, ny))
    return (
        m(-1,-1), m( 0,-1), m( 1,-1),
        m(-1, 0), m( 0, 0), m( 1, 0),
        m(-1, 1), m( 0, 1), m( 1, 1),
    )
end

# Generate explicit 3-tuple of neighbor Morton codes for 1D
@inline function neighborMortonCodes1D(ix::Int)::NTuple{3, UInt64}
    return (
        mortonEncode1D_GPU(ix - 1),
        mortonEncode1D_GPU(ix),
        mortonEncode1D_GPU(ix + 1),
    )
end

# Generate explicit 3-tuple of neighbor Morton codes for 1D with periodic wrapping
@inline function neighborMortonCodes1DPeriodic(ix::Int, nx::Int)::NTuple{3, UInt64}
    return (
        mortonEncode1D_GPU(mod(ix - 1, nx)),
        mortonEncode1D_GPU(mod(ix, nx)),
        mortonEncode1D_GPU(mod(ix + 1, nx)),
    )
end

# GPUCuDevice dispatch (inside kernel)
@inline function iterateOverNeighbors(mesh::UnstructuredMeshObject{GPUCuDevice, 1, S, DT, NN}, name::Symbol, x) where {S, DT, NN<:NeighborsHash}
    n = mesh._neighbors
    ht = n.hashTable[name]
    
    ix = floor(Int, x / n.cellSize[1])
    neighborCodes = if n.periodic !== nothing
        neighborMortonCodes1DPeriodic(ix, n.periodic[1])
    else
        neighborMortonCodes1D(ix)
    end
    numUnique = ht.numUniqueCodes[1]
    
    return HashNeighborIteratorGPU(ht.uniqueCodes, ht.codeOffsets, ht.sortedIndices, neighborCodes, numUnique)
end

@inline function iterateOverNeighbors(mesh::UnstructuredMeshObject{GPUCuDevice, 2, S, DT, NN}, name::Symbol, x, y) where {S, DT, NN<:NeighborsHash}
    n = mesh._neighbors
    ht = n.hashTable[name]
    
    ix = floor(Int, x / n.cellSize[1])
    iy = floor(Int, y / n.cellSize[2])
    neighborCodes = if n.periodic !== nothing
        neighborMortonCodes2DPeriodic(ix, iy, n.periodic[1], n.periodic[2])
    else
        neighborMortonCodes2D(ix, iy)
    end
    numUnique = ht.numUniqueCodes[1]
    
    return HashNeighborIteratorGPU(ht.uniqueCodes, ht.codeOffsets, ht.sortedIndices, neighborCodes, numUnique)
end

@inline function iterateOverNeighbors(mesh::UnstructuredMeshObject{GPUCuDevice, 3, S, DT, NN}, name::Symbol, x, y, z) where {S, DT, NN<:NeighborsHash}
    n = mesh._neighbors
    ht = n.hashTable[name]
    
    ix = floor(Int, x / n.cellSize[1])
    iy = floor(Int, y / n.cellSize[2])
    iz = floor(Int, z / n.cellSize[3])
    neighborCodes = if n.periodic !== nothing
        neighborMortonCodes3DPeriodic(ix, iy, iz, n.periodic[1], n.periodic[2], n.periodic[3])
    else
        neighborMortonCodes3D(ix, iy, iz)
    end
    numUnique = ht.numUniqueCodes[1]
    
    return HashNeighborIteratorGPU(ht.uniqueCodes, ht.codeOffsets, ht.sortedIndices, neighborCodes, numUnique)
end

@inline function Base.iterate(it::HashNeighborIteratorGPU, state=(1, 0, 0))
    cellIdx, pos, stop = state
    
    @inbounds while cellIdx <= length(it.neighborCodes)
        if stop == 0
            # Find this Morton code in unique codes using binary search
            code = it.neighborCodes[cellIdx]
            segIdx = binarySearchCode(it.uniqueCodes, code, it.numUnique)
            
            if segIdx > 0
                pos = it.codeOffsets[segIdx]
                stop = it.codeOffsets[segIdx + 1] - 1
            else
                # Code not found, move to next neighbor cell
                cellIdx += 1
                continue
            end
        end
        
        if pos <= stop
            pid = it.sortedIndices[pos]
            return pid, (cellIdx, pos + 1, stop)
        else
            # Move to next neighbor cell
            cellIdx += 1
            pos = 0
            stop = 0
        end
    end
    
    return nothing
end

@inline Base.eltype(::Type{<:HashNeighborIteratorGPU}) = Int
@inline Base.IteratorSize(::Type{<:HashNeighborIteratorGPU}) = Base.SizeUnknown()
