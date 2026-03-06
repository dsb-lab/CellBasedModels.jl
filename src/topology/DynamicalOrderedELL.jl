######################################################################################################
# DynamicalOrderedELL - ELL format with ordered traversal via doubly-linked list per row
######################################################################################################
struct DynamicalOrderedELL{
            P, T, V, I, COO
        } <: AbstractSparseMatrix

    _values::V
    _cols::I

    _nRows::I          # Number of rows (stored as array for GPU compatibility)
    _nColsPerRow::I    # Number of columns per row (fixed for all rows)

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

    _coo::COO          # Overflow storage (also ordered)
end
Adapt.@adapt_structure DynamicalOrderedELL

function DynamicalOrderedELL(
        _values,
        _cols,

        _nRows,
        _nColsPerRow,
        
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
    I = typeof(_nRows)
    COO = typeof(_coo)

    DynamicalOrderedELL{
            P, T, V, I, COO
        }(
            _values,
            _cols,

            _nRows,
            _nColsPerRow,
            
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

function doell_zeros(dtype::DataType, n_rows::Int=0, n_cols_per_row::Int=0, n_coo::Int=0)

    @assert n_rows >= 0 "n_rows must be >= 0"
    @assert n_cols_per_row >= 0 "n_cols_per_row must be >= 0"
    @assert n_coo >= 0 "n_coo must be >= 0"
    
    n_entries = n_rows * n_cols_per_row
    
    _values = zeros(dtype, n_entries)
    _cols = zeros(Int, n_entries)
    _nRows = Int[n_rows]
    _nColsPerRow = Int[n_cols_per_row]
    _prev = zeros(Int, n_entries)
    _next = zeros(Int, n_entries)
    _rowHead = zeros(Int, n_rows)
    _rowTail = zeros(Int, n_rows)

    _NEntries = zeros(Int, 1)
    _NEntriesCache = Int[n_entries]
    _NEntriesNonzero = zeros(Int, 1)
    _NOverflowInsert = zeros(Int, 1)

    _coo = docoo_zeros(dtype, n_coo)

    DynamicalOrderedELL(
            _values,
            _cols,

            _nRows,
            _nColsPerRow,
            
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

function doell_zeros(n_rows::Int=0, n_cols_per_row::Int=0, n_coo::Int=0)
    doell_zeros(Float64, n_rows, n_cols_per_row, n_coo)
end

function Base.show(io::IO, x::DynamicalOrderedELL{P, T}) where {P, T}
    
    nrows = numberOfRows(x)
    ncols = numberOfCols(x)
    nentries = numberOfEntries(x)
    nColsPerRow = getDeviceIndex(x._nColsPerRow)
    
    println(io, "DynamicalOrderedELL{$T} with $(nentries) stored entries ($nColsPerRow cols per row, ordered)")
    println(io, "  $(nrows) × $(ncols) sparse matrix")
    
    # Show entries per row
    ellRows = getDeviceIndex(x._nRows)
    if ellRows <= 10 && ellRows > 0
        rowHead = Array(x._rowHead)
        cols = Array(x._cols)
        values = Array(x._values)
        next = Array(x._next)
        
        for row in 1:ellRows
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

function Base.show(io::IO, x::Type{DynamicalOrderedELL{P, T, V, I}}) where {P, T, V, I}
    println(io, "DynamicalOrderedELL{$P, $T, $V, $I}")
end

Base.length(ell::DynamicalOrderedELL{P}) where {P} = length(ell._values)
numberOfEntries(ell::DynamicalOrderedELL{P}) where {P} = getDeviceIndex(ell._NEntries) + numberOfEntries(ell._coo)
numberOfEntriesCache(ell::DynamicalOrderedELL{P}) where {P} = getDeviceIndex(ell._NEntriesCache)
numberOfEntriesNonzero(ell::DynamicalOrderedELL{P}) where {P} = getDeviceIndex(ell._NEntriesNonzero) + numberOfEntriesNonzero(ell._coo)
numberOfRows(ell::DynamicalOrderedELL{P}) where {P} = max(numberOfRows(ell._coo), getDeviceIndex(ell._nRows))
numberOfCols(ell::DynamicalOrderedELL{P}) where {P} = max(maximum(ell._cols; init=0), numberOfCols(ell._coo))
numberOfColsPerRow(ell::DynamicalOrderedELL{P}) where {P} = getDeviceIndex(ell._nColsPerRow)

"""
    _row_range(ell::DynamicalOrderedELL, i::Int)

Get the start and end indices for row i in the ELL format.
"""
@inline function _row_range(ell::DynamicalOrderedELL, i::Int)
    nColsPerRow = ell._nColsPerRow[1]
    startIdx = (i - 1) * nColsPerRow + 1
    endIdx = i * nColsPerRow
    return startIdx, endIdx
end

"""
    getrowhead(ell::DynamicalOrderedELL, row::Int)

Get the index of the first entry in row's ordered list.
"""
@inline function getrowhead(ell::DynamicalOrderedELL, row::Int)
    return ell._rowHead[row]
end

"""
    getrowtail(ell::DynamicalOrderedELL, row::Int)

Get the index of the last entry in row's ordered list.
"""
@inline function getrowtail(ell::DynamicalOrderedELL, row::Int)
    return ell._rowTail[row]
end

"""
    getnext(ell::DynamicalOrderedELL, k::Int)

Get the next entry index after position k.
"""
@inline function getnext(ell::DynamicalOrderedELL, k::Int)
    return ell._next[k]
end

"""
    getprev(ell::DynamicalOrderedELL, k::Int)

Get the previous entry index before position k.
"""
@inline function getprev(ell::DynamicalOrderedELL, k::Int)
    return ell._prev[k]
end

"""
    getentry(ell::DynamicalOrderedELL, k::Int)

Get the (col, value) entry at position k.
"""
@inline function getentry(ell::DynamicalOrderedELL, k::Int)
    return (ell._cols[k], ell._values[k])
end

"""
    todense(ell::DynamicalOrderedELL)

Convert the sparse ELL matrix to a dense matrix.
"""
function todense(ell::DynamicalOrderedELL{P, T}) where {P, T}
    nRows = numberOfRows(ell)
    nCols = numberOfCols(ell)
    
    dense = zeros(T, nRows, nCols)
    
    cols = Array(ell._cols)
    values = Array(ell._values)
    rowHead = Array(ell._rowHead)
    next = Array(ell._next)
    ellRows = Array(ell._nRows)[1]
    
    # Fill from ELL portion (ordered iteration per row)
    for i in 1:ellRows
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
    coo_dense = todense(ell._coo)
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
    _findentry_in_row(ell::DynamicalOrderedELL, row::Int, col::Int)

Find the slot index for entry (row, col) in ELL portion.
"""
function _findentry_in_row(ell::DynamicalOrderedELL, row::Int, col::Int)
    nRows = ell._nRows[1]
    if row <= 0 || row > nRows
        return 0
    end
    
    k = ell._rowHead[row]
    while k != 0
        if ell._cols[k] == col
            return k
        end
        k = ell._next[k]
    end
    return 0
end

"""
    _get_free_slot_in_row!(ell::DynamicalOrderedELL, row::Int)

Get a free slot in the specified row.
"""
@inline function _get_free_slot_in_row!(ell::DynamicalOrderedELL, row::Int)
    nRows = ell._nRows[1]
    nColsPerRow = ell._nColsPerRow[1]
    
    if row <= 0 || row > nRows || nColsPerRow == 0
        return 0
    end
    
    startIdx, endIdx = _row_range(ell, row)
    
    # Find an empty slot
    for k in startIdx:endIdx
        if ell._cols[k] == 0
            return k
        end
    end
    
    Atomix.@atomic ell._NOverflowInsert[1] += 1
    return 0
end

"""
    Base.getindex(ell::DynamicalOrderedELL, i::Int, j::Int)

Get value at position (i, j).
"""
function Base.getindex(ell::DynamicalOrderedELL{P, T}, i::Int, j::Int) where {P, T}
    k = _findentry_in_row(ell, i, j)
    if k != 0
        return ell._values[k]
    end
    return ell._coo[i, j]
end

######################################################################################################
# Insertion functions
######################################################################################################

"""
    pushfirst!(ell::DynamicalOrderedELL, row::Int, col::Int, value)

Add an entry at the beginning of the row's ordered list.
"""
function Base.pushfirst!(ell::DynamicalOrderedELL, row::Int, col::Int, value)
    if row <= 0 || col <= 0
        @print "Indices must be positive integers."
        return false
    end
    
    nRows = ell._nRows[1]
    if row > nRows
        return pushfirst!(ell._coo, row, col, value)
    end
    
    k = _get_free_slot_in_row!(ell, row)
    if k == 0
        return append!(ell._coo, row, col, value)
    end
    
    ell._cols[k] = col
    ell._values[k] = value
    
    oldHead = ell._rowHead[row]
    ell._prev[k] = 0
    ell._next[k] = oldHead
    
    if oldHead != 0
        ell._prev[oldHead] = k
    else
        ell._rowTail[row] = k
    end
    ell._rowHead[row] = k
    
    Atomix.@atomic ell._NEntries[1] += 1
    if value != 0
        Atomix.@atomic ell._NEntriesNonzero[1] += 1
    end
    
    return true
end

"""
    append!(ell::DynamicalOrderedELL, row::Int, col::Int, value)

Add an entry at the end of the row's ordered list.
"""
function Base.append!(ell::DynamicalOrderedELL, row::Int, col::Int, value)
    if row <= 0 || col <= 0
        @print "Indices must be positive integers."
        return false
    end
    
    nRows = ell._nRows[1]
    if row > nRows
        return append!(ell._coo, row, col, value)
    end
    
    k = _get_free_slot_in_row!(ell, row)
    if k == 0
        return append!(ell._coo, row, col, value)
    end
    
    ell._cols[k] = col
    ell._values[k] = value
    
    oldTail = ell._rowTail[row]
    ell._prev[k] = oldTail
    ell._next[k] = 0
    
    if oldTail != 0
        ell._next[oldTail] = k
    else
        ell._rowHead[row] = k
    end
    ell._rowTail[row] = k
    
    Atomix.@atomic ell._NEntries[1] += 1
    if value != 0
        Atomix.@atomic ell._NEntriesNonzero[1] += 1
    end
    
    return true
end

"""
    insertafter!(ell::DynamicalOrderedELL, row::Int, col_ref::Int, col::Int, value)

Insert after entry (row, col_ref).
"""
function insertafter!(ell::DynamicalOrderedELL, row::Int, col_ref::Int, col::Int, value)
    if row <= 0 || col <= 0
        return false
    end
    
    k_ref = _findentry_in_row(ell, row, col_ref)
    if k_ref == 0
        return false
    end
    
    return insertafter_k!(ell, row, k_ref, col, value)
end

"""
    insertafter_k!(ell::DynamicalOrderedELL, row::Int, k_ref::Int, col::Int, value)

Insert after slot k_ref. GPU-compatible.
"""
function insertafter_k!(ell::DynamicalOrderedELL, row::Int, k_ref::Int, col::Int, value)
    if col <= 0
        return false
    end
    
    k = _get_free_slot_in_row!(ell, row)
    if k == 0
        return append!(ell._coo, row, col, value)
    end
    
    ell._cols[k] = col
    ell._values[k] = value
    
    k_next = ell._next[k_ref]
    
    ell._prev[k] = k_ref
    ell._next[k] = k_next
    ell._next[k_ref] = k
    
    if k_next != 0
        ell._prev[k_next] = k
    else
        ell._rowTail[row] = k
    end
    
    Atomix.@atomic ell._NEntries[1] += 1
    if value != 0
        Atomix.@atomic ell._NEntriesNonzero[1] += 1
    end
    
    return true
end

"""
    insertbefore!(ell::DynamicalOrderedELL, row::Int, col_ref::Int, col::Int, value)

Insert before entry (row, col_ref).
"""
function insertbefore!(ell::DynamicalOrderedELL, row::Int, col_ref::Int, col::Int, value)
    if row <= 0 || col <= 0
        return false
    end
    
    k_ref = _findentry_in_row(ell, row, col_ref)
    if k_ref == 0
        return false
    end
    
    return insertbefore_k!(ell, row, k_ref, col, value)
end

"""
    insertbefore_k!(ell::DynamicalOrderedELL, row::Int, k_ref::Int, col::Int, value)

Insert before slot k_ref. GPU-compatible.
"""
function insertbefore_k!(ell::DynamicalOrderedELL, row::Int, k_ref::Int, col::Int, value)
    if col <= 0
        return false
    end
    
    k = _get_free_slot_in_row!(ell, row)
    if k == 0
        return append!(ell._coo, row, col, value)
    end
    
    ell._cols[k] = col
    ell._values[k] = value
    
    k_prev = ell._prev[k_ref]
    
    ell._prev[k] = k_prev
    ell._next[k] = k_ref
    ell._prev[k_ref] = k
    
    if k_prev != 0
        ell._next[k_prev] = k
    else
        ell._rowHead[row] = k
    end
    
    Atomix.@atomic ell._NEntries[1] += 1
    if value != 0
        Atomix.@atomic ell._NEntriesNonzero[1] += 1
    end
    
    return true
end

######################################################################################################
# Deletion functions
######################################################################################################

"""
    delete!(ell::DynamicalOrderedELL, row::Int, col::Int)

Remove entry at (row, col).
"""
function Base.delete!(ell::DynamicalOrderedELL, row::Int, col::Int)
    k = _findentry_in_row(ell, row, col)
    if k != 0
        return delete_k!(ell, row, k)
    end
    return delete!(ell._coo, row, col)
end

"""
    delete_k!(ell::DynamicalOrderedELL, row::Int, k::Int)

Remove entry at slot k. GPU-compatible.
"""
function delete_k!(ell::DynamicalOrderedELL, row::Int, k::Int)
    oldValue = ell._values[k]
    
    k_prev = ell._prev[k]
    k_next = ell._next[k]
    
    if k_prev != 0
        ell._next[k_prev] = k_next
    else
        ell._rowHead[row] = k_next
    end
    
    if k_next != 0
        ell._prev[k_next] = k_prev
    else
        ell._rowTail[row] = k_prev
    end
    
    ell._cols[k] = 0
    ell._values[k] = 0
    ell._prev[k] = 0
    ell._next[k] = 0
    
    Atomix.@atomic ell._NEntries[1] -= 1
    if oldValue != 0
        Atomix.@atomic ell._NEntriesNonzero[1] -= 1
    end
    
    return true
end

######################################################################################################
# Row iteration support
######################################################################################################

"""
    OrderedELLRowIterator{V, I}

Iterator for ordered traversal of a row.
"""
struct OrderedELLRowIterator{V, I}
    row::Int
    _cols::I
    _values::V
    _next::I
    _head::Int
end
Adapt.@adapt_structure OrderedELLRowIterator

"""
    iterateRow(ell::DynamicalOrderedELL, row::Int)

Create an iterator for ordered traversal of the row.
"""
@inline function iterateRow(ell::DynamicalOrderedELL, row::Int)
    nRows = ell._nRows[1]
    if row <= 0 || row > nRows
        return OrderedELLRowIterator(row, ell._cols, ell._values, ell._next, 0)
    end
    head = ell._rowHead[row]
    return OrderedELLRowIterator(row, ell._cols, ell._values, ell._next, head)
end

@inline function getentry(iter::OrderedELLRowIterator, k::Int)
    return (iter._cols[k], iter._values[k])
end

@inline function getnext(iter::OrderedELLRowIterator, k::Int)
    return iter._next[k]
end

######################################################################################################
# Utility functions
######################################################################################################

function overflow(ell::DynamicalOrderedELL)
    return getDeviceIndex(ell._NOverflowInsert) > 0 || numberOfEntries(ell._coo) > 0
end

function overflowEntries(ell::DynamicalOrderedELL)
    return numberOfEntries(ell._coo)
end

function overflowRows(ell::DynamicalOrderedELL)
    return numberOfRows(ell._coo)
end

function allocationRatio(ell::DynamicalOrderedELL)
    cache = numberOfEntriesCache(ell)
    entries = getDeviceIndex(ell._NEntries)
    if cache == 0
        return 0.0
    end
    return entries / cache
end

function allocationsFailed(ell::DynamicalOrderedELL)
    return getDeviceIndex(ell._NOverflowInsert) > 0 || allocationsFailed(ell._coo)
end

function synchronize(ell::DynamicalOrderedELL)
    synchronize(ell._coo)
    ell._NOverflowInsert[1] = 0
    return
end

function setvalue!(ell::DynamicalOrderedELL, row::Int, col::Int, value)
    k = _findentry_in_row(ell, row, col)
    if k != 0
        oldValue = ell._values[k]
        ell._values[k] = value
        if oldValue == 0 && value != 0
            Atomix.@atomic ell._NEntriesNonzero[1] += 1
        elseif oldValue != 0 && value == 0
            Atomix.@atomic ell._NEntriesNonzero[1] -= 1
        end
        return true
    end
    return setvalue!(ell._coo, row, col, value)
end

@inline function setvalue_k!(ell::DynamicalOrderedELL, k::Int, value)
    oldValue = ell._values[k]
    ell._values[k] = value
    if oldValue == 0 && value != 0
        Atomix.@atomic ell._NEntriesNonzero[1] += 1
    elseif oldValue != 0 && value == 0
        Atomix.@atomic ell._NEntriesNonzero[1] -= 1
    end
    return true
end

function Base.copy(ell::DynamicalOrderedELL)
    return DynamicalOrderedELL(
        copy(ell._values),
        copy(ell._cols),
        copy(ell._nRows),
        copy(ell._nColsPerRow),
        copy(ell._prev),
        copy(ell._next),
        copy(ell._rowHead),
        copy(ell._rowTail),
        copy(ell._NEntries),
        copy(ell._NEntriesCache),
        copy(ell._NEntriesNonzero),
        copy(ell._NOverflowInsert),
        copy(ell._coo)
    )
end

###################################################################################################
# Platform adaptation
###################################################################################################

KernelAbstractions.get_backend(ell::DynamicalOrderedELL) = KernelAbstractions.get_backend(ell._values)

toBackend(::KernelAbstractions.CPU, ell::DynamicalOrderedELL{P}) where {P<:KernelAbstractions.CPU} = ell

function toBackend(::KernelAbstractions.CPU, ell::DynamicalOrderedELL{P, T}) where {P<:KernelAbstractions.GPU, T}
    DynamicalOrderedELL(
        Vector(ell._values),
        Vector(ell._cols),
        Vector(ell._nRows),
        Vector(ell._nColsPerRow),
        Vector(ell._prev),
        Vector(ell._next),
        Vector(ell._rowHead),
        Vector(ell._rowTail),
        Vector(ell._NEntries),
        Vector(ell._NEntriesCache),
        Vector(ell._NEntriesNonzero),
        Vector(ell._NOverflowInsert),
        toBackend(CPU(), ell._coo)
    )
end
    
toBackend(::KernelAbstractions.GPU, ell::DynamicalOrderedELL{P}) where {P<:KernelAbstractions.GPU} = ell

function toBackend(backend::KernelAbstractions.GPU, ell::DynamicalOrderedELL{P}) where {P<:KernelAbstractions.CPU}
    DynamicalOrderedELL(
        toBackend(backend, ell._values),
        toBackend(backend, ell._cols),
        toBackend(backend, ell._nRows),
        toBackend(backend, ell._nColsPerRow),
        toBackend(backend, ell._prev),
        toBackend(backend, ell._next),
        toBackend(backend, ell._rowHead),
        toBackend(backend, ell._rowTail),
        toBackend(backend, ell._NEntries),
        toBackend(backend, ell._NEntriesCache),
        toBackend(backend, ell._NEntriesNonzero),
        toBackend(backend, ell._NOverflowInsert),
        toBackend(backend, ell._coo)
    )
end
