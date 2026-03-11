# Enum for space-filling curve types (isbits-compatible for GPU)
@enum CurveType::Int8 begin
    CURVE_MORTON = 1
    CURVE_HILBERT = 2
end

"""
    NeighborsHash - Spatial hashing with Morton/Hilbert indexing

A neighbor structure that uses spatial hashing with space-filling curves (Morton or Hilbert)
for efficient sparse neighbor searches. Unlike NeighborsCellLinked, this structure:
- Does not require a bounding box (works in open/infinite space)
- Is efficient when the grid is mostly empty (sparse particles)
- Uses hash tables instead of dense cell arrays
- Supports periodic boundaries

The spatial hash maps 3D cell coordinates to a space-filling curve index,
then uses a hash table to store only occupied cells.
"""
struct NeighborsHash{D, P, UM, CS, HT, Per} <: AbstractNeighbors 

    u::UM

    cellSize::CS
    
    # Hash table: maps Morton/Hilbert index to list of particle indices
    hashTable::HT
    
    # Periodic boundary settings (nothing = open space, tuple = periodic bounds)
    periodic::Per
    
    # Curve type: CURVE_MORTON or CURVE_HILBERT (isbits enum)
    curveType::CurveType
    
end
Adapt.@adapt_structure NeighborsHash

"""
    NeighborsHash(; cellSize, box=nothing, periodic=false, curveType=:morton)

Create a NeighborsHash neighbor structure.

# Arguments
- `cellSize`: Size of each cell (scalar for uniform, tuple for per-dimension)
- `box=nothing`: Bounding box as matrix [min max; ...] per dimension (required if periodic=true)
- `periodic=false`: Whether to use periodic boundary conditions
- `curveType=:morton`: Space-filling curve type (:morton or :hilbert)

# Examples
```julia
# Open space, no periodicity
neighbors = NeighborsHash(cellSize=1.0)

# Periodic box [0,10]³
neighbors = NeighborsHash(cellSize=1.0, box=[0 10; 0 10; 0 10], periodic=true)

# 2D with Morton curve (use :morton or CURVE_MORTON)
neighbors = NeighborsHash(cellSize=0.5, curveType=:morton)
```
"""
function NeighborsHash(; cellSize, box=nothing, periodic=false, curveType=:morton)
    # Convert symbol to enum if needed
    ct = if curveType isa Symbol
        curveType == :morton ? CURVE_MORTON : CURVE_HILBERT
    else
        curveType
    end
    
    # Convert box + periodic boolean to periodic grid cell counts
    # Store as tuple of grid cell counts per dimension (for cell index wrapping)
    periodicGridCells = if periodic && box !== nothing
        D = size(box, 1)
        # Convert cellSize to tuple if scalar
        cs = cellSize isa Number ? ntuple(_ -> cellSize, D) : cellSize
        # Compute number of grid cells per dimension
        ntuple(d -> round(Int, (box[d, 2] - box[d, 1]) / cs[d]), D)
    else
        nothing
    end
    
    NeighborsHash{Nothing, Nothing, Nothing, typeof(cellSize), Nothing, typeof(periodicGridCells)}(
        nothing, 
        cellSize,
        nothing,
        periodicGridCells,
        ct
    )
end

function NeighborsHash(
    mesh,
    cellSize,
    hashTable,
    periodic,
    curveType::CurveType,
)
    D = length(cellSize)
    P = platform()
    
    NeighborsHash{
        D,
        P,
        typeof(mesh),
        typeof(cellSize),
        typeof(hashTable),
        typeof(periodic),
    }(
        mesh,
        cellSize,
        hashTable,
        periodic,
        curveType,
    )
end

# Initialize neighbors for NeighborsHash
# Specializes on UnstructuredMeshField with NeighborsHash type
function initNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}) where {P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsHash, FI}
    neighbors = field._neighbors
    # Infer dimensions from field properties (check for x, y, z fields)
    propNames = keys(field._p)
    D = 1
    if :z in propNames
        D = 3
    elseif :y in propNames
        D = 2
    end
    
    NCache = lengthCache(field)
    
    cellSize = neighbors.cellSize
    if cellSize isa Number
        cellSize = ntuple(_ -> cellSize, D)
    elseif cellSize isa AbstractVector
        cellSize = Tuple(cellSize)
    end
    
    # Create arrays for field-level Hash (similar to CellLinked approach)
    # This allows seamless GPU conversion via toBackend
    hashTable = (
        mortonCodes = zeros(UInt64, NCache),
        sortedIndices = zeros(Int, NCache),
        sortPerm = zeros(Int, NCache),
        uniqueCodes = zeros(UInt64, NCache),
        codeOffsets = zeros(Int, NCache + 1),
        numUniqueCodes = zeros(Int, 1),
        # Also store the Dict for CPU iteration
        cpuDict = Dict{UInt64, Vector{Int}}(),
    )
    
    NeighborsHash{
        D, P,
        Nothing,  # No mesh reference at field level
        typeof(cellSize),
        typeof(hashTable),
        typeof(neighbors.periodic),
    }(
        nothing,  # u
        cellSize,
        hashTable,
        neighbors.periodic,
        neighbors.curveType,
    )
end

"""
Convert position to cell coordinates (integer grid indices).
For open space, cells can have negative indices.
"""
@inline function positionToCell(x, cellSize)
    return floor(Int, x / cellSize)
end

@inline function positionToCell(x, y, cellSize::Tuple{T,T}) where T
    return (floor(Int, x / cellSize[1]), floor(Int, y / cellSize[2]))
end

@inline function positionToCell(x, y, z, cellSize::Tuple{T,T,T}) where T
    return (floor(Int, x / cellSize[1]), floor(Int, y / cellSize[2]), floor(Int, z / cellSize[3]))
end

@inline function positionToCell(x, cellSize::Number)
    return floor(Int, x / cellSize)
end

@inline function positionToCell(x, y, cellSize::Number)
    return (floor(Int, x / cellSize), floor(Int, y / cellSize))
end

@inline function positionToCell(x, y, z, cellSize::Number)
    return (floor(Int, x / cellSize), floor(Int, y / cellSize), floor(Int, z / cellSize))
end

"""
Compute Morton code (Z-order curve) for cell coordinates.
Handles negative coordinates by offsetting to positive range.
"""
@inline function mortonEncode(ix::Int)
    # For 1D, just return the index shifted to handle negatives
    return ix + (1 << 30)  # Offset to handle negative indices
end

@inline function mortonEncode(ix::Int, iy::Int)
    # Shift to positive range
    x = UInt64(ix + (1 << 30))
    y = UInt64(iy + (1 << 30))
    
    # Interleave bits
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

@inline function mortonEncode(ix::Int, iy::Int, iz::Int)
    # Shift to positive range
    x = UInt64(ix + (1 << 20))
    y = UInt64(iy + (1 << 20))
    z = UInt64(iz + (1 << 20))
    
    # Interleave bits for 3D
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

"""
Get neighbor cell coordinates for a given cell.
Returns cell coordinates (not Morton codes) of all neighboring cells.
"""
@inline function getNeighborCells1D(ix::Int)
    return (ix-1, ix, ix+1)
end

@inline function getNeighborCells2D(ix::Int, iy::Int)
    return ntuple(k -> begin
        dx = (k - 1) % 3 - 1
        dy = (k - 1) ÷ 3 - 1
        (ix + dx, iy + dy)
    end, 9)
end

@inline function getNeighborCells3D(ix::Int, iy::Int, iz::Int)
    return ntuple(k -> begin
        kk = k - 1
        dx = kk % 3 - 1
        dy = (kk ÷ 3) % 3 - 1
        dz = (kk ÷ 9) - 1
        (ix + dx, iy + dy, iz + dz)
    end, 27)
end

"""
Get neighbor cell coordinates with periodic wrapping.
periodic is a tuple of grid cell counts per dimension.
"""
@inline function getNeighborCells3DPeriodic(ix::Int, iy::Int, iz::Int, periodic::NTuple{3, Int})
    nx, ny, nz = periodic
    
    return ntuple(k -> begin
        kk = k - 1
        dx = kk % 3 - 1
        dy = (kk ÷ 3) % 3 - 1
        dz = (kk ÷ 9) - 1
        (mod(ix + dx, nx), mod(iy + dy, ny), mod(iz + dz, nz))
    end, 27)
end

@inline function getNeighborCells2DPeriodic(ix::Int, iy::Int, periodic::NTuple{2, Int})
    nx, ny = periodic
    
    return ntuple(k -> begin
        dx = (k - 1) % 3 - 1
        dy = (k - 1) ÷ 3 - 1
        (mod(ix + dx, nx), mod(iy + dy, ny))
    end, 9)
end

@inline function getNeighborCells1DPeriodic(ix::Int, periodic::NTuple{1, Int})
    nx = periodic[1]
    return (mod(ix - 1, nx), mod(ix, nx), mod(ix + 1, nx))
end

# Update for NeighborsHash - assigns particles to hash table
function update!(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}) where {P<:CPU, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsHash, FI}
    neighbors = field._neighbors
    D = length(neighbors.cellSize)
    N = lengthProperties(field)
    
    # Clear the CPU dictionary (used for iteration on CPU)
    cpuDict = neighbors.hashTable.cpuDict
    empty!(cpuDict)
    
    # Assign particles to cells based on dimension
    if D == 1
        assignParticlesToHash1D!(cpuDict, N, field._p, neighbors)
    elseif D == 2
        assignParticlesToHash2D!(cpuDict, N, field._p, neighbors)
    else
        assignParticlesToHash3D!(cpuDict, N, field._p, neighbors)
    end
    
    return nothing
end

function assignParticlesToHash1D!(hashTable, N, prop, neighbors)
    x = prop.x
    cellSize = neighbors.cellSize[1]
    periodic = neighbors.periodic
    
    @inbounds for i in 1:N
        ix = positionToCell(x[i], cellSize)
        
        # Wrap cell index for periodic boundaries
        if periodic !== nothing
            nx = periodic[1]
            ix = mod(ix, nx)
        end
        
        code = mortonEncode(ix)
        
        if haskey(hashTable, code)
            push!(hashTable[code], i)
        else
            hashTable[code] = [i]
        end
    end
end

function assignParticlesToHash2D!(hashTable, N, prop, neighbors)
    x = prop.x
    y = prop.y
    cellSize = neighbors.cellSize
    periodic = neighbors.periodic
    
    @inbounds for i in 1:N
        ix, iy = positionToCell(x[i], y[i], cellSize)
        
        # Wrap cell indices for periodic boundaries
        if periodic !== nothing
            nx, ny = periodic
            ix = mod(ix, nx)
            iy = mod(iy, ny)
        end
        
        code = mortonEncode(ix, iy)
        
        if haskey(hashTable, code)
            push!(hashTable[code], i)
        else
            hashTable[code] = [i]
        end
    end
end

function assignParticlesToHash3D!(hashTable, N, prop, neighbors)
    x = prop.x
    y = prop.y
    z = prop.z
    cellSize = neighbors.cellSize
    periodic = neighbors.periodic
    
    @inbounds for i in 1:N
        ix, iy, iz = positionToCell(x[i], y[i], z[i], cellSize)
        
        # Wrap cell indices for periodic boundaries (must match getNeighborCells3DPeriodic)
        if periodic !== nothing
            nx, ny, nz = periodic
            ix = mod(ix, nx)
            iy = mod(iy, ny)
            iz = mod(iz, nz)
        end
        
        code = mortonEncode(ix, iy, iz)
        
        if haskey(hashTable, code)
            push!(hashTable[code], i)
        else
            hashTable[code] = [i]
        end
    end
end

# Iterator for hash-based neighbors
struct HashNeighborIterator{HT, NC}
    hashTable::HT
    neighborCodes::NC  # Tuple of Morton codes for neighbor cells
end


# Field-based iterateOverNeighbors for NeighborsHash on CPU (per-field neighbors)
@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}, x) where {P<:CPU, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsHash{1}, FI}
    n = field._neighbors
    ix = positionToCell(x, n.cellSize[1])
    
    neighborCells = if n.periodic !== nothing
        # Wrap current cell index to match assignment
        nx = n.periodic[1]
        ix = mod(ix, nx)
        getNeighborCells1DPeriodic(ix, n.periodic)
    else
        getNeighborCells1D(ix)
    end
    
    neighborCodes = ntuple(i -> mortonEncode(neighborCells[i]), length(neighborCells))
    return HashNeighborIterator(n.hashTable.cpuDict, neighborCodes)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}, x, y) where {P<:CPU, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsHash{2}, FI}
    n = field._neighbors
    ix, iy = positionToCell(x, y, n.cellSize)
    
    neighborCells = if n.periodic !== nothing
        # Wrap current cell indices to match assignment
        nx, ny = n.periodic
        ix = mod(ix, nx)
        iy = mod(iy, ny)
        getNeighborCells2DPeriodic(ix, iy, n.periodic)
    else
        getNeighborCells2D(ix, iy)
    end
    
    neighborCodes = ntuple(i -> mortonEncode(neighborCells[i]...), length(neighborCells))
    return HashNeighborIterator(n.hashTable.cpuDict, neighborCodes)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}, x, y, z) where {P<:CPU, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsHash{3}, FI}
    n = field._neighbors
    ix, iy, iz = positionToCell(x, y, z, n.cellSize)
    
    neighborCells = if n.periodic !== nothing
        # Wrap current cell index to match assignment (important!)
        nx, ny, nz = n.periodic
        ix = mod(ix, nx)
        iy = mod(iy, ny)
        iz = mod(iz, nz)
        getNeighborCells3DPeriodic(ix, iy, iz, n.periodic)
    else
        getNeighborCells3D(ix, iy, iz)
    end
    
    neighborCodes = ntuple(i -> mortonEncode(neighborCells[i]...), length(neighborCells))
    return HashNeighborIterator(n.hashTable.cpuDict, neighborCodes)
end

@inline function Base.iterate(it::HashNeighborIterator, state=(1, 1))
    cellIdx, particleIdx = state
    
    @inbounds while cellIdx <= length(it.neighborCodes)
        code = it.neighborCodes[cellIdx]
        
        if haskey(it.hashTable, code)
            particles = it.hashTable[code]
            if particleIdx <= length(particles)
                pid = particles[particleIdx]
                return pid, (cellIdx, particleIdx + 1)
            end
        end
        
        # Move to next cell
        cellIdx += 1
        particleIdx = 1
    end
    
    return nothing
end

@inline Base.eltype(::Type{<:HashNeighborIterator}) = Int
@inline Base.IteratorSize(::Type{<:HashNeighborIterator}) = Base.SizeUnknown()
