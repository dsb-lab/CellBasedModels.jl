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

function initNeighbors(
        dims, 
        neighbors::NeighborsCellLinked,
        meshParameters::NamedTuple
    )

    D = dims
    P = platform()

    if dims < 1 || dims > 3
        error("NeighborsCellLinked only supports 1D, 2D, or 3D. Found dims=$dims")
    end

    if size(neighbors.box) != (D, 2)
        error("Box size mismatch. Expected size ($(D), 2), found size $(size(neighbors.box))")
    end
    box = Array(neighbors.box)  # Convert to CPU if on GPU

    cellSize = neighbors.cellSize
    if cellSize isa Number
        # Scalar cellSize: replicate for all dimensions
        cellSize = fill(cellSize, D)
    elseif cellSize isa Tuple
        # Tuple cellSize: convert to vector and check length
        cellSize = collect(cellSize)
        if length(cellSize) != D
            error("Cell size mismatch. Expected length $(D), found length $(length(cellSize))")
        end
    elseif cellSize isa AbstractVector
        # Vector cellSize: check length and convert to CPU
        cellSize = Array(cellSize)  # Convert to CPU if on GPU
        if length(cellSize) != D
            error("Cell size mismatch. Expected length $(D), found length $(length(cellSize))")        
        end
    else
        error("Cell size must be a Number, Tuple, or Vector. Found type $(typeof(cellSize))")
    end
    cellSize = Tuple(cellSize)

    # Calculate grid size: no padding for periodic dimensions, padding for non-periodic
    grid = round.(Int, (box[:,2] - box[:,1]) ./ cellSize)
    gridTuple = ntuple(i -> grid[i], D)  # Convert to NTuple for assignCell! compatibility
    gridSize = prod(grid)  # Total number of cells

    permTable = Dict()
    cell = Dict()
    cellOffset = Dict()
    cellCounts = Dict()  # Per-thread workspace arrays
    
    for (name, prop) in pairs(meshParameters)
        permTable[name] = zeros(Int, lengthCache(prop))
        cell[name] = zeros(Int, lengthCache(prop))
        cellOffset[name] = zeros(Int, gridSize+1)
        # Create per-thread workspace for cell counters (gridSize per thread)
        cellCounts[name] = zeros(Int, gridSize+1)
    end

    permTableNamed = NamedTuple{tuple(keys(permTable)...)}(values(permTable))
    cellNamed = NamedTuple{tuple(keys(cell)...)}(values(cell))
    cellOffsetNamed = NamedTuple{tuple(keys(cellOffset)...)}(values(cellOffset))
    cellCountsNamed = NamedTuple{tuple(keys(cellCounts)...)}(values(cellCounts))

    NeighborsCellLinked{
        D, P, 
        typeof(meshParameters), 
        typeof(box), typeof(cellSize), typeof(gridTuple), 
        typeof(cellNamed), typeof(cellOffsetNamed),
        typeof(neighbors.periodic),
    }(meshParameters, box, cellSize, gridTuple, cellNamed, cellOffsetNamed, cellCountsNamed, permTableNamed, neighbors.periodic)

end

function update!(mesh::UnstructuredMeshObject{P, D, S, DT, NN, PAR}) where {P, D, S, DT, NN<:NeighborsCellLinked, PAR}

    # Cell reassignment and permutation table filling
    for (name, prop) in pairs(mesh._p)
        N = lengthProperties(prop)
        
        # Step 1: Assign each particle to its cell
        assignCell!(mesh._neighbors.cell[name], N, prop, mesh._neighbors)
        
        # Step 2: Count particles in each cell (parallel, no allocations)
        countInCell!(mesh._neighbors.cellOffset[name], N, mesh._neighbors.cell[name])
        
        # Step 3: Fill the permutation table (parallel, reuses cellCounts workspace)
        fillPermTable!(mesh._neighbors.permTable[name], mesh._neighbors.cellOffset[name], 
                      mesh._neighbors.cell[name], N, mesh._neighbors.cellCounts[name])
    end

    #Renaming TO DO

    return nothing
end

function assignCell(neighbors, x)
    return positionToLinear1D(x, neighbors.box, neighbors.cellSize, neighbors.grid)
end

function assignCell(neighbors, x, y)
    return positionToLinear2D(x, y, neighbors.box, neighbors.cellSize, neighbors.grid)
end

function assignCell(neighbors, x, y, z)
    return positionToLinear3D(x, y, z, neighbors.box, neighbors.cellSize, neighbors.grid)
end

function assignCell!(cellArray, N, prop, neighbors::NeighborsCellLinked{1})
    x = @views prop.x[1:N]
    cell = @views cellArray[1:N]

    @inbounds for i in 1:N
        cell[i] = positionToLinear1D(x[i], neighbors.box, neighbors.cellSize, neighbors.grid)
    end
end

function assignCell!(cellArray, N, prop, neighbors::NeighborsCellLinked{2})
    x = @views prop.x[1:N]
    y = @views prop.y[1:N]
    cell = @views cellArray[1:N]
    
    @inbounds for i in 1:N
        cell[i] = positionToLinear2D(x[i], y[i], neighbors.box, neighbors.cellSize, neighbors.grid)
    end
end

function assignCell!(cellArray, N, prop, neighbors::NeighborsCellLinked{3})
    x = @views prop.x[1:N]
    y = @views prop.y[1:N]
    z = @views prop.z[1:N]
    cell = @views cellArray[1:N]
    
    @inbounds for i in 1:N
        cell[i] = positionToLinear3D(x[i], y[i], z[i], neighbors.box, neighbors.cellSize, neighbors.grid)
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

@inline function iterateOverNeighbors(mesh::UnstructuredMeshObject{P, 1, S, DT, NN}, name::Symbol, x) where {P, S, DT, NN<:NeighborsCellLinked}
    n = mesh._neighbors
    c = assignCell(n, x)
    neigh = n.periodic ? linearNeighbors1DPeriodic(c, n.grid) : linearNeighbors1D(c, n.grid)
    return CellLinkedIterator(length(neigh), n, neigh, n.cellOffset[name], n.permTable[name])
end

@inline function iterateOverNeighbors(mesh::UnstructuredMeshObject{P, 2, S, DT, NN}, name::Symbol, x, y) where {P, S, DT, NN<:NeighborsCellLinked}
    n = mesh._neighbors
    c = assignCell(n, x, y)
    neigh = n.periodic ? linearNeighbors2DPeriodic(c, n.grid) : linearNeighbors2D(c, n.grid)
    return CellLinkedIterator(length(neigh), n, neigh, n.cellOffset[name], n.permTable[name])
end

@inline function iterateOverNeighbors(mesh::UnstructuredMeshObject{P, 3, S, DT, NN}, name::Symbol, x, y, z) where {P, S, DT, NN<:NeighborsCellLinked}
    n = mesh._neighbors
    c = assignCell(n, x, y, z)
    neigh = n.periodic ? linearNeighbors3DPeriodic(c, n.grid) : linearNeighbors3D(c, n.grid)
    return CellLinkedIterator(length(neigh), n, neigh, n.cellOffset[name], n.permTable[name])
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
