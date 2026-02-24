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
        offsets = collect(1:n_cols:n_cols*n_rows+1)
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
numberOfEntries(csr::DynamicalCSR{P}) where {P} = getDeviceIndex(csr._NEntries) + getDeviceIndex(csr._coo._NEntries)
numberOfEntriesCache(csr::DynamicalCSR{P}) where {P} = getDeviceIndex(csr._NEntriesCache)
numberOfEntriesNonzero(csr::DynamicalCSR{P}) where {P} = getDeviceIndex(csr._NEntriesNonzero) + getDeviceIndex(csr._coo.NEntriesNonzero)
numberOfRows(csr::DynamicalCSR{P}) where {P} = max(maximum(csr._coo._rows), length(csr._rowOffsets)-1)
numberOfCols(csr::DynamicalCSR{P}) where {P} = max(maximum(csr._cols), maximum(csr._coo._cols))

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
                    @atomic csr._NEntriesNonzero[1] += 1
                elseif old != 0 && value == 0
                    @atomic csr._NEntriesNonzero[1] -= 1
                end
                csr._values[k] = value
                return false
            end
        end
        # Loop not found, add new
        for k in startIdx:endIdx
            if csr._cols[k] == 0
                result = @atomicreplace csr._cols[k] 0 => j
                if result.success
                    csr._values[k] = value
                    if value != 0
                        @atomic csr._NEntriesNonzero[1] += 1
                    end
                    @atomic csr._NEntries[1] += 1
                end
                return true
            end
        end
    end

    # Not found, add new at coo
    @atomic csr._NOverflowInsert[1] += 1

    return setindex!(csr._coo, value, i, j)

end

function Base.setindex!(csr::DynamicalCSR{P}, ::Nothing, i::Int, j::Int) where {P<:CPU}

    nEntries = min(csr._NEntriesCache[1], csr._NEntries[1])

    # Search for i j in csr
    for k in 1:1:nEntries
        #Found
        if csr._rows[k] == i && csr._cols[k] == j
            result = @atomicreplace csr._rows[k] k => 0
            if result.success
                @atomic csr._NEntries[1] -= 1
                if csr._values[k] != 0
                    @atomic csr._NEntriesNonzero[1] -= 1
                end
                csr._cols[k] = 0
                csr._values[k] = zero(eltype(csr._values))
                # Add to free entries
                newFreePos = @atomic csr._NEntriesFreeNext[1] += 1
                newPos = csr._NEntriesFreeNextInit[1] + newFreePos
                if newPos <= length(csr._entriesFree)
                    csr._entriesFree[newPos-1] = k
                else
                    lock(csr._lock) do
                        push!(csr._entriesFree, k)
                        csr._NOverflowErase[1] += 1
                    end
                end
            end
        end
    end
    # Not found
    return false

end

function Base.setindex!(csr::DynamicalCSR{P}, ::Nothing, i::Int, j::Int) where {P<:GPU}

    nEntries = min(csr._NEntriesCache[1], csr._NEntries[1])

    # Search for i j in csr
    for k in 1:1:nEntries
        #Found
        if csr._rows[k] == i && csr._cols[k] == j
            result = @atomicreplace csr._rows[k] k => 0
            if result.success
                @atomic csr._NEntries[1] -= 1
                if csr._values[k] != 0
                    @atomic csr._NEntriesNonzero[1] -= 1
                end
                csr._cols[k] = 0
                csr._values[k] = zero(eltype(csr._values))
                # Add to free entries
                newFreePos = @atomic csr._NEntriesFreeNext[1] += 1
                newPos = csr._NEntriesFreeNextInit[1] + newFreePos
                if newPos <= length(csr._entriesFree)
                    csr._entriesFree[newPos-1] = k
                else
                    @atomic csr._NEntriesFreeNext[1] -= 1
                    @atomic csr._NOverflowErase[1] += 1
                end
            end
        end
    end
    # Not found
    return false

end

"""
    getindex(csr::DynamicalCSR, i::Int, j::Int)

Get the value at position (i, j) in the sparse matrix.
Returns 0 if the entry does not exist.
Allows syntax: value = x[i,j]
"""
function Base.getindex(csr::DynamicalCSR{P, T}, i::Int, j::Int) where {P, T}

    nEntries = min(numberOfEntries(csr), numberOfEntriesCache(csr))

    # Search for i j in csr
    for k in 1:1:nEntries
        if csr._rows[k] == i && csr._cols[k] == j
            return csr._values[k]
        end
    end
    
    # Column not found, return zero
    return zero(T)
end

function _getindex(csr::DynamicalCSR, i::Int, j::Int)

    nEntries = min(numberOfEntries(csr), numberOfEntriesCache(csr))

    # Search for i j in csr
    for k in 1:1:nEntries
        if csr._rows[k] == i && csr._cols[k] == j
            return csr._values[k]
        end
    end
    
    # Column not found, return zero
    return nothing
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

    chunk = getDeviceIndex(csr._NEntriesFreeNext)

    chunkNewInit = getDeviceIndex(csr._NEntriesFree) + 1
    chunkNewEnd = chunkNewInit + chunk

    chunkOldInit = getDeviceIndex(csr._NEntriesFreeNextInit)
    chunkOldEnd = chunkOldInit + chunk

    if chunk > 0
        @view(csr._entriesFree[chunkNewInit:chunkNewEnd]) .= @views(csr._entriesFree[chunkOldInit:chunkOldEnd])
        @views(csr._entriesFree[chunkOldInit+1:1:chunkOldEnd]) .= 0
    end

    setDeviceIndex!(csr._NEntriesFree, chunkNewEnd - 1)
    setDeviceIndex!(csr._NEntriesFreeNext, 0)
    setDeviceIndex!(csr._NEntriesFreeNextInit, chunkNewEnd)

    # Resize if entries overflowed
    if length(csr._entriesFree) > length(csr._values)
        resize!(csr._entriesFree, length(csr._values))
    end

    return
end

function dropzeros!(csr::DynamicalCSR)

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
            @atomic nEntries[1] -= 1
            iFree = @atomic nEntriesFree[1] += 1
            entriesFree[iFree] = i
            @atomic nEntriesFreeNextInit[1] += 1
        end

    end

    CellBasedModels.synchronize(csr)

    backend = KernelAbstractions.get_backend(csr)
    threads = backend === CPU() ? Threads.nthreads() : 256
    kernel_compact_zeros!(backend, threads)(csr._rows, csr._cols, csr._values, csr._NEntries, csr._NEntriesFree, csr._NEntriesFreeNextInit, csr._entriesFree, ndrange = length(csr))

    return

end

function preallocate!(csr::DynamicalCSR; n_rows::Int=0, n_cols::Union{Int, <:AbstractArray{<:Int}}=1)

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

    nEntriesCache = numberOfEntriesCache(csr)
    nEntries = numberOfEntries(csr)

    nEntriesNew = 0
    if n_cols isa AbstractArray{<:Int}
        nEntriesNew += sum(n_cols)*n_rows
    else
        nEntriesNew += n_cols*n_rows
    end

    CellBasedModels.synchronize(csr)

    nEntriesCacheNew = nEntriesCache + nEntriesNew
    resize!(csr._rows, nEntriesCacheNew)
    resize!(csr._cols, nEntriesCacheNew)
    resize!(csr._values, nEntriesCacheNew)
    resize!(csr._entriesFree, nEntriesCacheNew)

    @views csr._rows[nEntriesCache+1:end] .= 0
    @views csr._cols[nEntriesCache+1:end] .= 0
    @views csr._values[nEntriesCache+1:end] .= 0

    nEntriesFree = getDeviceIndex(csr._NEntriesFree)
    nEntriesFreeNew = nEntriesFree + nEntriesNew

    backend = KernelAbstractions.get_backend(csr)
    threads = backend === CPU() ? Threads.nthreads() : 256
    kernel_entriesFreePreallocate!(backend, threads)(csr._entriesFree, nEntriesFree, nEntriesFreeNew, nEntriesCache-nEntriesFree, ndrange = nEntriesCacheNew)
    KernelAbstractions.synchronize(backend)

    setDeviceIndex!(csr._NEntriesFree, nEntriesFreeNew)
    setDeviceIndex!(csr._NEntriesFreeNextInit, nEntriesFreeNew + 1)
    setDeviceIndex!(csr._NEntriesCache, nEntriesCacheNew)

    return

end

function compact!(csr::DynamicalCSR)

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

    backend = KernelAbstractions.get_backend(csr)
    threads = backend === CPU() ? Threads.nthreads() : 256

    surviving = toBackend(backend, zeros(Int, length(csr)))
    mapping = copy(surviving)
    auxiliar_values = toBackend(backend, zeros(eltype(csr._values), length(csr)))
    auxiliar_cols = toBackend(backend, zeros(Int, length(csr)))

    kernel_mark_surviving!(backend, threads)(csr._rows, surviving, ndrange = length(csr))
    KernelAbstractions.synchronize(backend)

    cumsum!(mapping, surviving)
    nNonzero = sum(surviving) 

    kernel_map!(backend, threads)(csr._values, auxiliar_values, mapping, surviving, ndrange = length(csr))
    KernelAbstractions.synchronize(backend)
    csr._values .= auxiliar_values

    auxiliar_cols .= 0
    kernel_map!(backend, threads)(csr._cols, auxiliar_cols, mapping, surviving, ndrange = length(csr))
    KernelAbstractions.synchronize(backend)
    csr._cols .= auxiliar_cols

    auxiliar_cols .= 0
    kernel_map!(backend, threads)(csr._rows, auxiliar_cols, mapping, surviving, ndrange = length(csr))
    KernelAbstractions.synchronize(backend)
    csr._rows .= auxiliar_cols

    setDeviceIndex!(csr._NEntries, nNonzero)
    setDeviceIndex!(csr._NEntriesNonzero, nNonzero)
    setDeviceIndex!(csr._NOverflowInsert, 0)
    setDeviceIndex!(csr._NOverflowErase, 0)
    setDeviceIndex!(csr._NEntriesFree, length(csr)-nNonzero)
    setDeviceIndex!(csr._NEntriesFreeNextInit, length(csr)-nNonzero+1)
    setDeviceIndex!(csr._NEntriesFreeNext, 0)

    csr._entriesFree .= 0
    @view(csr._entriesFree[1:length(csr)-nNonzero]) .=  toBackend(backend, [i for i in length(csr):-1:nNonzero+1])

    return

end

function compactto!(csrTarget::DynamicalCSR{P, T}, csr::DynamicalCSR{P, T}) where {P, T}

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

    lscr = length(csr)
    ldst = length(csrTarget)
    if ldst < lscr
        resize!(csrTarget._values, lscr)
        resize!(csrTarget._cols, lscr)
        resize!(csrTarget._rows, lscr)
        resize!(csrTarget._entriesFree, lscr)
    end

    backend = KernelAbstractions.get_backend(csr)
    threads = backend === CPU() ? Threads.nthreads() : 256

    surviving = toBackend(backend, zeros(Int, length(csr)))
    mapping = copy(surviving)

    kernel_mark_surviving!(backend, threads)(csr._rows, surviving, ndrange = length(csr))
    KernelAbstractions.synchronize(backend)

    cumsum!(mapping, surviving)
    nNonzero = sum(surviving) 

    csrTarget._values .= 0
    kernel_map!(backend, threads)(csr._values, csrTarget._values, mapping, surviving, ndrange = length(csr))

    csrTarget._cols .= 0
    kernel_map!(backend, threads)(csr._cols, csrTarget._cols, mapping, surviving, ndrange = length(csr))

    csrTarget._rows .= 0
    kernel_map!(backend, threads)(csr._rows, csrTarget._rows, mapping, surviving, ndrange = length(csr))

    setDeviceIndex!(csrTarget._NEntries, nNonzero)
    setDeviceIndex!(csrTarget._NEntriesCache, getDeviceIndex(csr._NEntriesCache))
    setDeviceIndex!(csrTarget._NEntriesNonzero, nNonzero)
    setDeviceIndex!(csrTarget._NOverflowInsert, 0)
    setDeviceIndex!(csrTarget._NOverflowErase, 0)
    setDeviceIndex!(csrTarget._NEntriesFree, length(csr)-nNonzero)
    setDeviceIndex!(csrTarget._NEntriesFreeNextInit, length(csr)-nNonzero+1)
    setDeviceIndex!(csrTarget._NEntriesFreeNext, 0)
    
    csrTarget._entriesFree .= 0
    @view(csrTarget._entriesFree[1:length(csr)-nNonzero]) .=  toBackend(KernelAbstractions.get_backend(csrTarget), [i for i in length(csr):-1:nNonzero+1])

    return

end

function Base.similar(csr::DynamicalCSR)

    dtype = eltype(csr._values)
    n_csr = length(csr)

    backend = KernelAbstractions.get_backend(csr)

    _rows = toBackend(backend, Array{Int}(undef, n_csr))
    _cols = toBackend(backend, Array{Int}(undef, n_csr))
    _values = toBackend(backend, Array{dtype}(undef, n_csr))
    _NEntries = toBackend(backend, Array{Int}(undef, 1))
    _NEntriesCache = toBackend(backend, Array{Int}(undef, 1))
    _NEntriesNonzero = toBackend(backend, Array{Int}(undef, 1))
    _NOverflowInsert = toBackend(backend, Array{Int}(undef, 1))
    _NOverflowErase = toBackend(backend, Array{Int}(undef, 1))
    _NEntriesFree = toBackend(backend, Array{Int}(undef, 1))
    _NEntriesFreeNextInit = toBackend(backend, Array{Int}(undef, 1))
    _NEntriesFreeNext = toBackend(backend, Array{Int}(undef, 1))
    _entriesFree = toBackend(backend, Array{Int}(undef, n_csr))
    if backend === CPU
        _lock = ReentrantLock()
    else
        _lock = nothing
    end

    return DynamicalCSR(
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

function Base.copy(csr::DynamicalCSR)

    csrCopy = similar(csr)
    copyto!(csrCopy, csr)

    return csrCopy

end

function Base.copyto!(dest::DynamicalCSR{P, T}, src::DynamicalCSR{P, T}) where {P, T}

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

function dropcache!(csr::DynamicalCSR)

    compact!(csr)
    nEntriesNonzero = numberOfEntriesNonzero(csr)

    resize!(csr._rows, nEntriesNonzero)
    resize!(csr._cols, nEntriesNonzero)
    resize!(csr._values, nEntriesNonzero)
    resize!(csr._entriesFree, nEntriesNonzero)

    setDeviceIndex!(csr._NEntries, nEntriesNonzero)
    setDeviceIndex!(csr._NEntriesCache, nEntriesNonzero)
    setDeviceIndex!(csr._NEntriesNonzero, nEntriesNonzero)
    setDeviceIndex!(csr._NEntriesFree, nEntriesNonzero)
    setDeviceIndex!(csr._NEntriesFreeNextInit, nEntriesNonzero + 1)
    setDeviceIndex!(csr._NEntriesFreeNext, 0)

    csr._entriesFree .= 0

    return

end

function dropcacheto!(csrTarget::DynamicalCSR{P, T}, csr::DynamicalCSR{P, T}) where {P, T}

    compactto!(csrTarget, csr)
    nEntriesNonzero = numberOfEntriesNonzero(csrTarget)

    resize!(csrTarget._rows, nEntriesNonzero)
    resize!(csrTarget._cols, nEntriesNonzero)
    resize!(csrTarget._values, nEntriesNonzero)
    resize!(csrTarget._entriesFree, nEntriesNonzero)

    setDeviceIndex!(csrTarget._NEntries, nEntriesNonzero)
    setDeviceIndex!(csrTarget._NEntriesCache, nEntriesNonzero)
    setDeviceIndex!(csrTarget._NEntriesNonzero, nEntriesNonzero)
    setDeviceIndex!(csrTarget._NOverflowInsert, 0)
    setDeviceIndex!(csrTarget._NOverflowErase, 0)
    setDeviceIndex!(csrTarget._NEntriesFree, nEntriesNonzero)
    setDeviceIndex!(csrTarget._NEntriesFreeNextInit, nEntriesNonzero + 1)
    setDeviceIndex!(csrTarget._NEntriesFreeNext, 0)

    csrTarget._entriesFree .= 0

    return

end

function remaprows!(csr::DynamicalCSR, rowmap::AbstractVector{Int})

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

    rowmap = toBackend(KernelAbstractions.get_backend(csr), rowmap)

    backend = KernelAbstractions.get_backend(csr)
    threads = backend === CPU() ? Threads.nthreads() : 256
    kernel_remap_rows!(backend, threads)(csr._rows, rowmap, ndrange = length(csr))
    
    return

end

function remapcols!(csr::DynamicalCSR, colmap::AbstractVector{Int})

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
    
    colmap = toBackend(KernelAbstractions.get_backend(csr), colmap)

    backend = KernelAbstractions.get_backend(csr)
    threads = backend === CPU() ? Threads.nthreads() : 256
    kernel_remap_cols!(backend, threads)(csr._cols, colmap, ndrange = length(csr))
    
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
