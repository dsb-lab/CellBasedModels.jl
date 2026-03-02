@testset "DynamicalELL" begin

    function _dell_insert(ell)

        @kernel function insert_kernel!(ell)
            i = @index(Global)
            ell[1,1] = 5
            ell[3,5] = 12
            ell[2,3] = 7
        end

        backend = KernelAbstractions.get_backend(ell)
        threads = backend === CPU ? 1 : 256
        insert_kernel!(backend, threads)(ell, ndrange=1)
        KernelAbstractions.synchronize(backend)

    end

    function _dell_change(ell)

        @kernel function insert_kernel!(ell)
            i = @index(Global)
            ell[1,1] = 7
            ell[10,15] = 11
            ell[2,3] = 0
        end

        backend = KernelAbstractions.get_backend(ell)
        threads = backend === CPU ? 1 : 256
        insert_kernel!(backend, threads)(ell, ndrange=1)
        KernelAbstractions.synchronize(backend)

    end

    function _dell_remove(ell)

        @kernel function insert_kernel!(ell)
            i = @index(Global)
            ell[1,1] = nothing
            ell[1,3] = nothing
        end

        backend = KernelAbstractions.get_backend(ell)
        threads = backend === CPU ? 1 : 256
        insert_kernel!(backend, threads)(ell, ndrange=1)
        KernelAbstractions.synchronize(backend)

    end

    # Slicing test kernels
    function _dell_slice_setup(ell)
        @kernel function setup_kernel!(ell)
            i = @index(Global)
            ell[1,1] = 1.0
            ell[1,2] = 2.0
            ell[2,1] = 3.0
            ell[2,3] = 4.0
            ell[3,2] = 5.0
        end
        backend = KernelAbstractions.get_backend(ell)
        threads = backend === CPU ? 1 : 256
        setup_kernel!(backend, threads)(ell, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _dell_slice_row_value(ell)
        @kernel function slice_kernel!(ell)
            i = @index(Global)
            ell[1,:] = 0  # Set row 1 values to 0
        end
        backend = KernelAbstractions.get_backend(ell)
        threads = backend === CPU ? 1 : 256
        slice_kernel!(backend, threads)(ell, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _dell_slice_col_value(ell)
        @kernel function slice_kernel!(ell)
            i = @index(Global)
            ell[:,1] = 10  # Set column 1 values to 10
        end
        backend = KernelAbstractions.get_backend(ell)
        threads = backend === CPU ? 1 : 256
        slice_kernel!(backend, threads)(ell, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _dell_slice_row_remove(ell)
        @kernel function slice_kernel!(ell)
            i = @index(Global)
            ell[2,:] = nothing  # Remove row 2 entries
        end
        backend = KernelAbstractions.get_backend(ell)
        threads = backend === CPU ? 1 : 256
        slice_kernel!(backend, threads)(ell, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _dell_slice_col_remove(ell)
        @kernel function slice_kernel!(ell)
            i = @index(Global)
            ell[:,2] = nothing  # Remove column 2 entries
        end
        backend = KernelAbstractions.get_backend(ell)
        threads = backend === CPU ? 1 : 256
        slice_kernel!(backend, threads)(ell, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    for backend in backends
        # Build - 2 rows with 2 cols each
        ell = dell_zeros(Float64, 2, 2, 0)
        @test Array(ell._cols) == [0,0,0,0]
        @test Array(ell._values) == [0.0, 0.0, 0.0, 0.0]
        @test Array(ell._nRows) == [2]
        @test Array(ell._nColsPerRow) == [2]
        @test (Array(ell._NEntries), Array(ell._NEntriesCache), Array(ell._NEntriesNonzero)) == ([0],[4],[0])
        # To Device
        ell = toBackend(backend, ell)
        @test KernelAbstractions.get_backend(ell._values) === backend
        @test Array(ell._cols) == [0,0,0,0]
        @test Array(ell._values) == [0.0, 0.0, 0.0, 0.0]
        @test Array(ell._nRows) == [2]
        @test Array(ell._nColsPerRow) == [2]
        @test (Array(ell._NEntries), Array(ell._NEntriesCache), Array(ell._NEntriesNonzero)) == ([0],[4],[0])
        # Repeat To Device
        ell = toBackend(backend, ell)
        @test KernelAbstractions.get_backend(ell._values) === backend
        @test Array(ell._cols) == [0,0,0,0]
        @test Array(ell._values) == [0.0, 0.0, 0.0, 0.0]
        @test Array(ell._nRows) == [2]
        @test Array(ell._nColsPerRow) == [2]
        @test (Array(ell._NEntries), Array(ell._NEntriesCache), Array(ell._NEntriesNonzero)) == ([0],[4],[0])
        # Insert, overflow and allocations
        _dell_insert(ell)
        @test CellBasedModels.overflow(ell) == true
        @test CellBasedModels.overflowEntries(ell) == true  # row 3 goes to overflow
        @test CellBasedModels.overflowRows(ell) == true
        if CellBasedModels.allocationsFailed(ell) #In GPU should fail so you have to repeat
            # GPU: allocation failed, entry could NOT be stored in COO
            @test Array(ell._cols) == [1,0,3,0]
            @test Array(ell._values) == [5.0, 0.0, 7.0, 0.0]
            @test Array(ell._nRows) == [2]
            @test Array(ell._nColsPerRow) == [2]
            @test (Array(ell._NEntries), Array(ell._NEntriesCache), Array(ell._NEntriesNonzero)) == ([2],[4],[2])
            @test Array(ell._coo._rows) == []
            @test Array(ell._coo._cols) == []
            @test Array(ell._coo._values) == []
        else
            # CPU: allocation succeeded via push!, entry IS stored in COO
            @test Array(ell._cols) == [1,0,3,0]
            @test Array(ell._values) == [5.0, 0.0, 7.0, 0.0]
            @test Array(ell._nRows) == [2]
            @test Array(ell._nColsPerRow) == [2]
            @test (Array(ell._NEntries), Array(ell._NEntriesCache), Array(ell._NEntriesNonzero)) == ([2],[4],[2])
            @test Array(ell._coo._rows) == [3]
            @test Array(ell._coo._cols) == [5]
            @test Array(ell._coo._values) == [12.0]
        end
        # Insert without overflow (3 rows, 2 cols each, 2 COO slots)
        ell = dell_zeros(Float64, 3, 2, 2)
        ell = toBackend(backend, ell)
        _dell_insert(ell)  # [1,1]=5, [3,5]=12, [2,3]=7
        @test CellBasedModels.overflow(ell) == false  # row 3 col 5 fits in row 3's 2 slots
        @test CellBasedModels.allocationsFailed(ell) == false
        @test Array(ell._cols) == [1,0,3,0,5,0]  # row 1: [1,0], row 2: [3,0], row 3: [5,0]
        @test Array(ell._values) == [5.0, 0.0, 7.0, 0.0, 12.0, 0.0]
        @test Array(ell._nRows) == [3]
        @test Array(ell._nColsPerRow) == [2]
        @test (Array(ell._NEntries), Array(ell._NEntriesCache), Array(ell._NEntriesNonzero)) == ([3],[6],[3])
        @test Array(ell._NOverflowInsert) == [0]
        # lengths number of entries
        @test length(ell) == 6  # ELL array length
        @test CellBasedModels.numberOfEntries(ell) == 3  # 3 entries
        @test CellBasedModels.numberOfEntriesCache(ell) == 6  # ELL cache
        @test CellBasedModels.numberOfEntriesNonzero(ell) == 3
        @test CellBasedModels.numberOfRows(ell) == 3
        @test CellBasedModels.numberOfCols(ell) == 5  # max column
        @test CellBasedModels.numberOfColsPerRow(ell) == 2
        # Modify 
        _dell_change(ell)
        # After change: [1,1]=7 (update), [10,15]=11 (goes to COO), [2,3]=0 (value zeroed but col stays)
        @test Array(ell._cols) == [1, 0, 3, 0, 5, 0]  # cols unchanged
        @test Array(ell._values) == [7.0, 0.0, 0.0, 0.0, 12.0, 0.0]  # [1,1]=7, [2,3] value set to 0
        @test (Array(ell._NEntries), Array(ell._NEntriesCache), Array(ell._NEntriesNonzero)) == ([3],[6],[2])
        @test Array(ell._NOverflowInsert) == [1]  # One overflow insert to COO for [10,15]
        # Remove (ell[1,1] = nothing removes from ELL, ell[1,3] = nothing tries but col 3 not at [1,3])
        _dell_remove(ell)
        @test Array(ell._cols) == [0, 0, 3, 0, 5, 0]  # [1,1] removed
        @test Array(ell._values) == [0.0, 0.0, 0.0, 0.0, 12.0, 0.0]
        @test (Array(ell._NEntries), Array(ell._NEntriesCache), Array(ell._NEntriesNonzero)) == ([2],[6],[1])
        # synchronize (just syncs the embedded COO)
        ell = dell_zeros(Float64, 3, 1, 3)
        ell = toBackend(backend, ell)
        _dell_insert(ell)
        _dell_change(ell)
        CellBasedModels.synchronize(ell)
        # After insert [1,1]=5, [2,3]=7, [3,5]=12 then change [1,1]=7, [2,3]=0, [10,15]=11 (overflow)
        # ELL portion (3 rows, 1 col each)
        @test Array(ell._cols) == [1, 3, 5]  # row 1: [1], row 2: [3], row 3: [5]
        @test Array(ell._values) == [7.0, 0.0, 12.0]  # [1,1]=7, [2,3]=0, [3,5]=12
        @test Array(ell._nRows) == [3]
        @test Array(ell._nColsPerRow) == [1]
        @test (Array(ell._NEntries), Array(ell._NEntriesCache), Array(ell._NEntriesNonzero)) == ([3], [3], [2])
        @test Array(ell._NOverflowInsert) == [1]  # [10,15] went to overflow COO
        # Remove from ELL: [1,1]=nothing removes it, [1,3]=nothing not found
        _dell_remove(ell)
        @test Array(ell._cols) == [0, 3, 5]  # [1,1] removed
        @test Array(ell._values) == [0.0, 0.0, 12.0]
        @test (Array(ell._NEntries), Array(ell._NEntriesCache), Array(ell._NEntriesNonzero)) == ([2], [3], [1])
        # synchronize again 
        CellBasedModels.synchronize(ell)
        @test Array(ell._cols) == [0, 3, 5]
        @test Array(ell._values) == [0.0, 0.0, 12.0]
        # dropzeros! removes entries where value=0 but col!=0 (i.e., [2,3])
        CellBasedModels.dropzeros!(ell)
        @test Array(ell._cols) == [0, 0, 5]
        @test Array(ell._values) == [0.0, 0.0, 12.0]
        @test Array(ell._nRows) == [3]
        @test Array(ell._nColsPerRow) == [1]
        @test Array(ell._NEntries) == [1]
        @test Array(ell._NEntriesCache) == [3]
        @test Array(ell._NEntriesNonzero) == [1]
        @test Array(ell._NOverflowInsert) == [1]
        # preallocate! - add 2 rows (keeps same cols per row)
        CellBasedModels.preallocate!(ell, n_rows=2, n_cols=0)
        @test length(ell._cols) == 5  # 3 original + 2*1 new rows
        @test length(ell._values) == 5
        @test Array(ell._cols) == [0, 0, 5, 0, 0]
        @test Array(ell._values) == [0.0, 0.0, 12.0, 0.0, 0.0]
        @test Array(ell._nRows) == [5]  # 3 + 2
        @test Array(ell._nColsPerRow) == [1]  # unchanged
        @test Array(ell._NEntries) == [1]  # unchanged
        @test Array(ell._NEntriesCache) == [5]
        @test Array(ell._NEntriesNonzero) == [1]
        @test Array(ell._NOverflowInsert) == [1]
        # preallocate! - add 1 col per row (expands ALL rows)
        CellBasedModels.preallocate!(ell, n_rows=0, n_cols=1)
        @test length(ell._cols) == 10  # 5 rows * 2 cols each
        @test length(ell._values) == 10
        @test Array(ell._cols) == [0, 0, 0, 0, 5, 0, 0, 0, 0, 0]  # row 3 now at positions 5-6
        @test Array(ell._values) == [0.0, 0.0, 0.0, 0.0, 12.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        @test Array(ell._nRows) == [5]
        @test Array(ell._nColsPerRow) == [2]  # now 2 cols per row
        @test Array(ell._NEntriesCache) == [10]
        # similar
        ell2 = similar(ell)
        @test eltype(ell2._values) == eltype(ell._values)
        @test length(ell2._values) == length(ell._values)
        @test length(ell2._cols) == length(ell._cols)
        @test length(ell2._nRows) == 1
        @test length(ell2._nColsPerRow) == 1
        @test length(ell2._NEntries) == 1
        @test length(ell2._NEntriesCache) == 1
        @test length(ell2._NEntriesNonzero) == 1
        @test length(ell2._NOverflowInsert) == 1
        # compactto! - ell has one entry at row 3 (value 12.0, col 5)
        CellBasedModels.compactto!(ell2, ell)
        @test Array(ell2._cols)[5] == 5  # entry at row 3 position
        @test Array(ell2._values)[5] == 12.0
        @test Array(ell2._nRows) == [5]
        @test Array(ell2._nColsPerRow) == [2]
        @test Array(ell2._NEntries) == [1]
        @test Array(ell2._NEntriesCache) == [10]
        @test Array(ell2._NEntriesNonzero) == [1]
        @test Array(ell2._NOverflowInsert) == [0]
        # compact! - test on a fresh ELL
        ell3 = dell_zeros(Float64, 3, 2, 3)
        ell3 = toBackend(backend, ell3)
        _dell_insert(ell3)  # [1,1]=5, [3,5]=12, [2,3]=7
        CellBasedModels.compact!(ell3)
        # After compact: entries compacted within each row
        @test Array(ell3._cols) == [1, 0, 3, 0, 5, 0]  # entries at front of each row
        @test Array(ell3._values) == [5.0, 0.0, 7.0, 0.0, 12.0, 0.0]
        @test Array(ell3._nRows) == [3]
        @test Array(ell3._nColsPerRow) == [2]
        @test Array(ell3._NEntries) == [3]
        @test Array(ell3._NEntriesNonzero) == [3]
        @test Array(ell3._NOverflowInsert) == [0]
        # copyto!
        ell3 = similar(ell)
        copyto!(ell3, ell)
        @test Array(ell3._cols) == Array(ell._cols)
        @test Array(ell3._values) == Array(ell._values)
        @test Array(ell3._nRows) == Array(ell._nRows)
        @test Array(ell3._nColsPerRow) == Array(ell._nColsPerRow)
        @test Array(ell3._NEntries) == Array(ell._NEntries)
        @test Array(ell3._NEntriesCache) == Array(ell._NEntriesCache)
        @test Array(ell3._NEntriesNonzero) == Array(ell._NEntriesNonzero)
        @test Array(ell3._NOverflowInsert) == Array(ell._NOverflowInsert)
        # copy
        ell4 = copy(ell)
        @test Array(ell4._cols) == Array(ell._cols)
        @test Array(ell4._values) == Array(ell._values)
        @test Array(ell4._nRows) == Array(ell._nRows)
        @test Array(ell4._nColsPerRow) == Array(ell._nColsPerRow)
        @test Array(ell4._NEntries) == Array(ell._NEntries)
        @test Array(ell4._NEntriesCache) == Array(ell._NEntriesCache)
        @test Array(ell4._NEntriesNonzero) == Array(ell._NEntriesNonzero)
        @test Array(ell4._NOverflowInsert) == Array(ell._NOverflowInsert)
        # dropcacheto! - compacts and copies to remove cache
        nNonzero = Int(Array(ell._NEntriesNonzero)[1])  # Only ELL entries
        ell5 = similar(ell)
        CellBasedModels.dropcacheto!(ell5, ell)
        @test length(ell5._cols) == Array(ell5._nRows)[1] * Array(ell5._nColsPerRow)[1]
        @test length(ell5._values) == Array(ell5._nRows)[1] * Array(ell5._nColsPerRow)[1]
        @test Array(ell5._NEntries) == [nNonzero]
        @test Array(ell5._NEntriesNonzero) == [nNonzero]
        @test Array(ell5._NOverflowInsert) == [0]
        # dropcache! - compacts in place and removes cache
        nNonzeroBefore = Int(Array(ell._NEntriesNonzero)[1])
        CellBasedModels.dropcache!(ell)
        @test length(ell._cols) == Array(ell._nRows)[1] * Array(ell._nColsPerRow)[1]
        @test length(ell._values) == Array(ell._nRows)[1] * Array(ell._nColsPerRow)[1]
        @test Array(ell._NEntries) == [nNonzeroBefore]
        @test Array(ell._NEntriesNonzero) == [nNonzeroBefore]
        @test Array(ell._NOverflowInsert) == [0]
        # remapcols! - remap column indices (test on CPU only to avoid scalar indexing)
        ell_cpu = dell_zeros(Float64, 3, 2, 0)
        ell_cpu[1,1] = 5.0
        ell_cpu[2,2] = 7.0
        @test ell_cpu[1,1] == 5.0
        @test ell_cpu[2,2] == 7.0
        @test Array(ell_cpu._cols) == [1, 0, 2, 0, 0, 0]
        @test Array(ell_cpu._values) == [5.0, 0.0, 7.0, 0.0, 0.0, 0.0]
        @test Array(ell_cpu._NEntries) == [2]
        @test Array(ell_cpu._NEntriesNonzero) == [2]
        CellBasedModels.remapcols!(ell_cpu, [2, 1])  # swap columns 1<->2
        @test ell_cpu[1,2] == 5.0  # column 1 remapped to 2
        @test ell_cpu[2,1] == 7.0  # column 2 remapped to 1
        @test Array(ell_cpu._cols) == [2, 0, 1, 0, 0, 0]  # columns remapped
        @test Array(ell_cpu._values) == [5.0, 0.0, 7.0, 0.0, 0.0, 0.0]  # values unchanged
        @test Array(ell_cpu._NEntries) == [2]
        @test Array(ell_cpu._NEntriesNonzero) == [2]
        # remap! - combined row and column remapping
        ell_remap = dell_zeros(Float64, 3, 3, 2)  # 3 rows, 3 cols each, 2 overflow slots
        ell_remap = toBackend(backend, ell_remap)
        _dell_slice_setup(ell_remap)  # Sets up: [1,1]=1, [1,2]=2, [2,1]=3, [2,3]=4, [3,2]=5
        # Before remap
        @test Array(ell_remap._cols) == [1, 2, 0, 1, 3, 0, 2, 0, 0]
        @test Array(ell_remap._values) == [1.0, 2.0, 0.0, 3.0, 4.0, 0.0, 5.0, 0.0, 0.0]
        @test Array(ell_remap._nRows) == [3]
        @test Array(ell_remap._nColsPerRow) == [3]
        @test (Array(ell_remap._NEntries), Array(ell_remap._NEntriesCache), Array(ell_remap._NEntriesNonzero)) == ([5], [9], [5])
        @test Array(ell_remap._NOverflowInsert) == [0]
        # Apply remap!: rowmap=[3,1,2] rotates rows, colmap=[3,2,1] reverses cols
        CellBasedModels.remap!(ell_remap, [3, 1, 2], [3, 2, 1])
        # After remap: rows reordered, cols remapped
        @test Array(ell_remap._cols) == [2, 0, 0, 3, 2, 0, 3, 1, 0]
        @test Array(ell_remap._values) == [5.0, 0.0, 0.0, 1.0, 2.0, 0.0, 3.0, 4.0, 0.0]
        @test Array(ell_remap._nRows) == [3]
        @test Array(ell_remap._nColsPerRow) == [3]
        @test (Array(ell_remap._NEntries), Array(ell_remap._NEntriesCache), Array(ell_remap._NEntriesNonzero)) == ([5], [9], [5])
        @test Array(ell_remap._NOverflowInsert) == [0]
        # Test row/column slicing - using kernel functions
        ell_slice = dell_zeros(Float64, 3, 3, 2)
        ell_slice = toBackend(backend, ell_slice)
        _dell_slice_setup(ell_slice)
        # After setup: [1,1]=1, [1,2]=2, [2,1]=3, [2,3]=4, [3,2]=5
        @test Array(ell_slice._cols) == [1, 2, 0, 1, 3, 0, 2, 0, 0]
        @test Array(ell_slice._values) == [1.0, 2.0, 0.0, 3.0, 4.0, 0.0, 5.0, 0.0, 0.0]
        @test Array(ell_slice._nRows) == [3]
        @test Array(ell_slice._nColsPerRow) == [3]
        @test (Array(ell_slice._NEntries), Array(ell_slice._NEntriesCache), Array(ell_slice._NEntriesNonzero)) == ([5], [9], [5])
        @test Array(ell_slice._NOverflowInsert) == [0]
        # Set row 1 values to 0
        _dell_slice_row_value(ell_slice)
        @test Array(ell_slice._cols) == [1, 2, 0, 1, 3, 0, 2, 0, 0]
        @test Array(ell_slice._values) == [0.0, 0.0, 0.0, 3.0, 4.0, 0.0, 5.0, 0.0, 0.0]
        @test (Array(ell_slice._NEntries), Array(ell_slice._NEntriesCache), Array(ell_slice._NEntriesNonzero)) == ([5], [9], [3])
        @test Array(ell_slice._NOverflowInsert) == [0]
        # Set column 1 values to 10 (entries [1,1] and [2,1] exist)
        _dell_slice_col_value(ell_slice)
        @test Array(ell_slice._cols) == [1, 2, 0, 1, 3, 0, 2, 0, 0]
        @test Array(ell_slice._values) == [10.0, 0.0, 0.0, 10.0, 4.0, 0.0, 5.0, 0.0, 0.0]
        @test (Array(ell_slice._NEntries), Array(ell_slice._NEntriesCache), Array(ell_slice._NEntriesNonzero)) == ([5], [9], [4])
        @test Array(ell_slice._NOverflowInsert) == [0]
        # Remove row 2 entries
        _dell_slice_row_remove(ell_slice)
        @test Array(ell_slice._cols) == [1, 2, 0, 0, 0, 0, 2, 0, 0]
        @test Array(ell_slice._values) == [10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 5.0, 0.0, 0.0]
        @test (Array(ell_slice._NEntries), Array(ell_slice._NEntriesCache), Array(ell_slice._NEntriesNonzero)) == ([3], [9], [2])
        @test Array(ell_slice._NOverflowInsert) == [0]
        # Remove column 2 entries
        _dell_slice_col_remove(ell_slice)
        @test Array(ell_slice._cols) == [1, 0, 0, 0, 0, 0, 0, 0, 0]
        @test Array(ell_slice._values) == [10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        @test (Array(ell_slice._NEntries), Array(ell_slice._NEntriesCache), Array(ell_slice._NEntriesNonzero)) == ([1], [9], [1])
        @test Array(ell_slice._NOverflowInsert) == [0]
        # replaceIndex! - in-place index replacement (key ELL benefit: no column expansion)
        ell_replace = dell_zeros(Float64, 3, 3, 2)
        ell_replace = toBackend(backend, ell_replace)
        _dell_slice_setup(ell_replace)  # Sets up: [1,1]=1, [1,2]=2, [2,1]=3, [2,3]=4, [3,2]=5
        # Before replace: cols for row 1: [1,2,0], row 2: [1,3,0], row 3: [2,0,0]
        @test Array(ell_replace._cols) == [1, 2, 0, 1, 3, 0, 2, 0, 0]
        @test Array(ell_replace._values) == [1.0, 2.0, 0.0, 3.0, 4.0, 0.0, 5.0, 0.0, 0.0]
        @test Array(ell_replace._nRows) == [3]
        @test Array(ell_replace._nColsPerRow) == [3]
        @test (Array(ell_replace._NEntries), Array(ell_replace._NEntriesCache), Array(ell_replace._NEntriesNonzero)) == ([5], [9], [5])
        @test Array(ell_replace._NOverflowInsert) == [0]
        # Test same-row column replacement: [1,1] -> [1,5] (3-arg convenience form)
        # This is the key ELL benefit - just change column in place, no overflow
        result = CellBasedModels.replaceIndex!(ell_replace, 1, 1, 5)
        @test result == true
        @test Array(ell_replace._cols) == [5, 2, 0, 1, 3, 0, 2, 0, 0]  # col 1->5 at position 1
        @test Array(ell_replace._values) == [1.0, 2.0, 0.0, 3.0, 4.0, 0.0, 5.0, 0.0, 0.0]  # values unchanged
        @test Array(ell_replace._nRows) == [3]  # unchanged
        @test Array(ell_replace._nColsPerRow) == [3]  # unchanged, no expansion!
        @test (Array(ell_replace._NEntries), Array(ell_replace._NEntriesCache), Array(ell_replace._NEntriesNonzero)) == ([5], [9], [5])
        @test Array(ell_replace._NOverflowInsert) == [0]  # no overflow!
        # Test cross-row replacement within ELL: [2,1] -> [3,7] (5-arg full form)
        # This removes from row 2 and adds to row 3 (which has space)
        result = CellBasedModels.replaceIndex!(ell_replace, 2, 1, 3, 7)
        @test result == true
        @test Array(ell_replace._cols) == [5, 2, 0, 0, 3, 0, 2, 7, 0]  # row 2 col 1 removed, row 3 col 7 added
        @test Array(ell_replace._values) == [1.0, 2.0, 0.0, 0.0, 4.0, 0.0, 5.0, 3.0, 0.0]  # value 3.0 moved to row 3
        @test Array(ell_replace._nRows) == [3]
        @test Array(ell_replace._nColsPerRow) == [3]
        @test (Array(ell_replace._NEntries), Array(ell_replace._NEntriesCache), Array(ell_replace._NEntriesNonzero)) == ([5], [9], [5])
        @test Array(ell_replace._NOverflowInsert) == [0]  # no overflow needed
        # Test replacement on non-existent entry returns false
        result = CellBasedModels.replaceIndex!(ell_replace, 99, 99, 100, 100)
        @test result == false
        @test Array(ell_replace._cols) == [5, 2, 0, 0, 3, 0, 2, 7, 0]  # unchanged
        @test Array(ell_replace._values) == [1.0, 2.0, 0.0, 0.0, 4.0, 0.0, 5.0, 3.0, 0.0]  # unchanged
        @test Array(ell_replace._nRows) == [3]
        @test Array(ell_replace._nColsPerRow) == [3]
        @test (Array(ell_replace._NEntries), Array(ell_replace._NEntriesCache), Array(ell_replace._NEntriesNonzero)) == ([5], [9], [5])
        @test Array(ell_replace._NOverflowInsert) == [0]
        # Test replaceIndex! with zero value entry (should still work)
        ell_replace._values[2] = 0.0  # Make [1,2]=0 (still in ELL but zero value)
        Atomix.@atomic ell_replace._NEntriesNonzero[1] -= 1
        @test Array(ell_replace._values) == [1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 5.0, 3.0, 0.0]
        @test (Array(ell_replace._NEntriesNonzero)) == ([4])
        result = CellBasedModels.replaceIndex!(ell_replace, 1, 2, 1, 10)  # [1,2] -> [1,10]
        @test result == true
        @test Array(ell_replace._cols) == [5, 10, 0, 0, 3, 0, 2, 7, 0]  # col 2->10
        @test Array(ell_replace._values) == [1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 5.0, 3.0, 0.0]  # value still zero
        @test Array(ell_replace._nRows) == [3]
        @test Array(ell_replace._nColsPerRow) == [3]
        @test (Array(ell_replace._NEntries), Array(ell_replace._NEntriesCache), Array(ell_replace._NEntriesNonzero)) == ([5], [9], [4])  # nonzero unchanged
        @test Array(ell_replace._NOverflowInsert) == [0]
        # Test replaceIndex! cross-row that causes overflow to COO
        ell_replace2 = dell_zeros(Float64, 2, 1, 2)  # 2 rows, 1 col each, 2 COO slots
        ell_replace2 = toBackend(backend, ell_replace2)
        ell_replace2[1, 1] = 10.0
        ell_replace2[2, 2] = 20.0
        # Current state: row 1 full with col 1, row 2 full with col 2
        @test Array(ell_replace2._cols) == [1, 2]
        @test Array(ell_replace2._values) == [10.0, 20.0]
        @test Array(ell_replace2._nRows) == [2]
        @test Array(ell_replace2._nColsPerRow) == [1]
        @test (Array(ell_replace2._NEntries), Array(ell_replace2._NEntriesCache), Array(ell_replace2._NEntriesNonzero)) == ([2], [2], [2])
        @test Array(ell_replace2._NOverflowInsert) == [0]
        # Replace [1,1] -> [2,5], but row 2 is full, so should go to COO
        result = CellBasedModels.replaceIndex!(ell_replace2, 1, 1, 2, 5)
        @test result == true
        @test Array(ell_replace2._cols) == [0, 2]  # row 1 entry removed
        @test Array(ell_replace2._values) == [0.0, 20.0]
        @test Array(ell_replace2._nRows) == [2]
        @test Array(ell_replace2._nColsPerRow) == [1]  # columns NOT expanded!
        @test (Array(ell_replace2._NEntries), Array(ell_replace2._NEntriesCache), Array(ell_replace2._NEntriesNonzero)) == ([1], [2], [1])
        @test Array(ell_replace2._NOverflowInsert) == [1]  # overflow to COO
        @test Array(ell_replace2._coo._rows)[1] == 2
        @test Array(ell_replace2._coo._cols)[1] == 5
        @test Array(ell_replace2._coo._values)[1] == 10.0
        # Demonstrate key benefit: same-row replace NEVER overflows
        ell_replace3 = dell_zeros(Float64, 2, 1, 0)  # 2 rows, 1 col each, NO COO slots
        ell_replace3 = toBackend(backend, ell_replace3)
        ell_replace3[1, 1] = 100.0
        @test Array(ell_replace3._cols) == [1, 0]
        @test Array(ell_replace3._values) == [100.0, 0.0]
        @test Array(ell_replace3._nColsPerRow) == [1]
        @test Array(ell_replace3._NOverflowInsert) == [0]
        # Same-row column change: [1,1] -> [1,99] - no overflow, no expansion needed
        result = CellBasedModels.replaceIndex!(ell_replace3, 1, 1, 99)
        @test result == true
        @test Array(ell_replace3._cols) == [99, 0]  # col changed in place
        @test Array(ell_replace3._values) == [100.0, 0.0]  # value unchanged
        @test Array(ell_replace3._nColsPerRow) == [1]  # NO column expansion!
        @test Array(ell_replace3._NOverflowInsert) == [0]  # NO overflow!
    end

end
