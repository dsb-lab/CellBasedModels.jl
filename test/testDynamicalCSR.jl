@testset "DynamicalCSR" begin

    function _dcsr_insert(csr)

        @kernel function insert_kernel!(csr)
            i = @index(Global)
            csr[1,1] = 5
            csr[3,5] = 12
            csr[2,3] = 7
        end

        backend = KernelAbstractions.get_backend(csr)
        threads = backend === CPU ? 1 : 256
        insert_kernel!(backend, threads)(csr, ndrange=1)
        KernelAbstractions.synchronize(backend)

    end

    function _dcsr_change(csr)

        @kernel function insert_kernel!(csr)
            i = @index(Global)
            csr[1,1] = 7
            csr[10,15] = 11
            csr[2,3] = 0
        end

        backend = KernelAbstractions.get_backend(csr)
        threads = backend === CPU ? 1 : 256
        insert_kernel!(backend, threads)(csr, ndrange=1)
        KernelAbstractions.synchronize(backend)

    end

    function _dcsr_remove(csr)

        @kernel function insert_kernel!(csr)
            i = @index(Global)
            csr[1,1] = nothing
            csr[1,3] = nothing
        end

        backend = KernelAbstractions.get_backend(csr)
        threads = backend === CPU ? 1 : 256
        insert_kernel!(backend, threads)(csr, ndrange=1)
        KernelAbstractions.synchronize(backend)

    end

    # Slicing test kernels
    function _dcsr_slice_setup(csr)
        @kernel function setup_kernel!(csr)
            i = @index(Global)
            csr[1,1] = 1.0
            csr[1,2] = 2.0
            csr[2,1] = 3.0
            csr[2,3] = 4.0
            csr[3,2] = 5.0
        end
        backend = KernelAbstractions.get_backend(csr)
        threads = backend === CPU ? 1 : 256
        setup_kernel!(backend, threads)(csr, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _dcsr_slice_row_value(csr)
        @kernel function slice_kernel!(csr)
            i = @index(Global)
            csr[1,:] = 0  # Set row 1 values to 0
        end
        backend = KernelAbstractions.get_backend(csr)
        threads = backend === CPU ? 1 : 256
        slice_kernel!(backend, threads)(csr, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _dcsr_slice_col_value(csr)
        @kernel function slice_kernel!(csr)
            i = @index(Global)
            csr[:,1] = 10  # Set column 1 values to 10
        end
        backend = KernelAbstractions.get_backend(csr)
        threads = backend === CPU ? 1 : 256
        slice_kernel!(backend, threads)(csr, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _dcsr_slice_row_remove(csr)
        @kernel function slice_kernel!(csr)
            i = @index(Global)
            csr[2,:] = nothing  # Remove row 2 entries
        end
        backend = KernelAbstractions.get_backend(csr)
        threads = backend === CPU ? 1 : 256
        slice_kernel!(backend, threads)(csr, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _dcsr_slice_col_remove(csr)
        @kernel function slice_kernel!(csr)
            i = @index(Global)
            csr[:,2] = nothing  # Remove column 2 entries
        end
        backend = KernelAbstractions.get_backend(csr)
        threads = backend === CPU ? 1 : 256
        slice_kernel!(backend, threads)(csr, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    for backend in backends
        csr = dcsr_zeros(Float64, 2, 2, 0)
        # Build
        @test Array(csr._cols) == [0,0,0,0]
        @test Array(csr._values) == [0.0, 0.0, 0.0, 0.0]
        @test Array(csr._rowOffsets) == [1,3,5]
        @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([0],[4],[0])
        # To Device
        csr = toBackend(backend, csr)
        @test KernelAbstractions.get_backend(csr._values) === backend
        @test Array(csr._cols) == [0,0,0,0]
        @test Array(csr._values) == [0.0, 0.0, 0.0, 0.0]
        @test Array(csr._rowOffsets) == [1,3,5]
        @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([0],[4],[0])
        # Repeat To Device
        csr = toBackend(backend, csr)
        @test KernelAbstractions.get_backend(csr._values) === backend
        @test Array(csr._cols) == [0,0,0,0]
        @test Array(csr._values) == [0.0, 0.0, 0.0, 0.0]
        @test Array(csr._rowOffsets) == [1,3,5]
        @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([0],[4],[0])
        # Insert, overflow and allocations
        _dcsr_insert(csr)
        @test CellBasedModels.overflow(csr) == true
        @test CellBasedModels.overflowEntries(csr) == 1
        @test CellBasedModels.overflowRows(csr) == 1
        if CellBasedModels.allocationsFailed(csr) #In GPU should fail so you have to repeat
            # GPU: allocation failed, entry could NOT be stored in COO
            @test Array(csr._cols) == [1,0,3,0]
            @test Array(csr._values) == [5.0, 0.0, 7.0, 0.0]
            @test Array(csr._rowOffsets) == [1,3,5]
            @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([2],[4],[2])
            @test Array(csr._coo._rows) == []
            @test Array(csr._coo._cols) == []
            @test Array(csr._coo._values) == []
            @test CellBasedModels.allocationRatio(csr) == 0.75
        else
            # CPU: allocation succeeded via push!, entry IS stored in COO
            @test Array(csr._cols) == [1,0,3,0]
            @test Array(csr._values) == [5.0, 0.0, 7.0, 0.0]
            @test Array(csr._rowOffsets) == [1,3,5]
            @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([2],[4],[2])
            @test Array(csr._coo._rows) == [3]
            @test Array(csr._coo._cols) == [5]
            @test Array(csr._coo._values) == [12.0]
            @test CellBasedModels.allocationRatio(csr) == 0.75
        end
        # Insert without overflow
        csr = dcsr_zeros(Float64, 2, 2, 2)
        csr = toBackend(backend, csr)
        _dcsr_insert(csr)
        @test CellBasedModels.overflow(csr) == true
        @test CellBasedModels.overflowEntries(csr) == 1
        @test CellBasedModels.overflowRows(csr) == 1
        @test CellBasedModels.allocationsFailed(csr) == false
        @test Array(csr._cols) == [1,0,3,0]
        @test Array(csr._values) == [5.0, 0.0, 7.0, 0.0]
        @test Array(csr._rowOffsets) == [1,3,5]
        @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([2],[4],[2])
        @test Array(csr._coo._rows) == [3, 0]
        @test Array(csr._coo._cols) == [5, 0]
        @test Array(csr._coo._values) == [12.0, 0.0]
        # lengths number of entries (CSR has 2 in CSR + 1 in COO = 3 total)
        @test length(csr) == 4  # CSR array length
        @test CellBasedModels.numberOfEntries(csr) == 3  # 2 in CSR + 1 in COO
        @test CellBasedModels.numberOfEntriesCache(csr) == 4  # CSR cache only
        @test CellBasedModels.numberOfEntriesNonzero(csr) == 3  # 2 in CSR + 1 in COO
        @test CellBasedModels.numberOfRows(csr) == 3  # max(row 3 in COO, 2 rows in CSR)
        @test CellBasedModels.numberOfCols(csr) == 5  # max column (5 in COO)
        # Modify 
        _dcsr_change(csr)
        # After change: [1,1]=7 (update), [10,15]=11 (goes to COO), [2,3]=0 (value zeroed but col stays)
        @test Array(csr._cols) == [1, 0, 3, 0]  # [1,1] at k=1, [2,3] col stays at k=3 even though value=0
        @test Array(csr._values) == [7.0, 0.0, 0.0, 0.0]  # [1,1]=7, [2,3] value set to 0
        @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([2],[4],[1])  # 2 entries, 1 nonzero
        @test Array(csr._NOverflowInsert) == [2]  # Two overflow inserts to COO
        # Remove (csr[1,1] = nothing removes from CSR, csr[1,3] = nothing tries but col 3 not at [1,3])
        _dcsr_remove(csr)
        @test Array(csr._cols) == [0, 0, 3, 0]  # [1,1] removed, [2,3] still there (remove [1,3] didn't find it)
        @test Array(csr._values) == [0.0, 0.0, 0.0, 0.0]
        @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([1],[4],[0])  # 1 entry left ([2,3] with value 0)
        # synchronize (just syncs the embedded COO)
        csr = dcsr_zeros(Float64, 3, 1, 3)
        csr = toBackend(backend, csr)
        _dcsr_insert(csr)
        _dcsr_change(csr)
        CellBasedModels.synchronize(csr)
        # After insert [1,1]=5, [2,3]=7, [3,5]=12 then change [1,1]=7, [2,3]=0, [10,15]=11 (overflow)
        # CSR portion
        @test Array(csr._cols) == [1, 3, 5]
        @test Array(csr._values) == [7.0, 0.0, 12.0]
        @test Array(csr._rowOffsets) == [1, 2, 3, 4]
        @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([3], [3], [2])
        @test Array(csr._NOverflowInsert) == [1]  # Only [10,15] went to overflow COO
        # Remove from CSR: [1,1]=nothing removes it, [1,3]=nothing not found
        _dcsr_remove(csr)
        @test Array(csr._cols) == [0, 3, 5]  # [1,1] removed
        @test Array(csr._values) == [0.0, 0.0, 12.0]
        @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([2], [3], [1])
        # synchronize again 
        CellBasedModels.synchronize(csr)
        @test Array(csr._cols) == [0, 3, 5]
        @test Array(csr._values) == [0.0, 0.0, 12.0]
        # dropzeros! removes entries where value=0 but col!=0 (i.e., [2,3])
        CellBasedModels.dropzeros!(csr)
        @test Array(csr._cols) == [0, 0, 5]
        @test Array(csr._values) == [0.0, 0.0, 12.0]
        @test Array(csr._rowOffsets) == [1, 2, 3, 4]  # unchanged
        @test Array(csr._NEntries) == [1]
        @test Array(csr._NEntriesCache) == [3]  # unchanged
        @test Array(csr._NEntriesNonzero) == [1]
        @test Array(csr._NOverflowInsert) == [1]  # unchanged from previous _dcsr_change (overflow to COO for [10,15])
        # preallocate! - add 2 rows with 2 cols each
        CellBasedModels.preallocate!(csr, n_rows=2, n_cols=2)
        @test length(csr._cols) == 7  # 3 original + 2*2 new
        @test length(csr._values) == 7
        @test length(csr._rowOffsets) == 6  # 3 original rows + 2 new rows + 1
        @test Array(csr._cols) == [0, 0, 5, 0, 0, 0, 0]
        @test Array(csr._values) == [0.0, 0.0, 12.0, 0.0, 0.0, 0.0, 0.0]
        @test Array(csr._rowOffsets) == [1, 2, 3, 4, 6, 8]  # rows 4 and 5 have 2 cols each
        @test Array(csr._NEntries) == [1]  # unchanged
        @test Array(csr._NEntriesCache) == [7]
        @test Array(csr._NEntriesNonzero) == [1]  # unchanged
        @test Array(csr._NOverflowInsert) == [1]  # unchanged from before
        # preallocate! with variable cols per row
        CellBasedModels.preallocate!(csr, n_rows=2, n_cols=[1, 3])
        @test length(csr._cols) == 11  # 7 + 1 + 3
        @test length(csr._values) == 11
        @test length(csr._rowOffsets) == 8  # 6 + 2 new rows
        @test Array(csr._cols) == [0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0]
        @test Array(csr._values) == [0.0, 0.0, 12.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        @test Array(csr._rowOffsets) == [1, 2, 3, 4, 6, 8, 9, 12]
        @test Array(csr._NEntries) == [1]  # unchanged
        @test Array(csr._NEntriesCache) == [11]
        @test Array(csr._NEntriesNonzero) == [1]  # unchanged
        @test Array(csr._NOverflowInsert) == [1]  # unchanged from before
        # similar
        csr2 = similar(csr)
        @test eltype(csr2._values) == eltype(csr._values)
        @test length(csr2._values) == length(csr._values)
        @test length(csr2._cols) == length(csr._cols)
        @test length(csr2._rowOffsets) == length(csr._rowOffsets)
        @test length(csr2._NEntries) == 1
        @test length(csr2._NEntriesCache) == 1
        @test length(csr2._NEntriesNonzero) == 1
        @test length(csr2._NOverflowInsert) == 1
        # compactto! - csr has one entry at position 3 (value 12.0, col 5)
        CellBasedModels.compactto!(csr2, csr)
        # After compacting: entries compacted within each row, row offsets unchanged
        @test Array(csr2._cols)[3] == 5  # entry stays in row 3
        @test Array(csr2._values)[3] == 12.0
        @test Array(csr2._rowOffsets) == [1, 2, 3, 4, 6, 8, 9, 12]  # row offsets unchanged
        @test Array(csr2._NEntries) == [1]
        @test Array(csr2._NEntriesCache) == [11]
        @test Array(csr2._NEntriesNonzero) == [1]
        @test Array(csr2._NOverflowInsert) == [0]
        # compact! - test on a fresh CSR
        csr3 = dcsr_zeros(Float64, 3, 2, 3)
        csr3 = toBackend(backend, csr3)
        _dcsr_insert(csr3)  # Uses kernel: inserts [1,1]=5, [3,5]=12, [2,3]=7 - all fit in CSR (2 cols per row)
        CellBasedModels.compact!(csr3)
        # After compact: entries compacted within each row, row offsets unchanged
        @test Array(csr3._cols) == [1, 0, 3, 0, 5, 0]  # entries at front of each row
        @test Array(csr3._values) == [5.0, 0.0, 7.0, 0.0, 12.0, 0.0]
        @test Array(csr3._rowOffsets) == [1, 3, 5, 7]  # row offsets unchanged (3 rows, 2 cols each)
        @test Array(csr3._NEntries) == [3]  # 3 entries in CSR portion
        @test Array(csr3._NEntriesNonzero) == [3]  # 3 nonzero in CSR
        @test Array(csr3._NOverflowInsert) == [0]  # reset after compact
        # copyto!
        csr3 = similar(csr)
        copyto!(csr3, csr)
        @test Array(csr3._cols) == Array(csr._cols)
        @test Array(csr3._values) == Array(csr._values)
        @test Array(csr3._rowOffsets) == Array(csr._rowOffsets)
        @test Array(csr3._NEntries) == Array(csr._NEntries)
        @test Array(csr3._NEntriesCache) == Array(csr._NEntriesCache)
        @test Array(csr3._NEntriesNonzero) == Array(csr._NEntriesNonzero)
        @test Array(csr3._NOverflowInsert) == Array(csr._NOverflowInsert)
        # copy
        csr4 = copy(csr)
        @test Array(csr4._cols) == Array(csr._cols)
        @test Array(csr4._values) == Array(csr._values)
        @test Array(csr4._rowOffsets) == Array(csr._rowOffsets)
        @test Array(csr4._NEntries) == Array(csr._NEntries)
        @test Array(csr4._NEntriesCache) == Array(csr._NEntriesCache)
        @test Array(csr4._NEntriesNonzero) == Array(csr._NEntriesNonzero)
        @test Array(csr4._NOverflowInsert) == Array(csr._NOverflowInsert)
        # dropcacheto! - compacts and copies to remove cache
        nNonzero = Int(Array(csr._NEntriesNonzero)[1])  # Only CSR entries
        csr5 = similar(csr)
        CellBasedModels.dropcacheto!(csr5, csr)
        @test length(csr5._cols) == nNonzero
        @test length(csr5._values) == nNonzero
        @test Array(csr5._NEntries) == [nNonzero]
        @test Array(csr5._NEntriesCache) == [nNonzero]
        @test Array(csr5._NEntriesNonzero) == [nNonzero]
        @test Array(csr5._NOverflowInsert) == [0]
        # dropcache! - compacts in place and removes cache
        nNonzeroBefore = Int(Array(csr._NEntriesNonzero)[1])
        CellBasedModels.dropcache!(csr)
        @test length(csr._cols) == nNonzeroBefore
        @test length(csr._values) == nNonzeroBefore
        @test Array(csr._NEntries) == [nNonzeroBefore]
        @test Array(csr._NEntriesCache) == [nNonzeroBefore]
        @test Array(csr._NEntriesNonzero) == [nNonzeroBefore]
        @test Array(csr._NOverflowInsert) == [0]
        # remapcols! - remap column indices (test on CPU only to avoid scalar indexing)
        csr_cpu = dcsr_zeros(Float64, 3, 2, 0)
        csr_cpu[1,1] = 5.0
        csr_cpu[2,2] = 7.0
        @test csr_cpu[1,1] == 5.0
        @test csr_cpu[2,2] == 7.0
        @test Array(csr_cpu._cols) == [1, 0, 2, 0, 0, 0]
        @test Array(csr_cpu._values) == [5.0, 0.0, 7.0, 0.0, 0.0, 0.0]
        @test Array(csr_cpu._NEntries) == [2]
        @test Array(csr_cpu._NEntriesNonzero) == [2]
        CellBasedModels.remapcols!(csr_cpu, [2, 1])  # swap columns 1<->2
        @test csr_cpu[1,2] == 5.0  # column 1 remapped to 2
        @test csr_cpu[2,1] == 7.0  # column 2 remapped to 1
        @test Array(csr_cpu._cols) == [2, 0, 1, 0, 0, 0]  # columns remapped
        @test Array(csr_cpu._values) == [5.0, 0.0, 7.0, 0.0, 0.0, 0.0]  # values unchanged
        @test Array(csr_cpu._NEntries) == [2]  # counts unchanged
        @test Array(csr_cpu._NEntriesNonzero) == [2]
        # remap! - combined row and column remapping
        csr_remap = dcsr_zeros(Float64, 3, 3, 2)  # 3 rows, 3 cols each, 2 overflow slots
        csr_remap = toBackend(backend, csr_remap)
        _dcsr_slice_setup(csr_remap)  # Sets up: [1,1]=1, [1,2]=2, [2,1]=3, [2,3]=4, [3,2]=5
        # Before remap: row offsets=[1,4,7,10], we have 3 rows with 3 cols each
        @test Array(csr_remap._cols) == [1, 2, 0, 1, 3, 0, 2, 0, 0]
        @test Array(csr_remap._values) == [1.0, 2.0, 0.0, 3.0, 4.0, 0.0, 5.0, 0.0, 0.0]
        @test Array(csr_remap._rowOffsets) == [1, 4, 7, 10]
        @test (Array(csr_remap._NEntries), Array(csr_remap._NEntriesCache), Array(csr_remap._NEntriesNonzero)) == ([5], [9], [5])
        @test Array(csr_remap._NOverflowInsert) == [0]
        # Apply remap!: rowmap=[3,1,2] rotates rows (row 1->3, row 2->1, row 3->2)
        # colmap=[3,2,1] reverses cols (col 1->3, col 2->2, col 3->1)
        CellBasedModels.remap!(csr_remap, [3, 1, 2], [3, 2, 1])
        # After remap: physical row order changed, rows are now in order [old row 3, old row 1, old row 2]
        # New row 1 = old row 3: cols [2,0,0] -> [2,0,0], values [5,0,0]
        # New row 2 = old row 1: cols [1,2,0] -> [3,2,0], values [1,2,0]
        # New row 3 = old row 2: cols [1,3,0] -> [3,1,0], values [3,4,0]
        @test Array(csr_remap._cols) == [2, 0, 0, 3, 2, 0, 3, 1, 0]  # cols remapped
        @test Array(csr_remap._values) == [5.0, 0.0, 0.0, 1.0, 2.0, 0.0, 3.0, 4.0, 0.0]  # values reordered by row
        @test Array(csr_remap._rowOffsets) == [1, 4, 7, 10]  # row offsets unchanged (same cols per row)
        @test (Array(csr_remap._NEntries), Array(csr_remap._NEntriesCache), Array(csr_remap._NEntriesNonzero)) == ([5], [9], [5])  # counts unchanged
        @test Array(csr_remap._NOverflowInsert) == [0]  # no new overflow
        # Test remap! with overflow COO entries
        csr_remap_coo = dcsr_zeros(Float64, 2, 1, 3)  # 2 rows, 1 col each, 3 overflow slots
        csr_remap_coo = toBackend(backend, csr_remap_coo)
        _dcsr_insert(csr_remap_coo)  # Inserts [1,1]=5, [2,3]=7 in CSR (overflow), [3,5]=12 in COO
        # After insert: row 1=[1,0], row 2=[3,0] (only 1 fits), [3,5]=12 should be in COO
        @test CellBasedModels.overflow(csr_remap_coo) == true  # overflow occurred
        # COO entries should have [3,5]=12
        @test Array(csr_remap_coo._coo._rows)[1] == 3
        @test Array(csr_remap_coo._coo._cols)[1] == 5
        @test Array(csr_remap_coo._coo._values)[1] == 12.0
        # Apply remap!: rowmap=[2,1] swaps rows, colmap=[5,4,3,2,1] reverses cols
        CellBasedModels.remap!(csr_remap_coo, [2, 1], [5, 4, 3, 2, 1])
        # CSR: row 1 -> row 2 position, row 2 -> row 1 position, cols reversed
        # COO: row 3 -> should remap (3 > length(rowmap)=2, so row stays 3), col 5->1
        @test Array(csr_remap_coo._coo._cols)[1] == 1  # col 5 remapped to 1
        # Test row/column slicing - using kernel functions
        csr_slice = dcsr_zeros(Float64, 3, 3, 2)
        csr_slice = toBackend(backend, csr_slice)
        _dcsr_slice_setup(csr_slice)
        # After setup: [1,1]=1, [1,2]=2, [2,1]=3, [2,3]=4, [3,2]=5
        # Row 1: cols [1,2,0], Row 2: cols [1,3,0], Row 3: cols [2,0,0]
        @test Array(csr_slice._cols) == [1, 2, 0, 1, 3, 0, 2, 0, 0]
        @test Array(csr_slice._values) == [1.0, 2.0, 0.0, 3.0, 4.0, 0.0, 5.0, 0.0, 0.0]
        @test Array(csr_slice._rowOffsets) == [1, 4, 7, 10]
        @test (Array(csr_slice._NEntries), Array(csr_slice._NEntriesCache), Array(csr_slice._NEntriesNonzero)) == ([5], [9], [5])
        @test Array(csr_slice._NOverflowInsert) == [0]
        # Set row 1 values to 0
        _dcsr_slice_row_value(csr_slice)
        # After row 1 set to 0: [1,1]=0, [1,2]=0, [2,1]=3, [2,3]=4, [3,2]=5
        @test Array(csr_slice._cols) == [1, 2, 0, 1, 3, 0, 2, 0, 0]
        @test Array(csr_slice._values) == [0.0, 0.0, 0.0, 3.0, 4.0, 0.0, 5.0, 0.0, 0.0]
        @test Array(csr_slice._rowOffsets) == [1, 4, 7, 10]
        @test (Array(csr_slice._NEntries), Array(csr_slice._NEntriesCache), Array(csr_slice._NEntriesNonzero)) == ([5], [9], [3])
        @test Array(csr_slice._NOverflowInsert) == [0]
        # Set column 1 values to 10 (entries [1,1] and [2,1] exist)
        _dcsr_slice_col_value(csr_slice)
        # After column 1 set to 10: [1,1]=10, [1,2]=0, [2,1]=10, [2,3]=4, [3,2]=5
        @test Array(csr_slice._cols) == [1, 2, 0, 1, 3, 0, 2, 0, 0]
        @test Array(csr_slice._values) == [10.0, 0.0, 0.0, 10.0, 4.0, 0.0, 5.0, 0.0, 0.0]
        @test Array(csr_slice._rowOffsets) == [1, 4, 7, 10]
        @test (Array(csr_slice._NEntries), Array(csr_slice._NEntriesCache), Array(csr_slice._NEntriesNonzero)) == ([5], [9], [4])
        @test Array(csr_slice._NOverflowInsert) == [0]
        # Remove row 2 entries
        _dcsr_slice_row_remove(csr_slice)
        # After row 2 removed: [1,1]=10, [1,2]=0, [3,2]=5 remain
        @test Array(csr_slice._cols) == [1, 2, 0, 0, 0, 0, 2, 0, 0]
        @test Array(csr_slice._values) == [10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 5.0, 0.0, 0.0]
        @test Array(csr_slice._rowOffsets) == [1, 4, 7, 10]
        @test (Array(csr_slice._NEntries), Array(csr_slice._NEntriesCache), Array(csr_slice._NEntriesNonzero)) == ([3], [9], [2])
        @test Array(csr_slice._NOverflowInsert) == [0]
        # Remove column 2 entries
        _dcsr_slice_col_remove(csr_slice)
        # After column 2 removed: only [1,1]=10 remains
        @test Array(csr_slice._cols) == [1, 0, 0, 0, 0, 0, 0, 0, 0]
        @test Array(csr_slice._values) == [10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        @test Array(csr_slice._rowOffsets) == [1, 4, 7, 10]
        @test (Array(csr_slice._NEntries), Array(csr_slice._NEntriesCache), Array(csr_slice._NEntriesNonzero)) == ([1], [9], [1])
        @test Array(csr_slice._NOverflowInsert) == [0]
        # replaceIndex! - in-place index replacement
        csr_replace = dcsr_zeros(Float64, 3, 3, 2)
        csr_replace = toBackend(backend, csr_replace)
        _dcsr_slice_setup(csr_replace)  # Sets up: [1,1]=1, [1,2]=2, [2,1]=3, [2,3]=4, [3,2]=5
        # Before replace: Row 1: cols [1,2,0], Row 2: cols [1,3,0], Row 3: cols [2,0,0]
        @test Array(csr_replace._cols) == [1, 2, 0, 1, 3, 0, 2, 0, 0]
        @test Array(csr_replace._values) == [1.0, 2.0, 0.0, 3.0, 4.0, 0.0, 5.0, 0.0, 0.0]
        @test Array(csr_replace._rowOffsets) == [1, 4, 7, 10]
        @test (Array(csr_replace._NEntries), Array(csr_replace._NEntriesCache), Array(csr_replace._NEntriesNonzero)) == ([5], [9], [5])
        @test Array(csr_replace._NOverflowInsert) == [0]
        # Test same-row column replacement: [1,1] -> [1,5] (3-arg convenience form)
        result = CellBasedModels.replaceIndex!(csr_replace, 1, 1, 5)
        @test result == true
        @test Array(csr_replace._cols) == [5, 2, 0, 1, 3, 0, 2, 0, 0]  # col 1->5 at position 1
        @test Array(csr_replace._values) == [1.0, 2.0, 0.0, 3.0, 4.0, 0.0, 5.0, 0.0, 0.0]  # values unchanged
        @test Array(csr_replace._rowOffsets) == [1, 4, 7, 10]  # offsets unchanged
        @test (Array(csr_replace._NEntries), Array(csr_replace._NEntriesCache), Array(csr_replace._NEntriesNonzero)) == ([5], [9], [5])
        @test Array(csr_replace._NOverflowInsert) == [0]
        # Test cross-row replacement within CSR: [2,1] -> [3,7] (5-arg full form)
        # This removes from row 2 and adds to row 3 (which has space)
        result = CellBasedModels.replaceIndex!(csr_replace, 2, 1, 3, 7)
        @test result == true
        @test Array(csr_replace._cols) == [5, 2, 0, 0, 3, 0, 2, 7, 0]  # row 2 col 1 removed, row 3 col 7 added
        @test Array(csr_replace._values) == [1.0, 2.0, 0.0, 0.0, 4.0, 0.0, 5.0, 3.0, 0.0]  # value 3.0 moved to row 3
        @test Array(csr_replace._rowOffsets) == [1, 4, 7, 10]  # offsets unchanged
        @test (Array(csr_replace._NEntries), Array(csr_replace._NEntriesCache), Array(csr_replace._NEntriesNonzero)) == ([5], [9], [5])
        @test Array(csr_replace._NOverflowInsert) == [0]  # no overflow needed
        # Test replacement on non-existent entry returns false
        result = CellBasedModels.replaceIndex!(csr_replace, 99, 99, 100, 100)
        @test result == false
        @test Array(csr_replace._cols) == [5, 2, 0, 0, 3, 0, 2, 7, 0]  # unchanged
        @test Array(csr_replace._values) == [1.0, 2.0, 0.0, 0.0, 4.0, 0.0, 5.0, 3.0, 0.0]  # unchanged
        @test Array(csr_replace._rowOffsets) == [1, 4, 7, 10]
        @test (Array(csr_replace._NEntries), Array(csr_replace._NEntriesCache), Array(csr_replace._NEntriesNonzero)) == ([5], [9], [5])
        @test Array(csr_replace._NOverflowInsert) == [0]
        # Test replaceIndex! with zero value entry (should still work)
        csr_replace._values[2] = 0.0  # Make [1,2]=0 (still in CSR but zero value)
        Atomix.@atomic csr_replace._NEntriesNonzero[1] -= 1
        @test Array(csr_replace._values) == [1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 5.0, 3.0, 0.0]
        @test (Array(csr_replace._NEntriesNonzero)) == ([4])
        result = CellBasedModels.replaceIndex!(csr_replace, 1, 2, 1, 10)  # [1,2] -> [1,10]
        @test result == true
        @test Array(csr_replace._cols) == [5, 10, 0, 0, 3, 0, 2, 7, 0]  # col 2->10
        @test Array(csr_replace._values) == [1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 5.0, 3.0, 0.0]  # value still zero
        @test Array(csr_replace._rowOffsets) == [1, 4, 7, 10]
        @test (Array(csr_replace._NEntries), Array(csr_replace._NEntriesCache), Array(csr_replace._NEntriesNonzero)) == ([5], [9], [4])  # nonzero unchanged
        @test Array(csr_replace._NOverflowInsert) == [0]
        # Test replaceIndex! cross-row that causes overflow to COO
        csr_replace2 = dcsr_zeros(Float64, 2, 1, 2)  # 2 rows, 1 col each, 2 COO slots
        csr_replace2 = toBackend(backend, csr_replace2)
        csr_replace2[1, 1] = 10.0
        csr_replace2[2, 2] = 20.0
        # Current state: row 1 full with col 1, row 2 full with col 2
        @test Array(csr_replace2._cols) == [1, 2]
        @test Array(csr_replace2._values) == [10.0, 20.0]
        @test Array(csr_replace2._rowOffsets) == [1, 2, 3]
        @test (Array(csr_replace2._NEntries), Array(csr_replace2._NEntriesCache), Array(csr_replace2._NEntriesNonzero)) == ([2], [2], [2])
        @test Array(csr_replace2._NOverflowInsert) == [0]
        # Replace [1,1] -> [2,5], but row 2 is full, so should go to COO
        result = CellBasedModels.replaceIndex!(csr_replace2, 1, 1, 2, 5)
        @test result == true
        @test Array(csr_replace2._cols) == [0, 2]  # row 1 entry removed
        @test Array(csr_replace2._values) == [0.0, 20.0]
        @test (Array(csr_replace2._NEntries), Array(csr_replace2._NEntriesCache), Array(csr_replace2._NEntriesNonzero)) == ([1], [2], [1])
        @test Array(csr_replace2._NOverflowInsert) == [1]  # overflow to COO
        @test Array(csr_replace2._coo._rows)[1] == 2
        @test Array(csr_replace2._coo._cols)[1] == 5
        @test Array(csr_replace2._coo._values)[1] == 10.0
    end

end