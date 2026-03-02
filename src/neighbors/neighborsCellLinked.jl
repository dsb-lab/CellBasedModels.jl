struct NeighborsCellLinked{D, P, UM, B, CS, G, C, CO, Per} <: AbstractNeighbors 

    u::UM

    box::B
    cellSize::CS
    grid::G

    cell::C
    cellOffset::CO
    cellCounts::CO

    permTable::C

    periodic::Per
    
end
Adapt.@adapt_structure NeighborsCellLinked

function NeighborsCellLinked(;box, cellSize, periodic=false)
    NeighborsCellLinked{Nothing, Nothing, Nothing, typeof(box), typeof(cellSize), Nothing, Nothing, Nothing, typeof(periodic)}(
        nothing, 
        box, 
        cellSize,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        periodic
    )
end

function NeighborsCellLinked(
    mesh,

    box,
    cellSize,
    grid,

    cell,
    cellOffset,
    cellCounts,

    permTable,

    periodic,
)

    NeighborsCellLinked{
        length(cellSize),
        platform(),
        typeof(mesh),
        typeof(box),
        typeof(cellSize),
        typeof(grid),
        typeof(cell),
        typeof(cellOffset),
        typeof(periodic),
    }(
        mesh,
        box,
        cellSize,
        grid,
        cell,
        cellOffset,
        cellCounts,
        permTable,
        periodic,
    )

end

# Initialize neighbors for NeighborsCellLinked
# Specializes on UnstructuredMeshField with NeighborsCellLinked type
function initNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN}) where {P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsCellLinked}
    neighbors = field._neighbors
    # Use the box to determine dimensions
    D = size(neighbors.box, 1)
    NCache = lengthCache(field)
    
    box = Array(neighbors.box)
    
    cellSize = neighbors.cellSize
    if cellSize isa Number
        cellSize = ntuple(_ -> cellSize, D)
    elseif cellSize isa AbstractVector
        cellSize = Tuple(cellSize)
    elseif cellSize isa Tuple
        cellSize = cellSize
    end
    
    # Calculate grid dimensions
    grid = ntuple(d -> round(Int, (box[d, 2] - box[d, 1]) / cellSize[d]), D)
    gridSize = prod(grid)
    
    # Create simple arrays (not dictionaries) for field-level storage
    cell = zeros(Int, NCache)
    cellOffset = zeros(Int, gridSize + 1)
    cellCounts = zeros(Int, gridSize + 1)
    permTable = zeros(Int, NCache)
    
    NeighborsCellLinked{
        D, P,
        Nothing,  # No mesh reference at field level
        typeof(box), typeof(cellSize), typeof(grid),
        typeof(cell), typeof(cellOffset),
        typeof(neighbors.periodic),
    }(
        nothing,  # u
        box,
        cellSize,
        grid,
        cell,
        cellOffset,
        cellCounts,
        permTable,
        neighbors.periodic,
    )
end

# Update for NeighborsCellLinked - assigns particles to cells
function update!(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN}) where {P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsCellLinked}
    N = lengthProperties(field)
    neighbors = field._neighbors
    
    # Step 1: Assign each particle to its cell
    assignCell!(neighbors.cell, N, field._p, neighbors)
    
    # Step 2: Count particles in each cell
    countInCell!(neighbors.cellOffset, N, neighbors.cell)
    
    # Step 3: Fill the permutation table
    fillPermTable!(neighbors.permTable, neighbors.cellOffset, 
                  neighbors.cell, N, neighbors.cellCounts)
    
    return nothing
end

function assignCell(neighbors, x)
    xi = x
    if neighbors.periodic
        boxLen = neighbors.box[1, 2] - neighbors.box[1, 1]
        xi = neighbors.box[1, 1] + mod(xi - neighbors.box[1, 1], boxLen)
    end
    return positionToLinear1D(xi, neighbors.box, neighbors.cellSize, neighbors.grid)
end

function assignCell(neighbors, x, y)
    xi, yi = x, y
    if neighbors.periodic
        boxLenX = neighbors.box[1, 2] - neighbors.box[1, 1]
        boxLenY = neighbors.box[2, 2] - neighbors.box[2, 1]
        xi = neighbors.box[1, 1] + mod(xi - neighbors.box[1, 1], boxLenX)
        yi = neighbors.box[2, 1] + mod(yi - neighbors.box[2, 1], boxLenY)
    end
    return positionToLinear2D(xi, yi, neighbors.box, neighbors.cellSize, neighbors.grid)
end

function assignCell(neighbors, x, y, z)
    xi, yi, zi = x, y, z
    if neighbors.periodic
        boxLenX = neighbors.box[1, 2] - neighbors.box[1, 1]
        boxLenY = neighbors.box[2, 2] - neighbors.box[2, 1]
        boxLenZ = neighbors.box[3, 2] - neighbors.box[3, 1]
        xi = neighbors.box[1, 1] + mod(xi - neighbors.box[1, 1], boxLenX)
        yi = neighbors.box[2, 1] + mod(yi - neighbors.box[2, 1], boxLenY)
        zi = neighbors.box[3, 1] + mod(zi - neighbors.box[3, 1], boxLenZ)
    end
    return positionToLinear3D(xi, yi, zi, neighbors.box, neighbors.cellSize, neighbors.grid)
end

function assignCell!(cellArray, N, prop, neighbors::NeighborsCellLinked{1})
    x = @views prop.x[1:N]
    cell = @views cellArray[1:N]
    box = neighbors.box
    periodic = neighbors.periodic

    @inbounds for i in 1:N
        xi = x[i]
        # Wrap position for periodic boundaries before cell assignment
        if periodic
            boxLen = box[1, 2] - box[1, 1]
            xi = box[1, 1] + mod(xi - box[1, 1], boxLen)
        end
        cell[i] = positionToLinear1D(xi, box, neighbors.cellSize, neighbors.grid)
    end
end

function assignCell!(cellArray, N, prop, neighbors::NeighborsCellLinked{2})
    x = @views prop.x[1:N]
    y = @views prop.y[1:N]
    cell = @views cellArray[1:N]
    box = neighbors.box
    periodic = neighbors.periodic
    
    @inbounds for i in 1:N
        xi, yi = x[i], y[i]
        # Wrap positions for periodic boundaries before cell assignment
        if periodic
            boxLenX = box[1, 2] - box[1, 1]
            boxLenY = box[2, 2] - box[2, 1]
            xi = box[1, 1] + mod(xi - box[1, 1], boxLenX)
            yi = box[2, 1] + mod(yi - box[2, 1], boxLenY)
        end
        cell[i] = positionToLinear2D(xi, yi, box, neighbors.cellSize, neighbors.grid)
    end
end

function assignCell!(cellArray, N, prop, neighbors::NeighborsCellLinked{3})
    x = @views prop.x[1:N]
    y = @views prop.y[1:N]
    z = @views prop.z[1:N]
    cell = @views cellArray[1:N]
    box = neighbors.box
    periodic = neighbors.periodic
    
    @inbounds for i in 1:N
        xi, yi, zi = x[i], y[i], z[i]
        # Wrap positions for periodic boundaries before cell assignment
        if periodic
            boxLenX = box[1, 2] - box[1, 1]
            boxLenY = box[2, 2] - box[2, 1]
            boxLenZ = box[3, 2] - box[3, 1]
            xi = box[1, 1] + mod(xi - box[1, 1], boxLenX)
            yi = box[2, 1] + mod(yi - box[2, 1], boxLenY)
            zi = box[3, 1] + mod(zi - box[3, 1], boxLenZ)
        end
        cell[i] = positionToLinear3D(xi, yi, zi, box, neighbors.cellSize, neighbors.grid)
    end
end

function countInCell!(cellOffset, N, cell)
    """
    Parallel version of cell counting using per-thread workspace arrays.
    No temporary allocations - uses pre-allocated cellCounts workspace.
    """
    cellOffset .= 0
    @inbounds for i in 1:N
        cellIdx = cell[i]
        cellOffset[cellIdx+1] += 1
    end

    for i in 2:length(cellOffset)
        cellOffset[i] += cellOffset[i-1]
    end
end

function fillPermTable!(permTable, cellOffset, cell, N, cellCounts)
    """
    Sequential version of permutation table filling to avoid race conditions.
    Creates a stable, deterministic ordering within each cell based on 
    the original particle indices (lower indices come first within each cell).
    
    permTable[sortedPos] = originalParticleIndex
    """
    
    cellCounts .= 0    

    @inbounds for i in 1:N
        cellIdx = cell[i]

        pos = cellOffset[cellIdx] + cellCounts[cellIdx] + 1
        cellCounts[cellIdx] += 1

        permTable[pos] = i
    end
    
end

# Field-based iterateOverNeighbors for NeighborsCellLinked (per-field neighbors)
@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN}, x) where {P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsCellLinked{1}}
    n = field._neighbors
    c = assignCell(n, x)
    neigh = n.periodic ? linearNeighbors1DPeriodic(c, n.grid) : linearNeighbors1D(c, n.grid)
    return CellLinkedIterator(length(neigh), n, neigh, n.cellOffset, n.permTable)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN}, x, y) where {P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsCellLinked{2}}
    n = field._neighbors
    c = assignCell(n, x, y)
    neigh = n.periodic ? linearNeighbors2DPeriodic(c, n.grid) : linearNeighbors2D(c, n.grid)
    return CellLinkedIterator(length(neigh), n, neigh, n.cellOffset, n.permTable)
end

@inline function iterateOverNeighbors(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN}, x, y, z) where {P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN<:NeighborsCellLinked{3}}
    n = field._neighbors
    c = assignCell(n, x, y, z)
    neigh = n.periodic ? linearNeighbors3DPeriodic(c, n.grid) : linearNeighbors3D(c, n.grid)
    return CellLinkedIterator(length(neigh), n, neigh, n.cellOffset, n.permTable)
end

struct CellLinkedIterator{NN, NT, CO, PT}
    s::Int
    neighbors::NN                      # mesh._neighbors
    neighborsCells::NT                 # NTuple{27,Int}
    cellOffset::CO                     # per-property cellOffset array
    permTable::PT                      # per-property permTable array
end

@inline function Base.iterate(it::CellLinkedIterator, state=(1, 0, -1))
    k, pos, stop = state

    @inbounds while k <= it.s
        cellid = it.neighborsCells[k]

        if cellid == -1
            k += 1
            continue
        end

        # cellOffset is length nCells+1, with:
        # particles in cell c are in permTable[(cellOffset[c]+1) : cellOffset[c+1]]
        if stop < 0
            start = it.cellOffset[cellid] + 1
            stop  = it.cellOffset[cellid + 1]
            pos   = start
        end

        if pos <= stop
            pid = it.permTable[pos]     # original particle index
            return pid, (k, pos + 1, stop)
        else
            # move to next cell
            k += 1
            pos = 0
            stop = -1
        end
    end

    return nothing
end

@inline Base.eltype(::Type{<:CellLinkedIterator}) = Int
@inline Base.IteratorSize(::Type{<:CellLinkedIterator}) = Base.SizeUnknown()
