######################################################################################################
# DynamicalOrderedCSR - CSR format with ordered traversal via doubly-linked list per row
######################################################################################################
struct DynamicalOrderedCSR{
            P, T, V, I, COO
        } <: AbstractSparseMatrix

    _values::V
    _cols::I

    _rowOffsets::I 

    # Linked list pointers for each entry (0 means null/no link)
    _prev::I      # Previous entry index for each slot
    _next::I      # Next entry index for each slot
    
    # Per-row head/tail (one per row)
    _rowHead::I   # Head of linked list for each row
    _rowTail::I   # Tail of linked list for each row

    _NEntries::I
    _NEntriesCache::I
    _NEntriesNonzero::I
    _NOverflowInsert::I

    _coo::COO  # Overflow storage (also ordered)
end
Adapt.@adapt_structure DynamicalOrderedCSR

function DynamicalOrderedCSR(
        _values,
        _cols,

        _rowOffsets,
        
        _prev,
        _next,
        _rowHead,
        _rowTail,

        _NEntries,
        _NEntriesCache,
        _NEntriesNonzero,
        _NOverflowInsert,

        _coo
    )
    
    P = typeof(KernelAbstractions.get_backend(_values))
    T = eltype(_values)
    V = typeof(_values)
    I = typeof(_rowOffsets)
    COO = typeof(_coo)

    DynamicalOrderedCSR{
            P, T, V, I, COO
        }(
            _values,
            _cols,

            _rowOffsets,
            
            _prev,
            _next,
            _rowHead,
            _rowTail,

            _NEntries,
            _NEntriesCache,
            _NEntriesNonzero,
            _NOverflowInsert,

            _coo
        )
end

function docsr_zeros(dtype::DataType, n_rows::Int=0, n_cols::Union{Int, Vector}=0, n_coo::Int=0)

    @assert n_rows >= 0 "n_rows must be >= 0"
    n_entries = 0
    offsets = 0
    if n_cols isa Int
        @assert n_cols >= 0 "n_cols must be >= 0"
        n_entries += n_cols*n_rows
        if n_cols == 0
            offsets = ones(Int, n_rows + 1)
        else
            offsets = collect(1:n_cols:n_cols*n_rows+1)
        end
    else
        @assert all(n_cols .>= 0) "all elements of n_cols must be >= 0"
        @assert length(n_cols) == n_rows "length of n_cols must be == n_rows"
        n_entries += sum(n_cols)
        offsets = cumsum(vcat(1, n_cols))
    end
    @assert n_coo >= 0 "n_coo must be >= 0"
    
    _values = zeros(dtype, n_entries)
    _cols = zeros(Int, n_entries)
    _rowOffsets = offsets
    _prev = zeros(Int, n_entries)
    _next = zeros(Int, n_entries)
    _rowHead = zeros(Int, n_rows)
    _rowTail = zeros(Int, n_rows)

    _NEntries = zeros(Int, 1)
    _NEntriesCache = Int[n_entries]
    _NEntriesNonzero = zeros(Int, 1)
    _NOverflowInsert = zeros(Int, 1)

    _coo = docoo_zeros(dtype, n_coo)

    DynamicalOrderedCSR(
            _values,
            _cols,

            _rowOffsets,
            
            _prev,
            _next,
            _rowHead,
            _rowTail,

            _NEntries,
            _NEntriesCache,
            _NEntriesNonzero,
            _NOverflowInsert,

            _coo
        )
end

function docsr_zeros(n_rows::Int=0, n_cols::Union{Int, Vector}=0, n_coo::Int=0)
    docsr_zeros(Float64, n_rows, n_cols, n_coo)
end

function Base.show(io::IO, x::DynamicalOrderedCSR{P, T}) where {P, T}
    
    nrows = numberOfRows(x)
    ncols = numberOfCols(x)
    nentries = numberOfEntries(x)
    
    println(io, "DynamicalOrderedCSR{$T} with $(nentries) stored entries (ordered per row)")
    println(io, "  $(nrows) × $(ncols) sparse matrix")
    
    # Show entries per row
    if nrows <= 10 && nrows > 0
        rowHead = Array(x._rowHead)
        rowTail = Array(x._rowTail)
        cols = Array(x._cols)
        values = Array(x._values)
        next = Array(x._next)
        
        for row in 1:nrows
            print(io, "  Row $row: ")
            k = rowHead[row]
            count = 0
            while k != 0 && count < 10
                print(io, "[$(cols[k])]=$(values[k]) ")
                k = next[k]
                count += 1
            end
            println(io)
        end
    end
end

function Base.show(io::IO, x::Type{DynamicalOrderedCSR{P, T, V, I}}) where {P, T, V, I}
    println(io, "DynamicalOrderedCSR{$P, $T, $V, $I}")
end

Base.length(csr::DynamicalOrderedCSR{P}) where {P} = length(csr._values)
numberOfEntries(csr::DynamicalOrderedCSR{P}) where {P} = getDeviceIndex(csr._NEntries) + numberOfEntries(csr._coo)
numberOfEntriesCache(csr::DynamicalOrderedCSR{P}) where {P} = getDeviceIndex(csr._NEntriesCache)
numberOfEntriesNonzero(csr::DynamicalOrderedCSR{P}) where {P} = getDeviceIndex(csr._NEntriesNonzero) + numberOfEntriesNonzero(csr._coo)
numberOfRows(csr::DynamicalOrderedCSR{P}) where {P} = max(numberOfRows(csr._coo), length(csr._rowOffsets)-1)
numberOfCols(csr::DynamicalOrderedCSR{P}) where {P} = max(maximum(csr._cols; init=0), numberOfCols(csr._coo))

"""
    getrowhead(csr::DynamicalOrderedCSR, row::Int)

Get the index of the first entry in row's ordered list.
Returns 0 if the row is empty.
"""
@inline function getrowhead(csr::DynamicalOrderedCSR, row::Int)
    return csr._rowHead[row]
end

"""
    getrowtail(csr::DynamicalOrderedCSR, row::Int)

Get the index of the last entry in row's ordered list.
Returns 0 if the row is empty.
"""
@inline function getrowtail(csr::DynamicalOrderedCSR, row::Int)
    return csr._rowTail[row]
end

"""
    getnext(csr::DynamicalOrderedCSR, k::Int)

Get the index of the next entry after position k.
Returns 0 if k is the last entry in the row.
"""
@inline function getnext(csr::DynamicalOrderedCSR, k::Int)
    return csr._next[k]
end

"""
    getprev(csr::DynamicalOrderedCSR, k::Int)

Get the index of the previous entry before position k.
Returns 0 if k is the first entry in the row.
"""
@inline function getprev(csr::DynamicalOrderedCSR, k::Int)
    return csr._prev[k]
end

"""
    getentry(csr::DynamicalOrderedCSR, k::Int)

Get the (col, value) entry at position k.
"""
@inline function getentry(csr::DynamicalOrderedCSR, k::Int)
    return (csr._cols[k], csr._values[k])
end

"""
    todense(csr::DynamicalOrderedCSR)

Convert the sparse CSR matrix to a dense matrix.
"""
function todense(csr::DynamicalOrderedCSR{P, T}) where {P, T}
    nRows = numberOfRows(csr)
    nCols = numberOfCols(csr)
    
    dense = zeros(T, nRows, nCols)
    
    cols = Array(csr._cols)
    values = Array(csr._values)
    rowHead = Array(csr._rowHead)
    next = Array(csr._next)
    csrRows = length(rowHead)
    
    # Fill from CSR portion (ordered iteration per row)
    for i in 1:csrRows
        k = rowHead[i]
        while k != 0
            j = cols[k]
            if j > 0
                dense[i, j] = values[k]
            end
            k = next[k]
        end
    end
    
    # Fill from overflow COO
    coo_dense = todense(csr._coo)
    coo_nRows, coo_nCols = size(coo_dense)
    for i in 1:coo_nRows
        for j in 1:coo_nCols
            if coo_dense[i, j] != zero(T)
                dense[i, j] = coo_dense[i, j]
            end
        end
    end
    
    return dense
end

######################################################################################################
# Finding entries
######################################################################################################

"""
    _findentry_in_row(csr::DynamicalOrderedCSR, row::Int, col::Int)

Find the slot index for entry (row, col) in CSR portion. Returns 0 if not found.
"""
function _findentry_in_row(csr::DynamicalOrderedCSR, row::Int, col::Int)
    if row > length(csr._rowHead)
        return 0
    end
    
    k = csr._rowHead[row]
    while k != 0
        if csr._cols[k] == col
            return k
        end
        k = csr._next[k]
    end
    return 0
end

"""
    _get_free_slot_in_row!(csr::DynamicalOrderedCSR, row::Int)

Get a free slot in the specified row. Returns 0 if no slots available.
"""
@inline function _get_free_slot_in_row!(csr::DynamicalOrderedCSR, row::Int)
    if row > length(csr._rowOffsets) - 1
        return 0
    end
    
    startIdx = csr._rowOffsets[row]
    endIdx = csr._rowOffsets[row + 1] - 1
    
    # Find an empty slot in this row's range
    for k in startIdx:endIdx
        if csr._cols[k] == 0
            return k
        end
    end
    
    # No free slots in row
    Atomix.@atomic csr._NOverflowInsert[1] += 1
    return 0
end

"""
    Base.getindex(csr::DynamicalOrderedCSR, i::Int, j::Int)

Get the value at position (i, j).
"""
function Base.getindex(csr::DynamicalOrderedCSR{P, T}, i::Int, j::Int) where {P, T}
    k = _findentry_in_row(csr, i, j)
    if k != 0
        return csr._values[k]
    end
    # Check overflow COO
    return csr._coo[i, j]
end

######################################################################################################
# Insertion functions for rows
######################################################################################################

"""
    pushfirst!(csr::DynamicalOrderedCSR, row::Int, col::Int, value)

Add an entry at the beginning of the specified row's ordered list.
Returns true if successful, false if no space available.
"""
function Base.pushfirst!(csr::DynamicalOrderedCSR, row::Int, col::Int, value)
    if row <= 0 || col <= 0
        @print "Indices must be positive integers."
        return false
    end
    
    # Check if row is in CSR bounds
    if row > length(csr._rowHead)
        # Add to overflow COO
        return pushfirst!(csr._coo, row, col, value)
    end
    
    # Get a free slot in this row
    k = _get_free_slot_in_row!(csr, row)
    if k == 0
        # Row is full, add to overflow COO
        return append!(csr._coo, row, col, value)
    end
    
    # Set the entry data
    csr._cols[k] = col
    csr._values[k] = value
    
    # Update row's linked list
    oldHead = csr._rowHead[row]
    csr._prev[k] = 0
    csr._next[k] = oldHead
    
    if oldHead != 0
        csr._prev[oldHead] = k
    else
        # Row was empty, this is also the tail
        csr._rowTail[row] = k
    end
    csr._rowHead[row] = k
    
    # Update counts
    Atomix.@atomic csr._NEntries[1] += 1
    if value != 0
        Atomix.@atomic csr._NEntriesNonzero[1] += 1
    end
    
    return true
end

"""
    append!(csr::DynamicalOrderedCSR, row::Int, col::Int, value)

Add an entry at the end of the specified row's ordered list.
Returns true if successful, false if no space available.
"""
function Base.append!(csr::DynamicalOrderedCSR, row::Int, col::Int, value)
    if row <= 0 || col <= 0
        @print "Indices must be positive integers."
        return false
    end
    
    # Check if row is in CSR bounds
    if row > length(csr._rowHead)
        # Add to overflow COO
        return append!(csr._coo, row, col, value)
    end
    
    # Get a free slot in this row
    k = _get_free_slot_in_row!(csr, row)
    if k == 0
        # Row is full, add to overflow COO
        return append!(csr._coo, row, col, value)
    end
    
    # Set the entry data
    csr._cols[k] = col
    csr._values[k] = value
    
    # Update row's linked list
    oldTail = csr._rowTail[row]
    csr._prev[k] = oldTail
    csr._next[k] = 0
    
    if oldTail != 0
        csr._next[oldTail] = k
    else
        # Row was empty, this is also the head
        csr._rowHead[row] = k
    end
    csr._rowTail[row] = k
    
    # Update counts
    Atomix.@atomic csr._NEntries[1] += 1
    if value != 0
        Atomix.@atomic csr._NEntriesNonzero[1] += 1
    end
    
    return true
end

"""
    insertafter!(csr::DynamicalOrderedCSR, row::Int, col_ref::Int, col::Int, value)

Insert a new entry (row, col, value) after the entry at (row, col_ref) in the row.
Returns true if successful.
"""
function insertafter!(csr::DynamicalOrderedCSR, row::Int, col_ref::Int, col::Int, value)
    if row <= 0 || col <= 0
        @print "Indices must be positive integers."
        return false
    end
    
    # Find the reference entry
    k_ref = _findentry_in_row(csr, row, col_ref)
    if k_ref == 0
        return false
    end
    
    return insertafter_k!(csr, row, k_ref, col, value)
end

"""
    insertafter_k!(csr::DynamicalOrderedCSR, row::Int, k_ref::Int, col::Int, value)

Insert a new entry after slot k_ref in the row. GPU-compatible.
"""
function insertafter_k!(csr::DynamicalOrderedCSR, row::Int, k_ref::Int, col::Int, value)
    if col <= 0
        return false
    end
    
    # Get a free slot
    k = _get_free_slot_in_row!(csr, row)
    if k == 0
        # Row is full, add to overflow COO at end
        return append!(csr._coo, row, col, value)
    end
    
    # Set the entry data
    csr._cols[k] = col
    csr._values[k] = value
    
    # Update linked list: insert k after k_ref
    k_next = csr._next[k_ref]
    
    csr._prev[k] = k_ref
    csr._next[k] = k_next
    csr._next[k_ref] = k
    
    if k_next != 0
        csr._prev[k_next] = k
    else
        csr._rowTail[row] = k
    end
    
    Atomix.@atomic csr._NEntries[1] += 1
    if value != 0
        Atomix.@atomic csr._NEntriesNonzero[1] += 1
    end
    
    return true
end

"""
    insertbefore!(csr::DynamicalOrderedCSR, row::Int, col_ref::Int, col::Int, value)

Insert a new entry (row, col, value) before the entry at (row, col_ref) in the row.
"""
function insertbefore!(csr::DynamicalOrderedCSR, row::Int, col_ref::Int, col::Int, value)
    if row <= 0 || col <= 0
        @print "Indices must be positive integers."
        return false
    end
    
    k_ref = _findentry_in_row(csr, row, col_ref)
    if k_ref == 0
        return false
    end
    
    return insertbefore_k!(csr, row, k_ref, col, value)
end

"""
    insertbefore_k!(csr::DynamicalOrderedCSR, row::Int, k_ref::Int, col::Int, value)

Insert a new entry before slot k_ref. GPU-compatible.
"""
function insertbefore_k!(csr::DynamicalOrderedCSR, row::Int, k_ref::Int, col::Int, value)
    if col <= 0
        return false
    end
    
    k = _get_free_slot_in_row!(csr, row)
    if k == 0
        return append!(csr._coo, row, col, value)
    end
    
    csr._cols[k] = col
    csr._values[k] = value
    
    k_prev = csr._prev[k_ref]
    
    csr._prev[k] = k_prev
    csr._next[k] = k_ref
    csr._prev[k_ref] = k
    
    if k_prev != 0
        csr._next[k_prev] = k
    else
        csr._rowHead[row] = k
    end
    
    Atomix.@atomic csr._NEntries[1] += 1
    if value != 0
        Atomix.@atomic csr._NEntriesNonzero[1] += 1
    end
    
    return true
end

######################################################################################################
# Deletion functions
######################################################################################################

"""
    delete!(csr::DynamicalOrderedCSR, row::Int, col::Int)

Remove the entry at (row, col).
"""
function Base.delete!(csr::DynamicalOrderedCSR, row::Int, col::Int)
    k = _findentry_in_row(csr, row, col)
    if k != 0
        return delete_k!(csr, row, k)
    end
    # Try overflow COO
    return delete!(csr._coo, row, col)
end

"""
    delete_k!(csr::DynamicalOrderedCSR, row::Int, k::Int)

Remove the entry at slot k from the row. GPU-compatible.
"""
function delete_k!(csr::DynamicalOrderedCSR, row::Int, k::Int)
    oldValue = csr._values[k]
    
    k_prev = csr._prev[k]
    k_next = csr._next[k]
    
    if k_prev != 0
        csr._next[k_prev] = k_next
    else
        csr._rowHead[row] = k_next
    end
    
    if k_next != 0
        csr._prev[k_next] = k_prev
    else
        csr._rowTail[row] = k_prev
    end
    
    # Clear the slot
    csr._cols[k] = 0
    csr._values[k] = 0
    csr._prev[k] = 0
    csr._next[k] = 0
    
    Atomix.@atomic csr._NEntries[1] -= 1
    if oldValue != 0
        Atomix.@atomic csr._NEntriesNonzero[1] -= 1
    end
    
    return true
end

######################################################################################################
# Row iteration support
######################################################################################################

"""
    OrderedCSRRowIterator{V, I}

Iterator for ordered traversal of a row in DynamicalOrderedCSR.
"""
struct OrderedCSRRowIterator{V, I}
    row::Int
    _cols::I
    _values::V
    _next::I
    _head::Int
end
Adapt.@adapt_structure OrderedCSRRowIterator

"""
    iterateRow(csr::DynamicalOrderedCSR, row::Int)

Create an iterator for ordered traversal of the row.
"""
@inline function iterateRow(csr::DynamicalOrderedCSR, row::Int)
    if row <= 0 || row > length(csr._rowHead)
        return OrderedCSRRowIterator(row, csr._cols, csr._values, csr._next, 0)
    end
    head = csr._rowHead[row]
    return OrderedCSRRowIterator(row, csr._cols, csr._values, csr._next, head)
end

@inline function getentry(iter::OrderedCSRRowIterator, k::Int)
    return (iter._cols[k], iter._values[k])
end

@inline function getnext(iter::OrderedCSRRowIterator, k::Int)
    return iter._next[k]
end

# Standard Julia iteration protocol
@inline function Base.iterate(iter::OrderedCSRRowIterator)
    if iter._head == 0
        return nothing
    end
    k = iter._head
    col = iter._cols[k]
    return (col, k)
end

@inline function Base.iterate(iter::OrderedCSRRowIterator, k::Int)
    next_k = iter._next[k]
    if next_k == 0
        return nothing
    end
    col = iter._cols[next_k]
    return (col, next_k)
end

"""
    getRow(csr::DynamicalOrderedCSR, row::Int, ::Val{N})

Get all values in a row as a tuple of N elements.
Returns the values at columns 1, 2, ... N in order.
If the row has fewer than N entries, returns 0 for missing values.

The size N must be provided as a Val{N} type parameter for GPU compatibility.

Example:
```julia
(n1, n2) = getRow(edge_to_node, edge_idx, Val(2))
```
"""
@inline function getRow(csr::DynamicalOrderedCSR{P, T}, row::Int, ::Val{N}) where {P, T, N}
    startIdx = csr._rowOffsets[row]
    endIdx = csr._rowOffsets[row + 1] - 1
    rowSize = endIdx - startIdx + 1
    return ntuple(i -> i <= rowSize ? @inbounds(csr._values[startIdx + i - 1]) : zero(T), Val(N))
end

######################################################################################################
# Utility functions
######################################################################################################

function overflow(csr::DynamicalOrderedCSR)
    return getDeviceIndex(csr._NOverflowInsert) > 0 || numberOfEntries(csr._coo) > 0
end

function overflowEntries(csr::DynamicalOrderedCSR)
    return numberOfEntries(csr._coo)
end

function overflowRows(csr::DynamicalOrderedCSR)
    return numberOfRows(csr._coo)
end

function allocationRatio(csr::DynamicalOrderedCSR)
    cache = numberOfEntriesCache(csr)
    entries = getDeviceIndex(csr._NEntries)
    if cache == 0
        return 0.0
    end
    return entries / cache
end

function allocationsFailed(csr::DynamicalOrderedCSR)
    return getDeviceIndex(csr._NOverflowInsert) > 0 || allocationsFailed(csr._coo)
end

function synchronize(csr::DynamicalOrderedCSR)
    synchronize(csr._coo)
    csr._NOverflowInsert[1] = 0
    return
end

function setvalue!(csr::DynamicalOrderedCSR, row::Int, col::Int, value)
    k = _findentry_in_row(csr, row, col)
    if k != 0
        oldValue = csr._values[k]
        csr._values[k] = value
        if oldValue == 0 && value != 0
            Atomix.@atomic csr._NEntriesNonzero[1] += 1
        elseif oldValue != 0 && value == 0
            Atomix.@atomic csr._NEntriesNonzero[1] -= 1
        end
        return true
    end
    return setvalue!(csr._coo, row, col, value)
end

@inline function setvalue_k!(csr::DynamicalOrderedCSR, k::Int, value)
    oldValue = csr._values[k]
    csr._values[k] = value
    if oldValue == 0 && value != 0
        Atomix.@atomic csr._NEntriesNonzero[1] += 1
    elseif oldValue != 0 && value == 0
        Atomix.@atomic csr._NEntriesNonzero[1] -= 1
    end
    return true
end

function Base.copy(csr::DynamicalOrderedCSR)
    return DynamicalOrderedCSR(
        copy(csr._values),
        copy(csr._cols),
        copy(csr._rowOffsets),
        copy(csr._prev),
        copy(csr._next),
        copy(csr._rowHead),
        copy(csr._rowTail),
        copy(csr._NEntries),
        copy(csr._NEntriesCache),
        copy(csr._NEntriesNonzero),
        copy(csr._NOverflowInsert),
        copy(csr._coo)
    )
end

###################################################################################################
# Platform adaptation
###################################################################################################

KernelAbstractions.get_backend(csr::DynamicalOrderedCSR) = KernelAbstractions.get_backend(csr._values)

toBackend(::KernelAbstractions.CPU, csr::DynamicalOrderedCSR{P}) where {P<:KernelAbstractions.CPU} = csr

function toBackend(::KernelAbstractions.CPU, csr::DynamicalOrderedCSR{P, T}) where {P<:KernelAbstractions.GPU, T}
    DynamicalOrderedCSR(
        Vector(csr._values),
        Vector(csr._cols),
        Vector(csr._rowOffsets),
        Vector(csr._prev),
        Vector(csr._next),
        Vector(csr._rowHead),
        Vector(csr._rowTail),
        Vector(csr._NEntries),
        Vector(csr._NEntriesCache),
        Vector(csr._NEntriesNonzero),
        Vector(csr._NOverflowInsert),
        toBackend(CPU(), csr._coo)
    )
end
    
toBackend(::KernelAbstractions.GPU, csr::DynamicalOrderedCSR{P}) where {P<:KernelAbstractions.GPU} = csr

function toBackend(backend::KernelAbstractions.GPU, csr::DynamicalOrderedCSR{P}) where {P<:KernelAbstractions.CPU}
    DynamicalOrderedCSR(
        toBackend(backend, csr._values),
        toBackend(backend, csr._cols),
        toBackend(backend, csr._rowOffsets),
        toBackend(backend, csr._prev),
        toBackend(backend, csr._next),
        toBackend(backend, csr._rowHead),
        toBackend(backend, csr._rowTail),
        toBackend(backend, csr._NEntries),
        toBackend(backend, csr._NEntriesCache),
        toBackend(backend, csr._NEntriesNonzero),
        toBackend(backend, csr._NOverflowInsert),
        toBackend(backend, csr._coo)
    )
end
