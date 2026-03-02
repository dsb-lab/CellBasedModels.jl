######################################################################################################
# DynamicalCOO - Fixed-size tuples (block size is a type parameter)
######################################################################################################
struct DynamicalCOO{
            P, T, V, I, L
        } <: AbstractSparseMatrix

    _values::V
    _rows::I
    _cols::I

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
Adapt.@adapt_structure DynamicalCOO

function DynamicalCOO(
        _values,
        _rows,
        _cols,
        
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

    DynamicalCOO{
            P, T, V, I, L
        }(
            _values,
            _rows,
            _cols,
            
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

function dcoo_zeros(dtype::DataType, n_coo::Int=0)

    @assert n_coo >= 0 "n_coo must be >= 0"

    _rows = zeros(Int, n_coo)
    _cols = zeros(Int, n_coo)
    _values = zeros(dtype, n_coo)
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

    DynamicalCOO(
            _rows,
            _cols,
            _values,
            
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

function dcoo_zeros(nrows::Int, n_coo::Int=0)
    dcoo_zeros(Float64, n_coo)
end

function Base.show(io::IO, x::DynamicalCOO{P, T}) where {P, T}
    
    nrows = numberOfRows(x)
    ncols = numberOfCols(x)
    nentries = numberOfEntries(x)
    
    println(io, "DynamicalCOO{$T} with $(nentries) stored entries")
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

function Base.show(io::IO, x::Type{DynamicalCOO{P, T, V, I}}) where {P, T, V, I}
    println(io, "DynamicalCOO{$P, $T, $V, $I}")
end

Base.length(coo::DynamicalCOO{P}) where {P} = length(coo._values)
numberOfEntries(coo::DynamicalCOO{P}) where {P} = getDeviceIndex(coo._NEntries)
numberOfEntriesCache(coo::DynamicalCOO{P}) where {P} = getDeviceIndex(coo._NEntriesCache)
numberOfEntriesNonzero(coo::DynamicalCOO{P}) where {P} = getDeviceIndex(coo._NEntriesNonzero)
numberOfEntriesFree(coo::DynamicalCOO{P}) where {P} = getDeviceIndex(coo._NEntriesFree)
numberOfEntriesFreeNext(coo::DynamicalCOO{P}) where {P} = getDeviceIndex(coo._NEntriesFreeNext)
numberOfRows(coo::DynamicalCOO{P}) where {P} = maximum(coo._rows)
numberOfCols(coo::DynamicalCOO{P}) where {P} = maximum(coo._cols)

"""
    setindex!(coo::DynamicalCOO, value, i::Int, j::Int)

Set the value at position (i, j) in the sparse matrix.
Allows syntax: x[i,j] = value
"""
function Base.setindex!(coo::DynamicalCOO{P}, value, i::Int, j::Int) where {P<:CPU}

    nEntries = min(coo._NEntriesCache[1], coo._NEntries[1])

    if i <= 0 || j <= 0
        @print "Indices must be positive integers."
    end

    # Search for i j in coo
    for k in 1:1:nEntries
        #Found
        if coo._rows[k] == i && coo._cols[k] == j
            old = coo._values[k]
            if old == 0 && value != 0
                Atomix.@atomic coo._NEntriesNonzero[1] += 1
            elseif old != 0 && value == 0
                Atomix.@atomic coo._NEntriesNonzero[1] -= 1
            end
            coo._values[k] = value
            return false
        end
    end
    # Not found, add new
    newFreePos = Atomix.@atomic coo._NEntriesFree[1] -= 1
    if 0 <= newFreePos
        newPos = coo._entriesFree[newFreePos+1]
        coo._rows[newPos] = i
        coo._cols[newPos] = j
        coo._values[newPos] = value
        coo._entriesFree[newFreePos+1] = 0
    else # If overflow
        lock(coo._lock) do
            push!(coo._rows, i)
            push!(coo._cols, j)
            push!(coo._values, value)
            push!(coo._entriesFree, 0)
            coo._NEntriesCache[1] += 1
            coo._NEntriesFree[1] += 1
            coo._NOverflowInsert[1] += 1
        end
    end
    Atomix.@atomic coo._NEntries[1] += 1
    # Update cache
    if value != 0
        Atomix.@atomic coo._NEntriesNonzero[1] += 1
    end

    return true
    
end

function Base.setindex!(coo::DynamicalCOO{P}, value, i::Int, j::Int) where {P<:GPU}

    nEntries = min(coo._NEntriesCache[1], coo._NEntries[1])

    if i <= 0 || j <= 0
        @print "Indices must be positive integers."
    end

    # Search for i j in coo
    for k in 1:1:nEntries
        #Found
        if coo._rows[k] == i && coo._cols[k] == j
            old = coo._values[k]
            if old == 0 && value != 0
                Atomix.@atomic coo._NEntriesNonzero[1] += 1
            elseif old != 0 && value == 0
                Atomix.@atomic coo._NEntriesNonzero[1] -= 1
            end
            coo._values[k] = value
            return false
        end
    end
    # Not found, add new
    newFreePos = Atomix.@atomic coo._NEntriesFree[1] -= 1
    if 0 <= newFreePos
        newPos = coo._entriesFree[newFreePos+1]
        coo._rows[newPos] = i
        coo._cols[newPos] = j
        coo._values[newPos] = value
        coo._entriesFree[newFreePos+1] = 0
    else
        Atomix.@atomic coo._NEntriesFree[1] += 1
        Atomix.@atomic coo._NOverflowInsert[1] += 1
    end
    Atomix.@atomic coo._NEntries[1] += 1
    # Update cache
    if value != 0
        Atomix.@atomic coo._NEntriesNonzero[1] += 1
    end

    return true
    
end

function Base.setindex!(coo::DynamicalCOO{P}, ::Nothing, i::Int, j::Int) where {P<:CPU}

    nEntries = min(coo._NEntriesCache[1], coo._NEntries[1])

    # Search for i j in coo
    for k in 1:1:nEntries
        #Found
        if coo._rows[k] == i && coo._cols[k] == j
            result = Atomix.@atomicreplace coo._rows[k] k => 0
            if result.success
                Atomix.@atomic coo._NEntries[1] -= 1
                if coo._values[k] != 0
                    Atomix.@atomic coo._NEntriesNonzero[1] -= 1
                end
                coo._cols[k] = 0
                coo._values[k] = zero(eltype(coo._values))
                # Add to free entries
                newFreePos = Atomix.@atomic coo._NEntriesFreeNext[1] += 1
                newPos = coo._NEntriesFreeNextInit[1] + newFreePos
                if newPos <= length(coo._entriesFree)
                    coo._entriesFree[newPos-1] = k
                else
                    lock(coo._lock) do
                        push!(coo._entriesFree, k)
                        coo._NOverflowErase[1] += 1
                    end
                end
            end
        end
    end
    # Not found
    return false

end

function Base.setindex!(coo::DynamicalCOO{P}, ::Nothing, i::Int, j::Int) where {P<:GPU}

    nEntries = min(coo._NEntriesCache[1], coo._NEntries[1])

    # Search for i j in coo
    for k in 1:1:nEntries
        #Found
        if coo._rows[k] == i && coo._cols[k] == j
            result = Atomix.@atomicreplace coo._rows[k] k => 0
            if result.success
                Atomix.@atomic coo._NEntries[1] -= 1
                if coo._values[k] != 0
                    Atomix.@atomic coo._NEntriesNonzero[1] -= 1
                end
                coo._cols[k] = 0
                coo._values[k] = zero(eltype(coo._values))
                # Add to free entries
                newFreePos = Atomix.@atomic coo._NEntriesFreeNext[1] += 1
                newPos = coo._NEntriesFreeNextInit[1] + newFreePos
                if newPos <= length(coo._entriesFree)
                    coo._entriesFree[newPos-1] = k
                else
                    Atomix.@atomic coo._NEntriesFreeNext[1] -= 1
                    Atomix.@atomic coo._NOverflowErase[1] += 1
                end
            end
        end
    end
    # Not found
    return false

end

"""
    getindex(coo::DynamicalCOO, i::Int, j::Int)

Get the value at position (i, j) in the sparse matrix.
Returns 0 if the entry does not exist.
Allows syntax: value = x[i,j]
"""
function Base.getindex(coo::DynamicalCOO{P, T}, i::Int, j::Int) where {P, T}

    nEntries = min(numberOfEntries(coo), numberOfEntriesCache(coo))

    # Search for i j in coo
    for k in 1:1:nEntries
        if coo._rows[k] == i && coo._cols[k] == j
            return coo._values[k]
        end
    end
    
    # Column not found, return zero
    return zero(T)
end

function _getindex(coo::DynamicalCOO, i::Int, j::Int)

    nEntries = min(numberOfEntries(coo), numberOfEntriesCache(coo))

    # Search for i j in coo
    for k in 1:1:nEntries
        if coo._rows[k] == i && coo._cols[k] == j
            return coo._values[k]
        end
    end
    
    # Column not found, return zero
    return nothing
end

"""
    replaceIndex!(coo::DynamicalCOO, i_old::Int, j_old::Int, i_new::Int, j_new::Int)

Replace the indices of an existing entry in-place without removing and re-adding.
Finds the entry at (i_old, j_old) and changes its indices to (i_new, j_new), keeping the value.
Returns true if the entry was found and replaced, false otherwise.

This is more efficient than `coo[i_new, j_new] = coo[i_old, j_old]; coo[i_old, j_old] = nothing`
because it avoids the overhead of removal and insertion.
"""
function replaceIndex!(coo::DynamicalCOO, i_old::Int, j_old::Int, i_new::Int, j_new::Int)

    if i_old <= 0 || j_old <= 0 || i_new <= 0 || j_new <= 0
        @print "Indices must be positive integers."
        return false
    end

    nEntries = min(coo._NEntriesCache[1], coo._NEntries[1])

    # Search for the old entry
    for k in 1:1:nEntries
        if coo._rows[k] == i_old && coo._cols[k] == j_old
            # Found - replace indices in place
            coo._rows[k] = i_new
            coo._cols[k] = j_new
            return true
        end
    end

    # Entry not found
    return false
end

"""
    replaceIndex!(coo::DynamicalCOO, i::Int, j_old::Int, j_new::Int)

Replace the column index of an existing entry in-place, keeping the same row.
Shorthand for `replaceIndex!(coo, i, j_old, i, j_new)`.
Returns true if the entry was found and replaced, false otherwise.
"""
function replaceIndex!(coo::DynamicalCOO, i::Int, j_old::Int, j_new::Int)
    return replaceIndex!(coo, i, j_old, i, j_new)
end

"""
    setindex!(coo::DynamicalCOO, value, i::Int, ::Colon)

Set all entries in row i to value.
Allows syntax: coo[i,:] = value
"""
function Base.setindex!(coo::DynamicalCOO{P}, value, i::Int, ::Colon) where {P}

    nEntries = min(coo._NEntriesCache[1], coo._NEntries[1])

    for k in 1:1:nEntries
        if coo._rows[k] == i
            old = coo._values[k]
            if old == 0 && value != 0
                Atomix.@atomic coo._NEntriesNonzero[1] += 1
            elseif old != 0 && value == 0
                Atomix.@atomic coo._NEntriesNonzero[1] -= 1
            end
            coo._values[k] = value
        end
    end

    return
end

"""
    setindex!(coo::DynamicalCOO, value, ::Colon, j::Int)

Set all entries in column j to value.
Allows syntax: coo[:,j] = value
"""
function Base.setindex!(coo::DynamicalCOO{P}, value, ::Colon, j::Int) where {P}

    nEntries = min(coo._NEntriesCache[1], coo._NEntries[1])

    for k in 1:1:nEntries
        if coo._cols[k] == j
            old = coo._values[k]
            if old == 0 && value != 0
                Atomix.@atomic coo._NEntriesNonzero[1] += 1
            elseif old != 0 && value == 0
                Atomix.@atomic coo._NEntriesNonzero[1] -= 1
            end
            coo._values[k] = value
        end
    end

    return
end

"""
    setindex!(coo::DynamicalCOO, ::Nothing, i::Int, ::Colon)

Remove all entries in row i.
Allows syntax: coo[i,:] = nothing
"""
function Base.setindex!(coo::DynamicalCOO{P}, ::Nothing, i::Int, ::Colon) where {P<:CPU}

    nEntries = min(coo._NEntriesCache[1], coo._NEntries[1])

    for k in 1:1:nEntries
        if coo._rows[k] == i
            result = Atomix.@atomicreplace coo._rows[k] i => 0
            if result.success
                Atomix.@atomic coo._NEntries[1] -= 1
                if coo._values[k] != 0
                    Atomix.@atomic coo._NEntriesNonzero[1] -= 1
                end
                coo._cols[k] = 0
                coo._values[k] = zero(eltype(coo._values))
                # Add to free entries
                newFreePos = Atomix.@atomic coo._NEntriesFreeNext[1] += 1
                newPos = coo._NEntriesFreeNextInit[1] + newFreePos
                if newPos <= length(coo._entriesFree)
                    coo._entriesFree[newPos-1] = k
                else
                    lock(coo._lock) do
                        push!(coo._entriesFree, k)
                        coo._NOverflowErase[1] += 1
                    end
                end
            end
        end
    end

    return
end

function Base.setindex!(coo::DynamicalCOO{P}, ::Nothing, i::Int, ::Colon) where {P<:GPU}

    nEntries = min(coo._NEntriesCache[1], coo._NEntries[1])

    for k in 1:1:nEntries
        if coo._rows[k] == i
            result = Atomix.@atomicreplace coo._rows[k] i => 0
            if result.success
                Atomix.@atomic coo._NEntries[1] -= 1
                if coo._values[k] != 0
                    Atomix.@atomic coo._NEntriesNonzero[1] -= 1
                end
                coo._cols[k] = 0
                coo._values[k] = zero(eltype(coo._values))
                # Add to free entries
                newFreePos = Atomix.@atomic coo._NEntriesFreeNext[1] += 1
                newPos = coo._NEntriesFreeNextInit[1] + newFreePos
                if newPos <= length(coo._entriesFree)
                    coo._entriesFree[newPos-1] = k
                else
                    Atomix.@atomic coo._NEntriesFreeNext[1] -= 1
                    Atomix.@atomic coo._NOverflowErase[1] += 1
                end
            end
        end
    end

    return
end

"""
    setindex!(coo::DynamicalCOO, ::Nothing, ::Colon, j::Int)

Remove all entries in column j.
Allows syntax: coo[:,j] = nothing
"""
function Base.setindex!(coo::DynamicalCOO{P}, ::Nothing, ::Colon, j::Int) where {P<:CPU}

    nEntries = min(coo._NEntriesCache[1], coo._NEntries[1])

    for k in 1:1:nEntries
        if coo._cols[k] == j && coo._rows[k] != 0
            rowVal = coo._rows[k]
            result = Atomix.@atomicreplace coo._rows[k] rowVal => 0
            if result.success
                Atomix.@atomic coo._NEntries[1] -= 1
                if coo._values[k] != 0
                    Atomix.@atomic coo._NEntriesNonzero[1] -= 1
                end
                coo._cols[k] = 0
                coo._values[k] = zero(eltype(coo._values))
                # Add to free entries
                newFreePos = Atomix.@atomic coo._NEntriesFreeNext[1] += 1
                newPos = coo._NEntriesFreeNextInit[1] + newFreePos
                if newPos <= length(coo._entriesFree)
                    coo._entriesFree[newPos-1] = k
                else
                    lock(coo._lock) do
                        push!(coo._entriesFree, k)
                        coo._NOverflowErase[1] += 1
                    end
                end
            end
        end
    end

    return
end

function Base.setindex!(coo::DynamicalCOO{P}, ::Nothing, ::Colon, j::Int) where {P<:GPU}

    nEntries = min(coo._NEntriesCache[1], coo._NEntries[1])

    for k in 1:1:nEntries
        if coo._cols[k] == j && coo._rows[k] != 0
            rowVal = coo._rows[k]
            result = Atomix.@atomicreplace coo._rows[k] rowVal => 0
            if result.success
                Atomix.@atomic coo._NEntries[1] -= 1
                if coo._values[k] != 0
                    Atomix.@atomic coo._NEntriesNonzero[1] -= 1
                end
                coo._cols[k] = 0
                coo._values[k] = zero(eltype(coo._values))
                # Add to free entries
                newFreePos = Atomix.@atomic coo._NEntriesFreeNext[1] += 1
                newPos = coo._NEntriesFreeNextInit[1] + newFreePos
                if newPos <= length(coo._entriesFree)
                    coo._entriesFree[newPos-1] = k
                else
                    Atomix.@atomic coo._NEntriesFreeNext[1] -= 1
                    Atomix.@atomic coo._NOverflowErase[1] += 1
                end
            end
        end
    end

    return
end

function overflow(coo::DynamicalCOO)

    return overflowEntries(coo) >= 0

end

function overflowEntries(coo::DynamicalCOO)

    return getDeviceIndex(coo._NOverflowInsert)

end

function overflowRows(coo::DynamicalCOO)

    return overflowEntries(coo)

end

function allocationRatio(coo::DynamicalCOO)

    nEntries = numberOfEntries(coo)
    nEntriesCache = numberOfEntriesCache(coo)

    if nEntriesCache == 0
        return 0.0
    else
        return nEntries / nEntriesCache
    end

end

function allocationsFailed(coo::DynamicalCOO{P}) where {P<:CPU}

    return false

end

function allocationsFailed(coo::DynamicalCOO{P}) where {P<:GPU}

    return getDeviceIndex(coo._NOverflowInsert) > 0 || getDeviceIndex(coo._NOverflowErase) > 0

end

function synchronize(coo::DynamicalCOO)

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

    # Resize if entries overflowed
    if length(coo._entriesFree) > length(coo._values)
        resize!(coo._entriesFree, length(coo._values))
    end

    return
end

function dropzeros!(coo::DynamicalCOO)

    @kernel function kernel_compact_zeros!(
            rows,
            cols,
            values,
            nEntries,
            nEntriesFree,
            nEntriesFreeNextInit,
            entriesFree
        )
        
        i = @index(Global)

        if values[i] == 0 && rows[i] != 0
            rows[i] = 0
            cols[i] = 0
            Atomix.@atomic nEntries[1] -= 1
            iFree = Atomix.@atomic nEntriesFree[1] += 1
            entriesFree[iFree] = i
            Atomix.@atomic nEntriesFreeNextInit[1] += 1
        end

    end

    CellBasedModels.synchronize(coo)

    backend = KernelAbstractions.get_backend(coo)
    threads = backend === CPU() ? Threads.nthreads() : 256
    kernel_compact_zeros!(backend, threads)(coo._rows, coo._cols, coo._values, coo._NEntries, coo._NEntriesFree, coo._NEntriesFreeNextInit, coo._entriesFree, ndrange = length(coo))

    return

end

function preallocate!(coo::DynamicalCOO; n_rows::Int=0, n_cols::Union{Int, <:AbstractArray{<:Int}}=1)

    @kernel function kernel_entriesFreePreallocate!(
            entriesFree,
            nEntriesFree,
            nEntriesFreeNew,
            dFreeCache,
        )
        
        i = @index(Global)

        if i > nEntriesFree && i <= nEntriesFreeNew
            entriesFree[i] = i + dFreeCache
        elseif i > nEntriesFreeNew
            entriesFree[i] = 0
        end
    end

    @assert n_rows >= 0 "n_rows must be >= 0"
    if n_cols isa Int
        @assert n_cols >= 0 "n_cols must be >= 0"
    else
        @assert all(n_cols .>= 0) "all elements of n_cols must be >= 0"
        @assert length(n_cols) == n_rows "length of n_cols must be == n_rows"
    end

    nEntriesCache = numberOfEntriesCache(coo)
    nEntries = numberOfEntries(coo)

    nEntriesNew = 0
    if n_cols isa AbstractArray{<:Int}
        nEntriesNew += sum(n_cols)*n_rows
    else
        nEntriesNew += n_cols*n_rows
    end

    CellBasedModels.synchronize(coo)

    nEntriesCacheNew = nEntriesCache + nEntriesNew
    resize!(coo._rows, nEntriesCacheNew)
    resize!(coo._cols, nEntriesCacheNew)
    resize!(coo._values, nEntriesCacheNew)
    resize!(coo._entriesFree, nEntriesCacheNew)

    @views coo._rows[nEntriesCache+1:end] .= 0
    @views coo._cols[nEntriesCache+1:end] .= 0
    @views coo._values[nEntriesCache+1:end] .= 0

    nEntriesFree = getDeviceIndex(coo._NEntriesFree)
    nEntriesFreeNew = nEntriesFree + nEntriesNew

    backend = KernelAbstractions.get_backend(coo)
    threads = backend === CPU() ? Threads.nthreads() : 256
    kernel_entriesFreePreallocate!(backend, threads)(coo._entriesFree, nEntriesFree, nEntriesFreeNew, nEntriesCache-nEntriesFree, ndrange = nEntriesCacheNew)
    KernelAbstractions.synchronize(backend)

    setDeviceIndex!(coo._NEntriesFree, nEntriesFreeNew)
    setDeviceIndex!(coo._NEntriesFreeNextInit, nEntriesFreeNew + 1)
    setDeviceIndex!(coo._NEntriesCache, nEntriesCacheNew)

    return

end

function compact!(coo::DynamicalCOO)

    @kernel function kernel_mark_surviving!(rows, surviving)
       
        i = @index(Global)

        if rows[i] == 0
            surviving[i] = 0
        else
            surviving[i] = 1
        end

    end

    @kernel function kernel_map!(origin, target, mapping, surviving)

        i = @index(Global)

        if surviving[i] == 1
            newPos = mapping[i]
            target[newPos] = origin[i]
        end

    end

    backend = KernelAbstractions.get_backend(coo)
    threads = backend === CPU() ? Threads.nthreads() : 256

    surviving = toBackend(backend, zeros(Int, length(coo)))
    mapping = copy(surviving)
    auxiliar_values = toBackend(backend, zeros(eltype(coo._values), length(coo)))
    auxiliar_cols = toBackend(backend, zeros(Int, length(coo)))

    kernel_mark_surviving!(backend, threads)(coo._rows, surviving, ndrange = length(coo))
    KernelAbstractions.synchronize(backend)

    cumsum!(mapping, surviving)
    nNonzero = sum(surviving) 

    kernel_map!(backend, threads)(coo._values, auxiliar_values, mapping, surviving, ndrange = length(coo))
    KernelAbstractions.synchronize(backend)
    coo._values .= auxiliar_values

    auxiliar_cols .= 0
    kernel_map!(backend, threads)(coo._cols, auxiliar_cols, mapping, surviving, ndrange = length(coo))
    KernelAbstractions.synchronize(backend)
    coo._cols .= auxiliar_cols

    auxiliar_cols .= 0
    kernel_map!(backend, threads)(coo._rows, auxiliar_cols, mapping, surviving, ndrange = length(coo))
    KernelAbstractions.synchronize(backend)
    coo._rows .= auxiliar_cols

    setDeviceIndex!(coo._NEntries, nNonzero)
    setDeviceIndex!(coo._NEntriesNonzero, nNonzero)
    setDeviceIndex!(coo._NOverflowInsert, 0)
    setDeviceIndex!(coo._NOverflowErase, 0)
    setDeviceIndex!(coo._NEntriesFree, length(coo)-nNonzero)
    setDeviceIndex!(coo._NEntriesFreeNextInit, length(coo)-nNonzero+1)
    setDeviceIndex!(coo._NEntriesFreeNext, 0)

    coo._entriesFree .= 0
    @view(coo._entriesFree[1:length(coo)-nNonzero]) .=  toBackend(backend, [i for i in length(coo):-1:nNonzero+1])

    return

end

function compactto!(cooTarget::DynamicalCOO{P, T}, coo::DynamicalCOO{P, T}) where {P, T}

    @kernel function kernel_mark_surviving!(rows, surviving)
       
        i = @index(Global)

        if rows[i] == 0
            surviving[i] = 0
        else
            surviving[i] = 1
        end

    end

    @kernel function kernel_map!(origin, target, mapping, surviving)

        i = @index(Global)

        if surviving[i] == 1
            newPos = mapping[i]
            target[newPos] = origin[i]
        end

    end

    lscr = length(coo)
    ldst = length(cooTarget)
    if ldst < lscr
        resize!(cooTarget._values, lscr)
        resize!(cooTarget._cols, lscr)
        resize!(cooTarget._rows, lscr)
        resize!(cooTarget._entriesFree, lscr)
    end

    backend = KernelAbstractions.get_backend(coo)
    threads = backend === CPU() ? Threads.nthreads() : 256

    surviving = toBackend(backend, zeros(Int, length(coo)))
    mapping = copy(surviving)

    kernel_mark_surviving!(backend, threads)(coo._rows, surviving, ndrange = length(coo))
    KernelAbstractions.synchronize(backend)

    cumsum!(mapping, surviving)
    nNonzero = sum(surviving) 

    cooTarget._values .= 0
    kernel_map!(backend, threads)(coo._values, cooTarget._values, mapping, surviving, ndrange = length(coo))

    cooTarget._cols .= 0
    kernel_map!(backend, threads)(coo._cols, cooTarget._cols, mapping, surviving, ndrange = length(coo))

    cooTarget._rows .= 0
    kernel_map!(backend, threads)(coo._rows, cooTarget._rows, mapping, surviving, ndrange = length(coo))

    setDeviceIndex!(cooTarget._NEntries, nNonzero)
    setDeviceIndex!(cooTarget._NEntriesCache, getDeviceIndex(coo._NEntriesCache))
    setDeviceIndex!(cooTarget._NEntriesNonzero, nNonzero)
    setDeviceIndex!(cooTarget._NOverflowInsert, 0)
    setDeviceIndex!(cooTarget._NOverflowErase, 0)
    setDeviceIndex!(cooTarget._NEntriesFree, length(coo)-nNonzero)
    setDeviceIndex!(cooTarget._NEntriesFreeNextInit, length(coo)-nNonzero+1)
    setDeviceIndex!(cooTarget._NEntriesFreeNext, 0)
    
    cooTarget._entriesFree .= 0
    @view(cooTarget._entriesFree[1:length(coo)-nNonzero]) .=  toBackend(KernelAbstractions.get_backend(cooTarget), [i for i in length(coo):-1:nNonzero+1])

    return

end

function Base.similar(coo::DynamicalCOO)

    dtype = eltype(coo._values)
    n_coo = length(coo)

    backend = KernelAbstractions.get_backend(coo)

    _rows = toBackend(backend, Array{Int}(undef, n_coo))
    _cols = toBackend(backend, Array{Int}(undef, n_coo))
    _values = toBackend(backend, Array{dtype}(undef, n_coo))
    _NEntries = toBackend(backend, Array{Int}(undef, 1))
    _NEntriesCache = toBackend(backend, Array{Int}(undef, 1))
    _NEntriesNonzero = toBackend(backend, Array{Int}(undef, 1))
    _NOverflowInsert = toBackend(backend, Array{Int}(undef, 1))
    _NOverflowErase = toBackend(backend, Array{Int}(undef, 1))
    _NEntriesFree = toBackend(backend, Array{Int}(undef, 1))
    _NEntriesFreeNextInit = toBackend(backend, Array{Int}(undef, 1))
    _NEntriesFreeNext = toBackend(backend, Array{Int}(undef, 1))
    _entriesFree = toBackend(backend, Array{Int}(undef, n_coo))
    if backend === CPU
        _lock = ReentrantLock()
    else
        _lock = nothing
    end

    return DynamicalCOO(
            _rows,
            _cols,
            _values,
            
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

function Base.copy(coo::DynamicalCOO)

    cooCopy = similar(coo)
    copyto!(cooCopy, coo)

    return cooCopy

end

function Base.copyto!(dest::DynamicalCOO{P, T}, src::DynamicalCOO{P, T}) where {P, T}

    lscr = length(src)
    ldst = length(dest)
    biggerdst = ldst > lscr
    if ldst < lscr
        resize!(dest._values, lscr)
        resize!(dest._cols, lscr)
        resize!(dest._rows, lscr)
        resize!(dest._entriesFree, lscr)
    end

    if biggerdst
        @views(dest._values[1:length(src)]) .= src._values
        @views(dest._values[length(src)+1:end]) .= 0
        @views(dest._cols[1:length(src)]) .= src._cols
        @views(dest._cols[length(src)+1:end]) .= 0
        @views(dest._rows[1:length(src)]) .= src._rows
        @views(dest._rows[length(src)+1:end]) .= 0
        @views(dest._entriesFree[1:length(src)]) .= src._entriesFree
        @views(dest._entriesFree[length(src)+1:end]) .= 0
    else
        dest._values .= src._values
        dest._cols .= src._cols
        dest._rows .= src._rows
        dest._entriesFree .= src._entriesFree
    end
    dest._NEntries .= src._NEntries
    dest._NEntriesCache .= src._NEntriesCache
    dest._NEntriesNonzero .= src._NEntriesNonzero
    dest._NOverflowInsert .= src._NOverflowInsert
    dest._NOverflowErase .= src._NOverflowErase
    dest._NEntriesFree .= src._NEntriesFree
    dest._NEntriesFreeNextInit .= src._NEntriesFreeNextInit
    dest._NEntriesFreeNext .= src._NEntriesFreeNext

    return dest

end

function dropcache!(coo::DynamicalCOO)

    compact!(coo)
    nEntriesNonzero = numberOfEntriesNonzero(coo)

    resize!(coo._rows, nEntriesNonzero)
    resize!(coo._cols, nEntriesNonzero)
    resize!(coo._values, nEntriesNonzero)
    resize!(coo._entriesFree, nEntriesNonzero)

    setDeviceIndex!(coo._NEntries, nEntriesNonzero)
    setDeviceIndex!(coo._NEntriesCache, nEntriesNonzero)
    setDeviceIndex!(coo._NEntriesNonzero, nEntriesNonzero)
    setDeviceIndex!(coo._NEntriesFree, nEntriesNonzero)
    setDeviceIndex!(coo._NEntriesFreeNextInit, nEntriesNonzero + 1)
    setDeviceIndex!(coo._NEntriesFreeNext, 0)

    coo._entriesFree .= 0

    return

end

function dropcacheto!(cooTarget::DynamicalCOO{P, T}, coo::DynamicalCOO{P, T}) where {P, T}

    compactto!(cooTarget, coo)
    nEntriesNonzero = numberOfEntriesNonzero(cooTarget)

    resize!(cooTarget._rows, nEntriesNonzero)
    resize!(cooTarget._cols, nEntriesNonzero)
    resize!(cooTarget._values, nEntriesNonzero)
    resize!(cooTarget._entriesFree, nEntriesNonzero)

    setDeviceIndex!(cooTarget._NEntries, nEntriesNonzero)
    setDeviceIndex!(cooTarget._NEntriesCache, nEntriesNonzero)
    setDeviceIndex!(cooTarget._NEntriesNonzero, nEntriesNonzero)
    setDeviceIndex!(cooTarget._NOverflowInsert, 0)
    setDeviceIndex!(cooTarget._NOverflowErase, 0)
    setDeviceIndex!(cooTarget._NEntriesFree, nEntriesNonzero)
    setDeviceIndex!(cooTarget._NEntriesFreeNextInit, nEntriesNonzero + 1)
    setDeviceIndex!(cooTarget._NEntriesFreeNext, 0)

    cooTarget._entriesFree .= 0

    return

end

function remaprows!(coo::DynamicalCOO, rowmap::AbstractVector{Int})

    @kernel function kernel_remap_rows!(rows, rowmap)
        
        i = @index(Global)
        
        if rows[i] != 0
            oldRow = rows[i]
            if oldRow <= length(rowmap)
                rows[i] = rowmap[oldRow]
            else
                @print "Row index $oldRow out of bounds for rowmap of length $(length(rowmap))\n"
            end
        end
        
    end

    rowmap = toBackend(KernelAbstractions.get_backend(coo), rowmap)

    backend = KernelAbstractions.get_backend(coo)
    threads = backend === CPU() ? Threads.nthreads() : 256
    kernel_remap_rows!(backend, threads)(coo._rows, rowmap, ndrange = length(coo))
    
    return

end

function remapcols!(coo::DynamicalCOO, colmap::AbstractVector{Int})

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
    
    colmap = toBackend(KernelAbstractions.get_backend(coo), colmap)

    backend = KernelAbstractions.get_backend(coo)
    threads = backend === CPU() ? Threads.nthreads() : 256
    kernel_remap_cols!(backend, threads)(coo._cols, colmap, ndrange = length(coo))
    
    return

end

function remap!(coo::DynamicalCOO, rowmap::AbstractVector{Int}, colmap::AbstractVector{Int})
    """
    Remap both row and column indices in a single pass.
    """

    @kernel function kernel_remap!(rows, cols, rowmap, colmap)
        
        i = @index(Global)
        
        if rows[i] != 0
            oldRow = rows[i]
            if oldRow <= length(rowmap)
                rows[i] = rowmap[oldRow]
            else
                @print "Row index $oldRow out of bounds for rowmap of length $(length(rowmap))\n"
            end
        end
        
        if cols[i] != 0
            oldCol = cols[i]
            if oldCol <= length(colmap)
                cols[i] = colmap[oldCol]
            else
                @print "Column index $oldCol out of bounds for colmap of length $(length(colmap))\n"
            end
        end
        
    end
    
    backend = KernelAbstractions.get_backend(coo)
    rowmap_backend = toBackend(backend, rowmap)
    colmap_backend = toBackend(backend, colmap)

    threads = backend === CPU() ? Threads.nthreads() : 256
    kernel_remap!(backend, threads)(coo._rows, coo._cols, rowmap_backend, colmap_backend, ndrange = length(coo))
    
    return

end

###################################################################################################
# Platform adaptation
###################################################################################################

KernelAbstractions.get_backend(coo::DynamicalCOO) = KernelAbstractions.get_backend(coo._values)

toBackend(::KernelAbstractions.CPU, coo::DynamicalCOO{P}) where {P<:KernelAbstractions.CPU} = coo

function toBackend(::KernelAbstractions.CPU, coo::DynamicalCOO{P, T}) where {P<:KernelAbstractions.GPU, T}
    DynamicalCOO(
        Vector(coo._values),
        Vector(coo._rows),
        Vector(coo._cols),
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
    
toBackend(::KernelAbstractions.GPU, coo::DynamicalCOO{P}) where {P<:KernelAbstractions.GPU} = coo

function toBackend(backend::KernelAbstractions.GPU, coo::DynamicalCOO{P}) where {P<:KernelAbstractions.CPU}
    DynamicalCOO(
        toBackend(backend, coo._values),
        toBackend(backend, coo._rows),
        toBackend(backend, coo._cols),
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