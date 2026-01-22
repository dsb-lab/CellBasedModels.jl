######################################################################################################
# CSRTuple - Fixed-size tuples (block size is a type parameter)
######################################################################################################
struct CSRTuple{
            P, NBlock, PR, AI
        } <: AbstractCSR

    _NBlock::Int

    _map::PR

    _NRows::AI
    _NRowsCache::AI

    _NEntries::AI
    _NEntriesRow::VI

end
Adapt.@adapt_structure CSRTuple

function CSRTuple(
    NBlock::Int,
    N::Int,
    NCache::Int=N
)

    @assert NBlock > 0 "NBlock must be > 0"
    @assert N >= 0 "N must be >= 0"
    @assert NCache >= N "NCache must be >= N"

    _NBlock = NBlock

    _map = zeros(Int, NCache*NBlock)

    _NRows = SizedVector{1}(N)
    _NRowsCache = SizedVector{1}(NCache)
    _NEntries = SizedVector{1}(0)
    _NEntriesRow = zeros(Int, NCache)

    P = platform()
    PR = typeof(_map)
    AI = typeof(_NRows)

    CSRTuple{
            P, NBlock, PR, AI
        }(
            _NBlock,
            _map,
            _NRows,
            _NRowsCache,
            _NEntries,
            _NEntriesRow,
        )
end

function CSRTuple(
            _NBlock,
            _map,
            _NRows,
            _NRowsCache,
            _NEntries,
            _NEntriesRow,
        )
    
    P = platform()
    PR = typeof(_map)
    AI = typeof(_NRows)

    CSRTuple{
            P, _NBlock, PR, AI
        }(
            _NBlock,
            _map,
            _NRows,
            _NRowsCache,
            _NEntries,
            _NEntriesRow,
        )
end

function CSRTuple(data::AbstractMatrix{<:Int}; additionalCache::Int=0) 

    @assert additionalCache >= 0 "additionalCache must be >= 0"

    _NBlock = size(data, 2)
    _NRows = size(data, 1)
    _NRowsCache = _NRows + additionalCache
    
    # Create CSRTuple with appropriate size
    csr = CSRTuple(
        _NBlock,
        _NRows,
        _NRowsCache;
    )
    
    csr._map[1:(_NRows*_NBlock)] .= reshape(data, _NRows*_NBlock)
    
    # Count active entries and entries per row
    active_count = 0
    for row in 1:_NRows
        row_count = 0
        for col in 1:_NBlock
            idx = (row - 1) * _NBlock + col
            if data[row, col] != 0
                active_count += 1
                row_count += 1
            end
        end
        csr._NEntriesRow[row] = row_count
    end
    csr._NEntries[1] = active_count
    
    return csr
end

function CSRTuple(data::AbstractVector{<:AbstractVector{<:Int}}; additionalCache::Int=0)
    
    maxl = maximum(length.(data))
    minl = minimum(length.(data))
    @assert maxl == minl "All subarrays must have the same length"
    @assert additionalCache >= 0 "additionalCache must be >= 0"

    N = length(data)
    NBlock = maximum(maxl)
    NCache = N + additionalCache

    # Create CSRTuple with appropriate size
    csr = CSRTuple(
        NBlock,
        N,
        NCache
    )

    # Fill data, padding with zeros if necessary
    active_count = 0
    for i in 1:N
        row_count = 0
        for j in 1:length(data[i])
            linear_idx = (i - 1) * NBlock + j
            csr._map[linear_idx] = data[i][j]
            if data[i][j] != 0
                active_count += 1
                row_count += 1
            end
        end
        csr._NEntriesRow[i] = row_count
    end
    
    csr._NEntries[1] = active_count

    return csr
end

function Base.show(io::IO, x::CSRTuple{
            P, NBlock, PR, AI
        }) where {
            P, NBlock, PR, AI
        } 
    
    println(io, "CSRTuple{NBlock=$NBlock, NRows=$(numberOfRows(x)), NRowsCache=$(lengthRowCache(x))}")    
end

function Base.show(io::IO, x::Type{CSRTuple{P, NBlock, PR, AI}}) where {P, NBlock, PR, AI}
    println(io, "CSRTuple{$P, NBlock=$NBlock, $PR, $AI}")
end

Base.length(csr::CSRTuple{P, NBlock}) where {P, NBlock} = numberOfEntries(csr)

numberOfEntries(csr::CSRTuple{P, NBlock}) where {P<:CPU, NBlock} = csr._NEntries[1]
numberOfEntries(csr::CSRTuple{P, NBlock}) where {P<:GPU, NBlock} = Array(csr._NEntries)[1]
numberOfEntriesCache(csr::CSRTuple{P, NBlock}) where {P, NBlock} = length(csr._map)
numberOfRows(csr::CSRTuple{P, NBlock}) where {P<:CPU, NBlock} = csr._NRows[1]
numberOfRows(csr::CSRTuple{P, NBlock}) where {P<:GPU, NBlock} = Array(csr._NRows)[1]
numberOfRowsCache(csr::CSRTuple{P, NBlock}) where {P<:CPU, NBlock} = csr._NRowsCache[1]
numberOfRowsCache(csr::CSRTuple{P, NBlock}) where {P<:GPU, NBlock} = Array(csr._NRowsCache)[1]
numberOfEntriesPerRow(csr::CSRTuple{P, NBlock}, row::Int) where {P<:CPU, NBlock} = csr._NEntriesRow[row]
numberOfEntriesPerRow(csr::CSRTuple{P, NBlock}, row::Int) where {P<:GPU, NBlock} = Array(csr._NEntriesRow)[row]
numberOfEntriesPerRowCache(csr::CSRTuple{P, NBlock}, row::Int) where {P, NBlock} = NBlock

Base.size(csr::CSRTuple) = size(csr._map)

Base.eltype(::CSRTuple{P, NBlock}) where {P, NBlock} = Base.eltype(csr._map)

######################################################################################################
# Entry accessing
######################################################################################################

Base.getindex(csr::CSRTuple, i::Int) = csr._map[i]
Base.getindex(csr::CSRTuple, row::Int, col::Int) = getEntryAtRowCol(csr, row, col)

function getEntryAtRowPos(::CSRTuple{P, NBlock}, row::Int, pos::Int=1) where {P, NBlock}
    return (row - 1) * NBlock + pos
end

function getEntryAtRowCol(::CSRTuple{P, NBlock}, row::Int, col::Int) where {P, NBlock}
    i = getEntryAtRowPos(csr, row)
    for j in i:i+NBlock-1
        if csr._map[j] == col
            return j
        end
    end
    return 0
end

function getColumnAtRowPos(csr::CSRTuple{P, NBlock}, row::Int, pos::Int) where {P, NBlock}
    i = getEntryAtRowPos(csr, row, pos)
    return csr._map[i]
end

function getColumnAtEntry(csr::CSRTuple{P, NBlock}, index::Int) where {P, NBlock}
    return csr._map[index]
end

######################################################################################################
# Iterators
######################################################################################################

# Specialized iterator for CSRTuple - no active section checking
function Base.iterate(csr::CSRTuple{P, NBlock}, state=(1, 1)) where {P, NBlock}
    blockId, elementId = state
    
    # Check if we've exhausted all blocks
    if blockId > numberOfRows(csr)
        return nothing
    end
    
    # Find next non-zero entry
    while blockId <= numberOfRows(csr)
        linear_idx = (blockId - 1) * NBlock + elementId
        map_value = csr._map[linear_idx]
        
        # Calculate next state
        next_state = if elementId < NBlock
            (blockId, elementId + 1)
        else
            (blockId + 1, 1)
        end
        
        # Return if non-zero
        if map_value != 0
            return ((blockId, map_value), next_state)
        end
        
        # Move to next position
        blockId, elementId = next_state
    end
    
    return nothing
end

iterateRows(mesh::CSRTuple) = 1:numberOfRows(mesh)

function iterateEntriesOverRow(mesh::CSRTuple{P, NBlock}, row::Int) where {P, NBlock}
    i = getEntryAtRowPos(mesh, row)
    return i:i+NBlock-1
end

######################################################################################################
# Reshape
######################################################################################################

function preallocate!(csr::CSRTuple{P, NBlock}, NAddCache::Int=0) where {P, NBlock}
    
    @assert NAddCache >= 0 "NAddCache must be >= 0"

    N = numberOfRows(csr)
    oldNCache = numberOfRowsCache(csr)
    newNCache = N + NAddCache + numberOfRowsAdded(csr)

    if newNCache <= oldNCache
        return csr
    else
        newSize = newNCache * NBlock

        resize!(csr._map, newSize)
        resize!(csr._addElementOffsets, newNCache + 1)
        resize!(csr._childs, newNCache + 1)

        csr._NRowsCache .= newNCache

        return csr
    end

end

function map!(csrTarget::CSRTuple{P, NBlock}, csrOrigin::CSRTuple{P, NBlock}, map::AbstractVector) where {P, NBlock}

    @assert numberOfRows(csrTarget) == numberOfRows(csrOrigin) "Both CSRTuples must have the same number of rows"

    KernelAbstractions.@kernel function _kernel_remap!(csrTarget, csrOrigin, map)
        i = @index(Global)
        if map[i] == 0
            nothing
        else
            id = getEntryAtRowPos(csr, i)
            idRemap = getEntryAtRowPos(csr, map[i])
            for j in 0:NBlock-1
                auxiliar[idRemap + j] = map[id + j]
            end
        end
    end
    device = KernelAbstractions.get_backend(csrTarget)
    threads = device === CPU ? Threads.nthreads() : 256
    _kernel_remap!(device, threads)(csrTarget, csrOrigin, map, ndrange=numberOfRows(csrTarget))
    KernelAbstractions.synchronize(device)

    return
end

function reset!(csr::CSRTuple{P, NBlock}) where {P, NBlock}
    return
end

######################################################################################################
# Row Operations
######################################################################################################

function hasElement(csr::CSRTuple{P, NBlock}, row::Int, col::Int) where {P, NBlock}

    i = getEntryAtRowPos(csr, row)
    for j in i:i+NBlock-1
        if csr._map[j] == col
            return true
        end
    end

    return false 
end

function lengthRowCache(csr::CSRTuple{P, NBlock}, row::Int) where {P, NBlock}
    return NBlock
end

function lengthRowActive(csr::CSRTuple{P, NBlock}, row::Int) where {P, NBlock}
    count = 0
    i = getEntryAtRowPos(csr, row)
    for j in i:i+NBlock-1
        if csr._map[j] != 0
            count += 1
        end
    end
    return count
end

######################################################################################################
# Row Operations
######################################################################################################

function substituteColAtRow!(csr::CSRTuple{P, NBlock}, row::Int, colOld::Int, colNew::Int) where {P, NBlock}

    i = getEntryAtRowCol(csr, row, colOld)
    if i != 0
        if colNew == 0
            csr._NEntries[1] = max(0, csr._NEntries[1] - 1)
            csr._NEntriesRow[row] = max(0, csr._NEntriesRow[row] - 1)
        elseif csr._map[i] == 0
            @atomic csr._NEntries[1] += 1
            @atomic csr._NEntriesRow[row] += 1
        end

        csr._map[i] = colNew
        return
    end

    @print "Error: Column $colOld not found in row $row\n"
end

function substitutePosAtRow!(csr::CSRTuple{P, NBlock}, row::Int, pos::Int, colNew::Int) where {P, NBlock}

    i = getEntryAtRowPos(csr, row, pos)
    if i != 0
        if csr._map[i] != 0 && colNew == 0
            csr._NEntries[1] = max(0, csr._NEntries[1] - 1)
            csr._NEntriesRow[row] = max(0, csr._NEntriesRow[row] - 1)
        elseif csr._map[i] == 0 && colNew != 0
            @atomic csr._NEntries[1] += 1
            @atomic csr._NEntriesRow[row] += 1
        end
        csr._map[i] = colNew
        return
    end

end

function removeColAtRow!(csr::CSRTuple{P, NBlock}, row::Int, col::Int) where {P, NBlock}

    i = getEntryAtRowCol(csr, row, col)
    if i != 0
        csr._map[i] = 0
        csr._NEntries[1] = max(0, csr._NEntries[1] - 1)
        csr._NEntriesRow[row] = max(0, csr._NEntriesRow[row] - 1)
        return
    end

end

function removePosAtRow!(csr::CSRTuple{P, NBlock}, row::Int, pos::Int) where {P, NBlock}

    i = getEntryAtRowPos(csr, row, pos)
    if i != 0
        if csr._map[i] != 0
            csr._NEntries[1] = max(0, csr._NEntries[1] - 1)
            csr._NEntriesRow[row] = max(0, csr._NEntriesRow[row] - 1)
        end
        csr._map[i] = 0
        return
    end

end

######################################################################################################
# toDevice - Device transfer functions for CSR structures
######################################################################################################

function KernelAbstractions.get_backend(csr::CSRTuple)
    KernelAbstractions.get_backend(csr._map)
end

# CSRTuple to CPU
function toDevice(csr::CSRTuple{P, NBlock}, ::Type{CPU}) where {P<:GPU, NBlock}
    CSRTuple(
        csr._NBlock,
        Adapt.adapt(Array, csr._map),
        SizedVector{1}(Array(csr._NRows)[1]),
        SizedVector{1}(Array(csr._NRowsCache)[1]),
        SizedVector{1}(Array(csr._NEntries)[1]),
        Adapt.adapt(Array, csr._NEntriesRow),
    )
end
function toDevice(csr::CSRTuple{P, NBlock}, device::CPU) where {P<:CPU, NBlock}
    toDevice(csr, typeof(device))
end

toDevice(csr::CSRTuple{P, NBlock}, ::Type{CPU}) where {P<:CPU, NBlock} = csr
toDevice(csr::CSRTuple{P, NBlock}, ::CPU) where {P<:GPU, NBlock} = toDevice(csr, CPU)

function toDevice(csr::CSRTuple{P,NBlock}, backend::Type{<:KernelAbstractions.GPU}) where {P<:CPU, NBlock}
    CSRTuple(
        csr._NBlock,
        Adapt.adapt(backend, csr._map),
        Adapt.adapt(backend, csr._NRows),
        Adapt.adapt(backend, csr._NRowsCache),
        Adapt.adapt(backend, csr._NEntries),
        Adapt.adapt(backend, csr._NEntriesRow),
    )
end

function toDevice(csr::CSRTuple{P,NBlock}, backend::KernelAbstractions.GPU) where {P<:CPU, NBlock}
    toDevice(csr, typeof(backend))
end

toDevice(csr::CSRTuple{P,NBlock}, ::KernelAbstractions.GPU) where {P<:GPU,NBlock} = csr
toDevice(csr::CSRTuple{P,NBlock}, ::Type{<:KernelAbstractions.GPU}) where {P<:GPU,NBlock} = csr