######################################################################################################
# CSRBlock - Fixed-size tuples (block size is a type parameter)
######################################################################################################
struct CSRBlock{
            P, F, PR, AI, PR2
        } <: AbstractCSR

    _NBlock::AI
    _sortingFlavor::Int

    _map::PR
    _rowEntryNext::PR2
    _rowEntryPrevious::PR2
    _rowFirstEntry::PR2
    _rowLastEntry::PR2

    _NRows::AI
    _NRowsCache::AI
    _NRowsAdd::AI
    _NRowsCompacted::AI

    _NEntries::AI
    _NEntriesRow::PR
    _NEntriesRowAdd::PR
    _NEntriesRowCompacted::PR

end
Adapt.@adapt_structure CSRBlock

function CSRBlock(
    NBlock::Int,
    N::Int,
    NCache::Int=N;
    sortingFlavor::String="Unsorted"
)

    @assert NBlock > 0 "NBlock must be > 0"
    @assert N >= 0 "N must be >= 0"
    @assert NCache >= N "NCache must be >= N"
    @assert sortingFlavor in ["Unsorted", "Sorted", "CustomSorted"] "sortingFlavor must be 'Unsorted', 'Sorted', or 'CustomSorted'"

    _NBlock = SizedVector{1}(NBlock)
    _sortingFlavor = sortingFlavor == "Unsorted" ? 0 : sortingFlavor == "Sorted" ? 1 : 2

    _map = zeros(Int, NCache*NBlock)
    
    # Initialize custom sorting arrays if sortingFlavor is 1 or 2
    if _sortingFlavor in [1, 2]
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
    _NRowsAdd = SizedVector{1}(N)
    _NRowsCompacted = SizedVector{1}(N)

    _NEntries = SizedVector{1}(0)
    _NEntriesRow = zeros(Int, NCache)
    _NEntriesRowAdd = zeros(Int, NCache)
    _NEntriesRowCompacted = zeros(Int, NCache)

    P = platform()
    F = _sortingFlavor
    PR = typeof(_map)
    AI = typeof(_NRows)
    PR2 = typeof(_rowEntryNext)

    CSRBlock{
            P, F, PR, AI, PR2
        }(
            _NBlock,
            _sortingFlavor,
            _map,
            _rowEntryNext,
            _rowEntryPrevious,
            _rowFirstEntry,
            _rowLastEntry,
            _NRows,
            _NRowsCache,
            _NRowsAdd,
            _NRowsCompacted,
            _NEntries,
            _NEntriesRow,
            _NEntriesRowAdd,
            _NEntriesRowCompacted,
        )
end

function CSRBlock(
            _NBlock,
            _sortingFlavor,
            _map,
            _rowEntryNext,
            _rowEntryPrevious,
            _rowFirstEntry,
            _rowLastEntry,
            _NRows,
            _NRowsCache,
            _NRowsAdd,
            _NRowsCompacted,
            _NEntries,
            _NEntriesRow,
            _NEntriesRowAdd,
            _NEntriesRowCompacted,
        )
    
    P = platform()
    F = _sortingFlavor
    PR = typeof(_map)
    AI = typeof(_NRows)
    PR2 = typeof(_rowEntryNext)

    CSRBlock{
            P, F, PR, AI, PR2
        }(
            _NBlock,
            _sortingFlavor,
            _map,
            _rowEntryNext,
            _rowEntryPrevious,
            _rowFirstEntry,
            _rowLastEntry,
            _NRows,
            _NRowsCache,
            _NRowsAdd,
            _NRowsCompacted,
            _NEntries,
            _NEntriesRow,
            _NEntriesRowAdd,
            _NEntriesRowCompacted,
        )
end

function CSRBlock(data::AbstractMatrix{<:Int}; NRowsCache::Int=size(data, 1),  NBlock::Int=size(data, 2), sortingFlavor::String="Unsorted") 

    @assert NRowsCache >= size(data, 1) "NRowsCache must be >= number of rows in data"
    @assert NBlock >= size(data, 2) "NBlock must be >= number of columns in data"

    NSize = size(data, 1)
    NBlockMatrix = size(data, 2)

    # Create CSRBlock with appropriate size
    csr = CSRBlock(
        NBlock,
        NSize,
        NRowsCache;
        sortingFlavor=sortingFlavor
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
            end
        end
        csr._NEntriesRow[row] = row_count
    end

    csr._NEntries[1] = active_count
    csr._NEntriesRowAdd .= csr._NEntriesRow
    csr._NEntriesRowCompacted .= csr._NEntriesRow

    _initializeSorting!(csr)

    return csr
end

function CSRBlock(data::AbstractVector{<:AbstractVector{<:Int}};  NRowsCache::Int=length(data), NBlock=maximum(length.(data)), sortingFlavor::String="Unsorted")
    
    @assert NRowsCache >= length(data) "NRowsCache must be >= number of rows in data"
    @assert NBlock >= maximum(length.(data)) "NBlock must be >= maximum number of columns in data"

    N = length(data)
    NCache = NRowsCache

    # Create CSRBlock with appropriate size
    csr = CSRBlock(
        NBlock,
        N,
        NCache;
        sortingFlavor=sortingFlavor
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
            end
        end
        csr._NEntriesRow[i] = row_count
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
    
    sortingFlavor = sortingFlavor(x)

    println(io, "CSRBlock{NRows=$(numberOfRows(x)), NRowsCache=$(numberOfRowsCache(x)), SortingFlavor=$sortingFlavor, NBlock=$(x._NBlock[1])}")    
end

function Base.show(io::IO, x::Type{CSRBlock{P, F, PR, AI}}) where {P, F, PR, AI}

    sortingFlavor = sortingFlavorValue(x)
    println(io, "CSRBlock{$P, $PR, $AI, SortingFlavor=$sortingFlavor}")
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

sortingFlavor(csr::CSRBlock{P, 0}) where {P} = "Unsorted"
sortingFlavor(csr::CSRBlock{P, 1}) where {P} = "Sorted"
sortingFlavor(csr::CSRBlock{P, 2}) where {P} = "CustomSorted"
sortingFlavor(csr::Type{CSRBlock{P, 0}}) where {P} = "Unsorted"
sortingFlavor(csr::Type{CSRBlock{P, 1}}) where {P} = "Sorted"
sortingFlavor(csr::Type{CSRBlock{P, 2}}) where {P} = "CustomSorted"

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

function getColumnAtRowPos(csr::CSRBlock{P}, row::Int, pos::Int) where {P}
    i = getEntryAtRowPos(csr, row, pos)
    return csr._map[i]
end

function getColumnAtEntry(csr::CSRBlock{P}, index::Int) where {P}
    return csr._map[index]
end

######################################################################################################
# Entry accessing
######################################################################################################

isRowAlive(csr::CSRBlock{P}, row::Int) where {P} = numberOfEntriesInRow(csr, row) != -1

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

function iterateRowEntries(mesh::CSRBlock{P,0}, row::Int) where {P}
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

# Both flavor 1 and 2 use linked list traversal (differ only in how entries are added)
function iterateRowEntries(mesh::CSRBlock{P,1}, row::Int) where {P}
    first_offset = mesh._rowFirstEntry[row]
    base = getEntryAtRowPos(mesh, row) - 1
    return CSRBlockRowEntriesIterator(mesh, first_offset, row, base)
end

function iterateRowEntries(mesh::CSRBlock{P,2}, row::Int) where {P}
    first_offset = mesh._rowFirstEntry[row]
    base = getEntryAtRowPos(mesh, row) - 1
    return CSRBlockRowEntriesIterator(mesh, first_offset, row, base)
end

######################################################################################################
# Initialization of linked-list pointers depending on sorting flavor
######################################################################################################

# Unsorted flavor: nothing to initialize
function _initializeSorting!(csr::CSRBlock{P,0}) where {P}
    return csr
end

# Sorted flavor: sort row values and rebuild first/next pointers
function _initializeSorting!(csr::CSRBlock{P,1}) where {P}
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

# Custom flavor: keep current order, just rebuild first/next pointers
function _initializeSorting!(csr::CSRBlock{P,2}) where {P}
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
# Reshape
######################################################################################################

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

function compactRowEntries!(csr::CSRBlock{P, 0}) where {P}

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

function rebuildCSR!(csr::CSRBlock{P}, NRows, NBlock; auxiliarMap=Adapt.adapt(KernelAbstractions.get_backend(csr), zeros(Int, NRows*NBlock)), auxiliarCopy=similar(auxiliarMap)) where {P}

    compactRowEntries!(csr)

    oldNBlock = Array(csr._NBlock)[1]
    oldNRowsCache = numberOfRowsCache(csr)
    device = KernelAbstractions.get_backend(csr)
    threads = device === CPU ? Threads.nthreads() : 256

    # Kernel to remap _map entries (compacted entries are in first n positions)
    KernelAbstractions.@kernel function _kernel_remap_map!(csr, auxiliarMap, oldNBlock, NBlock)
        row = @index(Global)
        nentries = csr._NEntriesRow[row]
        
        # Skip rows marked for deletion
        if nentries != -1
            oldPos = (row - 1) * oldNBlock
            newPos = (row - 1) * NBlock
            
            # Copy first n entries to new position
            for i in 1:nentries
                auxiliarMap[newPos + i] = csr._map[oldPos + i]
            end
        end
    end
    
    # Kernel to remap _rowEntryNext
    KernelAbstractions.@kernel function _kernel_remap_rowEntryNext!(csr, auxiliarMap, oldNBlock, NBlock)
        row = @index(Global)
        nentries = csr._NEntriesRow[row]
        
        # Skip rows marked for deletion
        if nentries != -1
            oldPos = (row - 1) * oldNBlock
            newPos = (row - 1) * NBlock
            
            # Copy linked list pointers (already sequential 1->2->3...->0 after compact)
            for i in 1:nentries
                auxiliarMap[newPos + i] = csr._rowEntryNext[oldPos + i]
            end
        end
    end

    # Kernel to remap _rowEntryPrevious
    KernelAbstractions.@kernel function _kernel_remap_rowEntryPrevious!(csr, auxiliarMap, oldNBlock, NBlock)
        row = @index(Global)
        nentries = csr._NEntriesRow[row]
        if nentries != -1
            oldPos = (row - 1) * oldNBlock
            newPos = (row - 1) * NBlock
            for i in 1:nentries
                auxiliarMap[newPos + i] = csr._rowEntryPrevious[oldPos + i]
            end
        end
    end
    
    # Kernel to remap _rowFirstEntry (use first part of auxiliarMap)
    KernelAbstractions.@kernel function _kernel_remap_rowFirstEntry!(csr, auxiliarMap)
        row = @index(Global)
        nentries = csr._NEntriesRow[row]
        
        # Skip rows marked for deletion
        if nentries == -1
            auxiliarMap[row] = 0
        else
            auxiliarMap[row] = csr._rowFirstEntry[row]
        end
    end

    # Kernel to remap _rowLastEntry (reuse first part of auxiliarMap)
    KernelAbstractions.@kernel function _kernel_remap_rowLastEntry!(csr, auxiliarMap)
        row = @index(Global)
        nentries = csr._NEntriesRow[row]
        if nentries == -1
            auxiliarMap[row] = 0
        else
            auxiliarMap[row] = csr._rowLastEntry[row]
        end
    end

    # Remap _map
    _kernel_remap_map!(device, threads)(csr, auxiliarMap, oldNBlock, NBlock, ndrange=oldNRowsCache)
    KernelAbstractions.synchronize(device)
    
    resize!(csr._map, NRows * NBlock)
    csr._map .= @view auxiliarMap[1:NRows*NBlock]
    
    # Remap _rowEntryNext and _rowFirstEntry for flavors 1 and 2
    if csr._sortingFlavor in [1, 2]
        # Clear auxiliarMap for reuse
        auxiliarMap .= 0
        
        _kernel_remap_rowEntryNext!(device, threads)(csr, auxiliarMap, oldNBlock, NBlock, ndrange=oldNRowsCache)
        KernelAbstractions.synchronize(device)
        
        resize!(csr._rowEntryNext, NRows * NBlock)
        csr._rowEntryNext .= @view auxiliarMap[1:NRows*NBlock]
        
        auxiliarMap .= 0
        _kernel_remap_rowEntryPrevious!(device, threads)(csr, auxiliarMap, oldNBlock, NBlock, ndrange=oldNRowsCache)
        KernelAbstractions.synchronize(device)
        resize!(csr._rowEntryPrevious, NRows * NBlock)
        csr._rowEntryPrevious .= @view auxiliarMap[1:NRows*NBlock]

        # Clear first NRows elements of auxiliarMap for _rowFirstEntry
        auxiliarMap[1:NRows] .= 0
        
        _kernel_remap_rowFirstEntry!(device, threads)(csr, auxiliarMap, ndrange=oldNRowsCache)
        KernelAbstractions.synchronize(device)
        
        resize!(csr._rowFirstEntry, NRows)
        csr._rowFirstEntry .= @view auxiliarMap[1:NRows]

        auxiliarMap[1:NRows] .= 0
        _kernel_remap_rowLastEntry!(device, threads)(csr, auxiliarMap, ndrange=oldNRowsCache)
        KernelAbstractions.synchronize(device)
        resize!(csr._rowLastEntry, NRows)
        csr._rowLastEntry .= @view auxiliarMap[1:NRows]
    end

    # Update dimensions
    csr._NBlock .= NBlock
    csr._NRowsCache .= NRows
    
    # Reset compacted counters
    csr._NEntriesRowCompacted .= csr._NEntriesRow
    csr._NRowsCompacted .= numberOfRows(csr)

    return csr
end

function preallocate!(csr::CSRBlock{P}; auxiliarMap=nothing, auxiliarCopy=nothing) where {P}

    NRowsCache = numberOfRowsCache(csr)
    NRows = numberOfRows(csr)
    NRowsNew = Array(csr._NRowsAdd)[1]
    NRowsNewCompacted = Array(csr._NRowsCompacted)[1]

    NBlock = Array(csr._NBlock)[1]
    NBlockNew = maximum(@view csr._NEntriesRowAdd[1:NRows])
    NBlockCompacted = maximum(@view csr._NEntriesRowCompacted[1:NRows])

    if NBlockNew <= NBlock && NRowsNew <= NRowsCache
        nothing
    elseif NBlockCompacted < NBlock && NRowsNewCompacted < NRowsCache
        compactRowEntries!(csr)
    else
        rebuildCSR!(csr, NRows, NBlock; auxiliarMap=auxiliarMap, auxiliarCopy=auxiliarCopy)
    end

    return csr

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
    device = KernelAbstractions.get_backend(csrTarget)
    threads = device === CPU ? Threads.nthreads() : 256
    _kernel_remap!(device, threads)(csrTarget, csrOrigin, map, ndrange=numberOfRows(csrTarget))
    KernelAbstractions.synchronize(device)

    return
end

function reset!(csr::CSRBlock{P}) where {P}
    return
end

######################################################################################################
# Memory Claim Operations
######################################################################################################

function claim_pushRow!(csr::CSRBlock{P}, n::Int=1) where {P}

    @atomic csr._NRowsAdd[1] += n
    @atomic csr._NRowsCompacted[1] += n

end

function claim_removeRow!(csr::CSRBlock{P}, row::Int) where {P}

    if isRowAlive(csr, row)
        @atomic csr._NEntries[1] -= numberOfEntriesInRow(csr, row)

        # @atomic csr._NRows[1] -= 0
        # @atomic csr._NRowsAdd[1] -= 0
        @atomic csr._NRowsCompacted[1] -= 1

        @atomic csr._NEntriesRow[row] -= csr._NEntriesRow[row] + 1 
        @atomic csr._NEntriesRowAdd[row] -= csr._NEntriesRowAdd[row] + 1
        @atomic csr._NEntriesRowCompacted[row] -= csr._NEntriesRowCompacted[row] + 1

        i = getEntryAtRowPos(csr, row)
        n = numberOfEntriesInRowCache(csr, row)
        for j in i:i+n-1
            csr._map[j] = 0
        end
    end

end

function claim_insertRowCol!(csr::CSRBlock{P}, row::Int, col::Int) where {P}

    if isRowAlive(csr, row) && !hasRowCol(csr, row, col)

        # @atomic csr._NEntries[1] += 1 

        # @atomic csr._NRows[1] -= 0
        # @atomic csr._NRowsAdd[1] -= 0
        # @atomic csr._NRowsCompacted[1] -= 0

        # @atomic csr._NEntriesRow[row] += 1
        @atomic csr._NEntriesRowAdd[row] += 1
        @atomic csr._NEntriesRowCompacted[row] += 1 

    end

end

function claim_removeRowCol!(csr::CSRBlock{P}, row::Int, col::Int) where {P}

    if isRowAlive(csr, row) && hasRowCol(csr, row, col)
        i = getEntryAtRowCol(csr, row, col)
        csr._map[i] = 0

        @atomic csr._NEntries[1] -= 1 

        # @atomic csr._NRows[1] -= 0
        # @atomic csr._NRowsAdd[1] -= 0
        # @atomic csr._NRowsCompacted[1] -= 0

        # @atomic csr._NEntriesRow[row] -= 0
        # @atomic csr._NEntriesRowAdd[row] -= 0
        @atomic csr._NEntriesRowCompacted[row] -= 1         
    end

end

######################################################################################################
# Row Operations
######################################################################################################

function pushRow!(csr::CSRBlock{P}, col::Int) where {P}

    row = @atomic csr._NRows[1] += 1

    i = getEntryAtRowPos(csr, row)
    csr._map[i] = col
    @atomic csr._NEntries[1] += 1
    @atomic csr._NEntriesRow[row] += 1
    @atomic csr._NEntriesRowAdd[row] += 1
    @atomic csr._NEntriesRowCompacted[row] += 1

end

function pushRow!(csr::CSRBlock{P}, cols::NTuple{N,Int}) where {P,N}

    row = @atomic csr._NRows[1] += 1

    i = getEntryAtRowPos(csr, row)
    for j in i:i+N-1
        csr._map[j] = cols[j - i + 1]
    end
    @atomic csr._NEntries[1] += N
    @atomic csr._NEntriesRow[row] += N
    @atomic csr._NEntriesRowAdd[row] += N
    @atomic csr._NEntriesRowCompacted[row] += N

end

function removeRow!(csr::CSRBlock{P}, row::Int) where {P}

end

function insertRowCol!(csr::CSRBlock{P}, row::Int, col::Int, colNew::Int) where {P}

    if isRowAlive(csr, row)
        pNew = @atomic csr._NEntriesRow[row] += 1
        @atomic csr._NEntriesRowAdd[row] += n
        @atomic csr._NEntriesRowCompacted[row] += n
        iNew = getEntryAtRowPos(csr, row, pNew)
        iPrev = getEntryAtRowCol(csr, row, col)
        pNext = csr._rowEntryNext[iPrev]
        csr._map[iNew] = colNew
        csr._rowEntryNext[iPrev] = pNew
        csr._rowEntryNext[iNew] = pNext
    end

end

function insertRowCol!(csr::CSRBlock{P,0}, row::Int, col::Int) where {P}

    if isRowAlive(csr, row)
        
        @atomic csr._NEntries[1] += 1 
        pNew = @atomic csr._NEntriesRow[row] += 1

        iNew = getEntryAtRowPos(csr, row, pNew)
        csr._map[iNew] = col

    end

end

function removeRowCol!(csr::CSRBlock{P}, row::Int, col::Int) where {P}

    if isRowAlive(csr, row)
        i = getEntryAtRowCol(csr, row, col)
        if i != 0
            pNext = csr._rowEntryNext[i]
            # Find previous entry in linked list
            prevIdx = csr._rowFirstEntry[row]
            if prevIdx == i
                csr._rowFirstEntry[row] = pNext
            else
                while prevIdx != 0 && csr._rowEntryNext[prevIdx] != i
                    prevIdx = csr._rowEntryNext[prevIdx]
                end
                if prevIdx != 0
                    csr._rowEntryNext[prevIdx] = pNext
                end
            end
            csr._map[i] = 0
            @atomic csr._NEntriesRow[row] -= 1
            @atomic csr._NEntriesRowCompacted[row] -= 1
        end
    end

end

function removeRowCol!(csr::CSRBlock{P,0}, row::Int, col::Int) where {P}

end

######################################################################################################
# toDevice - Device transfer functions for CSR structures
######################################################################################################

function KernelAbstractions.get_backend(csr::CSRBlock)
    KernelAbstractions.get_backend(csr._map)
end

# CSRBlock to CPU
function toDevice(csr::CSRBlock{P}, ::Type{CPU}) where {P<:GPU}
    CSRBlock(
        Adapt.adapt(Array, csr._NBlock),
        csr._sortingFlavor,
        Adapt.adapt(Array, csr._map),
        isnothing(csr._rowEntryNext) ? nothing : Adapt.adapt(Array, csr._rowEntryNext),
        isnothing(csr._rowEntryPrevious) ? nothing : Adapt.adapt(Array, csr._rowEntryPrevious),
        isnothing(csr._rowFirstEntry) ? nothing : Adapt.adapt(Array, csr._rowFirstEntry),
        isnothing(csr._rowLastEntry) ? nothing : Adapt.adapt(Array, csr._rowLastEntry),
        SizedVector{1}(Array(csr._NRows)[1]),
        SizedVector{1}(Array(csr._NRowsCache)[1]),
        SizedVector{1}(Array(csr._NRowsAdd)[1]),
        SizedVector{1}(Array(csr._NRowsCompacted)[1]),
        SizedVector{1}(Array(csr._NEntries)[1]),
        Adapt.adapt(Array, csr._NEntriesRow),
        Adapt.adapt(Array, csr._NEntriesRowAdd),
        Adapt.adapt(Array, csr._NEntriesRowCompacted),
    )
end
function toDevice(csr::CSRBlock{P}, device::CPU) where {P<:CPU}
    toDevice(csr, typeof(device))
end

toDevice(csr::CSRBlock{P}, ::Type{CPU}) where {P<:CPU} = csr
toDevice(csr::CSRBlock{P}, ::CPU) where {P<:GPU} = toDevice(csr, CPU)

function toDevice(csr::CSRBlock{P,F}, backend::Type{<:KernelAbstractions.GPU}) where {P<:CPU,F}
    CSRBlock(
        Adapt.adapt(backend, csr._NBlock),
        csr._sortingFlavor,
        Adapt.adapt(backend, csr._map),
        isnothing(csr._rowEntryNext) ? nothing : Adapt.adapt(backend, csr._rowEntryNext),
        isnothing(csr._rowEntryPrevious) ? nothing : Adapt.adapt(backend, csr._rowEntryPrevious),
        isnothing(csr._rowFirstEntry) ? nothing : Adapt.adapt(backend, csr._rowFirstEntry),
        isnothing(csr._rowLastEntry) ? nothing : Adapt.adapt(backend, csr._rowLastEntry),
        Adapt.adapt(backend, csr._NRows),
        Adapt.adapt(backend, csr._NRowsCache),
        Adapt.adapt(backend, csr._NRowsAdd),
        Adapt.adapt(backend, csr._NRowsCompacted),
        Adapt.adapt(backend, csr._NEntries),
        Adapt.adapt(backend, csr._NEntriesRow),
        Adapt.adapt(backend, csr._NEntriesRowAdd),
        Adapt.adapt(backend, csr._NEntriesRowCompacted),
    )
end

function toDevice(csr::CSRBlock{P,F}, backend::KernelAbstractions.GPU) where {P<:CPU,F}
    toDevice(csr, typeof(backend))
end

toDevice(csr::CSRBlock{P,F}, ::KernelAbstractions.GPU) where {P<:GPU,F} = csr
toDevice(csr::CSRBlock{P,F}, ::Type{<:KernelAbstractions.GPU}) where {P<:GPU,F} = csr