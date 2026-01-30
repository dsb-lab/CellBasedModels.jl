using KernelAbstractions

"""
    compress_zeros_blocked!(a; backend=CPU(), groupsize=256, zero_tail=true) -> newlen

Stable in-place compaction of nonzeros (removes zeros) using:
1) Pass 1: pack nonzeros within each workgroup tile (size = groupsize) and record per-tile counts
2) Host scan of counts (size = #tiles) to compute tile offsets
3) Pass 2: move each tile's packed segment to its final global position

Only allocates O(#tiles) global auxiliary arrays: `counts` and `offsets`.
Returns `newlen` (number of nonzeros). Optionally zero-fills the tail.
"""
function compress_zeros_blocked!(a; zeroElement=zero(eltype(a)), zero_tail::Bool=true)

    n = length(a)

    backend = KernelAbstractions.get_backend(a)
    groupsize = backend isa CPU() ? 256 : 256

    nb = cld(n, groupsize)

    counts  = KernelAbstractions.zeros(backend, Int, nb)
    offsets = KernelAbstractions.zeros(backend, Int, nb)

    # ---------------------------
    # Pass 1 kernel: per-tile pack
    # ---------------------------
    @kernel function pass1_blockpack!(a, counts, n, zeroElement)
        gid = @index(Group)     # 1-based
        lid = @index(Local)     # 1-based
        gs  = @groupsize()[1]

        start = (gid - 1) * gs + 1
        i = start + (lid - 1)

        vals = @localmem(eltype(a), gs)
        scan = @localmem(Int32, gs)

        x = (i <= n) ? a[i] : zeroElement
        vals[lid] = x
        scan[lid] = (x != 0) ? Int32(1) : Int32(0)
        @barrier()

        # inclusive scan (Hillis–Steele)
        offset = 1
        while offset < gs
            t = (lid > offset) ? scan[lid - offset] : Int32(0)
            @barrier()
            scan[lid] += t
            @barrier()
            offset <<= 1
        end

        # scatter into front of this tile
        if x != zeroElement
            pos = Int(scan[lid]) - 1
            a[start + pos] = x
        end
        @barrier()

        if lid == gs
            counts[gid] = Int(scan[lid])
        end
    end

    # ---------------------------
    # Pass 2 kernel: tile move
    # ---------------------------
    @kernel function pass2_blockmove!(a, counts, offsets, n)
        gid = @index(Group)
        lid = @index(Local)
        gs  = @groupsize()[1]

        start = (gid - 1) * gs + 1
        c = counts[gid]
        dest = offsets[gid] + 1  # offsets are 0-based

        buf = @localmem(eltype(a), gs)

        # stage packed segment from this tile
        if lid <= c
            buf[lid] = a[start + (lid - 1)]
        end
        @barrier()

        # write to final location
        if lid <= c && (dest + (lid - 1) <= n)
            a[dest + (lid - 1)] = buf[lid]
        end
    end

    # ---------------------------
    # Optional tail zero-fill
    # ---------------------------
    @kernel function fill_tail_zeros!(a, newlen, n, zeroElement)
        i = @index(Global)
        if i > newlen && i <= n
            a[i] = zeroElement
        end
    end

    # Launch pass 1
    pass1 = pass1_blockpack!(backend, groupsize)
    pass1(a, counts, n; ndrange=nb * groupsize)
    synchronize(backend)

    # Host scan over counts (O(#tiles), not O(n))
    counts_h = Array(counts)
    offsets_h = similar(counts_h)
    s = 0
    @inbounds for b in 1:nb
        offsets_h[b] = s
        s += counts_h[b]
    end
    newlen = s

    copyto!(offsets, offsets_h)

    # Launch pass 2
    pass2 = pass2_blockmove!(backend, groupsize)
    pass2(a, counts, offsets, n; ndrange=nb * groupsize)
    synchronize(backend)

    # Zero tail if requested
    if zero_tail
        fillk = fill_tail_zeros!(backend)
        fillk(a, newlen, n; ndrange=n)
        synchronize(backend)
    end

    return newlen
end
