import CellBasedModels: assignCell!, countInCell!, fillPermTable!, platform
import CellBasedModels: positionToLinear1D, positionToLinear2D, positionToLinear3D

function initNeighborsGPU(
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
    box = neighbors.box

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
        # Vector cellSize: check length
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

    box = CUDA.cu(box)

    permTable = Dict()
    cell = Dict()
    cellOffset = Dict()
    cellCounts = Dict()  # Per-thread workspace arrays
    
    for (name, prop) in pairs(meshParameters)
        permTable[name] = CUDA.zeros(Int, lengthCache(prop))
        cell[name] = CUDA.zeros(Int, lengthCache(prop))
        cellOffset[name] = CUDA.zeros(Int, gridSize+1)
        cellCounts[name] = CUDA.zeros(Int, gridSize+1)
    end

    permTableNamed = NamedTuple{tuple(keys(permTable)...)}(values(permTable))
    cellNamed = NamedTuple{tuple(keys(cell)...)}(values(cell))
    cellOffsetNamed = NamedTuple{tuple(keys(cellOffset)...)}(values(cellOffset))
    cellCountsNamed = NamedTuple{tuple(keys(cellCounts)...)}(values(cellCounts))

    NeighborsCellLinked{
        D, GPUCuda, 
        typeof(meshParameters), 
        typeof(box), typeof(cellSize), typeof(gridTuple), 
        typeof(cellNamed), typeof(cellOffsetNamed),
        typeof(neighbors.periodic),
    }(meshParameters, box, cellSize, gridTuple, cellNamed, cellOffsetNamed, cellCountsNamed, permTableNamed, neighbors.periodic)

end

# GPU kernel for cell assignment - we need to dispatch on the assignCell! function
function assignCell!(cellArray, N, prop, neighbors::NeighborsCellLinked{1, GPUCuda})
    x = prop.x
    cell = cellArray
    
    function kernel(cell, x, N, box, cellSize, grid)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            @inbounds cell[i] = positionToLinear1D(x[i], box, cellSize, grid)
        end
        return nothing
    end
    
    threads_per_block = 256
    blocks = div(N + threads_per_block - 1, threads_per_block)
    
    CUDA.@cuda threads=threads_per_block blocks=blocks kernel(cell, x, N, neighbors.box, neighbors.cellSize, neighbors.grid)
    CUDA.synchronize()
end

function assignCell!(cellArray, N, prop, neighbors::NeighborsCellLinked{2, GPUCuda})
    x = prop.x
    y = prop.y
    cell = cellArray
    
    function kernel(cell, x, y, N, box, cellSize, grid)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            @inbounds cell[i] = positionToLinear2D(x[i], y[i], box, cellSize, grid)
        end
        return nothing
    end
    
    threads_per_block = 256
    blocks = div(N + threads_per_block - 1, threads_per_block)
    
    CUDA.@cuda threads=threads_per_block blocks=blocks kernel(cell, x, y, N, neighbors.box, neighbors.cellSize, neighbors.grid)
    CUDA.synchronize()
end

function assignCell!(cellArray, N, prop, neighbors::NeighborsCellLinked{3, GPUCuda})
    x = prop.x
    y = prop.y
    z = prop.z
    cell = cellArray
    
    function kernel(cell, x, y, z, N, box, cellSize, grid)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            @inbounds cell[i] = positionToLinear3D(x[i], y[i], z[i], box, cellSize, grid)
        end
        return nothing
    end
    
    threads_per_block = 256
    blocks = div(N + threads_per_block - 1, threads_per_block)
    
    CUDA.@cuda threads=threads_per_block blocks=blocks kernel(cell, x, y, z, N, neighbors.box, neighbors.cellSize, neighbors.grid)
    CUDA.synchronize()
end

# GPU-optimized cell counting using CUDA reductions
function countInCell!(cellOffset::CUDA.CuArray, N, cell::CUDA.CuArray)    

    # Clear workspace
    cellOffset .= 0
    
    # Count particles per cell using atomic operations
    function count_kernel(cell, cellOffset, N)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            cellIdx = cell[i]
            CUDA.@atomic cellOffset[cellIdx+1] += 1
        end
        return nothing
    end

    threads_per_block = 256
    blocks = div(N + threads_per_block - 1, threads_per_block)

    CUDA.@cuda threads=threads_per_block blocks=blocks count_kernel(cell, cellOffset, N)
    CUDA.synchronize()

    cellOffset .= cumsum(cellOffset)
    
    return nothing
end

function fillPermTable!(permTable::CUDA.CuArray, cellOffset::CUDA.CuArray,
                        cell::CUDA.CuArray, N, cellCounts)

    cellCounts .= 0

    function fill_permtable_kernel(permTable, cell, cellOffset, N, cellCounts)
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        if i <= N
            cellIdx = cell[i]
            p = CUDA.@atomic cellCounts[cellIdx] += 1
            pos = cellOffset[cellIdx] + p + 1
            permTable[pos] = i
        end
        return
    end

    threads = 256
    blocks  = cld(N, threads)

    CUDA.@cuda threads=threads blocks=blocks fill_permtable_kernel(
        permTable, cell, cellOffset, N, cellCounts)

    return nothing
end

