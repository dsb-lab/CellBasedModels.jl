######################################################################################################
# DynamicalCSR - Fixed-size tuples (block size is a type parameter)
######################################################################################################
struct DynamicalCSR{
            P, T, V, I, M, C
        } <: AbstractSparseMatrix

    _values::V
    _cols::I

    _rowOffsets::I

    _NRows::I
    _NCols::I

    _NEntries::I
    _NEntriesRow::M

    _coo::C

end
Adapt.@adapt_structure DynamicalCSR

function DynamicalCSR(
        _values,
        _cols,
        _rowOffsets,
        _NRows,
        _NCols,
        _NEntries,
        _NEntriesRow,
        _coo
    )
    
    P = platform()
    T = eltype(_values)
    V = typeof(_values)
    I = typeof(_cols)
    M = typeof(_NEntriesRow)
    C = typeof(_coo)

    DynamicalCSR{
            P, T, V, I, M, C
        }(
            _values,
            _cols,
            _rowOffsets,
            _NRows,
            _NCols,
            _NEntries,
            _NEntriesRow,
            _coo
        )
end

function dcsr_zeros(dtype::DataType, nrows::Int, n_entries_row::Union{Int, Vector{<:Int}}=10; n_coo::Int=0)

    @assert nrows > 0 "nrows must be > 0"
    @assert n_coo >= 0 "n_coo must be >= 0"
    if n_entries_row isa Int
        n_entries_row = fill(n_entries_row, nrows)
    end
    @assert all(n_entries_row .>= 0) "all elements of n_entries_row must be >= 0"

    n_entries = sum(n_entries_row)
    _values = zeros(dtype, n_entries)
    _cols = zeros(Int, n_entries)
    _rowOffsets = cumsum([1, n_entries_row...])
    _NRows = Int[nrows, nrows]
    _NCols = Int[0]
    _NEntries = [0, n_entries, 0]
    _NEntriesRow = [zeros(Int, nrows) n_entries_row zeros(Int, nrows)]
    _coo = DynamicalCOO(dtype, n_coo)

    P = platform()
    T = eltype(_values)
    V = typeof(_values)
    I = typeof(_cols)
    M = typeof(_NEntriesRow)
    C = typeof(_coo)

    DynamicalCSR{
            P, T, V, I, M, C
        }(
            _values,
            _cols,
            _rowOffsets,
            _NRows,
            _NCols,
            _NEntries,
            _NEntriesRow,
            _coo
        )
end

function dcsr_zeros(nrows::Int, n_entries_row::Int; n_coo::Int=0)
    dcsr_zeros(Float64, nrows::Int, n_entries_row, n_coo=n_coo)
end

function Base.show(io::IO, x::DynamicalCSR{P, T}) where {P, T}
    
    nrows = x._NRows[1]
    ncols = x._NCols[1]
    nentries = numberOfEntries(x)
    
    println(io, "DynamicalCSR{$T} with $(nentries) stored entries")
    println(io, "  $(nrows) × $(ncols) sparse matrix")
    
    # Show matrix contents if small enough
    if nrows <= 15 && ncols <= 15 && nrows > 0 && ncols > 0
        println(io, "")
        
        # First pass: determine column widths
        colwidths = ones(Int, ncols)
        for i in 1:nrows
            for j in 1:ncols
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
        for i in 1:nrows
            print(io, "  ")
            for j in 1:ncols
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

function Base.show(io::IO, x::Type{DynamicalCSR{P, T, V, I, M, C}}) where {P, T, V, I, M, C}
    println(io, "DynamicalCSR{$P, $T, $V, $I, $M, $C}")
end

Base.length(csr::DynamicalCSR{P}) where {P} = numberOfEntries(csr)
numberOfEntries(csr::DynamicalCSR{P}) where {P<:CPU} = getDeviceIndex(csr._NEntries, 1)

"""
    setindex!(csr::DynamicalCSR, value, i::Int, j::Int)

Set the value at position (i, j) in the sparse matrix.
Allows syntax: x[i,j] = value
"""
function Base.setindex!(csr::DynamicalCSR{P}, value, i::Int, j::Int) where {P}
    
    nRowsCache = csr._NRows[2]
    nCols = csr._NCols[1]

    # Check limits
    if i < 1 || j < 1
        @print "Index i=$(i) and j=$(j) must be >= 1. Ignoring operation."
        return
    end

    # Expand number of cols if needed
    if j > nCols
        @atomic csr._NCols[1] += max(j, csr._NCols[1]) - nCols
    end

    # Search in CSR 
    if i <= nRowsCache
        # Get row offset and number of entries in row i
        rowStart = csr._rowOffsets[i]
        rowEnd = csr._rowOffsets[i + 1] - 1
        nEntriesRowCache = csr._NEntriesRow[i, 2]
        
        # Search for column j in row i
        for k in rowStart:rowEnd
            # Found
            if csr._cols[k] == j
                old = csr._values[k]
                if old == 0 && value != 0
                    @atomic csr._NEntries[3] += 1
                elseif old != 0 && value == 0
                    @atomic csr._NEntries[3] -= 1
                end
                csr._values[k] = value
                return
            end
        end
        # Not found, add new if space
        pos = @atomic csr._NEntriesRow[i, 1] += 1
        if pos <= nEntriesRowCache
            index = rowStart + pos - 1
            csr._cols[index] = j
            csr._values[index] = value
            if value != 0
                @atomic csr._NEntries[3] += 1
                @atomic csr._NEntriesRow[i, 3] += 1
            end
            @atomic csr._NEntries[1] += 1
            return
        end
    end

    # Search for i j in coo
    for k in 1:1:minimum(csr._cooN)
        #Found
        if csr._coo[k][1] == i && csr._coo[k][2] == j
            old = csr._coo[k][3]
            if old == 0 && value != 0
                @atomic csr._NEntries[3] += 1
                if i <= nRowsCache
                    @atomic csr._NEntriesRow[i, 1] -= 1
                    @atomic csr._NEntriesRow[i, 3] += 1
                end
            elseif old != 0 && value == 0
                @atomic csr._NEntries[3] -= 1
                if i <= nRowsCache
                    @atomic csr._NEntriesRow[i, 1] -= 1
                    @atomic csr._NEntriesRow[i, 3] -= 1
                end
            end
            csr._coo[k] = (i, j, value)
            return
        end
    end
    # Not found, add new
    pos = @atomic csr._cooN[1] += 1
    # If not overflow
    if pos <= csr._cooN[2]
        if value != 0
            @atomic csr._NEntries[3] += 1
            if i <= nRowsCache
                @atomic csr._NEntriesRow[i, 3] += 1
                @atomic csr._cooN[3] += 1
            end
        end
        csr._coo[pos] = (i, j, value)
    end
    @atomic csr._NEntries[1] += 1
    # Expand NRows
    @atomic csr._NRows[1] += max(i, csr._NRows[1]) - csr._NRows[1]

    return
    
end

"""
    getindex(csr::DynamicalCSR, i::Int, j::Int)

Get the value at position (i, j) in the sparse matrix.
Returns 0 if the entry does not exist.
Allows syntax: value = x[i,j]
"""
function Base.getindex(csr::DynamicalCSR{P}, i::Int, j::Int) where {P}
    # Get row offset and number of entries in row i
    rowStart = csr._rowOffsets[i]
    rowEnd = csr._rowOffsets[i + 1] - 1
    
    # Search for column j in row i
    for k in rowStart:rowEnd
        if csr._cols[k] == j
            return csr._values[k]
        end
    end

    # Search for i j in coo
    for k in 1:1:min(csr._cooN[1], csr._cooNCache[1])
        if csr._cooRows[k] == i && csr._cooCols[k] == j
            return csr._cooValues[k]
        end
    end
    
    # Column not found, return zero
    return zero(eltype(csr._values))
end

function _getindex(csr::DynamicalCSR{P}, i::Int, j::Int) where {P}
    # Get row offset and number of entries in row i
    rowStart = csr._rowOffsets[i]
    rowEnd = csr._rowOffsets[i + 1] - 1
    
    # Search for column j in row i
    for k in rowStart:rowEnd
        if csr._cols[k] == j
            return csr._values[k]
        end
    end

    # Search for i j in coo
    for k in 1:1:minimum(csr._cooN)
        if csr._cooRows[k] == i && csr._cooCols[k] == j
            return csr._cooValues[k]
        end
    end
    
    # Column not found, return zero
    return nothing
end

function dropzeros!(csr::DynamicalCSR)

    if Array(csr._NRows)[1] > Array(csr._NRowsCache)[1]
        @error "Number of rows is less than or equal to cached number of rows. You need to preallocate more rows before dropping zeros."
    end

    @kernel function _kernel_dropzeros!(csr)
        row = @index(Global)

        rowStart = csr._rowOffsets[row]
        rowEnd = min(rowStart + csr._NEntriesRow[row] - 1, length(csr._rowOffsets[row + 1]))

        count = 0
        for i in rowStart:rowEnd
            iNew = rowStart + count
            # Copy non-zero values
            if csr._values[i] != 0
                csr._values[iNew] = csr._values[i]
                csr._cols[iNew] = csr._cols[i]
                if iNew != i
                    csr._values[i] = 0
                    csr._cols[i] = 0
                end
                count += 1
            end
        end
        for i in 1:csr._cooN[1]
            iNew = rowStart + count
            if csr._cooRows[i] == row && csr._cooValues[i] != 0
                csr._values[iNew] = csr._cooValues[i]
                csr._cols[iNew] = csr._cooCols[i]
                csr._cooRows[i] = 0
                csr._cooCols[i] = 0
                csr._cooValues[i] = 0
                count += 1
            end
        end

        csr._NEntriesRow[row] = count - 1

    end

    backend = KernelAbstractions.get_backend(csr)
    threads = backend === CPU ? Threads.nthreads() : 256
    _kernel_dropzeros!(backend, threads)(csr, ndrange=Array(csr._NRows)[1])
    KernelAbstractions.synchronize(backend)

    csr._cooN .= 0

end


# function compact!(csr::DynamicalCSR)

#     # Load current sizes
#     nRows = Array(csr._NRows)[1]
#     nRowsCache = Array(csr._NRowsCache)[1]
#     cooN = Array(csr._cooN)[1]
#     cooNCache = Array(csr._cooNCache)[1]
    
#     @kernel function _kernel_check_row_overload(NEntriesRow, NEntriesRowCache,result)
#         row = @index(Global)

#         if NEntriesRow[row] >= NEntriesRowCache[row]
#             result[1] = true
#         end
#     end

#     backend = KernelAbstractions.get_backend(csr)
#     threads = backend === CPU ? Threads.nthreads() : 256
#     nRowsEntriesOverflow = Adapt.adapt(backend, zeros(Bool, 1))
#     _kernel_check_row_overload(backend, threads)(csr._NEntriesRow, csr._NEntriesRowCache, nRowsEntriesOverflow, ndrange=Array(csr._NRowsCache)[1])
#     KernelAbstractions.synchronize(backend)

#     nRowsEntriesOverflow = Array(nRowsEntriesOverflow)[1]

#     if nRows <= nRowsCache && !nRowsEntriesOverflow && cooN == 0
#         nothing
#     elseif nRows <= nRowsCache && !nRowsEntriesOverflow && cooN > 0
#         dropzeros!(csr)
#     elseif nRows > nRowsCache && !nRowsEntriesOverflow && cooN == 0
#         preallocateRows!(csr)
#     elseif nRows > nRowsCache && !nRowsEntriesOverflow && cooN > 0
#         preallocateRows!(csr)
#         dropzeros!(csr)
#     else
#         preallocate!(csr)
#     end

# end

# function preallocateRows!(csr; factor=1.2, nRowEntries::Int=10)

#     @assert factor > 1 "Factor must be greater than 1."

#     function kernel_refillOffsets!(rowOffsets, nRowEntries)
#         index = @index(Global)
#         if index > 1
#             base = rowOffsets[1]
#             rowOffsets[index] = base + nRowEntries*(index-1)
#         end
#     end

#     backend = KernelAbstractions.get_backend(csr)
#     threads = backend === CPU ? Threads.nthreads() : 256

#     nRows = Array(csr._NRows)[1]
#     nRowsCache = Array(csr._NRowsCache)[1]
#     nRowsCacheNew = round(Int, nRows * factor)
#     nEntries = Array(csr._NEntriesCache)[1]
#     nEntriesNew = nEntries + nRowEntries * (nRowsCacheNew - nRowsCache)

#     resize!(csr._values, nEntriesNew)
#     @views csr._values[nEntries+1:end] .= 0
#     resize!(csr._cols, nEntriesNew)
#     @views csr._cols[nEntries+1:end] .= 0
#     resize!(csr._rowOffsets, nRowsCacheNew + 1)
#     offsets = @view csr._rowOffsets[nRowsCache:end]
#     kernel_refillOffsets!(backend, threads)(offsets, nRowEntries, ndrange=length(offsets))
#     KernelAbstractions.synchronize(backend)
#     csr._NRows .= nRowsCacheNew
#     csr._NRowsCache .= nRowsCacheNew
#     csr._NEntries .= nEntriesNew
#     csr._NEntriesCache .= nEntriesNew
#     resize!(csr._NEntriesRow, nRowsCacheNew)
#     @views csr._NEntriesRow[nRowsCache+1:end] .= 0
#     resize!(csr._NEntriesRowCache, nRowsCacheNew)
#     @views csr._NEntriesRowCache[nRowsCache+1:end] .= nRowEntries


# end

# """
#     preallocate!(csr::DynamicalCSR)

# Reallocate the sparse matrix when rows or per-row caches overflow.

# This function expands storage when:
# 1. Any row's entry count exceeds its allocated cache (expand that row's cache 1.5x)
# 2. Number of rows exceeds NRowsCache (expand NRowsCache 1.5x)
# 3. COO entries exceed cooNCache (expand cooNCache 1.5x)

# Strategy:
# - Check what needs expansion
# - If no expansion needed, return early
# - If row/cache expansion needed: compute new offsets, remap data, expand storage
# - If COO expansion needed: resize COO arrays
# - Uses kernels for parallel data movement (CPU/GPU compatible)
# """
# function preallocate!(csr::DynamicalCSR{P, T, V, I}) where {P, T, V, I}

#     if nRows < nRowsCache && !nRowsEntriesOverflow

#     # Step 1: Expand per-row caches if any row is full
#     for row in 1:nRows
#         if csr._NEntriesRow[row] >= csr._NEntriesRowCache[row]
#             # Row is full, expand its cache by 1.5x
#             csr._NEntriesRowCache[row] = round(Int, max(2, csr._NEntriesRowCache[row] * 1.5))
#         end
#     end
    
#     # Step 2: Determine new nRowsCache if current rows exceed it
#     newNRowsCache = nRows > nRowsCache ? max(nRows + 1, round(Int, nRowsCache * 1.5)) : nRowsCache
    
#     # Step 3: Determine new cooNCache if COO is full
#     newCooNCache = cooN >= cooNCache ? max(cooN + 1, round(Int, cooNCache * 1.5)) : cooNCache
    
#     # Step 4: Check if any reallocation needed
#     rowExpansionNeeded = newNRowsCache > nRowsCache
#     rowCacheChanged = any(csr._NEntriesRowCache[1:nRows] .!= @view csr._rowOffsets[2:nRows+1] .- @view csr._rowOffsets[1:nRows])
#     cooExpansionNeeded = newCooNCache > cooNCache
    
#     if !rowExpansionNeeded && !rowCacheChanged && !cooExpansionNeeded
#         return csr  # No expansion needed
#     end
    
#     # Step 5: If rows need expansion, remap storage and recompute offsets
#     if rowExpansionNeeded || rowCacheChanged
#         backend = KernelAbstractions.get_backend(csr._values)
        
#         # Save old offsets and storage info
#         oldRowOffsets = copy(csr._rowOffsets)
#         oldStorageSize = length(csr._values)
        
#         # Compute new offsets based on updated NEntriesRowCache
#         resize!(csr._rowOffsets, newNRowsCache + 1)
#         csr._rowOffsets[1] = 1
#         for i in 1:newNRowsCache
#             if i <= nRows
#                 csr._rowOffsets[i+1] = csr._rowOffsets[i] + csr._NEntriesRowCache[i]
#             else
#                 csr._rowOffsets[i+1] = csr._rowOffsets[i]  # New rows start empty
#             end
#         end
        
#         newStorageSize = csr._rowOffsets[newNRowsCache + 1] - 1
        
#         # Remap data from old positions to new positions using kernel
#         @kernel function _remap_and_fill!(values_old, cols_old, values_new, cols_new, 
#                                          oldOffsets, newOffsets, NEntriesRow, nRows)
#             row = @index(Global)
#             if row <= nRows
#                 oldStart = oldOffsets[row]
#                 newStart = newOffsets[row]
#                 nEntries = NEntriesRow[row]
                
#                 # Copy entries from old to new position
#                 for i in 1:nEntries
#                     values_new[newStart + i - 1] = values_old[oldStart + i - 1]
#                     cols_new[newStart + i - 1] = cols_old[oldStart + i - 1]
#                 end
#             end
#         end
        
#         # Create new arrays
#         newValues = similar(csr._values, newStorageSize)
#         newCols = similar(csr._cols, newStorageSize)
#         fill!(newValues, zero(T))
#         fill!(newCols, 0)
        
#         # Run kernel to remap data
#         _remap_and_fill!(backend, 256)(csr._values, csr._cols, newValues, newCols,
#                                        oldRowOffsets, csr._rowOffsets, csr._NEntriesRow, nRows,
#                                        ndrange=newNRowsCache)
#         KernelAbstractions.synchronize(backend)
        
#         # Replace with new arrays
#         csr._values = newValues
#         csr._cols = newCols
        
#         # Resize row metadata
#         resize!(csr._NEntriesRow, newNRowsCache)
#         resize!(csr._NEntriesRowCache, newNRowsCache)
#         if isdefined(csr, :_NEntriesRowCompacted)
#             resize!(csr._NEntriesRowCompacted, newNRowsCache)
#         end
        
#         # Fill new rows with zero entries
#         if newNRowsCache > nRowsCache
#             @views csr._NEntriesRow[nRowsCache+1:end] .= 0
#             @views csr._NEntriesRowCache[nRowsCache+1:end] .= 0
#             if isdefined(csr, :_NEntriesRowCompacted)
#                 @views csr._NEntriesRowCompacted[nRowsCache+1:end] .= 0
#             end
#         end
        
#         # Update cache size
#         csr._NRowsCache[1] = newNRowsCache
#     end
    
#     # Step 6: Expand COO arrays if needed
#     if cooExpansionNeeded
#         resize!(csr._cooRows, newCooNCache)
#         resize!(csr._cooCols, newCooNCache)
#         resize!(csr._cooValues, newCooNCache)
        
#         # Fill new COO entries with zeros
#         @views csr._cooRows[cooNCache+1:end] .= 0
#         @views csr._cooCols[cooNCache+1:end] .= 0
#         @views csr._cooValues[cooNCache+1:end] .= zero(T)
        
#         csr._cooNCache[1] = newCooNCache
#     end
    
#     return csr
# end


# # KernelAbstractions.get_backend(csr::DynamicalCSR) = KernelAbstractions.get_backend(csr._values)