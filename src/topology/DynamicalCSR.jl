######################################################################################################
# DynamicalCSR - Fixed-size tuples (block size is a type parameter)
######################################################################################################
struct DynamicalCSR{
            P, T, V, I, COO
        } <: AbstractSparseMatrix

    _values::V
    _cols::I

    _rowOffsets::I 

    _NEntries::I
    _NEntriesCache::I
    _NEntriesNonzero::I
    _NOverflowInsert::I

    _coo::COO
end
Adapt.@adapt_structure DynamicalCSR

function DynamicalCSR(
        _values,
        _cols,

        _rowOffsets,

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

    DynamicalCSR{
            P, T, V, I, COO
        }(
            _values,
            _cols,

            _rowOffsets,

            _NEntries,
            _NEntriesCache,
            _NEntriesNonzero,
            _NOverflowInsert,

            _coo
        )
end

function dcsr_zeros(dtype::DataType, n_rows::Int=0, n_cols::Union{Int, Vector}=0, n_coo::Int=0)

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

    _NEntries = zeros(Int, 1)
    _NEntriesCache = Int[n_entries]
    _NEntriesNonzero = zeros(Int, 1)
    _NOverflowInsert = zeros(Int, 1)

    _coo = dcoo_zeros(dtype, n_coo)

    DynamicalCSR(
            _values,
            _cols,

            _rowOffsets,

            _NEntries,
            _NEntriesCache,
            _NEntriesNonzero,
            _NOverflowInsert,

            _coo
        )
end

function dcsr_zeros(n_rows::Int=0, n_cols::Union{Int, Vector}=0, n_coo::Int=0)
    dcsr_zeros(Float64, n_rows, n_cols, n_coo)
end

function Base.show(io::IO, x::DynamicalCSR{P, T}) where {P, T}
    
    nrows = numberOfRows(x)
    ncols = numberOfCols(x)
    nentries = numberOfEntries(x)
    
    println(io, "DynamicalCSR{$T} with $(nentries) stored entries")
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

function Base.show(io::IO, x::Type{DynamicalCSR{P, T, V, I}}) where {P, T, V, I}
    println(io, "DynamicalCSR{$P, $T, $V, $I}")
end

Base.length(csr::DynamicalCSR{P}) where {P} = length(csr._values)
@inline numberOfEntries(csr::DynamicalCSR{P}) where {P} = @inbounds csr._NEntries[1] + numberOfEntries(csr._coo)
@inline numberOfEntriesCache(csr::DynamicalCSR{P}) where {P} = @inbounds csr._NEntriesCache[1]  # CSR cache only
@inline numberOfEntriesNonzero(csr::DynamicalCSR{P}) where {P} = @inbounds csr._NEntriesNonzero[1] + numberOfEntriesNonzero(csr._coo)
numberOfRows(csr::DynamicalCSR{P}) where {P} = max(numberOfRows(csr._coo), length(csr._rowOffsets)-1)
numberOfCols(csr::DynamicalCSR{P}) where {P} = max(maximum(csr._cols), numberOfCols(csr._coo))

"""
    todense(csr::DynamicalCSR)

Convert the sparse CSR matrix to a dense matrix.
Returns a dense matrix of size (nRows, nCols) with all stored entries filled in.
Includes entries from both the CSR portion and the overflow COO.
"""
function todense(csr::DynamicalCSR{P, T}) where {P, T}
    nRows = numberOfRows(csr)
    nCols = numberOfCols(csr)
    
    # Create dense matrix on CPU
    dense = zeros(T, nRows, nCols)
    
    # Copy CSR data to CPU for iteration
    cols = Array(csr._cols)
    values = Array(csr._values)
    rowOffsets = Array(csr._rowOffsets)
    
    # Fill from CSR portion
    csrRows = length(rowOffsets) - 1
    for i in 1:csrRows
        startIdx = rowOffsets[i]
        endIdx = rowOffsets[i+1] - 1
        for k in startIdx:endIdx
            j = cols[k]
            if j > 0
                dense[i, j] = values[k]
            end
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
# Row iteration support
######################################################################################################

"""
    CSRRowIterator{V, I}

Iterator struct for iterating over entries in a specific row of a DynamicalCSR matrix.
GPU and CPU compatible for use inside kernels.

Fields:
- `row`: The row index being iterated
- `_cols`: Reference to the column indices array
- `_values`: Reference to the values array
- `_startIdx`: Starting index in the CSR arrays for this row
- `_endIdx`: Ending index in the CSR arrays for this row

Usage in a kernel:
```julia
iter = iterateRow(csr, i)
for k in iter._startIdx:iter._endIdx
    col, val = iter._cols[k], iter._values[k]
    if col > 0  # entry exists
        # process col, val...
    end
end
```
"""
struct CSRRowIterator{V, I}
    row::Int
    _cols::I
    _values::V
    _startIdx::Int
    _endIdx::Int
end
Adapt.@adapt_structure CSRRowIterator

"""
    iterateRow(csr::DynamicalCSR, i::Int)

Create an iterator for traversing all entries in row `i` of the CSR matrix.
Returns a `CSRRowIterator` struct that can be used inside GPU/CPU kernels.

For CSR format, each row has a contiguous range of entries determined by rowOffsets.
Use the iterator as:

```julia
iter = iterateRow(csr, i)
for k in iter._startIdx:iter._endIdx
    col = iter._cols[k]
    val = iter._values[k]
    if col > 0  # entry exists
        # ... process entry
    end
end
```

Note: This only iterates over the CSR portion. Entries in the overflow COO
are not included. Use `iterateRow(csr._coo, i)` to iterate overflow entries.
"""
@inline function iterateRow(csr::DynamicalCSR, i::Int)
    nRows = length(csr._rowOffsets) - 1
    if i <= 0 || i > nRows
        # Return empty iterator for out-of-bounds rows
        return CSRRowIterator(i, csr._cols, csr._values, 1, 0)
    end
    startIdx = csr._rowOffsets[i]
    endIdx = csr._rowOffsets[i+1] - 1
    return CSRRowIterator(i, csr._cols, csr._values, startIdx, endIdx)
end

"""
    getentry(iter::CSRRowIterator, k::Int)

Get the (col, value) entry at position k in the CSR arrays.
Returns `(col, value)` tuple.
"""
@inline function getentry(iter::CSRRowIterator, k::Int)
    return (iter._cols[k], iter._values[k])
end

"""
    Base.length(iter::CSRRowIterator)

Return the number of slots in this row (may include empty slots where col == 0).
"""
@inline function Base.length(iter::CSRRowIterator)
    return max(0, iter._endIdx - iter._startIdx + 1)
end

# Standard Julia iteration protocol for CSRRowIterator
# Returns column indices only (skipping empty slots where col == 0)
@inline function Base.iterate(iter::CSRRowIterator)
    k = iter._startIdx
    while k <= iter._endIdx
        col = iter._cols[k]
        if col > 0  # valid entry
            return (col, k + 1)
        end
        k += 1
    end
    return nothing
end

@inline function Base.iterate(iter::CSRRowIterator, k::Int)
    while k <= iter._endIdx
        col = iter._cols[k]
        if col > 0  # valid entry
            return (col, k + 1)
        end
        k += 1
    end
    return nothing
end

"""
    getRow(csr::DynamicalCSR, row::Int, ::Val{N})

Get all values in a row as a tuple of N elements.
Returns the values at columns 1, 2, ... N in order.
If the row has fewer than N entries, returns 0 for missing values.

The size N must be provided as a Val{N} type parameter for GPU compatibility.

Example:
```julia
(n1, n2) = getRow(edge_to_node, edge_idx, Val(2))
```
"""
@inline function getRow(csr::DynamicalCSR{P, T}, row::Int, ::Val{N}) where {P, T, N}
    startIdx = csr._rowOffsets[row]
    endIdx = csr._rowOffsets[row + 1] - 1
    rowSize = endIdx - startIdx + 1
    return ntuple(i -> i <= rowSize ? @inbounds(csr._values[startIdx + i - 1]) : zero(T), Val(N))
end

"""
    setindex!(csr::DynamicalCSR, value, i::Int, j::Int)

Set the value at position (i, j) in the sparse matrix.
Allows syntax: x[i,j] = value
"""
function Base.setindex!(csr::DynamicalCSR, value, i::Int, j::Int)

    if i <= 0 || j <= 0
        @print "Indices must be positive integers."
    end

    # Search in csr
    if i < length(csr._rowOffsets)
        startIdx = csr._rowOffsets[i]
        endIdx = csr._rowOffsets[i+1] - 1
        # Loop if found
        for k in startIdx:endIdx
            if csr._cols[k] == j
                old = csr._values[k]
                if old == 0 && value != 0
                    Atomix.@atomic csr._NEntriesNonzero[1] += 1
                elseif old != 0 && value == 0
                    Atomix.@atomic csr._NEntriesNonzero[1] -= 1
                end
                csr._values[k] = value
                return false
            end
        end
        # Loop not found, add new
        for k in startIdx:endIdx
            if csr._cols[k] == 0
                result = Atomix.@atomicreplace csr._cols[k] 0 => j
                if result.success
                    csr._values[k] = value
                    if value != 0
                        Atomix.@atomic csr._NEntriesNonzero[1] += 1
                    end
                    Atomix.@atomic csr._NEntries[1] += 1
                end
                return true
            end
        end
    end

    # Not found, add new at coo
    Atomix.@atomic csr._NOverflowInsert[1] += 1

    return setindex!(csr._coo, value, i, j)

end

function Base.setindex!(csr::DynamicalCSR{P}, ::Nothing, i::Int, j::Int) where {P<:CPU}

    # Search in CSR portion using row offsets
    if i > 0 && i < length(csr._rowOffsets)
        startIdx = csr._rowOffsets[i]
        endIdx = csr._rowOffsets[i+1] - 1
        for k in startIdx:endIdx
            if csr._cols[k] == j
                if csr._values[k] != zero(eltype(csr._values))
                    Atomix.@atomic csr._NEntriesNonzero[1] -= 1
                end
                csr._cols[k] = 0
                csr._values[k] = zero(eltype(csr._values))
                Atomix.@atomic csr._NEntries[1] -= 1
                return true
            end
        end
    end
    
    # Also search and remove from overflow COO
    setindex!(csr._coo, nothing, i, j)
    
    return false

end

function Base.setindex!(csr::DynamicalCSR{P}, ::Nothing, i::Int, j::Int) where {P<:GPU}

    # Search in CSR portion using row offsets
    if i > 0 && i < length(csr._rowOffsets)
        startIdx = csr._rowOffsets[i]
        endIdx = csr._rowOffsets[i+1] - 1
        for k in startIdx:endIdx
            if csr._cols[k] == j
                if csr._values[k] != zero(eltype(csr._values))
                    Atomix.@atomic csr._NEntriesNonzero[1] -= 1
                end
                csr._cols[k] = 0
                csr._values[k] = zero(eltype(csr._values))
                Atomix.@atomic csr._NEntries[1] -= 1
                return true
            end
        end
    end
    
    # Also search and remove from overflow COO
    setindex!(csr._coo, nothing, i, j)
    
    return false

end

"""
    getindex(csr::DynamicalCSR, i::Int, j::Int)

Get the value at position (i, j) in the sparse matrix.
Returns 0 if the entry does not exist.
Allows syntax: value = x[i,j]
"""
function Base.getindex(csr::DynamicalCSR{P, T}, i::Int, j::Int) where {P, T}

    # Search in CSR portion using row offsets
    if i > 0 && i < length(csr._rowOffsets)
        startIdx = csr._rowOffsets[i]
        endIdx = csr._rowOffsets[i+1] - 1
        for k in startIdx:endIdx
            if csr._cols[k] == j
                return csr._values[k]
            end
        end
    end
    
    # Also check overflow COO
    val = csr._coo[i, j]
    if val != zero(T)
        return val
    end
    
    # Not found, return zero
    return zero(T)
end

function _getindex(csr::DynamicalCSR, i::Int, j::Int)

    # Search in CSR portion using row offsets
    if i > 0 && i < length(csr._rowOffsets)
        startIdx = csr._rowOffsets[i]
        endIdx = csr._rowOffsets[i+1] - 1
        for k in startIdx:endIdx
            if csr._cols[k] == j
                return csr._values[k]
            end
        end
    end
    
    # Also check overflow COO
    val = _getindex(csr._coo, i, j)
    if val !== nothing
        return val
    end
    
    # Not found
    return nothing
end

"""
    replaceIndex!(csr::DynamicalCSR, i_old::Int, j_old::Int, i_new::Int, j_new::Int)

Replace the indices of an existing entry in-place without removing and re-adding.
Finds the entry at (i_old, j_old) and changes its indices to (i_new, j_new), keeping the value.
Returns true if the entry was found and replaced, false otherwise.

If the row stays the same (i_old == i_new), only the column index is changed in place,
which is very efficient. If the row changes, the function removes from the old row and
adds to the new row (which may overflow to COO if the new row is full).

This is more efficient than `csr[i_new, j_new] = csr[i_old, j_old]; csr[i_old, j_old] = nothing`
because it avoids the overhead of separate removal and insertion operations.
"""
function replaceIndex!(csr::DynamicalCSR, i_old::Int, j_old::Int, i_new::Int, j_new::Int)

    if i_old <= 0 || j_old <= 0 || i_new <= 0 || j_new <= 0
        @print "Indices must be positive integers."
        return false
    end

    # Search in CSR portion
    if i_old > 0 && i_old < length(csr._rowOffsets)
        startIdx = csr._rowOffsets[i_old]
        endIdx = csr._rowOffsets[i_old+1] - 1
        for k in startIdx:endIdx
            if csr._cols[k] == j_old
                # Found entry
                if i_old == i_new
                    # Same row - just change column in place (efficient!)
                    csr._cols[k] = j_new
                    return true
                else
                    # Different row - need to remove and re-add
                    value = csr._values[k]
                    # Remove from old position
                    if value != zero(eltype(csr._values))
                        Atomix.@atomic csr._NEntriesNonzero[1] -= 1
                    end
                    csr._cols[k] = 0
                    csr._values[k] = zero(eltype(csr._values))
                    Atomix.@atomic csr._NEntries[1] -= 1
                    # Add to new position (may overflow to COO)
                    setindex!(csr, value, i_new, j_new)
                    return true
                end
            end
        end
    end

    # Also search in overflow COO
    return replaceIndex!(csr._coo, i_old, j_old, i_new, j_new)
end

"""
    replaceIndex!(csr::DynamicalCSR, i::Int, j_old::Int, j_new::Int)

Replace the column index of an existing entry in-place, keeping the same row.
Shorthand for `replaceIndex!(csr, i, j_old, i, j_new)`.
Returns true if the entry was found and replaced, false otherwise.

This is the most efficient form as it only changes the column index without
any structural changes to the CSR format.
"""
function replaceIndex!(csr::DynamicalCSR, i::Int, j_old::Int, j_new::Int)
    return replaceIndex!(csr, i, j_old, i, j_new)
end

"""
    setindex!(csr::DynamicalCSR, value, i::Int, ::Colon)

Set all entries in row i to value.
Allows syntax: csr[i,:] = value
"""
function Base.setindex!(csr::DynamicalCSR, value, i::Int, ::Colon)

    # Set in CSR portion
    if i > 0 && i < length(csr._rowOffsets)
        startIdx = csr._rowOffsets[i]
        endIdx = csr._rowOffsets[i+1] - 1
        for k in startIdx:endIdx
            if csr._cols[k] != 0
                old = csr._values[k]
                if old == 0 && value != 0
                    Atomix.@atomic csr._NEntriesNonzero[1] += 1
                elseif old != 0 && value == 0
                    Atomix.@atomic csr._NEntriesNonzero[1] -= 1
                end
                csr._values[k] = value
            end
        end
    end
    
    # Also set in overflow COO
    csr._coo[i, :] = value

    return
end

"""
    setindex!(csr::DynamicalCSR, value, ::Colon, j::Int)

Set all entries in column j to value.
Allows syntax: csr[:,j] = value
"""
function Base.setindex!(csr::DynamicalCSR, value, ::Colon, j::Int)

    # Set in CSR portion - must scan all entries
    nEntries = length(csr)
    for k in 1:nEntries
        if csr._cols[k] == j
            old = csr._values[k]
            if old == 0 && value != 0
                Atomix.@atomic csr._NEntriesNonzero[1] += 1
            elseif old != 0 && value == 0
                Atomix.@atomic csr._NEntriesNonzero[1] -= 1
            end
            csr._values[k] = value
        end
    end
    
    # Also set in overflow COO
    csr._coo[:, j] = value

    return
end

"""
    setindex!(csr::DynamicalCSR, ::Nothing, i::Int, ::Colon)

Remove all entries in row i.
Allows syntax: csr[i,:] = nothing
"""
function Base.setindex!(csr::DynamicalCSR, ::Nothing, i::Int, ::Colon)

    # Remove in CSR portion
    if i > 0 && i < length(csr._rowOffsets)
        startIdx = csr._rowOffsets[i]
        endIdx = csr._rowOffsets[i+1] - 1
        for k in startIdx:endIdx
            if csr._cols[k] != 0
                if csr._values[k] != zero(eltype(csr._values))
                    Atomix.@atomic csr._NEntriesNonzero[1] -= 1
                end
                csr._cols[k] = 0
                csr._values[k] = zero(eltype(csr._values))
                Atomix.@atomic csr._NEntries[1] -= 1
            end
        end
    end
    
    # Also remove from overflow COO
    csr._coo[i, :] = nothing

    return
end

"""
    setindex!(csr::DynamicalCSR, ::Nothing, ::Colon, j::Int)

Remove all entries in column j.
Allows syntax: csr[:,j] = nothing
"""
function Base.setindex!(csr::DynamicalCSR, ::Nothing, ::Colon, j::Int)

    # Remove in CSR portion - must scan all entries
    nEntries = length(csr)
    for k in 1:nEntries
        if csr._cols[k] == j
            if csr._values[k] != zero(eltype(csr._values))
                Atomix.@atomic csr._NEntriesNonzero[1] -= 1
            end
            csr._cols[k] = 0
            csr._values[k] = zero(eltype(csr._values))
            Atomix.@atomic csr._NEntries[1] -= 1
        end
    end
    
    # Also remove from overflow COO
    csr._coo[:, j] = nothing

    return
end

function overflow(csr::DynamicalCSR)

    return overflowEntries(csr) > 0

end

function overflowEntries(csr::DynamicalCSR)

    return getDeviceIndex(csr._NOverflowInsert) > 0

end

function overflowRows(csr::DynamicalCSR)

    return overflowEntries(csr)

end

function allocationRatio(csr::DynamicalCSR)

    nEntries = numberOfEntries(csr)
    nEntriesCache = numberOfEntriesCache(csr)

    if nEntriesCache == 0
        return 0.0
    else
        return nEntries / nEntriesCache
    end

end

function allocationsFailed(csr::DynamicalCSR)

    return allocationsFailed(csr._coo)

end

function synchronize(csr::DynamicalCSR)

    # CSR doesn't maintain a free list like COO
    # Just synchronize the overflow COO storage
    synchronize(csr._coo)

    return
end

function dropzeros!(csr::DynamicalCSR)

    @kernel function kernel_dropzeros_csr!(
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

    CellBasedModels.synchronize(csr)

    backend = KernelAbstractions.get_backend(csr)
    threads = backend === CPU() ? Threads.nthreads() : 256
    kernel_dropzeros_csr!(backend, threads)(csr._cols, csr._values, csr._NEntries, ndrange = length(csr))

    # Also drop zeros from the overflow COO
    CellBasedModels.dropzeros!(csr._coo)

    return

end

function preallocate!(csr::DynamicalCSR; n_rows::Int=0, n_cols::Union{Int, <:AbstractArray{<:Int}}=1)
    """
    Preallocate additional rows in the CSR structure.
    
    Arguments:
    - n_rows: Number of new rows to add
    - n_cols: Number of columns per row (Int) or array of column counts per row
    """

    @assert n_rows >= 0 "n_rows must be >= 0"
    if n_cols isa Int
        @assert n_cols >= 0 "n_cols must be >= 0"
    else
        @assert all(n_cols .>= 0) "all elements of n_cols must be >= 0"
        @assert length(n_cols) == n_rows "length of n_cols must be == n_rows"
    end

    if n_rows == 0
        return
    end

    # Calculate new entries needed
    nEntriesNew = 0
    if n_cols isa AbstractArray{<:Int}
        nEntriesNew = sum(n_cols)
    else
        nEntriesNew = n_cols * n_rows
    end

    # Current sizes
    nEntriesCache = numberOfEntriesCache(csr)
    currentNRows = length(csr._rowOffsets) - 1

    # New sizes
    nEntriesCacheNew = nEntriesCache + nEntriesNew
    nRowsNew = currentNRows + n_rows

    # Get backend
    backend = KernelAbstractions.get_backend(csr)

    # Build new row offsets array on CPU first
    rowOffsets_cpu = Array(csr._rowOffsets)
    lastOffset = rowOffsets_cpu[currentNRows + 1]
    
    newOffsets = Vector{Int}(undef, n_rows)
    if n_cols isa Int
        for i in 1:n_rows
            newOffsets[i] = lastOffset + i * n_cols
        end
    else
        cumOffset = lastOffset
        for i in 1:n_rows
            cumOffset += n_cols[i]
            newOffsets[i] = cumOffset
        end
    end

    # Resize arrays
    resize!(csr._cols, nEntriesCacheNew)
    resize!(csr._values, nEntriesCacheNew)
    resize!(csr._rowOffsets, nRowsNew + 1)

    # Initialize new entries to zero
    @views csr._cols[nEntriesCache+1:end] .= 0
    @views csr._values[nEntriesCache+1:end] .= 0

    # Copy new offsets to the resized rowOffsets array
    newOffsetsBackend = toBackend(backend, newOffsets)
    @views csr._rowOffsets[currentNRows+2:end] .= newOffsetsBackend

    # Update cache counter
    setDeviceIndex!(csr._NEntriesCache, nEntriesCacheNew)

    return

end

function compact!(csr::DynamicalCSR)
    """
    Compact the CSR structure by removing empty entries (where cols[k] == 0)
    within each row. Row offsets remain unchanged, entries are compacted to the
    front of each row's allocated space. Also compacts the overflow COO.
    """

    @kernel function kernel_compact_row!(values, cols, rowOffsets)
        row = @index(Global)
        
        startIdx = rowOffsets[row]
        endIdx = rowOffsets[row + 1] - 1
        
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

    backend = KernelAbstractions.get_backend(csr)
    threads = backend === CPU() ? Threads.nthreads() : 256

    nRows = length(csr._rowOffsets) - 1
    
    if nRows > 0
        kernel_compact_row!(backend, threads)(csr._values, csr._cols, csr._rowOffsets, ndrange = nRows)
        KernelAbstractions.synchronize(backend)
    end

    # Update counters - NEntries and NEntriesNonzero stay the same, just reset overflow
    setDeviceIndex!(csr._NOverflowInsert, 0)

    # Also compact the overflow COO
    compact!(csr._coo)

    return

end

function compactto!(csrTarget::DynamicalCSR{P, T}, csr::DynamicalCSR{P, T}) where {P, T}
    """
    Copy source CSR into target CSR, compacting entries within each row.
    Row offsets remain unchanged, entries are compacted to the front of each row.
    """

    @kernel function kernel_compact_row_to!(srcValues, srcCols, dstValues, dstCols, rowOffsets)
        row = @index(Global)
        
        startIdx = rowOffsets[row]
        endIdx = rowOffsets[row + 1] - 1
        
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

    backend = KernelAbstractions.get_backend(csr)
    threads = backend === CPU() ? Threads.nthreads() : 256

    nOldEntries = length(csr)
    
    # Ensure target has enough space
    if length(csrTarget) < nOldEntries
        resize!(csrTarget._values, nOldEntries)
        resize!(csrTarget._cols, nOldEntries)
    end
    if length(csrTarget._rowOffsets) != length(csr._rowOffsets)
        resize!(csrTarget._rowOffsets, length(csr._rowOffsets))
    end

    nRows = length(csr._rowOffsets) - 1
    
    # Copy row offsets (unchanged)
    csrTarget._rowOffsets .= csr._rowOffsets
    
    if nRows > 0
        kernel_compact_row_to!(backend, threads)(
            csr._values, csr._cols, csrTarget._values, csrTarget._cols, csr._rowOffsets,
            ndrange = nRows
        )
        KernelAbstractions.synchronize(backend)
    end

    # Copy counters
    csrTarget._NEntries .= csr._NEntries
    csrTarget._NEntriesCache .= csr._NEntriesCache
    csrTarget._NEntriesNonzero .= csr._NEntriesNonzero
    setDeviceIndex!(csrTarget._NOverflowInsert, 0)

    # Compact overflow COO to target
    compactto!(csrTarget._coo, csr._coo)

    return

end

function Base.similar(csr::DynamicalCSR)

    dtype = eltype(csr._values)
    n_entries = length(csr)
    n_rows = length(csr._rowOffsets)
    n_coo = length(csr._coo)

    backend = KernelAbstractions.get_backend(csr)

    _values = toBackend(backend, Array{dtype}(undef, n_entries))
    _cols = toBackend(backend, Array{Int}(undef, n_entries))
    _rowOffsets = toBackend(backend, Array{Int}(undef, n_rows))
    _NEntries = toBackend(backend, Array{Int}(undef, 1))
    _NEntriesCache = toBackend(backend, Array{Int}(undef, 1))
    _NEntriesNonzero = toBackend(backend, Array{Int}(undef, 1))
    _NOverflowInsert = toBackend(backend, Array{Int}(undef, 1))

    # Create similar COO for overflow storage
    _coo = similar(csr._coo)

    return DynamicalCSR(
            _values,
            _cols,

            _rowOffsets,

            _NEntries,
            _NEntriesCache,
            _NEntriesNonzero,
            _NOverflowInsert,

            _coo
        )

end

function Base.copy(csr::DynamicalCSR)

    csrCopy = similar(csr)
    copyto!(csrCopy, csr)

    return csrCopy

end

function Base.copyto!(dest::DynamicalCSR{P, T}, src::DynamicalCSR{P, T}) where {P, T}

    lsrc = length(src)
    ldst = length(dest)
    
    # Resize if needed
    if ldst < lsrc
        resize!(dest._values, lsrc)
        resize!(dest._cols, lsrc)
    end
    if length(dest._rowOffsets) != length(src._rowOffsets)
        resize!(dest._rowOffsets, length(src._rowOffsets))
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
    dest._rowOffsets .= src._rowOffsets
    dest._NEntries .= src._NEntries
    dest._NEntriesCache .= src._NEntriesCache
    dest._NEntriesNonzero .= src._NEntriesNonzero
    dest._NOverflowInsert .= src._NOverflowInsert

    # Copy the overflow COO
    copyto!(dest._coo, src._coo)

    return dest

end

function dropcache!(csr::DynamicalCSR)
    """
    Drop unused cache from the CSR structure by fully compacting entries 
    (rebuilding row offsets) and resizing arrays.
    """

    backend = KernelAbstractions.get_backend(csr)
    
    # Get arrays on CPU for rebuilding
    rowOffsets_cpu = Array(csr._rowOffsets)
    cols_cpu = Array(csr._cols)
    values_cpu = Array(csr._values)
    nRows = length(rowOffsets_cpu) - 1
    
    # Count surviving entries per row and total
    survivingPerRow = zeros(Int, nRows)
    for row in 1:nRows
        startIdx = rowOffsets_cpu[row]
        endIdx = rowOffsets_cpu[row + 1] - 1
        for k in startIdx:endIdx
            if cols_cpu[k] != 0
                survivingPerRow[row] += 1
            end
        end
    end
    nSurviving = sum(survivingPerRow)
    
    # Build new row offsets
    newRowOffsets = Vector{Int}(undef, nRows + 1)
    newRowOffsets[1] = 1
    for row in 1:nRows
        newRowOffsets[row + 1] = newRowOffsets[row] + survivingPerRow[row]
    end
    
    # Build compacted arrays
    newCols = zeros(Int, nSurviving)
    newValues = zeros(eltype(values_cpu), nSurviving)
    
    writePos = 1
    for row in 1:nRows
        startIdx = rowOffsets_cpu[row]
        endIdx = rowOffsets_cpu[row + 1] - 1
        for k in startIdx:endIdx
            if cols_cpu[k] != 0
                newCols[writePos] = cols_cpu[k]
                newValues[writePos] = values_cpu[k]
                writePos += 1
            end
        end
    end
    
    # Resize and copy back
    resize!(csr._cols, nSurviving)
    resize!(csr._values, nSurviving)
    resize!(csr._rowOffsets, nRows + 1)
    
    csr._cols .= toBackend(backend, newCols)
    csr._values .= toBackend(backend, newValues)
    csr._rowOffsets .= toBackend(backend, newRowOffsets)

    # Update counters to reflect new cache size
    setDeviceIndex!(csr._NEntries, nSurviving)
    setDeviceIndex!(csr._NEntriesCache, nSurviving)
    setDeviceIndex!(csr._NEntriesNonzero, nSurviving)
    setDeviceIndex!(csr._NOverflowInsert, 0)

    # Drop cache from the overflow COO as well
    dropcache!(csr._coo)

    return

end

function dropcacheto!(csrTarget::DynamicalCSR{P, T}, csr::DynamicalCSR{P, T}) where {P, T}
    """
    Drop unused cache from csr and copy fully compacted version to csrTarget.
    Rebuilds row offsets to remove empty slots.
    """
    
    backend = KernelAbstractions.get_backend(csr)
    
    # Get arrays on CPU for rebuilding
    rowOffsets_cpu = Array(csr._rowOffsets)
    cols_cpu = Array(csr._cols)
    values_cpu = Array(csr._values)
    nRows = length(rowOffsets_cpu) - 1
    
    # Count surviving entries per row and total
    survivingPerRow = zeros(Int, nRows)
    for row in 1:nRows
        startIdx = rowOffsets_cpu[row]
        endIdx = rowOffsets_cpu[row + 1] - 1
        for k in startIdx:endIdx
            if cols_cpu[k] != 0
                survivingPerRow[row] += 1
            end
        end
    end
    nSurviving = sum(survivingPerRow)
    
    # Build new row offsets
    newRowOffsets = Vector{Int}(undef, nRows + 1)
    newRowOffsets[1] = 1
    for row in 1:nRows
        newRowOffsets[row + 1] = newRowOffsets[row] + survivingPerRow[row]
    end
    
    # Build compacted arrays
    newCols = zeros(Int, nSurviving)
    newValues = zeros(eltype(values_cpu), nSurviving)
    
    writePos = 1
    for row in 1:nRows
        startIdx = rowOffsets_cpu[row]
        endIdx = rowOffsets_cpu[row + 1] - 1
        for k in startIdx:endIdx
            if cols_cpu[k] != 0
                newCols[writePos] = cols_cpu[k]
                newValues[writePos] = values_cpu[k]
                writePos += 1
            end
        end
    end
    
    # Resize target and copy
    resize!(csrTarget._cols, nSurviving)
    resize!(csrTarget._values, nSurviving)
    resize!(csrTarget._rowOffsets, nRows + 1)
    
    csrTarget._cols .= toBackend(backend, newCols)
    csrTarget._values .= toBackend(backend, newValues)
    csrTarget._rowOffsets .= toBackend(backend, newRowOffsets)

    # Update target counters to reflect new cache size
    setDeviceIndex!(csrTarget._NEntries, nSurviving)
    setDeviceIndex!(csrTarget._NEntriesCache, nSurviving)
    setDeviceIndex!(csrTarget._NEntriesNonzero, nSurviving)
    setDeviceIndex!(csrTarget._NOverflowInsert, 0)

    # Drop cache from the overflow COO as well
    dropcacheto!(csrTarget._coo, csr._coo)

    return

end

function remaprows!(csr::DynamicalCSR, rowmap::AbstractVector{Int})
    """
    Physically reorder rows in the CSR structure according to rowmap.
    rowmap[newRow] = oldRow means new row newRow gets data from old row oldRow.
    """

    @kernel function kernel_remap_rows!(values, cols, newValues, newCols, rowOffsets, newRowOffsets, rowmap)
        newRow = @index(Global)
        
        oldRow = rowmap[newRow]
        
        # Get old and new row ranges
        oldStart = rowOffsets[oldRow]
        oldEnd = rowOffsets[oldRow + 1] - 1
        newStart = newRowOffsets[newRow]
        
        # Copy entries from old row to new position
        for k in 0:(oldEnd - oldStart)
            newValues[newStart + k] = values[oldStart + k]
            newCols[newStart + k] = cols[oldStart + k]
        end
    end
    
    backend = KernelAbstractions.get_backend(csr)
    threads = backend === CPU() ? Threads.nthreads() : 256
    
    # Get row offsets on CPU for computing new offsets
    rowOffsets_cpu = Array(csr._rowOffsets)
    rowmap_cpu = Array(rowmap)
    nRows = length(rowOffsets_cpu) - 1
    
    @assert length(rowmap_cpu) == nRows "rowmap length must equal number of rows"
    
    # Compute new row offsets on CPU (small array, sequential cumsum)
    newRowOffsets_cpu = Vector{Int}(undef, nRows + 1)
    newRowOffsets_cpu[1] = 1
    for newRow in 1:nRows
        oldRow = rowmap_cpu[newRow]
        rowLength = rowOffsets_cpu[oldRow + 1] - rowOffsets_cpu[oldRow]
        newRowOffsets_cpu[newRow + 1] = newRowOffsets_cpu[newRow] + rowLength
    end
    
    # Create temporary arrays on device for reordered data
    newValues = similar(csr._values)
    newCols = similar(csr._cols)
    newRowOffsets = toBackend(backend, newRowOffsets_cpu)
    rowmap_backend = toBackend(backend, rowmap_cpu)
    
    # Run kernel to copy entries
    kernel_remap_rows!(backend, threads)(
        csr._values, csr._cols, newValues, newCols,
        csr._rowOffsets, newRowOffsets, rowmap_backend,
        ndrange = nRows
    )
    KernelAbstractions.synchronize(backend)
    
    # Copy reordered data back
    csr._values .= newValues
    csr._cols .= newCols
    csr._rowOffsets .= newRowOffsets
    
    # Also remap the overflow COO
    remaprows!(csr._coo, rowmap)
    
    return

end

function remapcols!(csr::DynamicalCSR, colmap::AbstractVector{Int})
    """
    Remap column indices in the CSR structure.
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
    
    colmap_backend = toBackend(KernelAbstractions.get_backend(csr), colmap)

    backend = KernelAbstractions.get_backend(csr)
    threads = backend === CPU() ? Threads.nthreads() : 256
    kernel_remap_cols!(backend, threads)(csr._cols, colmap_backend, ndrange = length(csr))
    
    # Also remap columns in overflow COO
    remapcols!(csr._coo, colmap)
    
    return

end

function remap!(csr::DynamicalCSR, rowmap::AbstractVector{Int}, colmap::AbstractVector{Int})
    """
    Remap both rows and columns in a single pass.
    Physically reorders rows and remaps column indices together.
    """

    @kernel function kernel_remap!(values, cols, newValues, newCols, rowOffsets, newRowOffsets, rowmap, colmap)
        newRow = @index(Global)
        
        oldRow = rowmap[newRow]
        
        # Get old and new row ranges
        oldStart = rowOffsets[oldRow]
        oldEnd = rowOffsets[oldRow + 1] - 1
        newStart = newRowOffsets[newRow]
        
        # Copy entries from old row to new position and remap columns
        for k in 0:(oldEnd - oldStart)
            newValues[newStart + k] = values[oldStart + k]
            oldCol = cols[oldStart + k]
            if oldCol != 0 && oldCol <= length(colmap)
                newCols[newStart + k] = colmap[oldCol]
            else
                newCols[newStart + k] = oldCol
            end
        end
    end
    
    backend = KernelAbstractions.get_backend(csr)
    threads = backend === CPU() ? Threads.nthreads() : 256
    
    # Get row offsets on CPU for computing new offsets
    rowOffsets_cpu = Array(csr._rowOffsets)
    rowmap_cpu = Array(rowmap)
    nRows = length(rowOffsets_cpu) - 1
    
    @assert length(rowmap_cpu) == nRows "rowmap length must equal number of rows"
    
    # Compute new row offsets on CPU (small array, sequential cumsum)
    newRowOffsets_cpu = Vector{Int}(undef, nRows + 1)
    newRowOffsets_cpu[1] = 1
    for newRow in 1:nRows
        oldRow = rowmap_cpu[newRow]
        rowLength = rowOffsets_cpu[oldRow + 1] - rowOffsets_cpu[oldRow]
        newRowOffsets_cpu[newRow + 1] = newRowOffsets_cpu[newRow] + rowLength
    end
    
    # Create temporary arrays on device for reordered data
    newValues = similar(csr._values)
    newCols = similar(csr._cols)
    newRowOffsets = toBackend(backend, newRowOffsets_cpu)
    rowmap_backend = toBackend(backend, rowmap_cpu)
    colmap_backend = toBackend(backend, colmap)
    
    # Run kernel to copy entries and remap columns
    kernel_remap!(backend, threads)(
        csr._values, csr._cols, newValues, newCols,
        csr._rowOffsets, newRowOffsets, rowmap_backend, colmap_backend,
        ndrange = nRows
    )
    KernelAbstractions.synchronize(backend)
    
    # Copy reordered data back
    csr._values .= newValues
    csr._cols .= newCols
    csr._rowOffsets .= newRowOffsets
    
    # Also remap the overflow COO
    remap!(csr._coo, rowmap, colmap)
    
    return

end

###################################################################################################
# Platform adaptation
###################################################################################################

KernelAbstractions.get_backend(csr::DynamicalCSR) = KernelAbstractions.get_backend(csr._values)

toBackend(::KernelAbstractions.CPU, csr::DynamicalCSR{P}) where {P<:KernelAbstractions.CPU} = csr

function toBackend(::KernelAbstractions.CPU, csr::DynamicalCSR{P, T}) where {P<:KernelAbstractions.GPU, T}
    DynamicalCSR(
        Vector(csr._values),
        Vector(csr._cols),
        Vector(csr._rowOffsets),
        Vector(csr._NEntries),
        Vector(csr._NEntriesCache),
        Vector(csr._NEntriesNonzero),
        Vector(csr._NOverflowInsert),
        toBackend(CPU(), csr._coo)
    )
end
    
toBackend(::KernelAbstractions.GPU, csr::DynamicalCSR{P}) where {P<:KernelAbstractions.GPU} = csr

function toBackend(backend::KernelAbstractions.GPU, csr::DynamicalCSR{P}) where {P<:KernelAbstractions.CPU}
    DynamicalCSR(
        toBackend(backend, csr._values),
        toBackend(backend, csr._cols),
        toBackend(backend, csr._rowOffsets),
        toBackend(backend, csr._NEntries),
        toBackend(backend, csr._NEntriesCache),
        toBackend(backend, csr._NEntriesNonzero),
        toBackend(backend, csr._NOverflowInsert),
        toBackend(backend, csr._coo)
    )
end
