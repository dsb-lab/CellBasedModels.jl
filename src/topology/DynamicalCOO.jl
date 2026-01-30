######################################################################################################
# DynamicalCOO - Fixed-size tuples (block size is a type parameter)
######################################################################################################
struct DynamicalCOO{
            P, T, V, I, L
        } <: AbstractSparseMatrix

    _values::V
    _rows::I
    _cols::I

    _NRows::I
    _NCols::I

    _NEntries::I
    _NEntriesCache::I
    _NEntriesNonzero::I

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

        _NRows,
        _NCols,
        
        _NEntries,
        _NEntriesCache,
        _NEntriesNonzero,
        
        _NEntriesFree,
        _NEntriesFreeNextInit,
        _NEntriesFreeNext,
        _entriesFree,

        _lock
    )
    
    P = platform()
    T = eltype(_values)
    V = typeof(_values)
    I = typeof(_NRows)
    L = typeof(_lock)

    DynamicalCOO{
            P, T, V, I, L
        }(
            _values,
            _rows,
            _cols,

            _NRows,
            _NCols,
            
            _NEntries,
            _NEntriesCache,
            _NEntriesNonzero,
            
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
    _NRows = Int[0]
    _NCols = Int[0]
    _NEntries = Int[0]
    _NEntriesCache = Int[n_coo]
    _NEntriesNonzero = Int[0]
    _NEntriesFree = Int[n_coo]
    _NEntriesFreeNextInit = Int[n_coo+1]
    _NEntriesFreeNext = Int[0]
    _entriesFree = [i for i in n_coo:-1:1]
    _lock = ReentrantLock()

    DynamicalCOO(
            _rows,
            _cols,
            _values,

            _NRows,
            _NCols,
            
            _NEntries,
            _NEntriesCache,
            _NEntriesNonzero,
            
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
    
    nrows = getDeviceIndex(x._NRows)
    ncols = getDeviceIndex(x._NCols)
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

Base.length(coo::DynamicalCOO{P}) where {P} = numberOfEntriesCache(coo)
numberOfEntries(coo::DynamicalCOO{P}) where {P<:CPU} = getDeviceIndex(coo._NEntries)
numberOfEntriesCache(coo::DynamicalCOO{P}) where {P<:CPU} = getDeviceIndex(coo._NEntriesCache)
numberOfEntriesNonzero(coo::DynamicalCOO{P}) where {P<:CPU} = getDeviceIndex(coo._NEntriesNonzero)
numberOfEntriesFree(coo::DynamicalCOO{P}) where {P<:CPU} = getDeviceIndex(coo._NEntriesFree)
numberOfEntriesFreeNext(coo::DynamicalCOO{P}) where {P<:CPU} = getDeviceIndex(coo._NEntriesFreeNext)

"""
    setindex!(coo::DynamicalCOO, value, i::Int, j::Int)

Set the value at position (i, j) in the sparse matrix.
Allows syntax: x[i,j] = value
"""
function Base.setindex!(coo::DynamicalCOO{P}, value, i::Int, j::Int) where {P<:CPU}

    nRows = getDeviceIndex(coo._NRows)
    nCols = getDeviceIndex(coo._NCols)
    nEntries = min(numberOfEntriesCache(coo), numberOfEntries(coo))

    if i <= 0 || j <= 0
        @print "Indices must be positive integers."
    end

    if i > nRows
        @atomic coo._NRows[1] = max(i, Array(coo._NRows)[1])
    end        

    if j > nCols
        @atomic coo._NCols[1] = max(j, Array(coo._NCols)[1])
    end

    # Search for i j in coo
    for k in 1:1:nEntries
        #Found
        if coo._rows[k] == i && coo._cols[k] == j
            old = coo._values[k]
            if old == 0 && value != 0
                @atomic coo._NEntriesNonzero[1] += 1
            elseif old != 0 && value == 0
                @atomic coo._NEntriesNonzero[1] -= 1
            end
            coo._values[k] = value
            return false
        end
    end
    # Not found, add new
    newFreePos = @atomic coo._NEntriesFree[1] -= 1
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
        end
    end
    @atomic coo._NEntries[1] += 1
    # Update cache
    if value != 0
        @atomic coo._NEntriesNonzero[1] += 1
    end

    return true
    
end

function Base.setindex!(coo::DynamicalCOO{P}, value, i::Int, j::Int) where {P<:GPU}

    nRows = getDeviceIndex(coo._NRows)
    nCols = getDeviceIndex(coo._NCols)
    nEntries = min(numberOfEntriesCache(coo), numberOfEntries(coo))

    if i <= 0 || j <= 0
        @print "Indices must be positive integers."
    end

    if i > nRows
        @atomic coo._NRows[1] = max(i, Array(coo._NRows)[1])
    end        

    if j > nCols
        @atomic coo._NCols[1] = max(j, Array(coo._NCols)[1])
    end

    # Search for i j in coo
    for k in 1:1:nEntries
        #Found
        if coo._coo[k][1] == i && coo._coo[k][2] == j
            old = coo._coo[k][3]
            if old == 0 && value != 0
                @atomic coo._NEntriesNonzero[1] += 1
            elseif old != 0 && value == 0
                @atomic coo._NEntriesNonzero[1] -= 1
            end
            coo._coo[k] = (i, j, value)
            return false
        end
    end
    # Not found, add new
    pos = @atomic coo._NEntries[1] = 1
    # If overflow
    if pos < coo._NEntriesCache[1]
        coo._rows[pos-1] = i
        coo._cols[pos-1] = j
        coo._values[pos-1] = value
    end
    # Update cache
    if value != 0
        @atomic coo._NEntriesNonzero[1] += 1
    end

    return true
    
end

function Base.setindex!(coo::DynamicalCOO{P}, ::Nothing, i::Int, j::Int) where {P<:CPU}

    nEntries = min(numberOfEntriesCache(coo), numberOfEntries(coo))

    # Search for i j in coo
    for k in 1:1:nEntries
        #Found
        if coo._rows[k] == i && coo._cols[k] == j
            result = @atomicreplace coo._rows[k] k => 0
            if result.success
                @atomic coo._NEntries[1] -= 1
                if coo._values[k] != 0
                    @atomic coo._NEntriesNonzero[1] -= 1
                end
                coo._cols[k] = 0
                coo._values[k] = zero(eltype(coo._values))
                # Add to free entries
                newFreePos = @atomic coo._NEntriesFreeNext[1] += 1
                newPos = coo._NEntriesFreeNextInit[1] + newFreePos - 1
                if newPos <= length(coo._entriesFree)
                    coo._entriesFree[newPos] = k
                else
                    lock(coo._lock) do
                        push!(coo._rows, 0)
                        push!(coo._cols, 0)
                        push!(coo._values, 0)
                        push!(coo._entriesFree, k)
                    end
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

function synchronize(coo::DynamicalCOO)

    chunk = getDeviceIndex(coo._NEntriesFreeNext) - 1

    if chunk >= 0

        chunkNewInit = max(getDeviceIndex(coo._NEntriesFree), 1)
        chunkNewEnd = chunkNewInit + chunk

        chunkOldInit = getDeviceIndex(coo._NEntriesFreeNextInit)
        chunkOldEnd = chunkOldInit + chunk

        @view(coo._entriesFree[chunkNewInit:chunkNewEnd]) .= @views(coo._entriesFree[chunkOldInit:chunkOldEnd])
        @views(coo._entriesFree[chunkOldInit:chunkOldEnd]) .= 0
        setDeviceIndex!(coo._NEntriesFree, chunkNewEnd)
        setDeviceIndex!(coo._NEntriesFreeNext, 0)
        setDeviceIndex!(coo._NEntriesFreeNextInit, chunkNewEnd + 1)

    end

    return
end

function dropzeros!(coo::DynamicalCOO{P, T}) where {P<:CPU, T}

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
            @print "Dropping zero at position $i\n"
            rows[i] = 0
            cols[i] = 0
            @atomic nEntries[1] -= 1
            iFree = @atomic nEntriesFree[1] += 1
            entriesFree[iFree] = i
            @atomic nEntriesFreeNextInit[1] += 1
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

    surviving = toDevice(backend, zeros(Int, length(coo)))
    mapping = copy(surviving)
    auxiliar_values = zeros(eltype(coo._values), length(coo))
    auxiliar_cols = zeros(Int, length(coo))

    kernel_mark_surviving!(backend, threads)(coo._rows, surviving, ndrange = length(coo))
    KernelAbstractions.synchronize(backend)

    cumsum!(mapping, surviving)
    nNonzero = sum(surviving) 

    kernel_map!(backend, threads)(coo._values, auxiliar_values, mapping, surviving, ndrange = length(coo))
    coo._values .= auxiliar_values

    auxiliar_cols .= 0
    kernel_map!(backend, threads)(coo._cols, auxiliar_cols, mapping, surviving, ndrange = length(coo))
    coo._cols .= auxiliar_cols

    auxiliar_cols .= 0
    kernel_map!(backend, threads)(coo._rows, auxiliar_cols, mapping, surviving, ndrange = length(coo))
    coo._rows .= auxiliar_cols

    setDeviceIndex!(coo._NEntries, nNonzero)
    setDeviceIndex!(coo._NEntriesNonzero, nNonzero)
    setDeviceIndex!(coo._NEntriesFree, length(coo)-nNonzero)
    setDeviceIndex!(coo._NEntriesFreeNextInit, length(coo)-nNonzero+1)
    setDeviceIndex!(coo._NEntriesFreeNext, 0)

    coo._entriesFree .= 0
    @view(coo._entriesFree[1:length(coo)-nNonzero]) .=  [i for i in length(coo):-1:nNonzero+1]

    return

end

function compactto!(coo::DynamicalCOO, cooTarget::DynamicalCOO)

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

    surviving = toDevice(backend, zeros(Int, length(coo)))
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
    setDeviceIndex!(cooTarget._NEntriesNonzero, nNonzero)
    setDeviceIndex!(cooTarget._NEntriesFree, length(coo)-nNonzero)
    setDeviceIndex!(cooTarget._NEntriesFreeNextInit, length(coo)-nNonzero+1)
    setDeviceIndex!(cooTarget._NEntriesFreeNext, 0)
    
    cooTarget._entriesFree .= 0
    @view(cooTarget._entriesFree[1:length(coo)-nNonzero]) .=  [i for i in length(coo):-1:nNonzero+1]

    return

end

function dropcache!(coo::DynamicalCOO)

    dropzeros!(coo)
    nEntries = numberOfEntries(coo)
    resize!(coo._coo, nEntries)
    coo._NEntries .= nEntries

    return

end

function overflowed(coo::DynamicalCOO)

    nEntriesCache = numberOfEntriesCache(coo)
    nEntries = numberOfEntries(coo)

    return nEntries > nEntriesCache

end

KernelAbstractions.get_backend(coo::DynamicalCOO) = KernelAbstractions.get_backend(coo._values)

toDevice(coo::DynamicalCOO{P}, ::Type{CPU}) where {P<:CPU} = coo

function toDevice(coo::DynamicalCOO{P, T}, ::Type{<:KernelAbstractions.CPU}) where {P<:GPU, T}
    DynamicalCOO(
        Vector(coo._coo),
        Vector(coo._NRows),
        Vector(coo._NCols),
        Vector(coo._NEntries)
    )
end

function toDevice(coo::DynamicalCOO{P}, backend::KernelAbstractions.CPU) where {P<:CPU}
    toDevice(coo, typeof(backend))
end

toDevice(coo::DynamicalCOO{P}, ::GPU) where {P<:GPU} = coo

function toDevice(coo::DynamicalCOO{P, T}, backend::Type{<:KernelAbstractions.GPU}) where {P<:CPU, T}
    DynamicalCOO(
        Adapt.adapt(backend, coo._coo),
        Adapt.adapt(backend, coo._NRows),
        Adapt.adapt(backend, coo._NCols),
        Adapt.adapt(backend, coo._NEntries)
    )
end

function toDevice(coo::DynamicalCOO{P}, backend::KernelAbstractions.GPU) where {P<:CPU}
    toDevice(coo, typeof(backend))
end

"""
    compress_zeros_blocked!(a; zeroElement=zero(eltype(a)), zero_tail=true) -> newlen

Parallel in-place compaction of nonzeros (removes `zeroElement`) using:
1) Pass 1: pack nonzeros within each workgroup tile and record per-tile counts
2) Host scan of counts to compute tile offsets
3) Pass 2: move each tile's packed segment to its final global position

Returns `newlen` (number of kept elements). Optionally zero-fills the tail.
"""
function compress_zeros_blocked!(a; zeroElement=zero(eltype(a)), zero_tail::Bool=true)


    return newlen
end
