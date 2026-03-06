######################################################################################################
# DynamicalOrderedCOO - COO format with ordered traversal via doubly-linked list
######################################################################################################
struct DynamicalOrderedCOO{
            P, T, V, I, L
        } <: AbstractSparseMatrix

    _values::V
    _rows::I
    _cols::I

    # Linked list pointers (0 means null/no link)
    _prev::I      # Previous entry index for each slot
    _next::I      # Next entry index for each slot
    _head::I      # Index of first entry (single element array)
    _tail::I      # Index of last entry (single element array)

    _NEntries::I
    _NEntriesCache::I
    _NEntriesNonzero::I
    _NOverflowInsert::I
    _NOverflowErase::I

    _NEntriesFree::I
    _NEntriesFreeNextInit::I
    _NEntriesFreeNext::I
    _entriesFree::I

    _lock::L
end
Adapt.@adapt_structure DynamicalOrderedCOO

function DynamicalOrderedCOO(
        _values,
        _rows,
        _cols,
        
        _prev,
        _next,
        _head,
        _tail,
        
        _NEntries,
        _NEntriesCache,
        _NEntriesNonzero,
        _NOverflowInsert,
        _NOverflowErase,
        
        _NEntriesFree,
        _NEntriesFreeNextInit,
        _NEntriesFreeNext,
        _entriesFree,

        _lock
    )
    
    P = typeof(KernelAbstractions.get_backend(_values))
    T = eltype(_values)
    V = typeof(_values)
    I = typeof(_NEntries)
    L = typeof(_lock)

    DynamicalOrderedCOO{
            P, T, V, I, L
        }(
            _values,
            _rows,
            _cols,
            
            _prev,
            _next,
            _head,
            _tail,
            
            _NEntries,
            _NEntriesCache,
            _NEntriesNonzero,
            _NOverflowInsert,
            _NOverflowErase,
            _NEntriesFree,
            _NEntriesFreeNextInit,
            _NEntriesFreeNext,
            _entriesFree,

            _lock
        )
end

function docoo_zeros(dtype::DataType, n_coo::Int=0)

    @assert n_coo >= 0 "n_coo must be >= 0"

    _rows = zeros(Int, n_coo)
    _cols = zeros(Int, n_coo)
    _values = zeros(dtype, n_coo)
    _prev = zeros(Int, n_coo)
    _next = zeros(Int, n_coo)
    _head = Int[0]
    _tail = Int[0]
    _NEntries = Int[0]
    _NEntriesCache = Int[n_coo]
    _NEntriesNonzero = Int[0]
    _NOverflowInsert = Int[0]
    _NOverflowErase = Int[0]
    _NEntriesFree = Int[n_coo]
    _NEntriesFreeNextInit = Int[n_coo+1]
    _NEntriesFreeNext = Int[0]
    _entriesFree = [i for i in n_coo:-1:1]
    _lock = ReentrantLock()

    DynamicalOrderedCOO(
            _rows,
            _cols,
            _values,
            
            _prev,
            _next,
            _head,
            _tail,
            
            _NEntries,
            _NEntriesCache,
            _NEntriesNonzero,
            _NOverflowInsert,
            _NOverflowErase,
            
            _NEntriesFree,
            _NEntriesFreeNextInit,
            _NEntriesFreeNext,
            _entriesFree,
            
            _lock
        )
end

function docoo_zeros(n_coo::Int=0)
    docoo_zeros(Float64, n_coo)
end

function Base.show(io::IO, x::DynamicalOrderedCOO{P, T}) where {P, T}
    
    nrows = numberOfRows(x)
    ncols = numberOfCols(x)
    nentries = numberOfEntries(x)
    
    println(io, "DynamicalOrderedCOO{$T} with $(nentries) stored entries (ordered)")
    println(io, "  $(nrows) × $(ncols) sparse matrix")
    
    # Show ordered list of entries
    if nentries <= 20 && nentries > 0
        println(io, "  Entries (in order):")
        k = gethead(x)
        count = 0
        while k != 0 && count < 20
            i, j = x._rows[k], x._cols[k]
            v = x._values[k]
            println(io, "    [$i, $j] = $v")
            k = x._next[k]
            count += 1
        end
    end
end

function Base.show(io::IO, x::Type{DynamicalOrderedCOO{P, T, V, I}}) where {P, T, V, I}
    println(io, "DynamicalOrderedCOO{$P, $T, $V, $I}")
end

Base.length(coo::DynamicalOrderedCOO{P}) where {P} = length(coo._values)
numberOfEntries(coo::DynamicalOrderedCOO{P}) where {P} = getDeviceIndex(coo._NEntries)
numberOfEntriesCache(coo::DynamicalOrderedCOO{P}) where {P} = getDeviceIndex(coo._NEntriesCache)
numberOfEntriesNonzero(coo::DynamicalOrderedCOO{P}) where {P} = getDeviceIndex(coo._NEntriesNonzero)
numberOfEntriesFree(coo::DynamicalOrderedCOO{P}) where {P} = getDeviceIndex(coo._NEntriesFree)
numberOfEntriesFreeNext(coo::DynamicalOrderedCOO{P}) where {P} = getDeviceIndex(coo._NEntriesFreeNext)
numberOfRows(coo::DynamicalOrderedCOO{P}) where {P} = maximum(coo._rows; init=0)
numberOfCols(coo::DynamicalOrderedCOO{P}) where {P} = maximum(coo._cols; init=0)

"""
    gethead(coo::DynamicalOrderedCOO)

Get the index of the first entry in the ordered list.
Returns 0 if the list is empty.
"""
@inline function gethead(coo::DynamicalOrderedCOO)
    return coo._head[1]
end

"""
    gettail(coo::DynamicalOrderedCOO)

Get the index of the last entry in the ordered list.
Returns 0 if the list is empty.
"""
@inline function gettail(coo::DynamicalOrderedCOO)
    return coo._tail[1]
end

"""
    getnext(coo::DynamicalOrderedCOO, k::Int)

Get the index of the next entry after position k.
Returns 0 if k is the last entry.
"""
@inline function getnext(coo::DynamicalOrderedCOO, k::Int)
    return coo._next[k]
end

"""
    getprev(coo::DynamicalOrderedCOO, k::Int)

Get the index of the previous entry before position k.
Returns 0 if k is the first entry.
"""
@inline function getprev(coo::DynamicalOrderedCOO, k::Int)
    return coo._prev[k]
end

"""
    getentry(coo::DynamicalOrderedCOO, k::Int)

Get the (row, col, value) entry at position k.
"""
@inline function getentry(coo::DynamicalOrderedCOO, k::Int)
    return (coo._rows[k], coo._cols[k], coo._values[k])
end

"""
    todense(coo::DynamicalOrderedCOO)

Convert the sparse COO matrix to a dense matrix.
Returns a dense matrix of size (nRows, nCols) with all stored entries filled in.
"""
function todense(coo::DynamicalOrderedCOO{P, T}) where {P, T}
    nRows = numberOfRows(coo)
    nCols = numberOfCols(coo)
    
    # Create dense matrix on CPU
    dense = zeros(T, nRows, nCols)
    
    # Copy data to CPU for iteration
    rows = Array(coo._rows)
    cols = Array(coo._cols)
    values = Array(coo._values)
    next = Array(coo._next)
    head = Array(coo._head)[1]
    
    # Fill in the values following ordered list
    k = head
    while k != 0
        i, j = rows[k], cols[k]
        if i > 0 && j > 0
            dense[i, j] = values[k]
        end
        k = next[k]
    end
    
    return dense
end

######################################################################################################
# Finding entries
######################################################################################################

"""
    _findentry(coo::DynamicalOrderedCOO, i::Int, j::Int)

Find the slot index for entry (i, j). Returns 0 if not found.
Searches through all entries (not just ordered list).
"""
function _findentry(coo::DynamicalOrderedCOO, i::Int, j::Int)
    nEntries = min(coo._NEntriesCache[1], coo._NEntries[1])
    for k in 1:nEntries
        if coo._rows[k] == i && coo._cols[k] == j
            return k
        end
    end
    # Also search through entries not yet compacted
    for k in nEntries+1:length(coo)
        if coo._rows[k] == i && coo._cols[k] == j
            return k
        end
    end
    return 0
end

"""
    Base.getindex(coo::DynamicalOrderedCOO, i::Int, j::Int)

Get the value at position (i, j) in the sparse matrix.
Returns 0 if the entry does not exist.
"""
function Base.getindex(coo::DynamicalOrderedCOO{P, T}, i::Int, j::Int) where {P, T}
    k = _findentry(coo, i, j)
    if k != 0
        return coo._values[k]
    end
    return zero(T)
end

######################################################################################################
# Internal slot management
######################################################################################################

"""
    _get_free_slot!(coo::DynamicalOrderedCOO)

Get a free slot index. Returns 0 if no slots available.
"""
@inline function _get_free_slot!(coo::DynamicalOrderedCOO)
    nFree = coo._NEntriesFree[1]
    if nFree > 0
        k = coo._entriesFree[nFree]
        Atomix.@atomic coo._NEntriesFree[1] -= 1
        return k
    else
        # Try to get from uninitialized pool
        nextInit = coo._NEntriesFreeNextInit[1]
        if nextInit <= length(coo._values)
            Atomix.@atomic coo._NEntriesFreeNextInit[1] += 1
            return nextInit
        end
    end
    # No free slots
    Atomix.@atomic coo._NOverflowInsert[1] += 1
    return 0
end

"""
    _return_slot!(coo::DynamicalOrderedCOO, k::Int)

Return slot k to the free pool.
"""
@inline function _return_slot!(coo::DynamicalOrderedCOO, k::Int)
    nFreeNext = coo._NEntriesFreeNext[1]
    if nFreeNext < length(coo._entriesFree)
        coo._entriesFree[nFreeNext + 1] = k
        Atomix.@atomic coo._NEntriesFreeNext[1] += 1
    else
        Atomix.@atomic coo._NOverflowErase[1] += 1
    end
end

######################################################################################################
# Insertion functions
######################################################################################################

"""
    pushfirst!(coo::DynamicalOrderedCOO, i::Int, j::Int, value)

Add an entry at the beginning of the ordered list.
Returns true if successful, false if no space available.
"""
function Base.pushfirst!(coo::DynamicalOrderedCOO, i::Int, j::Int, value)
    if i <= 0 || j <= 0
        @print "Indices must be positive integers."
        return false
    end
    
    # Get a free slot
    k = _get_free_slot!(coo)
    if k == 0
        return false
    end
    
    # Set the entry data
    coo._rows[k] = i
    coo._cols[k] = j
    coo._values[k] = value
    
    # Update linked list
    oldHead = coo._head[1]
    coo._prev[k] = 0
    coo._next[k] = oldHead
    
    if oldHead != 0
        coo._prev[oldHead] = k
    else
        # List was empty, this is also the tail
        coo._tail[1] = k
    end
    coo._head[1] = k
    
    # Update counts
    Atomix.@atomic coo._NEntries[1] += 1
    if value != 0
        Atomix.@atomic coo._NEntriesNonzero[1] += 1
    end
    
    return true
end

"""
    append!(coo::DynamicalOrderedCOO, i::Int, j::Int, value)

Add an entry at the end of the ordered list.
Returns true if successful, false if no space available.
"""
function Base.append!(coo::DynamicalOrderedCOO, i::Int, j::Int, value)
    if i <= 0 || j <= 0
        @print "Indices must be positive integers."
        return false
    end
    
    # Get a free slot
    k = _get_free_slot!(coo)
    if k == 0
        return false
    end
    
    # Set the entry data
    coo._rows[k] = i
    coo._cols[k] = j
    coo._values[k] = value
    
    # Update linked list
    oldTail = coo._tail[1]
    coo._prev[k] = oldTail
    coo._next[k] = 0
    
    if oldTail != 0
        coo._next[oldTail] = k
    else
        # List was empty, this is also the head
        coo._head[1] = k
    end
    coo._tail[1] = k
    
    # Update counts
    Atomix.@atomic coo._NEntries[1] += 1
    if value != 0
        Atomix.@atomic coo._NEntriesNonzero[1] += 1
    end
    
    return true
end

"""
    insertafter!(coo::DynamicalOrderedCOO, i_ref::Int, j_ref::Int, i::Int, j::Int, value)

Insert a new entry (i, j, value) after the entry at (i_ref, j_ref).
Returns true if successful, false if reference entry not found or no space available.
"""
function insertafter!(coo::DynamicalOrderedCOO, i_ref::Int, j_ref::Int, i::Int, j::Int, value)
    if i <= 0 || j <= 0
        @print "Indices must be positive integers."
        return false
    end
    
    # Find the reference entry
    k_ref = _findentry(coo, i_ref, j_ref)
    if k_ref == 0
        return false
    end
    
    # Get a free slot
    k = _get_free_slot!(coo)
    if k == 0
        return false
    end
    
    # Set the entry data
    coo._rows[k] = i
    coo._cols[k] = j
    coo._values[k] = value
    
    # Update linked list: insert k after k_ref
    k_next = coo._next[k_ref]
    
    coo._prev[k] = k_ref
    coo._next[k] = k_next
    coo._next[k_ref] = k
    
    if k_next != 0
        coo._prev[k_next] = k
    else
        # k_ref was the tail, now k is the tail
        coo._tail[1] = k
    end
    
    # Update counts
    Atomix.@atomic coo._NEntries[1] += 1
    if value != 0
        Atomix.@atomic coo._NEntriesNonzero[1] += 1
    end
    
    return true
end

"""
    insertbefore!(coo::DynamicalOrderedCOO, i_ref::Int, j_ref::Int, i::Int, j::Int, value)

Insert a new entry (i, j, value) before the entry at (i_ref, j_ref).
Returns true if successful, false if reference entry not found or no space available.
"""
function insertbefore!(coo::DynamicalOrderedCOO, i_ref::Int, j_ref::Int, i::Int, j::Int, value)
    if i <= 0 || j <= 0
        @print "Indices must be positive integers."
        return false
    end
    
    # Find the reference entry
    k_ref = _findentry(coo, i_ref, j_ref)
    if k_ref == 0
        return false
    end
    
    # Get a free slot
    k = _get_free_slot!(coo)
    if k == 0
        return false
    end
    
    # Set the entry data
    coo._rows[k] = i
    coo._cols[k] = j
    coo._values[k] = value
    
    # Update linked list: insert k before k_ref
    k_prev = coo._prev[k_ref]
    
    coo._prev[k] = k_prev
    coo._next[k] = k_ref
    coo._prev[k_ref] = k
    
    if k_prev != 0
        coo._next[k_prev] = k
    else
        # k_ref was the head, now k is the head
        coo._head[1] = k
    end
    
    # Update counts
    Atomix.@atomic coo._NEntries[1] += 1
    if value != 0
        Atomix.@atomic coo._NEntriesNonzero[1] += 1
    end
    
    return true
end

"""
    insertafter_k!(coo::DynamicalOrderedCOO, k_ref::Int, i::Int, j::Int, value)

Insert a new entry (i, j, value) after the entry at slot k_ref (by slot index).
Returns true if successful, false if no space available.
GPU-compatible when used inside kernels.
"""
function insertafter_k!(coo::DynamicalOrderedCOO, k_ref::Int, i::Int, j::Int, value)
    if i <= 0 || j <= 0
        return false
    end
    
    # Get a free slot
    k = _get_free_slot!(coo)
    if k == 0
        return false
    end
    
    # Set the entry data
    coo._rows[k] = i
    coo._cols[k] = j
    coo._values[k] = value
    
    # Update linked list: insert k after k_ref
    k_next = coo._next[k_ref]
    
    coo._prev[k] = k_ref
    coo._next[k] = k_next
    coo._next[k_ref] = k
    
    if k_next != 0
        coo._prev[k_next] = k
    else
        # k_ref was the tail, now k is the tail
        coo._tail[1] = k
    end
    
    # Update counts
    Atomix.@atomic coo._NEntries[1] += 1
    if value != 0
        Atomix.@atomic coo._NEntriesNonzero[1] += 1
    end
    
    return true
end

"""
    insertbefore_k!(coo::DynamicalOrderedCOO, k_ref::Int, i::Int, j::Int, value)

Insert a new entry (i, j, value) before the entry at slot k_ref (by slot index).
Returns true if successful, false if no space available.
GPU-compatible when used inside kernels.
"""
function insertbefore_k!(coo::DynamicalOrderedCOO, k_ref::Int, i::Int, j::Int, value)
    if i <= 0 || j <= 0
        return false
    end
    
    # Get a free slot
    k = _get_free_slot!(coo)
    if k == 0
        return false
    end
    
    # Set the entry data
    coo._rows[k] = i
    coo._cols[k] = j
    coo._values[k] = value
    
    # Update linked list: insert k before k_ref
    k_prev = coo._prev[k_ref]
    
    coo._prev[k] = k_prev
    coo._next[k] = k_ref
    coo._prev[k_ref] = k
    
    if k_prev != 0
        coo._next[k_prev] = k
    else
        # k_ref was the head, now k is the head
        coo._head[1] = k
    end
    
    # Update counts
    Atomix.@atomic coo._NEntries[1] += 1
    if value != 0
        Atomix.@atomic coo._NEntriesNonzero[1] += 1
    end
    
    return true
end

######################################################################################################
# Deletion functions
######################################################################################################

"""
    delete!(coo::DynamicalOrderedCOO, i::Int, j::Int)

Remove the entry at position (i, j) from the ordered list.
Returns true if the entry was found and removed, false otherwise.
"""
function Base.delete!(coo::DynamicalOrderedCOO, i::Int, j::Int)
    # Find the entry
    k = _findentry(coo, i, j)
    if k == 0
        return false
    end
    
    return delete_k!(coo, k)
end

"""
    delete_k!(coo::DynamicalOrderedCOO, k::Int)

Remove the entry at slot k from the ordered list.
GPU-compatible when used inside kernels.
Returns true if successful.
"""
function delete_k!(coo::DynamicalOrderedCOO, k::Int)
    oldValue = coo._values[k]
    
    # Update linked list
    k_prev = coo._prev[k]
    k_next = coo._next[k]
    
    if k_prev != 0
        coo._next[k_prev] = k_next
    else
        # k was the head
        coo._head[1] = k_next
    end
    
    if k_next != 0
        coo._prev[k_next] = k_prev
    else
        # k was the tail
        coo._tail[1] = k_prev
    end
    
    # Clear the slot
    coo._rows[k] = 0
    coo._cols[k] = 0
    coo._values[k] = 0
    coo._prev[k] = 0
    coo._next[k] = 0
    
    # Return slot to free pool
    _return_slot!(coo, k)
    
    # Update counts
    Atomix.@atomic coo._NEntries[1] -= 1
    if oldValue != 0
        Atomix.@atomic coo._NEntriesNonzero[1] -= 1
    end
    
    return true
end

"""
    popfirst!(coo::DynamicalOrderedCOO)

Remove and return the first entry (row, col, value) from the ordered list.
Returns nothing if the list is empty.
"""
function Base.popfirst!(coo::DynamicalOrderedCOO{P, T}) where {P, T}
    k = coo._head[1]
    if k == 0
        return nothing
    end
    
    row, col, val = coo._rows[k], coo._cols[k], coo._values[k]
    delete_k!(coo, k)
    
    return (row, col, val)
end

"""
    pop!(coo::DynamicalOrderedCOO)

Remove and return the last entry (row, col, value) from the ordered list.
Returns nothing if the list is empty.
"""
function Base.pop!(coo::DynamicalOrderedCOO{P, T}) where {P, T}
    k = coo._tail[1]
    if k == 0
        return nothing
    end
    
    row, col, val = coo._rows[k], coo._cols[k], coo._values[k]
    delete_k!(coo, k)
    
    return (row, col, val)
end

######################################################################################################
# Ordered iteration support
######################################################################################################

"""
    OrderedCOOIterator{V, I}

Iterator struct for ordered traversal of a DynamicalOrderedCOO matrix.
GPU and CPU compatible for use inside kernels.

Usage in a kernel:
```julia
k = gethead(coo)
while k != 0
    row, col, val = getentry(coo, k)
    # process entry...
    k = getnext(coo, k)
end
```
"""
struct OrderedCOOIterator{V, I}
    _rows::I
    _cols::I
    _values::V
    _next::I
    _head::Int
end
Adapt.@adapt_structure OrderedCOOIterator

"""
    iterateOrdered(coo::DynamicalOrderedCOO)

Create an iterator for ordered traversal of the COO matrix.
Returns an `OrderedCOOIterator` struct.
"""
@inline function iterateOrdered(coo::DynamicalOrderedCOO)
    return OrderedCOOIterator(coo._rows, coo._cols, coo._values, coo._next, coo._head[1])
end

"""
    getentry(iter::OrderedCOOIterator, k::Int)

Get the (row, col, value) entry at position k.
"""
@inline function getentry(iter::OrderedCOOIterator, k::Int)
    return (iter._rows[k], iter._cols[k], iter._values[k])
end

"""
    getnext(iter::OrderedCOOIterator, k::Int)

Get the next index after k.
"""
@inline function getnext(iter::OrderedCOOIterator, k::Int)
    return iter._next[k]
end

######################################################################################################
# Row iteration support (iterate over row entries in matrix order, not storage order)
######################################################################################################

"""
    iterateRow(coo::DynamicalOrderedCOO, i::Int)

Create an iterator for traversing all entries in row `i`.
Note: For ordered COO, this still scans all entries but returns a standard COORowIterator
since row iteration doesn't require ordered traversal.
"""
@inline function iterateRow(coo::DynamicalOrderedCOO, i::Int)
    nEntries = length(coo)
    return COORowIterator(i, coo._rows, coo._cols, coo._values, nEntries)
end

######################################################################################################
# Utility functions
######################################################################################################

function overflow(coo::DynamicalOrderedCOO)
    return numberOfEntriesFree(coo) == 0 && numberOfEntriesFreeNext(coo) >= length(coo) - numberOfEntries(coo)
end

function overflowEntries(coo::DynamicalOrderedCOO)
    return getDeviceIndex(coo._NOverflowInsert)
end

function overflowRows(coo::DynamicalOrderedCOO)
    return length(unique(Array(coo._rows)[Array(coo._rows) .> 0]))
end

function allocationRatio(coo::DynamicalOrderedCOO)
    cache = numberOfEntriesCache(coo)
    entries = numberOfEntries(coo)
    if cache == 0
        return 0.0
    end
    return entries / cache
end

function allocationsFailed(coo::DynamicalOrderedCOO)
    return getDeviceIndex(coo._NOverflowInsert) > 0 || getDeviceIndex(coo._NOverflowErase) > 0
end

function synchronize(coo::DynamicalOrderedCOO)
    # Use getDeviceIndex for GPU compatibility
    chunk = getDeviceIndex(coo._NEntriesFreeNext)

    chunkNewInit = getDeviceIndex(coo._NEntriesFree) + 1
    chunkNewEnd = chunkNewInit + chunk

    chunkOldInit = getDeviceIndex(coo._NEntriesFreeNextInit)
    chunkOldEnd = chunkOldInit + chunk

    if chunk > 0
        @view(coo._entriesFree[chunkNewInit:chunkNewEnd]) .= @views(coo._entriesFree[chunkOldInit:chunkOldEnd])
        @views(coo._entriesFree[chunkOldInit+1:1:chunkOldEnd]) .= 0
    end

    setDeviceIndex!(coo._NEntriesFree, chunkNewEnd - 1)
    setDeviceIndex!(coo._NEntriesFreeNext, 0)
    setDeviceIndex!(coo._NEntriesFreeNextInit, chunkNewEnd)

    # Reset overflow counters
    setDeviceIndex!(coo._NOverflowInsert, 0)
    setDeviceIndex!(coo._NOverflowErase, 0)

    # Resize if entries overflowed
    if length(coo._entriesFree) > length(coo._values)
        resize!(coo._entriesFree, length(coo._values))
    end

    return
end

function dropzeros!(coo::DynamicalOrderedCOO)
    # Copy to CPU to iterate through the list
    coo_cpu = toBackend(CPU(), coo)
    
    # Iterate through ordered list on CPU and remove zero entries
    k = coo_cpu._head[1]
    while k != 0
        k_next = coo_cpu._next[k]
        if coo_cpu._values[k] == 0
            delete_k!(coo, k)
        end
        k = k_next
    end
    
    return
end

function preallocate!(coo::DynamicalOrderedCOO; n_entries::Int=0)
    if n_entries <= 0
        return coo
    end
    
    currentCache = numberOfEntriesCache(coo)
    newCache = currentCache + n_entries
    
    # Create new arrays
    new_values = zeros(eltype(coo._values), newCache)
    new_rows = zeros(Int, newCache)
    new_cols = zeros(Int, newCache)
    new_prev = zeros(Int, newCache)
    new_next = zeros(Int, newCache)
    new_entriesFree = zeros(Int, newCache)
    
    # Copy existing data
    new_values[1:currentCache] .= Array(coo._values)
    new_rows[1:currentCache] .= Array(coo._rows)
    new_cols[1:currentCache] .= Array(coo._cols)
    new_prev[1:currentCache] .= Array(coo._prev)
    new_next[1:currentCache] .= Array(coo._next)
    new_entriesFree[1:currentCache] .= Array(coo._entriesFree)
    
    # Add new free slots
    for i in newCache:-1:currentCache+1
        new_entriesFree[length(coo._entriesFree) + (newCache - i + 1)] = i
    end
    
    backend = KernelAbstractions.get_backend(coo)
    
    return DynamicalOrderedCOO(
        toBackend(backend, new_values),
        toBackend(backend, new_rows),
        toBackend(backend, new_cols),
        toBackend(backend, new_prev),
        toBackend(backend, new_next),
        toBackend(backend, Array(coo._head)),
        toBackend(backend, Array(coo._tail)),
        toBackend(backend, Array(coo._NEntries)),
        toBackend(backend, Int[newCache]),
        toBackend(backend, Array(coo._NEntriesNonzero)),
        toBackend(backend, Array(coo._NOverflowInsert)),
        toBackend(backend, Array(coo._NOverflowErase)),
        toBackend(backend, Int[numberOfEntriesFree(coo) + n_entries]),
        toBackend(backend, Array(coo._NEntriesFreeNextInit)),
        toBackend(backend, Array(coo._NEntriesFreeNext)),
        toBackend(backend, new_entriesFree),
        backend === CPU() ? ReentrantLock() : nothing
    )
end

function Base.similar(coo::DynamicalOrderedCOO)
    return docoo_zeros(eltype(coo._values), length(coo))
end

function Base.copy(coo::DynamicalOrderedCOO)
    return DynamicalOrderedCOO(
        copy(coo._values),
        copy(coo._rows),
        copy(coo._cols),
        copy(coo._prev),
        copy(coo._next),
        copy(coo._head),
        copy(coo._tail),
        copy(coo._NEntries),
        copy(coo._NEntriesCache),
        copy(coo._NEntriesNonzero),
        copy(coo._NOverflowInsert),
        copy(coo._NOverflowErase),
        copy(coo._NEntriesFree),
        copy(coo._NEntriesFreeNextInit),
        copy(coo._NEntriesFreeNext),
        copy(coo._entriesFree),
        coo._lock isa ReentrantLock ? ReentrantLock() : nothing
    )
end

function Base.copyto!(dest::DynamicalOrderedCOO{P, T}, src::DynamicalOrderedCOO{P, T}) where {P, T}
    copyto!(dest._values, src._values)
    copyto!(dest._rows, src._rows)
    copyto!(dest._cols, src._cols)
    copyto!(dest._prev, src._prev)
    copyto!(dest._next, src._next)
    copyto!(dest._head, src._head)
    copyto!(dest._tail, src._tail)
    copyto!(dest._NEntries, src._NEntries)
    copyto!(dest._NEntriesCache, src._NEntriesCache)
    copyto!(dest._NEntriesNonzero, src._NEntriesNonzero)
    copyto!(dest._NOverflowInsert, src._NOverflowInsert)
    copyto!(dest._NOverflowErase, src._NOverflowErase)
    copyto!(dest._NEntriesFree, src._NEntriesFree)
    copyto!(dest._NEntriesFreeNextInit, src._NEntriesFreeNextInit)
    copyto!(dest._NEntriesFreeNext, src._NEntriesFreeNext)
    copyto!(dest._entriesFree, src._entriesFree)
    return dest
end

######################################################################################################
# Value modification
######################################################################################################

"""
    setvalue!(coo::DynamicalOrderedCOO, i::Int, j::Int, value)

Set the value of an existing entry at (i, j).
Returns true if entry found and modified, false if not found.
Does NOT add new entries - use append!/pushfirst!/insert*! for that.
"""
function setvalue!(coo::DynamicalOrderedCOO, i::Int, j::Int, value)
    k = _findentry(coo, i, j)
    if k == 0
        return false
    end
    
    oldValue = coo._values[k]
    coo._values[k] = value
    
    # Update nonzero count
    if oldValue == 0 && value != 0
        Atomix.@atomic coo._NEntriesNonzero[1] += 1
    elseif oldValue != 0 && value == 0
        Atomix.@atomic coo._NEntriesNonzero[1] -= 1
    end
    
    return true
end

"""
    setvalue_k!(coo::DynamicalOrderedCOO, k::Int, value)

Set the value at slot k (GPU-compatible).
"""
@inline function setvalue_k!(coo::DynamicalOrderedCOO, k::Int, value)
    oldValue = coo._values[k]
    coo._values[k] = value
    
    if oldValue == 0 && value != 0
        Atomix.@atomic coo._NEntriesNonzero[1] += 1
    elseif oldValue != 0 && value == 0
        Atomix.@atomic coo._NEntriesNonzero[1] -= 1
    end
    
    return true
end

###################################################################################################
# Platform adaptation
###################################################################################################

KernelAbstractions.get_backend(coo::DynamicalOrderedCOO) = KernelAbstractions.get_backend(coo._values)

toBackend(::KernelAbstractions.CPU, coo::DynamicalOrderedCOO{P}) where {P<:KernelAbstractions.CPU} = coo

function toBackend(::KernelAbstractions.CPU, coo::DynamicalOrderedCOO{P, T}) where {P<:KernelAbstractions.GPU, T}
    DynamicalOrderedCOO(
        Vector(coo._values),
        Vector(coo._rows),
        Vector(coo._cols),
        Vector(coo._prev),
        Vector(coo._next),
        Vector(coo._head),
        Vector(coo._tail),
        Vector(coo._NEntries),
        Vector(coo._NEntriesCache),
        Vector(coo._NEntriesNonzero),
        Vector(coo._NOverflowInsert),
        Vector(coo._NOverflowErase),
        Vector(coo._NEntriesFree),
        Vector(coo._NEntriesFreeNextInit),
        Vector(coo._NEntriesFreeNext),
        Vector(coo._entriesFree),
        ReentrantLock()
    )
end
    
toBackend(::KernelAbstractions.GPU, coo::DynamicalOrderedCOO{P}) where {P<:KernelAbstractions.GPU} = coo

function toBackend(backend::KernelAbstractions.GPU, coo::DynamicalOrderedCOO{P}) where {P<:KernelAbstractions.CPU}
    DynamicalOrderedCOO(
        toBackend(backend, coo._values),
        toBackend(backend, coo._rows),
        toBackend(backend, coo._cols),
        toBackend(backend, coo._prev),
        toBackend(backend, coo._next),
        toBackend(backend, coo._head),
        toBackend(backend, coo._tail),
        toBackend(backend, coo._NEntries),
        toBackend(backend, coo._NEntriesCache),
        toBackend(backend, coo._NEntriesNonzero),
        toBackend(backend, coo._NOverflowInsert),
        toBackend(backend, coo._NOverflowErase),
        toBackend(backend, coo._NEntriesFree),
        toBackend(backend, coo._NEntriesFreeNextInit),
        toBackend(backend, coo._NEntriesFreeNext),
        toBackend(backend, coo._entriesFree),
        nothing
    )
end
