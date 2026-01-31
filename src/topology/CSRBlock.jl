######################################################################################################
# CSRBlock - Fixed-size tuples (block size is a type parameter)
######################################################################################################
struct CSRBlock{
            P, F, PR, AI, PR2, AF
        } <: AbstractCSR

    _NBlock::AI
    _sorted::Bool

    _map::PR
    _rowEntryNext::PR2
    _rowEntryPrevious::PR2
    _rowFirstEntry::PR2
    _rowLastEntry::PR2

    _NRows::AI
    _NRowsCache::AI
    _NRowsCompacted::AI

    _NEntries::AI
    _NEntriesRow::PR
    _NEntriesRowAdd::PR
    _NEntriesRowCompacted::PR

    _rowSurvived::PR
    _auxiliar::AF

end
Adapt.@adapt_structure CSRBlock

function CSRBlock(
    NBlock::Int,
    N::Int,
    NCache::Int=N;
    sorted::Bool=false,
    auxiliar::Union{Nothing, AuxiliarFields}=nothing
)

    @assert NBlock > 0 "NBlock must be > 0"
    @assert N >= 0 "N must be >= 0"
    @assert NCache >= N "NCache must be >= N"

    _NBlock = SizedVector{1}(NBlock)
    _sorted = sorted

    _map = zeros(Int, NCache*NBlock)
    
    # Initialize sorting arrays if sorted is true
    if _sorted
        _rowEntryNext = zeros(Int, NCache*NBlock)
        _rowEntryPrevious = zeros(Int, NCache*NBlock)
        _rowFirstEntry = zeros(Int, NCache)
        _rowLastEntry = zeros(Int, NCache)
    else
        _rowEntryNext = nothing
        _rowEntryPrevious = nothing
        _rowFirstEntry = nothing
        _rowLastEntry = nothing
    end

    _NRows = SizedVector{1}(N)
    _NRowsCache = SizedVector{1}(NCache)
    _NRowsCompacted = SizedVector{1}(N)

    _NEntries = SizedVector{1}(0)
    _NEntriesRow = zeros(Int, NCache)
    _NEntriesRowAdd = zeros(Int, NCache)
    _NEntriesRowCompacted = zeros(Int, NCache)

    _rowSurvived = ones(Int, NCache)
    @views _rowSurvived[N+1:end] .= 0
    _auxiliar = auxiliar
    if _auxiliar === nothing
        _auxiliar = AuxiliarFields(0, 0)
    end

    P = platform()
    F = _sorted
    PR = typeof(_map)
    AI = typeof(_NRows)
    PR2 = typeof(_rowEntryNext)
    AF = typeof(_auxiliar)

    CSRBlock{
            P, F, PR, AI, PR2, AF
        }(
            _NBlock,
            _sorted,
            _map,
            _rowEntryNext,
            _rowEntryPrevious,
            _rowFirstEntry,
            _rowLastEntry,
            _NRows,
            _NRowsCache,
            _NRowsCompacted,
            _NEntries,
            _NEntriesRow,
            _NEntriesRowAdd,
            _NEntriesRowCompacted,
            _rowSurvived,
            _auxiliar
        )
end

function CSRBlock(
            _NBlock,
            _sorted,
            _map,
            _rowEntryNext,
            _rowEntryPrevious,
            _rowFirstEntry,
            _rowLastEntry,
            _NRows,
            _NRowsCache,
            _NRowsCompacted,
            _NEntries,
            _NEntriesRow,
            _NEntriesRowAdd,
            _NEntriesRowCompacted,
            _rowSurvived,
            _auxiliar,
        )
    
    P = platform()
    F = _sorted
    PR = typeof(_map)
    AI = typeof(_NRows)
    PR2 = typeof(_rowEntryNext)
    AF = typeof(_auxiliar)

    CSRBlock{
            P, F, PR, AI, PR2, AF
        }(
            _NBlock,
            _sorted,
            _map,
            _rowEntryNext,
            _rowEntryPrevious,
            _rowFirstEntry,
            _rowLastEntry,
            _NRows,
            _NRowsCache,
            _NRowsCompacted,
            _NEntries,
            _NEntriesRow,
            _NEntriesRowAdd,
            _NEntriesRowCompacted,
            _rowSurvived,
            _auxiliar,
        )
end

function CSRBlock(
        data::AbstractMatrix{<:Int}; 
        NRowsCache::Int=size(data, 1),  
        NBlock::Int=size(data, 2), 
        sorted::Bool=false, 
        auxiliar::Union{Nothing, AuxiliarFields}=nothing
    )

    @assert NRowsCache >= size(data, 1) "NRowsCache must be >= number of rows in data"
    @assert NBlock >= size(data, 2) "NBlock must be >= number of columns in data"

    NSize = size(data, 1)
    NBlockMatrix = size(data, 2)

    # Create CSRBlock with appropriate size
    csr = CSRBlock(
        NBlock,
        NSize,
        NRowsCache;
        sorted=sorted,
        auxiliar=auxiliar
    )
    
    # Count active entries and entries per row
    active_count = 0
    for row in 1:NSize
        row_count = 0
        for col in 1:NBlockMatrix
            if data[row, col] != 0
                active_count += 1
                row_count += 1
                i = getEntryAtRowPos(csr, row, col)
                csr._map[i] = data[row,col]
                if sorted
                    csr._rowEntryPrevious[i] = col > 1 ? col - 1 : 0
                    csr._rowEntryNext[i] = col < NBlockMatrix ? col + 1 : 0
                end
            end
        end
        csr._NEntriesRow[row] = row_count
        if sorted && row_count > 0
            csr._rowFirstEntry[row] = 1
            csr._rowLastEntry[row] = row_count
        end
    end

    csr._NEntries[1] = active_count
    csr._NEntriesRowAdd .= csr._NEntriesRow
    csr._NEntriesRowCompacted .= csr._NEntriesRow

    _initializeSorting!(csr)

    return csr
end

function CSRBlock(data::AbstractVector{<:AbstractVector{<:Int}};  NRowsCache::Int=length(data), NBlock=maximum(length.(data)), sorted::Bool=false, auxiliar::Union{Nothing, AuxiliarFields}=nothing)
    
    @assert NRowsCache >= length(data) "NRowsCache must be >= number of rows in data"
    @assert NBlock >= maximum(length.(data)) "NBlock must be >= maximum number of columns in data"

    N = length(data)
    NCache = NRowsCache

    # Create CSRBlock with appropriate size
    csr = CSRBlock(
        NBlock,
        N,
        NCache;
        sorted=sorted,
        auxiliar=auxiliar
    )

    # Fill data, padding with zeros if necessary
    active_count = 0
    for i in 1:N
        row_count = 0
        for j in 1:length(data[i])
            if data[i][j] != 0
                active_count += 1
                row_count += 1
                idx = getEntryAtRowPos(csr, i, j)
                csr._map[idx] = data[i][j]
                if sorted
                    csr._rowEntryPrevious[idx] = j > 1 ? j - 1 : 0
                    csr._rowEntryNext[idx] = j < length(data[i]) ? j + 1 : 0
                end
            end
        end
        csr._NEntriesRow[i] = row_count
        if sorted && row_count > 0
            csr._rowFirstEntry[i] = 1
            csr._rowLastEntry[i] = row_count
        end
    end
    
    csr._NEntries[1] = active_count
    csr._NEntriesRowAdd .= csr._NEntriesRow
    csr._NEntriesRowCompacted .= csr._NEntriesRow

    _initializeSorting!(csr)

    return csr
end

function Base.show(io::IO, x::CSRBlock{
            P, PR, AI
        }) where {
            P, PR, AI
        } 
    
    sorted = isSorted(x)

    println(io, "CSRBlock{NRows=$(numberOfRows(x)), NRowsCache=$(numberOfRowsCache(x)), Sorted=$sorted, NBlock=$(x._NBlock[1])}")    
end

function Base.show(io::IO, x::Type{CSRBlock{P, F, PR, AI}}) where {P, F, PR, AI}

    sorted = isSorted(x)
    println(io, "CSRBlock{$P, $PR, $AI, Sorted=$sorted}")
end

Base.length(csr::CSRBlock{P}) where {P} = numberOfEntries(csr)

numberOfEntries(csr::CSRBlock{P}) where {P<:CPU} = csr._NEntries[1]
numberOfEntries(csr::CSRBlock{P}) where {P<:GPU} = Array(csr._NEntries)[1]
numberOfEntriesCache(csr::CSRBlock{P}) where {P} = length(csr._map)
numberOfRows(csr::CSRBlock{P}) where {P<:CPU} = csr._NRows[1]
numberOfRows(csr::CSRBlock{P}) where {P<:GPU} = Array(csr._NRows)[1]
numberOfRowsCache(csr::CSRBlock{P}) where {P<:CPU} = csr._NRowsCache[1]
numberOfRowsCache(csr::CSRBlock{P}) where {P<:GPU} = Array(csr._NRowsCache)[1]
numberOfEntriesInRow(csr::CSRBlock{P}, row::Int) where {P<:CPU} = csr._NEntriesRow[row]
numberOfEntriesInRow(csr::CSRBlock{P}, row::Int) where {P<:GPU} = Array(csr._NEntriesRow)[row]
numberOfEntriesInRowCache(csr::CSRBlock{P}, row::Int) where {P} = csr._NBlock[1]

blockLength(csr::CSRBlock{P}) where {P} = csr._NBlock[1]

isSorted(csr::CSRBlock{P, false}) where {P} = false
isSorted(csr::CSRBlock{P, true}) where {P} = true
isSorted(csr::Type{CSRBlock{P, false}}) where {P} = false
isSorted(csr::Type{CSRBlock{P, true}}) where {P} = true

sortingFlavorValue(csr::CSRBlock{P, F}) where {P, F} = F
sortingFlavorValue(csr::Type{CSRBlock{P, F}}) where {P, F} = F

Base.size(csr::CSRBlock) = size(csr._map)

Base.eltype(::CSRBlock{P}) where {P} = Base.eltype(csr._map)

######################################################################################################
# Entry accessing
######################################################################################################

Base.getindex(csr::CSRBlock, i::Int) = csr._map[i]
Base.getindex(csr::CSRBlock, row::Int, col::Int) = getEntryAtRowCol(csr, row, col)

function getEntryAtRowPos(csr::CSRBlock{P}, row::Int, pos::Int=1) where {P}
    nblock = csr._NBlock[1]
    return (row - 1) * nblock + pos
end

function getEntryAtRowCol(csr::CSRBlock{P}, row::Int, col::Int) where {P}
    i = getEntryAtRowPos(csr, row)
    n = numberOfEntriesInRow(csr, row)
    for j in i:i+n-1
        if csr._map[j] == col
            return j
        end
    end
    return 0
end

function getPosAtRowCol(csr::CSRBlock{P}, row::Int, col::Int) where {P}
    i = getEntryAtRowPos(csr, row)
    n = numberOfEntriesInRow(csr, row)
    for pos in 1:n
        j = i + pos - 1
        if csr._map[j] == col
            return pos
        end
    end
    return 0
end

function getColumnAtRowPos(csr::CSRBlock{P}, row::Int, pos::Int) where {P}
    i = getEntryAtRowPos(csr, row, pos)
    return csr._map[i]
end

function getColumnAtEntry(csr::CSRBlock{P}, index::Int) where {P}
    return csr._map[index]
end

function getNextEntryAtRowPos(csr::CSRBlock{P, false}, row::Int, pos::Int) where {P}

    if pos >= numberOfEntriesInRow(csr, row)
        return 0
    else
        return getEntryAtRowPos(csr, row, pos) + 1
    end

end

function getNextEntryInRowPos(csr::CSRBlock{P, true}, row::Int, pos::Int) where {P}

    i = getEntryAtRowPos(csr, row, pos)
    pNext = csr._rowEntryNext[i]
    if pNext == 0
        return 0
    else
        return getEntryAtRowPos(csr, row, pNext)
    end

end

function getNextPosAtRowPos(csr::CSRBlock{P, false}, row::Int, pos::Int) where {P}

    if pos >= numberOfEntriesInRow(csr, row)
        return 0
    else
        return pos + 1
    end

end

function getNextPosAtRowCol(csr::CSRBlock{P, false}, row::Int, col::Int) where {P}

    pos = getPosAtRowCol(csr, row, col)
    if pos == 0 || pos >= numberOfEntriesInRow(csr, row)
        return 0
    else
        return pos + 1
    end

end

function getNextPosAtRowCol(csr::CSRBlock{P, true}, row::Int, col::Int) where {P}

    pos = getPosAtRowCol(csr, row, col)
    if pos == 0
        return 0
    else
        i = getEntryAtRowPos(csr, row, pos)
        pNext = csr._rowEntryNext[i]
        return pNext
    end

end

function getPreviousEntryAtRowPos(csr::CSRBlock{P, true}, row::Int, pos::Int) where {P}

    for i in 1:blockLength(csr)
        if csr._rowEntryNext[getEntryAtRowPos(csr, row, i)] == pos
            return i
        end
    end

    return 0

end

function getPreviousEntryAtRowCol(csr::CSRBlock{P, false}, row::Int, col::Int) where {P}

    pos = getPosAtRowCol(csr, row, col)
    if pos == 0 || pos <= 1
        return 0
    else
        return getEntryAtRowPos(csr, row, pos - 1)
    end

end

function getPreviousEntryAtRowCol(csr::CSRBlock{P, true}, row::Int, col::Int) where {P}

    for i in 1:blockLength(csr)
        if csr._rowEntryNext[getEntryAtRowPos(csr, row, i)] == getPosAtRowCol(csr, row, col)
            return getEntryAtRowPos(csr, row, i)
        end
    end

    return 0

end

function getPreviousPosAtRowCol(csr::CSRBlock{P, false}, row::Int, col::Int) where {P}

    pos = getPosAtRowCol(csr, row, col)
    if pos == 0 || pos <= 1
        return 0
    else
        return pos - 1
    end

end

function getPreviousPosAtRowCol(csr::CSRBlock{P, true}, row::Int, col::Int) where {P}

    for i in 1:blockLength(csr)
        if csr._rowEntryNext[getEntryAtRowPos(csr, row, i)] == getPosAtRowCol(csr, row, col)
            return i
        end
    end

    return 0

end

######################################################################################################
# Entry accessing
######################################################################################################

isRowAlive(csr::CSRBlock{P}, row::Int) where {P} = csr._rowSurvived[row] != 0

hasRowCol(csr::CSRBlock{P}, row::Int, col::Int) where {P} = getEntryAtRowCol(csr, row, col) != 0

######################################################################################################
# Iterators
######################################################################################################

# Specialized iterator for CSRBlock - active elements are stored at beginning of each row
function Base.iterate(csr::CSRBlock{P}, state=(1, 1)) where {P}
    row, pos = state
    nblock = csr._NBlock[1]
    
    # Check if we've exhausted all rows
    if row > numberOfRows(csr)
        return nothing
    end
    
    # Get number of entries in current row
    n_entries = numberOfEntriesInRow(csr, row)
    
    # If position exceeds entries in this row, move to next row
    if pos > n_entries
        return Base.iterate(csr, (row + 1, 1))
    end
    
    # Get value at current position (active entries are at beginning)
    linear_idx = (row - 1) * nblock + pos
    map_value = csr._map[linear_idx]
    
    # Calculate next state
    next_state = (row, pos + 1)
    
    return ((row, map_value), next_state)
end

iterateRows(mesh::CSRBlock) = Iterators.filter(row -> mesh._NEntriesRow[row] > 0, 1:numberOfRows(mesh))

function iterateRowEntries(mesh::CSRBlock{P,false}, row::Int) where {P}
    nblock = mesh._NBlock[1]
    start = getEntryAtRowPos(mesh, row)
    idxs = Iterators.filter(idx -> mesh._map[idx] > 0, start:(start + nblock - 1))
    return Base.Generator(idx -> mesh._map[idx], idxs)
end

# Custom iterator for sorted entries (both flavor 1 and 2 use linked list)
struct CSRBlockSortedIterator{P, F, PR}
    mesh::CSRBlock{P, F, PR}
    first_idx::Int
    row::Int
end

# Both EntriesPerRowSorting and CustomSorting use the same first-next logic
function Base.iterate(iter::CSRBlockSortedIterator)
    if iter.first_idx == 0
        return nothing
    end
    return (iter.first_idx, iter.first_idx)
end

function Base.iterate(iter::CSRBlockSortedIterator, state::Int)
    next_idx = iter.mesh._rowEntryNext[state]
    if next_idx == 0
        return nothing
    end
    return (next_idx, next_idx)
end

Base.IteratorSize(::Type{<:CSRBlockSortedIterator}) = Base.HasLength()
Base.eltype(::Type{<:CSRBlockSortedIterator}) = Int
Base.length(iter::CSRBlockSortedIterator) = numberOfEntriesInRow(iter.mesh, iter.row)

# Custom iterator for row entries (returns values, not indices)
struct CSRBlockRowEntriesIterator{P, F, PR}
    mesh::CSRBlock{P, F, PR}
    first_offset::Int
    row::Int
    base::Int
end

function Base.iterate(iter::CSRBlockRowEntriesIterator)
    if iter.first_offset == 0
        return nothing
    end
    idx = iter.base + iter.first_offset
    return (iter.mesh._map[idx], iter.first_offset)
end

function Base.iterate(iter::CSRBlockRowEntriesIterator, state::Int)
    next_offset = iter.mesh._rowEntryNext[iter.base + state]
    if next_offset == 0
        return nothing
    end
    idx = iter.base + next_offset
    return (iter.mesh._map[idx], next_offset)
end

Base.IteratorSize(::Type{<:CSRBlockRowEntriesIterator}) = Base.HasLength()
Base.eltype(::Type{<:CSRBlockRowEntriesIterator}) = Int
Base.length(iter::CSRBlockRowEntriesIterator) = numberOfEntriesInRow(iter.mesh, iter.row)

# Sorted flavor uses linked list traversal
function iterateRowEntries(mesh::CSRBlock{P,true}, row::Int) where {P}
    first_offset = mesh._rowFirstEntry[row]
    base = getEntryAtRowPos(mesh, row) - 1
    return CSRBlockRowEntriesIterator(mesh, first_offset, row, base)
end

######################################################################################################
# Initialization of linked-list pointers depending on sorting flavor
######################################################################################################

# Unsorted flavor: nothing to initialize
function _initializeSorting!(csr::CSRBlock{P,false}) where {P}
    return csr
end

# Sorted flavor: sort row values and rebuild first/next pointers
function _initializeSorting!(csr::CSRBlock{P,true}) where {P}
    nblock = csr._NBlock[1]
    nrows = numberOfRows(csr)
    for row in 1:nrows
        n = csr._NEntriesRow[row]
        if n <= 0
            csr._rowFirstEntry[row] = 0
            csr._rowLastEntry[row] = 0
            if !isnothing(csr._rowEntryNext)
                start = getEntryAtRowPos(csr, row)
                @inbounds @views begin
                    csr._rowEntryNext[start:start + nblock - 1] .= 0
                    csr._rowEntryPrevious[start:start + nblock - 1] .= 0
                end
            end
            continue
        end

        start = getEntryAtRowPos(csr, row)
        @inbounds @views sort!(csr._map[start:start + n - 1])

        # Rebuild linked list pointers: 1 -> 2 -> ... -> n -> 0
        csr._rowFirstEntry[row] = 1
        csr._rowLastEntry[row] = n
        @inbounds begin
            for i in 1:n
                csr._rowEntryNext[start + i - 1] = (i < n) ? (i + 1) : 0
                csr._rowEntryPrevious[start + i - 1] = (i > 1) ? (i - 1) : 0
            end
            if n < nblock
                csr._rowEntryNext[start + n:start + nblock - 1] .= 0
                csr._rowEntryPrevious[start + n:start + nblock - 1] .= 0
            end
        end
    end
    return csr
end



######################################################################################################
# Basic Functions
######################################################################################################

function Base.copy(csr::CSRBlock{P}) where {P}

    csrCopy = CSRBlock(
        Array(csr._NBlock)[1],
        numberOfRows(csr),
        numberOfRowsCache(csr);
        sorted=isSorted(csr),
        auxiliar=csr._auxiliar
    )

    copy!(csrCopy._map, csr._map)
    copy!(csrCopy._rowEntryNext, csr._rowEntryNext)
    copy!(csrCopy._rowEntryPrevious, csr._rowEntryPrevious)
    copy!(csrCopy._rowFirstEntry, csr._rowFirstEntry)
    copy!(csrCopy._rowLastEntry, csr._rowLastEntry)
    copy!(csrCopy._NRows, csr._NRows)
    copy!(csrCopy._NRowsCache, csr._NRowsCache)
    copy!(csrCopy._NRowsCompacted, csr._NRowsCompacted)
    copy!(csrCopy._NEntries, csr._NEntries)
    copy!(csrCopy._NEntriesRow, csr._NEntriesRow)
    copy!(csrCopy._NEntriesRowAdd, csr._NEntriesRowAdd)
    copy!(csrCopy._NEntriesRowCompacted, csr._NEntriesRowCompacted)
    copy!(csrCopy._rowSurvived, csr._rowSurvived)

    return csrCopy
end

function Base.copy(csr::CSRBlock{P,false}) where {P}

    csrCopy = CSRBlock(
        Array(csr._NBlock)[1],
        numberOfRows(csr),
        numberOfRowsCache(csr);
        sorted=isSorted(csr),
        auxiliar=csr._auxiliar
    )

    copy!(csrCopy._map, csr._map)
    copy!(csrCopy._NRows, csr._NRows)
    copy!(csrCopy._NRowsCache, csr._NRowsCache)
    copy!(csrCopy._NRowsCompacted, csr._NRowsCompacted)
    copy!(csrCopy._NEntries, csr._NEntries)
    copy!(csrCopy._NEntriesRow, csr._NEntriesRow)
    copy!(csrCopy._NEntriesRowAdd, csr._NEntriesRowAdd)
    copy!(csrCopy._NEntriesRowCompacted, csr._NEntriesRowCompacted)
    copy!(csrCopy._rowSurvived, csr._rowSurvived)

    return csrCopy
end

function Base.copyto!(dest::CSRBlock{P}, src::CSRBlock{P}) where {P}

    copy!(dest._map, src._map)
    copy!(dest._rowEntryNext, src._rowEntryNext)
    copy!(dest._rowEntryPrevious, src._rowEntryPrevious)
    copy!(dest._rowFirstEntry, src._rowFirstEntry)
    copy!(dest._rowLastEntry, src._rowLastEntry)
    copy!(dest._NRows, src._NRows)
    copy!(dest._NRowsCache, src._NRowsCache)
    copy!(dest._NRowsCompacted, src._NRowsCompacted)
    copy!(dest._NEntries, src._NEntries)
    copy!(dest._NEntriesRow, src._NEntriesRow)
    copy!(dest._NEntriesRowAdd, src._NEntriesRowAdd)
    copy!(dest._NEntriesRowCompacted, src._NEntriesRowCompacted)
    copy!(dest._rowSurvived, src._rowSurvived)

    return dest
end

function Base.copyto!(dest::CSRBlock{P,false}, src::CSRBlock{P,false}) where {P}

    copy!(dest._map, src._map)
    copy!(dest._NRows, src._NRows)
    copy!(dest._NRowsCache, src._NRowsCache)
    copy!(dest._NRowsCompacted, src._NRowsCompacted)
    copy!(dest._NEntries, src._NEntries)
    copy!(dest._NEntriesRow, src._NEntriesRow)
    copy!(dest._NEntriesRowAdd, src._NEntriesRowAdd)
    copy!(dest._NEntriesRowCompacted, src._NEntriesRowCompacted)
    copy!(dest._rowSurvived, src._rowSurvived)

    return dest
end

######################################################################################################
# Reshape
######################################################################################################

function overflow(csr::CSRBlock{P}) where {P}

    NRowsCache = numberOfRowsCache(csr)
    NRowsNew = numberOfRows(csr)

    NBlock = Array(csr._NBlock)[1]
    NBlockNew = maximum(csr._NEntriesRowAdd)

    if NBlockNew <= NBlock && NRowsNew <= NRowsCache
        return false
    else
        return true
    end

end

function compactRowEntries!(csr::CSRBlock{P, F}) where {P, F}

    KernelAbstractions.@kernel function _kernel_compact!(csr)
        row = @index(Global)
        NBlock = csr._NBlock[1]

        posFirst = getEntryAtRowPos(csr, row)
        nentries = numberOfEntriesInRow(csr, row)

        # Collect entries in linked list order
        readIdx = csr._rowFirstEntry[row]
        for writePos in 1:nentries
            if readIdx == 0
                break
            end
            actualReadPos = posFirst + readIdx - 1
            
            if writePos > 1
                actualWritePos = posFirst + writePos - 2
                if actualReadPos != actualWritePos
                    csr._map[actualWritePos] = csr._map[actualReadPos]
                end
            end
            readIdx = csr._rowEntryNext[readIdx]
        end

        # Clear remaining entries
        for writePos in nentries+1:NBlock
            csr._map[posFirst + writePos - 1] = 0
        end

        # Reset row entry next for the compacted entries
        for i in 1:nentries-1
            csr._rowEntryNext[posFirst + i - 1] = i + 1
            csr._rowEntryPrevious[posFirst + i - 1] = i - 1
        end
        if nentries > 0
            csr._rowEntryNext[posFirst + nentries - 1] = 0
            csr._rowEntryPrevious[posFirst] = 0
            csr._rowEntryPrevious[posFirst + nentries - 1] = nentries - 1
        end
        csr._rowFirstEntry[row] = nentries > 0 ? 1 : 0
        csr._rowLastEntry[row] = nentries > 0 ? nentries : 0

        csr._NEntriesRowAdd[row] = 0
        csr._NEntriesRowCompacted[row] = 0
    end

    N = numberOfRows(csr)

    backend = KernelAbstractions.get_backend(csr)
    threads = backend === CPU ? Threads.nthreads() : 256
    _kernel_compact!(backend, threads)(csr, ndrange=N)
    KernelAbstractions.synchronize(backend)

    return csr
end

function compactRowEntries!(csr::CSRBlock{P, false}) where {P}

    KernelAbstractions.@kernel function _kernel_compact!(csr)
        row = @index(Global)
        NBlock = csr._NBlock[1]
        NRowEntries = csr._NEntriesRow[row]

        if NRowEntries > 0 
            posFirst = getEntryAtRowPos(csr, row)
            offset = 0
            nEntries = 0
            for j in 0:NBlock-1
                readPos = posFirst + j
                if csr._map[readPos] == 0
                    offset += 1
                elseif offset > 0
                    writePos = readPos - offset
                    csr._map[writePos] = csr._map[readPos]
                    csr._map[readPos] = 0
                    nEntries += 1
                else
                    nEntries += 1
                end
            end
            csr._NEntriesRow[row] = nEntries
            csr._NEntriesRowAdd[row] = nEntries
            csr._NEntriesRowCompacted[row] = nEntries
        end
    end

    N = numberOfRows(csr)

    backend = KernelAbstractions.get_backend(csr)
    threads = backend === CPU ? Threads.nthreads() : 256
    _kernel_compact!(backend, threads)(csr, ndrange=N)
    KernelAbstractions.synchronize(backend)

    return csr
end

function rebuildCSR!(csr::CSRBlock{P}, NRows, NBlock) where {P}

    # Kernel to make _map
    function _build_map!(csr::CSRBlock{P, false}, NBlockOld, NBlockNew) where {P}
        KernelAbstractions.@kernel function _kernel_build_map!(csr::CSRBlock{P, false}, NBlockOld, NBlockNew)
            row = @index(Global)
            rowNew = csr._auxiliar._mapRow[row]
            rowAlive = csr._rowSurvived[row]

            # Skip rows marked for deletion
            if rowAlive != 0

                oldPos = (row - 1) * NBlockOld
                newPos = (rowNew - 1) * NBlockNew
                pos = 1
                for i in 1:NBlockOld
                    if csr._map[oldPos + i] != 0
                        csr._auxiliar._map[oldPos + i] = newPos + pos
                        pos += 1
                    end
                end
                csr._NEntriesRow[rowNew] = csr._NEntriesRow[row]

            end
        end

        backend = KernelAbstractions.get_backend(csr)
        threads = backend === CPU ? Threads.nthreads() : 256
        _kernel_build_map!(backend, threads)(csr, NBlockOld, NBlockNew, ndrange=numberOfRowsCache(csr))
        KernelAbstractions.synchronize(backend)
    end

    # Kernel to map _map
    function _map!(csr::CSRBlock{P}, map::AbstractVector) where {P}
        KernelAbstractions.@kernel function _kernel_map!(csr::CSRBlock{P, false}, map)
            index = @index(Global)

            if csr._auxiliar._map[index] != 0
                oldPos = index
                newPos = csr._auxiliar._map[index]
                csr._auxiliar._copy[newPos] = map[oldPos]
            end
        end    

        backend = KernelAbstractions.get_backend(csr)
        threads = backend === CPU ? Threads.nthreads() : 256
        _kernel_map!(backend, threads)(csr, map, ndrange=numberOfRowsCache(csr)*csr._NBlock[1])
        KernelAbstractions.synchronize(backend)

        resize!(map, NRows*NBlock)
        map .= csr._auxiliar._copy[1:NRows*NBlock]
        @views map[NRows*NBlock+1:end] .= 0
    end

    # Kernel to map _mapRow
    function _mapRow!(csr::CSRBlock{P}, map::AbstractVector, oldNRows::Int, compactedNRows::Int) where {P}
        KernelAbstractions.@kernel function _kernel_mapRow!(csr::CSRBlock{P, false}, map)
            index = @index(Global)
            
            if csr._rowSurvived[index] != 0
                oldPos = index
                newPos = csr._auxiliar._mapRow[index]
                csr._auxiliar._copyRow[newPos] = map[oldPos]
            end
        end    

        backend = KernelAbstractions.get_backend(csr)
        threads = backend === CPU ? Threads.nthreads() : 256
        _kernel_mapRow!(backend, threads)(csr, map, ndrange=oldNRows)
        KernelAbstractions.synchronize(backend)

        resize!(map, NRows)
        @views map[1:compactedNRows] .= csr._auxiliar._copyRow[1:compactedNRows]
        @views map[compactedNRows+1:end] .= 0
    end

    oldNBlock = Array(csr._NBlock)[1]
    oldNRows = numberOfRowsCache(csr)
    oldNRowsCache = numberOfRowsCache(csr)
    compactedNRows = Array(csr._NRowsCompacted)[1]

    preallocate!(csr._auxiliar; N=NRows*NBlock, NRow=NRows)
    clear!(csr._auxiliar, N=NRows*NBlock, NRow=NRows)

    # Build _mapRow
    cumsum!(@view(csr._auxiliar._mapRow[1:oldNRowsCache]), csr._rowSurvived)
    # Build _map
    _build_map!(csr, oldNBlock, NBlock)

    # _NBlock
    csr._NBlock .= NBlock
    # _map
    _map!(csr, csr._map)
    # _rowEntryNext
    if csr._sorted
        _map!(csr, csr._rowEntryNext)
    end
    # _rowEntryPrevious
    if csr._sorted
        _map!(csr, csr._rowEntryPrevious)
    end
    # _rowFirstEntry
    if csr._sorted
        _map!(csr, csr._rowFirstEntry)
    end
    # _rowLastEntry
    if csr._sorted
        _map!(csr, csr._rowLastEntry)
    end
    # _NRows
    csr._NRows .= Array(csr._auxiliar._mapRow)[oldNRows]
    # _NRowsCache
    csr._NRowsCache .= NRows
    # _NRowsCompacted
    csr._NRowsCompacted .= csr._NRowsCompacted
    # _NEntries
    # csr._NEntries .= csr._NEntries
    # _NEntriesRowCompacted
    _mapRow!(csr, csr._NEntriesRowCompacted, oldNRows, compactedNRows)
    # _NEntriesRow
    # csr._NEntriesRow .= csr._NEntriesRowCompacted
    @views csr._NEntriesRow[numberOfRows(csr)+1:end] .= 0    
    # _NEntriesRowAdd
    resize!(csr._NEntriesRowAdd, NRows)
    csr._NEntriesRowAdd .= csr._NEntriesRowCompacted
    # _rowSurvived
    resize!(csr._rowSurvived, NRows)
    @views csr._rowSurvived[1:numberOfRows(csr)] .= 1
    @views csr._rowSurvived[numberOfRows(csr)+1:end] .= 0
    
    return csr
end

function preallocate!(csr::CSRBlock{P}, csrOld::CSRBlock{P}) where {P}

    NRowsCache = numberOfRowsCache(csr)
    NRows = numberOfRows(csr)
    NRowsNewCompacted = Array(csr._NRowsCompacted)[1]

    NBlock = Array(csr._NBlock)[1]
    NBlockNew = maximum(@view csr._NEntriesRowAdd[1:min(NRows, NRowsCache)])
    NBlockCompacted = maximum(@view csr._NEntriesRowCompacted[1:min(NRows, NRowsCache)])

    if NBlockNew <= NBlock && NRows <= NRowsCache
        nothing
    elseif NBlockCompacted <= NBlock && NRowsNewCompacted <= NRowsCache
        compactRowEntries!(csrOld)
        copyto!(csr, csrOld)
    else
        rebuildCSR!(csrOld, max(NRowsNewCompacted, NRowsCache), max(NBlock, NBlockCompacted))
        copyto!(csr, csrOld)
    end

    return

end

function map!(csrTarget::CSRBlock{P}, csrOrigin::CSRBlock{P}, map::AbstractVector) where {P}

    @assert numberOfRows(csrTarget) == numberOfRows(csrOrigin) "Both CSRBlocks must have the same number of rows"

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
    backend = KernelAbstractions.get_backend(csrTarget)
    threads = backend === CPU ? Threads.nthreads() : 256
    _kernel_remap!(backend, threads)(csrTarget, csrOrigin, map, ndrange=numberOfRows(csrTarget))
    KernelAbstractions.synchronize(backend)

    return
end

function reset!(csr::CSRBlock{P}) where {P}
    return
end

######################################################################################################
# Row Operations
######################################################################################################

function pushRow!(csr::CSRBlock{P, false}, col::Int) where {P}

    row = @atomic csr._NRows[1] += 1
    @atomic csr._NRowsCompacted[1] += 1

    if row <= numberOfRowsCache(csr)
        i = getEntryAtRowPos(csr, row)
        csr._map[i] = col
        @atomic csr._NEntries[1] += 1
        @atomic csr._NEntriesRow[row] += 1
        @atomic csr._NEntriesRowAdd[row] += 1
        @atomic csr._NEntriesRowCompacted[row] += 1
        csr._rowSurvived[row] = 1
    end

end

function pushRow!(csr::CSRBlock{P, true}, col::Int) where {P}

    row = @atomic csr._NRows[1] += 1
    @atomic csr._NRowsCompacted[1] += 1

    if row <= numberOfRowsCache(csr)
        i = getEntryAtRowPos(csr, row)
        csr._map[i] = col
        @atomic csr._NEntries[1] += 1
        @atomic csr._NEntriesRow[row] += 1
        @atomic csr._NEntriesRowAdd[row] += 1
        @atomic csr._NEntriesRowCompacted[row] += 1
        csr._rowSurvived[row] = 1

        # Update linked list pointers
        csr._rowFirstEntry[row] = 1
        csr._rowEntryNext[i] = 0
    end

end

function pushRow!(csr::CSRBlock{P, false}, cols::NTuple{N,Int}) where {P,N}

    row = @atomic csr._NRows[1] += 1
    @atomic csr._NRowsCompacted[1] += 1

    if row <= numberOfRowsCache(csr)
        @atomic csr._NEntries[1] += N
        @atomic csr._NEntriesRow[row] += N
        @atomic csr._NEntriesRowAdd[row] += N
        @atomic csr._NEntriesRowCompacted[row] += N
        csr._rowSurvived[row] = 1
        if N < csr._NBlock[1]
            i = getEntryAtRowPos(csr, row)
            for j in 1:N
                csr._map[i + j - 1] = cols[j]
            end
        end
    end

end

function pushRow!(csr::CSRBlock{P, true}, cols::NTuple{N,Int}) where {P,N}

    row = @atomic csr._NRows[1] += 1
    @atomic csr._NRowsCompacted[1] += 1

    if row <= numberOfRowsCache(csr)
        @atomic csr._NEntries[1] += N
        @atomic csr._NEntriesRow[row] += N
        @atomic csr._NEntriesRowAdd[row] += N
        @atomic csr._NEntriesRowCompacted[row] += N
        csr._rowSurvived[row] = 1
        if N < csr._NBlock[1]
            i = getEntryAtRowPos(csr, row)
            for j in 1:N
                csr._map[i + j - 1] = cols[j]
            end

            # Update linked list pointers
            csr._rowFirstEntry[row] = 1
            for j in 1:N-1
                csr._rowEntryNext[i + j - 1] = j + 1
            end
            csr._rowEntryNext[i + N - 1] = 0
        end
    end

end

function removeRow!(csr::CSRBlock{P, false}, row::Int) where {P}

    if row > numberOfRows(csr) || row < 1

        @print("Warning: Trying to remove a row that is out of bounds.\n")

    elseif !isRowAlive(csr, row)

        @print("Warning: Trying to remove a row that is already removed.\n")

    else
        @atomic csr._NRowsCompacted[1] -= 1
        @atomic csr._NEntries[1] -= numberOfEntriesInRow(csr, row)
        @atomic csr._NEntriesRow[row] = 0
        @atomic csr._NEntriesRowAdd[row] = 0
        @atomic csr._NEntriesRowCompacted[row] = 0    
        csr._rowSurvived[row] = 0
        for j in getEntryAtRowPos(csr, row):getEntryAtRowPos(csr, row)+numberOfEntriesInRowCache(csr, row)-1
            csr._map[j] = 0
        end
    end

end

function removeRow!(csr::CSRBlock{P, true}, row::Int) where {P}

    if row > numberOfRows(csr) || row < 1

        @print("Warning: Trying to remove a row that is out of bounds.\n")

    elseif !isRowAlive(csr, row)

        @print("Warning: Trying to remove a row that is already removed.\n")

    else
        @atomic csr._NRowsCompacted[1] -= 1
        @atomic csr._NEntries[1] -= numberOfEntriesInRow(csr, row)
        @atomic csr._NEntriesRow[row] = 0
        @atomic csr._NEntriesRowAdd[row] = 0
        @atomic csr._NEntriesRowCompacted[row] = 0    
        csr._rowSurvived[row] = 0
        for j in getEntryAtRowPos(csr, row):getEntryAtRowPos(csr, row)+numberOfEntriesInRowCache(csr, row)-1
            csr._map[j] = 0
            csr._rowEntryNext[j] = 0
        end
    end

end

function insertRowCol!(csr::CSRBlock{P, false}, row::Int, colNew::Int) where {P}


    if !isRowAlive(csr, row)

        @print("Warning: insertRowCol - Trying to insert in a row that is not alive.\n")

    elseif row > numberOfRows(csr)

        @print("Warning: insertRowCol - Trying to insert in a row that does not exist.\n")

    else
        @atomic csr._NEntries[1] += 1
        pNew = @atomic csr._NEntriesRow[row] += 1
        @atomic csr._NEntriesRowAdd[row] += 1
        @atomic csr._NEntriesRowCompacted[row] += 1 

        if pNew <= csr._NBlock[1]
            iNew = getEntryAtRowPos(csr, row, pNew)
            csr._map[iNew] = colNew
        end
    end

end

function insertRowCol!(csr::CSRBlock{P, true}, row::Int, col::Int, colNew::Int) where {P}

    if !isRowAlive(csr, row)

        @print("Warning: insertRowCol - Trying to insert in a row that is not alive.\n")

    elseif row > numberOfRows(csr)

        @print("Warning: insertRowCol - Trying to insert in a row that does not exist.\n")

    else
        @atomic csr._NEntries[1] += 1
        pNew = @atomic csr._NEntriesRow[row] += 1
        @atomic csr._NEntriesRowAdd[row] += 1
        @atomic csr._NEntriesRowCompacted[row] += 1 

        if pNew <= csr._NBlock[1]
            iNew = getEntryAtRowPos(csr, row, pNew)
            csr._map[iNew] = colNew

            iPrev = getEntryAtRowCol(csr, row, col)
            pPrevNext = csr._rowEntryNext[iPrev]
            csr._rowEntryNext[iPrev] = pNew
            csr._rowEntryNext[iNew] = pPrevNext
        end
    end

end

function removeRowCol!(csr::CSRBlock{P, false}, row::Int, col::Int) where {P}

    if !isRowAlive(csr, row)

        @print("Warning: Trying to remove from a row that is not alive. Ignoring.\n")

    elseif !hasRowCol(csr, row, col)

        @print("Warning: Trying to remove a column that does not exist in the row. Ignoring.\n")

    else

        i = getEntryAtRowCol(csr, row, col)
        if i != 0            
            csr._map[i] = 0

            @atomic csr._NEntries[1] -= 1
            @atomic csr._NEntriesRowCompacted[row] -= 1
        end

    end

end

function removeRowCol!(csr::CSRBlock{P, true}, row::Int, col::Int) where {P}

    if !isRowAlive(csr, row)

        @print("Warning: Trying to remove from a row that is not alive. Ignoring.\n")

    elseif !hasRowCol(csr, row, col)

        @print("Warning: Trying to remove a column that does not exist in the row. Ignoring.\n")

    else

        i = getEntryAtRowCol(csr, row, col)
        if i != 0            
            csr._map[i] = 0

            @atomic csr._NEntries[1] -= 1
            @atomic csr._NEntriesRowCompacted[row] -= 1

            iPrevious = getPreviousEntryAtRowCol(csr, row, col)
            pNext = csr._rowEntryNext[i]

            csr._rowEntryNext[i] = 0
            if iPrevious != 0
                csr._rowEntryNext[iPrevious] = pNext
            else
                csr._rowFirstEntry[row] = pNext
            end

        end

    end

end


######################################################################################################
# toBackend - Device transfer functions for CSR structures
######################################################################################################

function KernelAbstractions.get_backend(csr::CSRBlock)
    KernelAbstractions.get_backend(csr._map)
end

# CSRBlock to CPU
function toBackend(csr::CSRBlock{P}, ::Type{CPU}) where {P<:GPU}
    CSRBlock(
        Adapt.adapt(Array, csr._NBlock),
        csr._sorted,
        Adapt.adapt(Array, csr._map),
        isnothing(csr._rowEntryNext) ? nothing : Adapt.adapt(Array, csr._rowEntryNext),
        isnothing(csr._rowEntryPrevious) ? nothing : Adapt.adapt(Array, csr._rowEntryPrevious),
        isnothing(csr._rowFirstEntry) ? nothing : Adapt.adapt(Array, csr._rowFirstEntry),
        isnothing(csr._rowLastEntry) ? nothing : Adapt.adapt(Array, csr._rowLastEntry),
        SizedVector{1}(Array(csr._NRows)[1]),
        SizedVector{1}(Array(csr._NRowsCache)[1]),
        SizedVector{1}(Array(csr._NRowsCompacted)[1]),
        SizedVector{1}(Array(csr._NEntries)[1]),
        Adapt.adapt(Array, csr._NEntriesRow),
        Adapt.adapt(Array, csr._NEntriesRowAdd),
        Adapt.adapt(Array, csr._NEntriesRowCompacted),
        Adapt.adapt(Array, csr._rowSurvived),
        Adapt.adapt(Array, csr._auxiliar),
    )
end
function toBackend(csr::CSRBlock{P}, backend::CPU) where {P<:CPU}
    toBackend(csr, typeof(backend))
end

toBackend(csr::CSRBlock{P}, ::Type{CPU}) where {P<:CPU} = csr
toBackend(csr::CSRBlock{P}, ::CPU) where {P<:GPU} = toBackend(csr, CPU)

function toBackend(csr::CSRBlock{P,F}, backend::Type{<:KernelAbstractions.GPU}) where {P<:CPU,F}
    CSRBlock(
        Adapt.adapt(backend, csr._NBlock),
        csr._sorted,
        Adapt.adapt(backend, csr._map),
        isnothing(csr._rowEntryNext) ? nothing : Adapt.adapt(backend, csr._rowEntryNext),
        isnothing(csr._rowEntryPrevious) ? nothing : Adapt.adapt(backend, csr._rowEntryPrevious),
        isnothing(csr._rowFirstEntry) ? nothing : Adapt.adapt(backend, csr._rowFirstEntry),
        isnothing(csr._rowLastEntry) ? nothing : Adapt.adapt(backend, csr._rowLastEntry),
        Adapt.adapt(backend, csr._NRows),
        Adapt.adapt(backend, csr._NRowsCache),
        Adapt.adapt(backend, csr._NRowsCompacted),
        Adapt.adapt(backend, csr._NEntries),
        Adapt.adapt(backend, csr._NEntriesRow),
        Adapt.adapt(backend, csr._NEntriesRowAdd),
        Adapt.adapt(backend, csr._NEntriesRowCompacted),
        Adapt.adapt(backend, csr._rowSurvived),
        Adapt.adapt(backend, csr._auxiliar),
    )
end

function toBackend(csr::CSRBlock{P,F}, backend::KernelAbstractions.GPU) where {P<:CPU,F}
    toBackend(csr, typeof(backend))
end

toBackend(csr::CSRBlock{P,F}, ::KernelAbstractions.GPU) where {P<:GPU,F} = csr
toBackend(csr::CSRBlock{P,F}, ::Type{<:KernelAbstractions.GPU}) where {P<:GPU,F} = csr