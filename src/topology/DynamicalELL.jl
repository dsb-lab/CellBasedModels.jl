######################################################################################################
# DynamicalELL - ELLPACK format with fixed columns per row
######################################################################################################
struct DynamicalELL{
            P, T, V, I, COO
        } <: AbstractSparseMatrix

    _values::V
    _cols::I

    _nRows::I          # Number of rows (stored as array for GPU compatibility)
    _nColsPerRow::I    # Number of columns per row (fixed for all rows)

    _NEntries::I
    _NEntriesCache::I
    _NEntriesNonzero::I
    _NOverflowInsert::I

    _coo::COO          # Overflow storage
end
Adapt.@adapt_structure DynamicalELL

function DynamicalELL(
        _values,
        _cols,

        _nRows,
        _nColsPerRow,

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

    DynamicalELL{
            P, T, V, I, COO
        }(
            _values,
            _cols,

            _nRows,
            _nColsPerRow,

            _NEntries,
            _NEntriesCache,
            _NEntriesNonzero,
            _NOverflowInsert,

            _coo
        )
end

function dell_zeros(dtype::DataType, n_rows::Int=0, n_cols_per_row::Int=0, n_coo::Int=0)

    @assert n_rows >= 0 "n_rows must be >= 0"
    @assert n_cols_per_row >= 0 "n_cols_per_row must be >= 0"
    @assert n_coo >= 0 "n_coo must be >= 0"
    
    n_entries = n_rows * n_cols_per_row
    
    _values = zeros(dtype, n_entries)
    _cols = zeros(Int, n_entries)
    _nRows = Int[n_rows]
    _nColsPerRow = Int[n_cols_per_row]

    _NEntries = zeros(Int, 1)
    _NEntriesCache = Int[n_entries]
    _NEntriesNonzero = zeros(Int, 1)
    _NOverflowInsert = zeros(Int, 1)

    _coo = dcoo_zeros(dtype, n_coo)

    DynamicalELL(
            _values,
            _cols,

            _nRows,
            _nColsPerRow,

            _NEntries,
            _NEntriesCache,
            _NEntriesNonzero,
            _NOverflowInsert,

            _coo
        )
end

function dell_zeros(n_rows::Int=0, n_cols_per_row::Int=0, n_coo::Int=0)
    dell_zeros(Float64, n_rows, n_cols_per_row, n_coo)
end

function Base.show(io::IO, x::DynamicalELL{P, T}) where {P, T}
    
    nrows = numberOfRows(x)
    ncols = numberOfCols(x)
    nentries = numberOfEntries(x)
    nColsPerRow = getDeviceIndex(x._nColsPerRow)
    
    println(io, "DynamicalELL{$T} with $(nentries) stored entries ($nColsPerRow cols per row)")
    println(io, "  $(nrows) × $(ncols) sparse matrix")
    
    # Show matrix contents if small enough
    if nrows <= 15 && ncols <= 15 && nrows > 0 && ncols > 0
        println(io, "")
        
        # First pass: determine column widths
        colwidths = ones(Int, ncols)
        for i in 1:1:nrows
            for j in 1:1:ncols
                val = _getindex(x, i, j)
                if val === nothing
                    width = 1  # "⋅"
                else
                    width = length(string(val))
                end
                colwidths[j] = max(colwidths[j], width)
            end
        end
        
        # Second pass: print with aligned columns
        for i in 1:1:nrows
            print(io, "  ")
            for j in 1:1:ncols
                val = _getindex(x, i, j)
                if val === nothing
                    str = "⋅"
                else
                    str = string(val)
                end
                print(io, lpad(str, colwidths[j]))
                if j < ncols
                    print(io, "  ")
                end
            end
            println(io)
        end
    end

end

function Base.show(io::IO, x::Type{DynamicalELL{P, T, V, I}}) where {P, T, V, I}
    println(io, "DynamicalELL{$P, $T, $V, $I}")
end

Base.length(ell::DynamicalELL{P}) where {P} = length(ell._values)
numberOfEntries(ell::DynamicalELL{P}) where {P} = getDeviceIndex(ell._NEntries) + numberOfEntries(ell._coo)
numberOfEntriesCache(ell::DynamicalELL{P}) where {P} = getDeviceIndex(ell._NEntriesCache)
numberOfEntriesNonzero(ell::DynamicalELL{P}) where {P} = getDeviceIndex(ell._NEntriesNonzero) + numberOfEntriesNonzero(ell._coo)
numberOfRows(ell::DynamicalELL{P}) where {P} = max(numberOfRows(ell._coo), getDeviceIndex(ell._nRows))
numberOfCols(ell::DynamicalELL{P}) where {P} = max(maximum(ell._cols; init=0), numberOfCols(ell._coo))
numberOfColsPerRow(ell::DynamicalELL{P}) where {P} = getDeviceIndex(ell._nColsPerRow)

"""
    _row_range(ell::DynamicalELL, i::Int)

Get the start and end indices for row i in the ELL format.
For row i, entries are at positions (i-1)*nColsPerRow + 1 to i*nColsPerRow
"""
@inline function _row_range(ell::DynamicalELL, i::Int)
    nColsPerRow = ell._nColsPerRow[1]
    startIdx = (i - 1) * nColsPerRow + 1
    endIdx = i * nColsPerRow
    return startIdx, endIdx
end

"""
    setindex!(ell::DynamicalELL, value, i::Int, j::Int)

Set the value at position (i, j) in the sparse matrix.
Allows syntax: x[i,j] = value
"""
function Base.setindex!(ell::DynamicalELL, value, i::Int, j::Int)

    if i <= 0 || j <= 0
        @print "Indices must be positive integers."
    end

    nRows = ell._nRows[1]
    nColsPerRow = ell._nColsPerRow[1]

    # Search in ELL portion if row exists
    if i <= nRows && nColsPerRow > 0
        startIdx, endIdx = _row_range(ell, i)
        # Loop if found
        for k in startIdx:endIdx
            if ell._cols[k] == j
                old = ell._values[k]
                if old == 0 && value != 0
                    Atomix.@atomic ell._NEntriesNonzero[1] += 1
                elseif old != 0 && value == 0
                    Atomix.@atomic ell._NEntriesNonzero[1] -= 1
                end
                ell._values[k] = value
                return false
            end
        end
        # Loop not found, add new
        for k in startIdx:endIdx
            if ell._cols[k] == 0
                result = Atomix.@atomicreplace ell._cols[k] 0 => j
                if result.success
                    ell._values[k] = value
                    if value != 0
                        Atomix.@atomic ell._NEntriesNonzero[1] += 1
                    end
                    Atomix.@atomic ell._NEntries[1] += 1
                end
                return true
            end
        end
    end

    # Not found or row overflow, add new at COO
    Atomix.@atomic ell._NOverflowInsert[1] += 1

    return setindex!(ell._coo, value, i, j)

end

function Base.setindex!(ell::DynamicalELL{P}, ::Nothing, i::Int, j::Int) where {P<:CPU}

    nRows = ell._nRows[1]
    nColsPerRow = ell._nColsPerRow[1]

    # Search in ELL portion
    if i > 0 && i <= nRows && nColsPerRow > 0
        startIdx, endIdx = _row_range(ell, i)
        for k in startIdx:endIdx
            if ell._cols[k] == j
                if ell._values[k] != zero(eltype(ell._values))
                    Atomix.@atomic ell._NEntriesNonzero[1] -= 1
                end
                ell._cols[k] = 0
                ell._values[k] = zero(eltype(ell._values))
                Atomix.@atomic ell._NEntries[1] -= 1
                return true
            end
        end
    end
    
    # Also search and remove from overflow COO
    setindex!(ell._coo, nothing, i, j)
    
    return false

end

function Base.setindex!(ell::DynamicalELL{P}, ::Nothing, i::Int, j::Int) where {P<:GPU}

    nRows = ell._nRows[1]
    nColsPerRow = ell._nColsPerRow[1]

    # Search in ELL portion
    if i > 0 && i <= nRows && nColsPerRow > 0
        startIdx, endIdx = _row_range(ell, i)
        for k in startIdx:endIdx
            if ell._cols[k] == j
                if ell._values[k] != zero(eltype(ell._values))
                    Atomix.@atomic ell._NEntriesNonzero[1] -= 1
                end
                ell._cols[k] = 0
                ell._values[k] = zero(eltype(ell._values))
                Atomix.@atomic ell._NEntries[1] -= 1
                return true
            end
        end
    end
    
    # Also search and remove from overflow COO
    setindex!(ell._coo, nothing, i, j)
    
    return false

end

"""
    getindex(ell::DynamicalELL, i::Int, j::Int)

Get the value at position (i, j) in the sparse matrix.
Returns 0 if the entry does not exist.
Allows syntax: value = x[i,j]
"""
function Base.getindex(ell::DynamicalELL{P, T}, i::Int, j::Int) where {P, T}

    nRows = ell._nRows[1]
    nColsPerRow = ell._nColsPerRow[1]

    # Search in ELL portion
    if i > 0 && i <= nRows && nColsPerRow > 0
        startIdx, endIdx = _row_range(ell, i)
        for k in startIdx:endIdx
            if ell._cols[k] == j
                return ell._values[k]
            end
        end
    end
    
    # Also check overflow COO
    val = ell._coo[i, j]
    if val != zero(T)
        return val
    end
    
    # Not found, return zero
    return zero(T)
end

function _getindex(ell::DynamicalELL, i::Int, j::Int)

    nRows = ell._nRows[1]
    nColsPerRow = ell._nColsPerRow[1]

    # Search in ELL portion
    if i > 0 && i <= nRows && nColsPerRow > 0
        startIdx, endIdx = _row_range(ell, i)
        for k in startIdx:endIdx
            if ell._cols[k] == j
                return ell._values[k]
            end
        end
    end
    
    # Also check overflow COO
    val = _getindex(ell._coo, i, j)
    if val !== nothing
        return val
    end
    
    # Not found
    return nothing
end

"""
    replaceIndex!(ell::DynamicalELL, i_old::Int, j_old::Int, i_new::Int, j_new::Int)

Replace the indices of an existing entry in-place without removing and re-adding.
Finds the entry at (i_old, j_old) and changes its indices to (i_new, j_new), keeping the value.
Returns true if the entry was found and replaced, false otherwise.

If the row stays the same (i_old == i_new), only the column index is changed in place,
which is very efficient and avoids expanding the ELL columns. If the row changes, 
the function removes from the old row and adds to the new row (which may overflow 
to COO if the new row is full).

This is more efficient than `ell[i_new, j_new] = ell[i_old, j_old]; ell[i_old, j_old] = nothing`
because it avoids the overhead of separate removal and insertion operations, and crucially
for same-row changes, it never causes overflow to COO.
"""
function replaceIndex!(ell::DynamicalELL, i_old::Int, j_old::Int, i_new::Int, j_new::Int)

    if i_old <= 0 || j_old <= 0 || i_new <= 0 || j_new <= 0
        @print "Indices must be positive integers."
        return false
    end

    nRows = ell._nRows[1]
    nColsPerRow = ell._nColsPerRow[1]

    # Search in ELL portion
    if i_old > 0 && i_old <= nRows && nColsPerRow > 0
        startIdx, endIdx = _row_range(ell, i_old)
        for k in startIdx:endIdx
            if ell._cols[k] == j_old
                # Found entry
                if i_old == i_new
                    # Same row - just change column in place (efficient! No overflow possible)
                    ell._cols[k] = j_new
                    return true
                else
                    # Different row - need to remove and re-add
                    value = ell._values[k]
                    # Remove from old position
                    if value != zero(eltype(ell._values))
                        Atomix.@atomic ell._NEntriesNonzero[1] -= 1
                    end
                    ell._cols[k] = 0
                    ell._values[k] = zero(eltype(ell._values))
                    Atomix.@atomic ell._NEntries[1] -= 1
                    # Add to new position (may overflow to COO)
                    setindex!(ell, value, i_new, j_new)
                    return true
                end
            end
        end
    end

    # Also search in overflow COO
    return replaceIndex!(ell._coo, i_old, j_old, i_new, j_new)
end

"""
    replaceIndex!(ell::DynamicalELL, i::Int, j_old::Int, j_new::Int)

Replace the column index of an existing entry in-place, keeping the same row.
Shorthand for `replaceIndex!(ell, i, j_old, i, j_new)`.
Returns true if the entry was found and replaced, false otherwise.

This is the most efficient form for ELL as it only changes the column index without
any structural changes and never causes overflow to COO.
"""
function replaceIndex!(ell::DynamicalELL, i::Int, j_old::Int, j_new::Int)
    return replaceIndex!(ell, i, j_old, i, j_new)
end

"""
    setindex!(ell::DynamicalELL, value, i::Int, ::Colon)

Set all entries in row i to value.
Allows syntax: ell[i,:] = value
"""
function Base.setindex!(ell::DynamicalELL, value, i::Int, ::Colon)

    nRows = ell._nRows[1]
    nColsPerRow = ell._nColsPerRow[1]

    # Set in ELL portion
    if i > 0 && i <= nRows && nColsPerRow > 0
        startIdx, endIdx = _row_range(ell, i)
        for k in startIdx:endIdx
            if ell._cols[k] != 0
                old = ell._values[k]
                if old == 0 && value != 0
                    Atomix.@atomic ell._NEntriesNonzero[1] += 1
                elseif old != 0 && value == 0
                    Atomix.@atomic ell._NEntriesNonzero[1] -= 1
                end
                ell._values[k] = value
            end
        end
    end
    
    # Also set in overflow COO
    ell._coo[i, :] = value

    return
end

"""
    setindex!(ell::DynamicalELL, value, ::Colon, j::Int)

Set all entries in column j to value.
Allows syntax: ell[:,j] = value
"""
function Base.setindex!(ell::DynamicalELL, value, ::Colon, j::Int)

    # Set in ELL portion - must scan all entries
    nEntries = length(ell)
    for k in 1:nEntries
        if ell._cols[k] == j
            old = ell._values[k]
            if old == 0 && value != 0
                Atomix.@atomic ell._NEntriesNonzero[1] += 1
            elseif old != 0 && value == 0
                Atomix.@atomic ell._NEntriesNonzero[1] -= 1
            end
            ell._values[k] = value
        end
    end
    
    # Also set in overflow COO
    ell._coo[:, j] = value

    return
end

"""
    setindex!(ell::DynamicalELL, ::Nothing, i::Int, ::Colon)

Remove all entries in row i.
Allows syntax: ell[i,:] = nothing
"""
function Base.setindex!(ell::DynamicalELL, ::Nothing, i::Int, ::Colon)

    nRows = ell._nRows[1]
    nColsPerRow = ell._nColsPerRow[1]

    # Remove in ELL portion
    if i > 0 && i <= nRows && nColsPerRow > 0
        startIdx, endIdx = _row_range(ell, i)
        for k in startIdx:endIdx
            if ell._cols[k] != 0
                if ell._values[k] != zero(eltype(ell._values))
                    Atomix.@atomic ell._NEntriesNonzero[1] -= 1
                end
                ell._cols[k] = 0
                ell._values[k] = zero(eltype(ell._values))
                Atomix.@atomic ell._NEntries[1] -= 1
            end
        end
    end
    
    # Also remove from overflow COO
    ell._coo[i, :] = nothing

    return
end

"""
    setindex!(ell::DynamicalELL, ::Nothing, ::Colon, j::Int)

Remove all entries in column j.
Allows syntax: ell[:,j] = nothing
"""
function Base.setindex!(ell::DynamicalELL, ::Nothing, ::Colon, j::Int)

    # Remove in ELL portion - must scan all entries
    nEntries = length(ell)
    for k in 1:nEntries
        if ell._cols[k] == j
            if ell._values[k] != zero(eltype(ell._values))
                Atomix.@atomic ell._NEntriesNonzero[1] -= 1
            end
            ell._cols[k] = 0
            ell._values[k] = zero(eltype(ell._values))
            Atomix.@atomic ell._NEntries[1] -= 1
        end
    end
    
    # Also remove from overflow COO
    ell._coo[:, j] = nothing

    return
end

function overflow(ell::DynamicalELL)

    return overflowEntries(ell) > 0

end

function overflowEntries(ell::DynamicalELL)

    return getDeviceIndex(ell._NOverflowInsert) > 0

end

function overflowRows(ell::DynamicalELL)

    return overflowEntries(ell)

end

function allocationRatio(ell::DynamicalELL)

    nEntries = numberOfEntries(ell)
    nEntriesCache = numberOfEntriesCache(ell)

    if nEntriesCache == 0
        return 0.0
    else
        return nEntries / nEntriesCache
    end

end

function allocationsFailed(ell::DynamicalELL)

    return allocationsFailed(ell._coo)

end

function synchronize(ell::DynamicalELL)

    # ELL doesn't maintain a free list like COO
    # Just synchronize the overflow COO storage
    synchronize(ell._coo)

    return
end

function dropzeros!(ell::DynamicalELL)

    @kernel function kernel_dropzeros_ell!(
            cols,
            values,
            nEntries
        )
        
        i = @index(Global)

        # If value is 0 but column is set, clear the entry
        if values[i] == 0 && cols[i] != 0
            cols[i] = 0
            Atomix.@atomic nEntries[1] -= 1
        end

    end

    CellBasedModels.synchronize(ell)

    backend = KernelAbstractions.get_backend(ell)
    threads = backend === CPU() ? Threads.nthreads() : 256
    kernel_dropzeros_ell!(backend, threads)(ell._cols, ell._values, ell._NEntries, ndrange = length(ell))

    # Also drop zeros from the overflow COO
    CellBasedModels.dropzeros!(ell._coo)

    return

end

function preallocate!(ell::DynamicalELL; n_rows::Int=0, n_cols::Int=0)
    """
    Preallocate additional rows or columns in the ELL structure.
    
    Arguments:
    - n_rows: Number of new rows to add
    - n_cols: Number of new columns per row to add (will expand ALL rows)
    
    Note: Unlike CSR, adding columns expands ALL existing rows to maintain fixed column count.
    """

    @kernel function kernel_copy_expand!(oldValues, oldCols, newValues, newCols, oldColsPerRow, newColsPerRow)
        row = @index(Global)
        
        oldStartIdx = (row - 1) * oldColsPerRow + 1
        newStartIdx = (row - 1) * newColsPerRow + 1
        
        for k in 0:(oldColsPerRow - 1)
            newValues[newStartIdx + k] = oldValues[oldStartIdx + k]
            newCols[newStartIdx + k] = oldCols[oldStartIdx + k]
        end
    end

    @assert n_rows >= 0 "n_rows must be >= 0"
    @assert n_cols >= 0 "n_cols must be >= 0"

    if n_rows == 0 && n_cols == 0
        return
    end

    # Current sizes
    currentNRows = getDeviceIndex(ell._nRows)
    currentColsPerRow = getDeviceIndex(ell._nColsPerRow)
    nEntriesCache = numberOfEntriesCache(ell)

    # New sizes
    newNRows = currentNRows + n_rows
    newColsPerRow = currentColsPerRow + n_cols
    nEntriesCacheNew = newNRows * newColsPerRow

    # Get backend
    backend = KernelAbstractions.get_backend(ell)
    threads = backend === CPU() ? Threads.nthreads() : 256

    if n_cols > 0 && currentNRows > 0
        # Need to expand existing rows - copy old data to new layout using kernel
        oldValues = copy(ell._values)
        oldCols = copy(ell._cols)
        
        # Create new arrays (not resize, to avoid issues)
        newValues = toBackend(backend, zeros(eltype(ell._values), nEntriesCacheNew))
        newCols = toBackend(backend, zeros(Int, nEntriesCacheNew))
        
        # Copy existing data with new layout using kernel
        kernel_copy_expand!(backend, threads)(
            oldValues, oldCols, newValues, newCols, 
            currentColsPerRow, newColsPerRow,
            ndrange = currentNRows
        )
        KernelAbstractions.synchronize(backend)
        
        # Replace arrays
        resize!(ell._values, nEntriesCacheNew)
        resize!(ell._cols, nEntriesCacheNew)
        ell._values .= newValues
        ell._cols .= newCols
        
        # Update dimensions
        setDeviceIndex!(ell._nColsPerRow, newColsPerRow)
        setDeviceIndex!(ell._nRows, newNRows)
    else
        # Just adding rows, no column expansion needed
        resize!(ell._cols, nEntriesCacheNew)
        resize!(ell._values, nEntriesCacheNew)

        # Initialize new entries to zero
        @views ell._cols[nEntriesCache+1:end] .= 0
        @views ell._values[nEntriesCache+1:end] .= 0
        
        setDeviceIndex!(ell._nRows, newNRows)
        if newColsPerRow > currentColsPerRow
            setDeviceIndex!(ell._nColsPerRow, newColsPerRow)
        end
    end

    # Update cache counter
    setDeviceIndex!(ell._NEntriesCache, nEntriesCacheNew)

    return

end

function compact!(ell::DynamicalELL)
    """
    Compact the ELL structure by removing empty entries (where cols[k] == 0)
    within each row. Entries are compacted to the front of each row's allocated space.
    Also compacts the overflow COO.
    """

    @kernel function kernel_compact_row!(values, cols, nRows, nColsPerRow)
        row = @index(Global)
        
        startIdx = (row - 1) * nColsPerRow[1] + 1
        endIdx = row * nColsPerRow[1]
        
        # Compact entries within this row
        writePos = startIdx
        for k in startIdx:endIdx
            if cols[k] != 0
                if writePos != k
                    cols[writePos] = cols[k]
                    values[writePos] = values[k]
                    cols[k] = 0
                    values[k] = zero(eltype(values))
                end
                writePos += 1
            end
        end
    end

    backend = KernelAbstractions.get_backend(ell)
    threads = backend === CPU() ? Threads.nthreads() : 256

    nRows = getDeviceIndex(ell._nRows)
    
    if nRows > 0
        kernel_compact_row!(backend, threads)(ell._values, ell._cols, ell._nRows, ell._nColsPerRow, ndrange = nRows)
        KernelAbstractions.synchronize(backend)
    end

    # Reset overflow counter
    setDeviceIndex!(ell._NOverflowInsert, 0)

    # Also compact the overflow COO
    compact!(ell._coo)

    return

end

function compactto!(ellTarget::DynamicalELL{P, T}, ell::DynamicalELL{P, T}) where {P, T}
    """
    Copy source ELL into target ELL, compacting entries within each row.
    """

    @kernel function kernel_compact_row_to!(srcValues, srcCols, dstValues, dstCols, nRowsSrc, nColsPerRowSrc)
        row = @index(Global)
        
        startIdx = (row - 1) * nColsPerRowSrc[1] + 1
        endIdx = row * nColsPerRowSrc[1]
        
        # Compact entries within this row
        writePos = startIdx
        for k in startIdx:endIdx
            if srcCols[k] != 0
                dstCols[writePos] = srcCols[k]
                dstValues[writePos] = srcValues[k]
                writePos += 1
            end
        end
        # Zero out remaining positions in the row
        for k in writePos:endIdx
            dstCols[k] = 0
            dstValues[k] = zero(eltype(dstValues))
        end
    end

    backend = KernelAbstractions.get_backend(ell)
    threads = backend === CPU() ? Threads.nthreads() : 256

    nOldEntries = length(ell)
    
    # Ensure target has enough space
    if length(ellTarget) < nOldEntries
        resize!(ellTarget._values, nOldEntries)
        resize!(ellTarget._cols, nOldEntries)
    end

    nRows = getDeviceIndex(ell._nRows)
    
    # Copy dimensions
    ellTarget._nRows .= ell._nRows
    ellTarget._nColsPerRow .= ell._nColsPerRow
    
    if nRows > 0
        kernel_compact_row_to!(backend, threads)(
            ell._values, ell._cols, ellTarget._values, ellTarget._cols, ell._nRows, ell._nColsPerRow,
            ndrange = nRows
        )
        KernelAbstractions.synchronize(backend)
    end

    # Copy counters
    ellTarget._NEntries .= ell._NEntries
    ellTarget._NEntriesCache .= ell._NEntriesCache
    ellTarget._NEntriesNonzero .= ell._NEntriesNonzero
    setDeviceIndex!(ellTarget._NOverflowInsert, 0)

    # Compact overflow COO to target
    compactto!(ellTarget._coo, ell._coo)

    return

end

function Base.similar(ell::DynamicalELL)

    dtype = eltype(ell._values)
    n_entries = length(ell)
    n_coo = length(ell._coo)

    backend = KernelAbstractions.get_backend(ell)

    _values = toBackend(backend, Array{dtype}(undef, n_entries))
    _cols = toBackend(backend, Array{Int}(undef, n_entries))
    _nRows = toBackend(backend, Array{Int}(undef, 1))
    _nColsPerRow = toBackend(backend, Array{Int}(undef, 1))
    _NEntries = toBackend(backend, Array{Int}(undef, 1))
    _NEntriesCache = toBackend(backend, Array{Int}(undef, 1))
    _NEntriesNonzero = toBackend(backend, Array{Int}(undef, 1))
    _NOverflowInsert = toBackend(backend, Array{Int}(undef, 1))

    # Create similar COO for overflow storage
    _coo = similar(ell._coo)

    return DynamicalELL(
            _values,
            _cols,

            _nRows,
            _nColsPerRow,

            _NEntries,
            _NEntriesCache,
            _NEntriesNonzero,
            _NOverflowInsert,

            _coo
        )

end

function Base.copy(ell::DynamicalELL)

    ellCopy = similar(ell)
    copyto!(ellCopy, ell)

    return ellCopy

end

function Base.copyto!(dest::DynamicalELL{P, T}, src::DynamicalELL{P, T}) where {P, T}

    lsrc = length(src)
    ldst = length(dest)
    
    # Resize if needed
    if ldst < lsrc
        resize!(dest._values, lsrc)
        resize!(dest._cols, lsrc)
    end

    biggerdst = ldst > lsrc
    if biggerdst
        @views(dest._values[1:lsrc]) .= src._values
        @views(dest._values[lsrc+1:end]) .= 0
        @views(dest._cols[1:lsrc]) .= src._cols
        @views(dest._cols[lsrc+1:end]) .= 0
    else
        dest._values .= src._values
        dest._cols .= src._cols
    end
    dest._nRows .= src._nRows
    dest._nColsPerRow .= src._nColsPerRow
    dest._NEntries .= src._NEntries
    dest._NEntriesCache .= src._NEntriesCache
    dest._NEntriesNonzero .= src._NEntriesNonzero
    dest._NOverflowInsert .= src._NOverflowInsert

    # Copy the overflow COO
    copyto!(dest._coo, src._coo)

    return dest

end

function dropcache!(ell::DynamicalELL)
    """
    Drop unused cache from the ELL structure by compacting and 
    reducing columns per row to the maximum used in any row.
    """

    backend = KernelAbstractions.get_backend(ell)
    
    # Get arrays on CPU for rebuilding
    cols_cpu = Array(ell._cols)
    values_cpu = Array(ell._values)
    nRows = getDeviceIndex(ell._nRows)
    nColsPerRow = getDeviceIndex(ell._nColsPerRow)
    
    # Count surviving entries per row and find max used
    maxUsedCols = 0
    entriesPerRow = zeros(Int, nRows)
    for row in 1:nRows
        startIdx = (row - 1) * nColsPerRow + 1
        endIdx = row * nColsPerRow
        count = 0
        for k in startIdx:endIdx
            if cols_cpu[k] != 0
                count += 1
            end
        end
        entriesPerRow[row] = count
        maxUsedCols = max(maxUsedCols, count)
    end
    
    if maxUsedCols == 0
        maxUsedCols = 1  # Keep at least 1 column per row
    end
    
    nSurviving = nRows * maxUsedCols
    
    # Build compacted arrays with new layout
    newCols = zeros(Int, nSurviving)
    newValues = zeros(eltype(values_cpu), nSurviving)
    
    for row in 1:nRows
        oldStartIdx = (row - 1) * nColsPerRow + 1
        oldEndIdx = row * nColsPerRow
        newStartIdx = (row - 1) * maxUsedCols + 1
        
        writePos = newStartIdx
        for k in oldStartIdx:oldEndIdx
            if cols_cpu[k] != 0
                newCols[writePos] = cols_cpu[k]
                newValues[writePos] = values_cpu[k]
                writePos += 1
            end
        end
    end
    
    # Resize and copy back
    resize!(ell._cols, nSurviving)
    resize!(ell._values, nSurviving)
    
    ell._cols .= toBackend(backend, newCols)
    ell._values .= toBackend(backend, newValues)

    # Update counters
    totalEntries = sum(entriesPerRow)
    setDeviceIndex!(ell._nColsPerRow, maxUsedCols)
    setDeviceIndex!(ell._NEntries, totalEntries)
    setDeviceIndex!(ell._NEntriesCache, nSurviving)
    setDeviceIndex!(ell._NEntriesNonzero, totalEntries)
    setDeviceIndex!(ell._NOverflowInsert, 0)

    # Drop cache from the overflow COO as well
    dropcache!(ell._coo)

    return

end

function dropcacheto!(ellTarget::DynamicalELL{P, T}, ell::DynamicalELL{P, T}) where {P, T}
    """
    Drop unused cache from ell and copy compacted version to ellTarget.
    """
    
    backend = KernelAbstractions.get_backend(ell)
    
    # Get arrays on CPU for rebuilding
    cols_cpu = Array(ell._cols)
    values_cpu = Array(ell._values)
    nRows = getDeviceIndex(ell._nRows)
    nColsPerRow = getDeviceIndex(ell._nColsPerRow)
    
    # Count surviving entries per row and find max used
    maxUsedCols = 0
    entriesPerRow = zeros(Int, nRows)
    for row in 1:nRows
        startIdx = (row - 1) * nColsPerRow + 1
        endIdx = row * nColsPerRow
        count = 0
        for k in startIdx:endIdx
            if cols_cpu[k] != 0
                count += 1
            end
        end
        entriesPerRow[row] = count
        maxUsedCols = max(maxUsedCols, count)
    end
    
    if maxUsedCols == 0
        maxUsedCols = 1
    end
    
    nSurviving = nRows * maxUsedCols
    
    # Build compacted arrays with new layout
    newCols = zeros(Int, nSurviving)
    newValues = zeros(eltype(values_cpu), nSurviving)
    
    for row in 1:nRows
        oldStartIdx = (row - 1) * nColsPerRow + 1
        oldEndIdx = row * nColsPerRow
        newStartIdx = (row - 1) * maxUsedCols + 1
        
        writePos = newStartIdx
        for k in oldStartIdx:oldEndIdx
            if cols_cpu[k] != 0
                newCols[writePos] = cols_cpu[k]
                newValues[writePos] = values_cpu[k]
                writePos += 1
            end
        end
    end
    
    # Resize target and copy
    resize!(ellTarget._cols, nSurviving)
    resize!(ellTarget._values, nSurviving)
    
    ellTarget._cols .= toBackend(backend, newCols)
    ellTarget._values .= toBackend(backend, newValues)

    # Update target counters
    totalEntries = sum(entriesPerRow)
    setDeviceIndex!(ellTarget._nRows, nRows)
    setDeviceIndex!(ellTarget._nColsPerRow, maxUsedCols)
    setDeviceIndex!(ellTarget._NEntries, totalEntries)
    setDeviceIndex!(ellTarget._NEntriesCache, nSurviving)
    setDeviceIndex!(ellTarget._NEntriesNonzero, totalEntries)
    setDeviceIndex!(ellTarget._NOverflowInsert, 0)

    # Drop cache from the overflow COO as well
    dropcacheto!(ellTarget._coo, ell._coo)

    return

end

function remaprows!(ell::DynamicalELL, rowmap::AbstractVector{Int})
    """
    Physically reorder rows in the ELL structure according to rowmap.
    rowmap[newRow] = oldRow means new row newRow gets data from old row oldRow.
    """

    @kernel function kernel_remap_rows!(values, cols, newValues, newCols, nColsPerRow, rowmap)
        newRow = @index(Global)
        
        oldRow = rowmap[newRow]
        
        # Get old and new row ranges
        nCols = nColsPerRow[1]
        oldStart = (oldRow - 1) * nCols + 1
        newStart = (newRow - 1) * nCols + 1
        
        # Copy entries from old row to new position
        for k in 0:(nCols - 1)
            newValues[newStart + k] = values[oldStart + k]
            newCols[newStart + k] = cols[oldStart + k]
        end
    end
    
    backend = KernelAbstractions.get_backend(ell)
    threads = backend === CPU() ? Threads.nthreads() : 256
    
    nRows = getDeviceIndex(ell._nRows)
    rowmap_cpu = Array(rowmap)
    
    @assert length(rowmap_cpu) == nRows "rowmap length must equal number of rows"
    
    # Create temporary arrays on device for reordered data
    newValues = similar(ell._values)
    newCols = similar(ell._cols)
    rowmap_backend = toBackend(backend, rowmap_cpu)
    
    # Run kernel to copy entries
    kernel_remap_rows!(backend, threads)(
        ell._values, ell._cols, newValues, newCols,
        ell._nColsPerRow, rowmap_backend,
        ndrange = nRows
    )
    KernelAbstractions.synchronize(backend)
    
    # Copy reordered data back
    ell._values .= newValues
    ell._cols .= newCols
    
    # Also remap the overflow COO
    remaprows!(ell._coo, rowmap)
    
    return

end

function remapcols!(ell::DynamicalELL, colmap::AbstractVector{Int})
    """
    Remap column indices in the ELL structure.
    """

    @kernel function kernel_remap_cols!(cols, colmap)
        
        i = @index(Global)
        
        if cols[i] != 0
            oldCol = cols[i]
            if oldCol <= length(colmap)
                cols[i] = colmap[oldCol]
            else
                @print "Column index $oldCol out of bounds for colmap of length $(length(colmap))\n"
            end
        end
        
    end
    
    colmap_backend = toBackend(KernelAbstractions.get_backend(ell), colmap)

    backend = KernelAbstractions.get_backend(ell)
    threads = backend === CPU() ? Threads.nthreads() : 256
    kernel_remap_cols!(backend, threads)(ell._cols, colmap_backend, ndrange = length(ell))
    
    # Also remap columns in overflow COO
    remapcols!(ell._coo, colmap)
    
    return

end

function remap!(ell::DynamicalELL, rowmap::AbstractVector{Int}, colmap::AbstractVector{Int})
    """
    Remap both rows and columns in a single pass.
    Physically reorders rows and remaps column indices together.
    """

    @kernel function kernel_remap!(values, cols, newValues, newCols, nColsPerRow, rowmap, colmap)
        newRow = @index(Global)
        
        oldRow = rowmap[newRow]
        
        # Get old and new row ranges
        nCols = nColsPerRow[1]
        oldStart = (oldRow - 1) * nCols + 1
        newStart = (newRow - 1) * nCols + 1
        
        # Copy entries from old row to new position and remap columns
        for k in 0:(nCols - 1)
            newValues[newStart + k] = values[oldStart + k]
            oldCol = cols[oldStart + k]
            if oldCol != 0 && oldCol <= length(colmap)
                newCols[newStart + k] = colmap[oldCol]
            else
                newCols[newStart + k] = oldCol
            end
        end
    end
    
    backend = KernelAbstractions.get_backend(ell)
    threads = backend === CPU() ? Threads.nthreads() : 256
    
    nRows = getDeviceIndex(ell._nRows)
    rowmap_cpu = Array(rowmap)
    
    @assert length(rowmap_cpu) == nRows "rowmap length must equal number of rows"
    
    # Create temporary arrays on device for reordered data
    newValues = similar(ell._values)
    newCols = similar(ell._cols)
    rowmap_backend = toBackend(backend, rowmap_cpu)
    colmap_backend = toBackend(backend, colmap)
    
    # Run kernel to copy entries and remap columns
    kernel_remap!(backend, threads)(
        ell._values, ell._cols, newValues, newCols,
        ell._nColsPerRow, rowmap_backend, colmap_backend,
        ndrange = nRows
    )
    KernelAbstractions.synchronize(backend)
    
    # Copy reordered data back
    ell._values .= newValues
    ell._cols .= newCols
    
    # Also remap the overflow COO
    remap!(ell._coo, rowmap, colmap)
    
    return

end

###################################################################################################
# Platform adaptation
###################################################################################################

KernelAbstractions.get_backend(ell::DynamicalELL) = KernelAbstractions.get_backend(ell._values)

toBackend(::KernelAbstractions.CPU, ell::DynamicalELL{P}) where {P<:KernelAbstractions.CPU} = ell

function toBackend(::KernelAbstractions.CPU, ell::DynamicalELL{P, T}) where {P<:KernelAbstractions.GPU, T}
    DynamicalELL(
        Vector(ell._values),
        Vector(ell._cols),
        Vector(ell._nRows),
        Vector(ell._nColsPerRow),
        Vector(ell._NEntries),
        Vector(ell._NEntriesCache),
        Vector(ell._NEntriesNonzero),
        Vector(ell._NOverflowInsert),
        toBackend(CPU(), ell._coo)
    )
end
    
toBackend(::KernelAbstractions.GPU, ell::DynamicalELL{P}) where {P<:KernelAbstractions.GPU} = ell

function toBackend(backend::KernelAbstractions.GPU, ell::DynamicalELL{P}) where {P<:KernelAbstractions.CPU}
    DynamicalELL(
        toBackend(backend, ell._values),
        toBackend(backend, ell._cols),
        toBackend(backend, ell._nRows),
        toBackend(backend, ell._nColsPerRow),
        toBackend(backend, ell._NEntries),
        toBackend(backend, ell._NEntriesCache),
        toBackend(backend, ell._NEntriesNonzero),
        toBackend(backend, ell._NOverflowInsert),
        toBackend(backend, ell._coo)
    )
end
