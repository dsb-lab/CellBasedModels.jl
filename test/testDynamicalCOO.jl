@testset "DynamicalCOO" begin

    function _dcoo_insert(coo)

        @kernel function insert_kernel!(coo)
            i = @index(Global)
            coo[1,1] = 5
            coo[10,15] = 12
            coo[2,3] = 7
        end

        backend = KernelAbstractions.get_backend(coo)
        threads = backend === CPU ? 1 : 256
        insert_kernel!(backend, threads)(coo, ndrange=1)
        KernelAbstractions.synchronize(backend)

    end

    function _dcoo_change(coo)

        @kernel function insert_kernel!(coo)
            i = @index(Global)
            coo[1,1] = 7
            coo[10,15] = 11
            coo[2,3] = 0
        end

        backend = KernelAbstractions.get_backend(coo)
        threads = backend === CPU ? 1 : 256
        insert_kernel!(backend, threads)(coo, ndrange=1)
        KernelAbstractions.synchronize(backend)

    end

    function _dcoo_remove(coo)

        @kernel function insert_kernel!(coo)
            i = @index(Global)
            coo[1,1] = nothing
            coo[1,3] = nothing
        end

        backend = KernelAbstractions.get_backend(coo)
        threads = backend === CPU ? 1 : 256
        insert_kernel!(backend, threads)(coo, ndrange=1)
        KernelAbstractions.synchronize(backend)

    end

    # Slicing test kernels
    function _dcoo_slice_setup(coo)
        @kernel function setup_kernel!(coo)
            i = @index(Global)
            coo[1,1] = 1.0
            coo[1,2] = 2.0
            coo[2,1] = 3.0
            coo[2,3] = 4.0
        end
        backend = KernelAbstractions.get_backend(coo)
        threads = backend === CPU ? 1 : 256
        setup_kernel!(backend, threads)(coo, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _dcoo_slice_row_value(coo)
        @kernel function slice_kernel!(coo)
            i = @index(Global)
            coo[1,:] = 0  # Set row 1 values to 0
        end
        backend = KernelAbstractions.get_backend(coo)
        threads = backend === CPU ? 1 : 256
        slice_kernel!(backend, threads)(coo, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _dcoo_slice_col_value(coo)
        @kernel function slice_kernel!(coo)
            i = @index(Global)
            coo[:,1] = 10  # Set column 1 values to 10
        end
        backend = KernelAbstractions.get_backend(coo)
        threads = backend === CPU ? 1 : 256
        slice_kernel!(backend, threads)(coo, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _dcoo_slice_row_remove(coo)
        @kernel function slice_kernel!(coo)
            i = @index(Global)
            coo[2,:] = nothing  # Remove row 2 entries
        end
        backend = KernelAbstractions.get_backend(coo)
        threads = backend === CPU ? 1 : 256
        slice_kernel!(backend, threads)(coo, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _dcoo_slice_col_remove(coo)
        @kernel function slice_kernel!(coo)
            i = @index(Global)
            coo[:,2] = nothing  # Remove column 2 entries
        end
        backend = KernelAbstractions.get_backend(coo)
        threads = backend === CPU ? 1 : 256
        slice_kernel!(backend, threads)(coo, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    for backend in backends
        coo = dcoo_zeros(Float64, 2)
        # Build
        @test Array(coo._rows) == [0,0]
        @test Array(coo._cols) == [0,0]
        @test Array(coo._values) == [0.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([0],[2],[0])
        @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([0],[0])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([2],[3],[0])
        @test (Array(coo._entriesFree)) == [2,1]
        # To Device
        coo = toBackend(backend, coo)
        @test KernelAbstractions.get_backend(coo._values) === backend
        @test Array(coo._rows) == [0,0]
        @test Array(coo._cols) == [0,0]
        @test Array(coo._values) == [0.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([0],[2],[0])
        @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([0],[0])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([2],[3],[0])
        @test (Array(coo._entriesFree)) == [2,1]
        # Repeat To Device
        coo = toBackend(backend, coo)
        @test KernelAbstractions.get_backend(coo._values) === backend
        @test Array(coo._rows) == [0,0]
        @test Array(coo._cols) == [0,0]
        @test Array(coo._values) == [0.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([0],[2],[0])
        @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([0],[0])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([2],[3],[0])
        @test (Array(coo._entriesFree)) == [2,1]
        # Insert, overflow and allocations
        _dcoo_insert(coo)
        @test CellBasedModels.overflow(coo) == true
        @test CellBasedModels.overflowEntries(coo) == 1
        @test CellBasedModels.overflowRows(coo) == 1
        if CellBasedModels.allocationsFailed(coo) #In GPU should fail so you have to repeat
            @test Array(coo._rows) == [1,10]
            @test Array(coo._cols) == [1,15]
            @test Array(coo._values) == [5.0, 12.0]
            @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([3],[2],[3])
            @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([1],[0])
            @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([0],[3],[0])
            @test (Array(coo._entriesFree)) == [0,0]
            @test CellBasedModels.allocationRatio(coo) == 3.0/2.0
        else
            @test Array(coo._rows) == [1,10,2]
            @test Array(coo._cols) == [1,15,3]
            @test Array(coo._values) == [5.0, 12.0, 7.0]
            @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([3],[3],[3])
            @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([1],[0])
            @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([0],[3],[0])
            @test (Array(coo._entriesFree)) == [0,0,0]
            @test CellBasedModels.allocationRatio(coo) == 1.0
        end
        # Insert without overflow
        coo = dcoo_zeros(Float64, 3)
        coo = toBackend(backend, coo)
        _dcoo_insert(coo)
        @test Array(coo._rows) == [1,10,2]
        @test Array(coo._cols) == [1,15,3]
        @test Array(coo._values) == [5.0, 12.0, 7.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([3],[3],[3])
        @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([0],[0])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([0],[4],[0])
        @test (Array(coo._entriesFree)) == [0,0,0]
        # lengths number of entries
        @test length(coo) == 3
        @test CellBasedModels.numberOfEntries(coo) == 3
        @test CellBasedModels.numberOfEntriesCache(coo) == 3
        @test CellBasedModels.numberOfEntriesNonzero(coo) == 3
        @test CellBasedModels.numberOfRows(coo) == 10
        @test CellBasedModels.numberOfCols(coo) == 15
        # Modify 
        _dcoo_change(coo)
        @test Array(coo._rows) == [1,10,2]
        @test Array(coo._cols) == [1,15,3]
        @test Array(coo._values) == [7.0, 11.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([3],[3],[2])
        @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([0],[0])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([0],[4],[0])
        @test (Array(coo._entriesFree)) == [0,0,0]
        # Remove with overflow
        _dcoo_remove(coo)
        @test CellBasedModels.overflow(coo) == true
        @test CellBasedModels.overflowEntries(coo) == 0
        @test CellBasedModels.overflowRows(coo) == 0
        if CellBasedModels.allocationsFailed(coo) #In GPU should fail so you have to repeat
            @test Array(coo._rows) == [0,10,2]
            @test Array(coo._cols) == [0,15,3]
            @test Array(coo._values) == [0.0, 11.0, 0.0]
            @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([2],[3],[1])
            @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([0],[1])
            @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([0],[4],[0])
            @test (Array(coo._entriesFree)) == [0,0,0]
        else
            @test Array(coo._rows) == [0,10,2]
            @test Array(coo._cols) == [0,15,3]
            @test Array(coo._values) == [0.0, 11.0, 0.0]
            @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([2],[3],[1])
            @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([0],[1])
            @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([0],[4],[1])
            @test (Array(coo._entriesFree)) == [0,0,0,1]
        end
        # synchronize
        coo = dcoo_zeros(Float64, 3)
        coo = toBackend(backend, coo)
        _dcoo_insert(coo)
        _dcoo_change(coo)
        CellBasedModels.synchronize(coo)
        @test Array(coo._rows) == [1,10,2]
        @test Array(coo._cols) == [1,15,3]
        @test Array(coo._values) == [7.0, 11.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([3],[3],[2])
        @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([0],[0])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([0],[1],[0])
        @test (Array(coo._entriesFree)) == [0,0,0]
        # Remove without overflow
        _dcoo_remove(coo)
        @test Array(coo._rows) == [0,10,2]
        @test Array(coo._cols) == [0,15,3]
        @test Array(coo._values) == [0.0, 11.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([2],[3],[1])
        @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([0],[0])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([0],[1],[1])
        @test (Array(coo._entriesFree)) == [1,0,0]
        # synchronize
        CellBasedModels.synchronize(coo)
        @test Array(coo._rows) == [0,10,2]
        @test Array(coo._cols) == [0,15,3]
        @test Array(coo._values) == [0.0, 11.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([2],[3],[1])
        @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([0],[0])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([1],[2],[0])
        @test (Array(coo._entriesFree)) == [1,0,0]
        # dropzeros!
        CellBasedModels.dropzeros!(coo)
        @test Array(coo._rows) == [0,10,0]
        @test Array(coo._cols) == [0,15,0]
        @test Array(coo._values) == [0.0, 11.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([1],[3],[1])
        @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([0],[0])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([2],[3],[0])
        @test (Array(coo._entriesFree)) == [1,3,0]
        # preallocate!
        CellBasedModels.preallocate!(coo, n_rows=2)
        @test Array(coo._rows) == [0,10,0,0,0]
        @test Array(coo._cols) == [0,15,0,0,0]
        @test Array(coo._values) == [0.0, 11.0, 0.0, 0.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([1],[5],[1])
        @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([0],[0])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([4],[5],[0])
        @test (Array(coo._entriesFree)) == [1,3,4,5,0]
        # similar
        coo2 = similar(coo)
        @test eltype(coo2._values) == eltype(coo._values)
        @test length(coo2._values) == length(coo._values)
        @test length(coo2._rows) == length(coo._rows)
        @test length(coo2._cols) == length(coo._cols)
        @test length(coo2._entriesFree) == length(coo._entriesFree)
        # compactto!
        CellBasedModels.compactto!(coo2, coo)
        @test Array(coo2._rows) == [10,0,0,0,0]
        @test Array(coo2._cols) == [15,0,0,0,0]
        @test Array(coo2._values) == [11.0, 0.0, 0.0, 0.0, 0.0]
        @test (Array(coo2._NEntries), Array(coo2._NEntriesCache), Array(coo2._NEntriesNonzero)) == ([1],[5],[1])
        @test (Array(coo2._NOverflowInsert), Array(coo2._NOverflowErase)) == ([0],[0])
        @test (Array(coo2._NEntriesFree), Array(coo2._NEntriesFreeNextInit), Array(coo2._NEntriesFreeNext)) == ([4],[5],[0])
        @test (Array(coo2._entriesFree)) == [5,4,3,2,0]
        # compact!
        CellBasedModels.compact!(coo)
        @test Array(coo._rows) == [10,0,0,0,0]
        @test Array(coo._cols) == [15,0,0,0,0]
        @test Array(coo._values) == [11.0, 0.0, 0.0, 0.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([1],[5],[1])
        @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([0],[0])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([4],[5],[0])
        @test (Array(coo._entriesFree)) == [5,4,3,2,0]
        # copyto!
        coo3 = similar(coo)
        copyto!(coo3, coo)
        @test Array(coo3._rows) == [10,0,0,0,0]
        @test Array(coo3._cols) == [15,0,0,0,0]
        @test Array(coo3._values) == [11.0, 0.0, 0.0, 0.0, 0.0]
        @test (Array(coo3._NEntries), Array(coo3._NEntriesCache), Array(coo3._NEntriesNonzero)) == ([1],[5],[1])
        @test (Array(coo3._NOverflowInsert), Array(coo3._NOverflowErase)) == ([0],[0])
        @test (Array(coo3._NEntriesFree), Array(coo3._NEntriesFreeNextInit), Array(coo3._NEntriesFreeNext)) == ([4],[5],[0])
        @test (Array(coo3._entriesFree)) == [5,4,3,2,0]
        # copy
        coo4 = copy(coo)
        @test Array(coo4._rows) == [10,0,0,0,0]
        @test Array(coo4._cols) == [15,0,0,0,0]
        @test Array(coo4._values) == [11.0, 0.0, 0.0, 0.0, 0.0]
        @test (Array(coo4._NEntries), Array(coo4._NEntriesCache), Array(coo4._NEntriesNonzero)) == ([1],[5],[1])
        @test (Array(coo4._NOverflowInsert), Array(coo4._NOverflowErase)) == ([0],[0])
        @test (Array(coo4._NEntriesFree), Array(coo4._NEntriesFreeNextInit), Array(coo4._NEntriesFreeNext)) == ([4],[5],[0])
        @test (Array(coo4._entriesFree)) == [5,4,3,2,0]
        # dropcacheto!
        coo5 = similar(coo)
        CellBasedModels.dropcacheto!(coo5, coo)
        @test Array(coo5._rows) == [10]
        @test Array(coo5._cols) == [15]
        @test Array(coo5._values) == [11.0]
        @test (Array(coo5._NEntries), Array(coo5._NEntriesCache), Array(coo5._NEntriesNonzero)) == ([1],[1],[1])
        @test (Array(coo5._NOverflowInsert), Array(coo5._NOverflowErase)) == ([0],[0])
        @test (Array(coo5._NEntriesFree), Array(coo5._NEntriesFreeNextInit), Array(coo5._NEntriesFreeNext)) == ([1],[2],[0])
        @test (Array(coo5._entriesFree)) == [0]
        # dropcache!
        CellBasedModels.dropcache!(coo)
        @test Array(coo._rows) == [10]
        @test Array(coo._cols) == [15]
        @test Array(coo._values) == [11.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([1],[1],[1])
        @test (Array(coo._NOverflowInsert), Array(coo._NOverflowErase)) == ([0],[0])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([1],[2],[0])
        @test (Array(coo._entriesFree)) == [0]
        # remaprows!
        CellBasedModels.remaprows!(coo, [i for i in 10:-1:1])
        @test Array(coo._rows) == [1]
        # remapcols!
        CellBasedModels.remapcols!(coo, [i for i in 15:-1:1])
        @test Array(coo._cols) == [1]
        # remap! - combined row and column remapping
        coo_remap = dcoo_zeros(Float64, 5)
        coo_remap = toBackend(backend, coo_remap)
        _dcoo_slice_setup(coo_remap)  # Sets up: [1,1]=1, [1,2]=2, [2,1]=3, [2,3]=4
        # Before remap: rows=[1,1,2,2,0], cols=[1,2,1,3,0], values=[1,2,3,4,0]
        @test Array(coo_remap._rows) == [1, 1, 2, 2, 0]
        @test Array(coo_remap._cols) == [1, 2, 1, 3, 0]
        @test Array(coo_remap._values) == [1.0, 2.0, 3.0, 4.0, 0.0]
        @test (Array(coo_remap._NEntries), Array(coo_remap._NEntriesCache), Array(coo_remap._NEntriesNonzero)) == ([4], [5], [4])
        @test (Array(coo_remap._NOverflowInsert), Array(coo_remap._NOverflowErase)) == ([0], [0])
        @test (Array(coo_remap._NEntriesFree), Array(coo_remap._NEntriesFreeNextInit), Array(coo_remap._NEntriesFreeNext)) == ([1], [6], [0])
        @test Array(coo_remap._entriesFree) == [5, 0, 0, 0, 0]
        # Apply remap!: rowmap=[2,1] swaps rows 1<->2, colmap=[3,2,1] reverses cols 1->3, 2->2, 3->1
        CellBasedModels.remap!(coo_remap, [2, 1], [3, 2, 1])
        # After remap: row 1->2, row 2->1, col 1->3, col 2->2, col 3->1
        # Original entries: [1,1]=1 -> [2,3]=1, [1,2]=2 -> [2,2]=2, [2,1]=3 -> [1,3]=3, [2,3]=4 -> [1,1]=4
        @test Array(coo_remap._rows) == [2, 2, 1, 1, 0]
        @test Array(coo_remap._cols) == [3, 2, 3, 1, 0]
        @test Array(coo_remap._values) == [1.0, 2.0, 3.0, 4.0, 0.0]  # values unchanged
        @test (Array(coo_remap._NEntries), Array(coo_remap._NEntriesCache), Array(coo_remap._NEntriesNonzero)) == ([4], [5], [4])  # counts unchanged
        @test (Array(coo_remap._NOverflowInsert), Array(coo_remap._NOverflowErase)) == ([0], [0])  # overflows unchanged
        @test (Array(coo_remap._NEntriesFree), Array(coo_remap._NEntriesFreeNextInit), Array(coo_remap._NEntriesFreeNext)) == ([1], [6], [0])  # free list unchanged
        @test Array(coo_remap._entriesFree) == [5, 0, 0, 0, 0]  # free entries unchanged
        # To Device back
        coo_cpu = toBackend(CPU(), coo)
        @test Array(coo_cpu._rows) == [1]
        @test Array(coo_cpu._cols) == [1]
        @test Array(coo_cpu._values) == [11.0]
        @test (Array(coo_cpu._NEntries), Array(coo_cpu._NEntriesCache), Array(coo_cpu._NEntriesNonzero)) == ([1],[1],[1])
        @test (Array(coo_cpu._NOverflowInsert), Array(coo_cpu._NOverflowErase)) == ([0],[0])
        @test (Array(coo_cpu._NEntriesFree), Array(coo_cpu._NEntriesFreeNextInit), Array(coo_cpu._NEntriesFreeNext)) == ([1],[2],[0])
        @test (Array(coo_cpu._entriesFree)) == [0]
        # Test row/column slicing - using kernel functions
        coo_slice = dcoo_zeros(Float64, 5)
        coo_slice = toBackend(backend, coo_slice)
        _dcoo_slice_setup(coo_slice)
        # After setup: [1,1]=1, [1,2]=2, [2,1]=3, [2,3]=4
        @test Array(coo_slice._rows) == [1, 1, 2, 2, 0]
        @test Array(coo_slice._cols) == [1, 2, 1, 3, 0]
        @test Array(coo_slice._values) == [1.0, 2.0, 3.0, 4.0, 0.0]
        @test (Array(coo_slice._NEntries), Array(coo_slice._NEntriesCache), Array(coo_slice._NEntriesNonzero)) == ([4], [5], [4])
        @test (Array(coo_slice._NOverflowInsert), Array(coo_slice._NOverflowErase)) == ([0], [0])
        @test (Array(coo_slice._NEntriesFree), Array(coo_slice._NEntriesFreeNextInit), Array(coo_slice._NEntriesFreeNext)) == ([1], [6], [0])
        @test Array(coo_slice._entriesFree) == [5, 0, 0, 0, 0]
        # Set row 1 values to 0
        _dcoo_slice_row_value(coo_slice)
        # After row 1 set to 0: [1,1]=0, [1,2]=0, [2,1]=3, [2,3]=4
        @test Array(coo_slice._rows) == [1, 1, 2, 2, 0]
        @test Array(coo_slice._cols) == [1, 2, 1, 3, 0]
        @test Array(coo_slice._values) == [0.0, 0.0, 3.0, 4.0, 0.0]
        @test (Array(coo_slice._NEntries), Array(coo_slice._NEntriesCache), Array(coo_slice._NEntriesNonzero)) == ([4], [5], [2])
        @test (Array(coo_slice._NOverflowInsert), Array(coo_slice._NOverflowErase)) == ([0], [0])
        @test (Array(coo_slice._NEntriesFree), Array(coo_slice._NEntriesFreeNextInit), Array(coo_slice._NEntriesFreeNext)) == ([1], [6], [0])
        @test Array(coo_slice._entriesFree) == [5, 0, 0, 0, 0]
        # Set column 1 values to 10 (both [1,1] and [2,1] exist)
        _dcoo_slice_col_value(coo_slice)
        # After column 1 set to 10: [1,1]=10, [1,2]=0, [2,1]=10, [2,3]=4
        @test Array(coo_slice._rows) == [1, 1, 2, 2, 0]
        @test Array(coo_slice._cols) == [1, 2, 1, 3, 0]
        @test Array(coo_slice._values) == [10.0, 0.0, 10.0, 4.0, 0.0]
        @test (Array(coo_slice._NEntries), Array(coo_slice._NEntriesCache), Array(coo_slice._NEntriesNonzero)) == ([4], [5], [3])
        @test (Array(coo_slice._NOverflowInsert), Array(coo_slice._NOverflowErase)) == ([0], [0])
        @test (Array(coo_slice._NEntriesFree), Array(coo_slice._NEntriesFreeNextInit), Array(coo_slice._NEntriesFreeNext)) == ([1], [6], [0])
        @test Array(coo_slice._entriesFree) == [5, 0, 0, 0, 0]
        # Remove row 2 entries
        _dcoo_slice_row_remove(coo_slice)
        # After row 2 removed: [1,1]=10, [1,2]=0, entries 3,4 removed
        if CellBasedModels.allocationsFailed(coo_slice)
            # GPU: free list overflow
            @test Array(coo_slice._rows) == [1, 1, 0, 0, 0]
            @test Array(coo_slice._cols) == [1, 2, 0, 0, 0]
            @test Array(coo_slice._values) == [10.0, 0.0, 0.0, 0.0, 0.0]
            @test (Array(coo_slice._NEntries), Array(coo_slice._NEntriesCache), Array(coo_slice._NEntriesNonzero)) == ([2], [5], [1])
            @test (Array(coo_slice._NOverflowInsert), Array(coo_slice._NOverflowErase)) == ([0], [2])
            @test (Array(coo_slice._NEntriesFree), Array(coo_slice._NEntriesFreeNextInit), Array(coo_slice._NEntriesFreeNext)) == ([1], [6], [0])
            @test Array(coo_slice._entriesFree) == [5, 0, 0, 0, 0]
        else
            # CPU: free list updated (iteration order: entry 3 freed before 4)
            @test Array(coo_slice._rows) == [1, 1, 0, 0, 0]
            @test Array(coo_slice._cols) == [1, 2, 0, 0, 0]
            @test Array(coo_slice._values) == [10.0, 0.0, 0.0, 0.0, 0.0]
            @test (Array(coo_slice._NEntries), Array(coo_slice._NEntriesCache), Array(coo_slice._NEntriesNonzero)) == ([2], [5], [1])
            @test (Array(coo_slice._NOverflowInsert), Array(coo_slice._NOverflowErase)) == ([0], [2])
            @test (Array(coo_slice._NEntriesFree), Array(coo_slice._NEntriesFreeNextInit), Array(coo_slice._NEntriesFreeNext)) == ([1], [6], [2])
            @test Array(coo_slice._entriesFree) == [5, 0, 0, 0, 0, 3, 4]
        end
        # Remove column 2 entries
        _dcoo_slice_col_remove(coo_slice)
        # After column 2 removed: only [1,1]=10 remains
        if CellBasedModels.allocationsFailed(coo_slice)
            # GPU: free list overflow continues
            @test Array(coo_slice._rows) == [1, 0, 0, 0, 0]
            @test Array(coo_slice._cols) == [1, 0, 0, 0, 0]
            @test Array(coo_slice._values) == [10.0, 0.0, 0.0, 0.0, 0.0]
            @test (Array(coo_slice._NEntries), Array(coo_slice._NEntriesCache), Array(coo_slice._NEntriesNonzero)) == ([1], [5], [1])
            @test (Array(coo_slice._NOverflowInsert), Array(coo_slice._NOverflowErase)) == ([0], [3])
            @test (Array(coo_slice._NEntriesFree), Array(coo_slice._NEntriesFreeNextInit), Array(coo_slice._NEntriesFreeNext)) == ([1], [6], [0])
            @test Array(coo_slice._entriesFree) == [5, 0, 0, 0, 0]
        else
            # CPU: free list updated (entry 2 freed)
            @test Array(coo_slice._rows) == [1, 0, 0, 0, 0]
            @test Array(coo_slice._cols) == [1, 0, 0, 0, 0]
            @test Array(coo_slice._values) == [10.0, 0.0, 0.0, 0.0, 0.0]
            @test (Array(coo_slice._NEntries), Array(coo_slice._NEntriesCache), Array(coo_slice._NEntriesNonzero)) == ([1], [5], [1])
            @test (Array(coo_slice._NOverflowInsert), Array(coo_slice._NOverflowErase)) == ([0], [3])
            @test (Array(coo_slice._NEntriesFree), Array(coo_slice._NEntriesFreeNextInit), Array(coo_slice._NEntriesFreeNext)) == ([1], [6], [3])
            @test Array(coo_slice._entriesFree) == [5, 0, 0, 0, 0, 3, 4, 2]
        end
        # replaceIndex! - in-place index replacement
        coo_replace = dcoo_zeros(Float64, 5)
        coo_replace = toBackend(backend, coo_replace)
        _dcoo_slice_setup(coo_replace)  # Sets up: [1,1]=1, [1,2]=2, [2,1]=3, [2,3]=4
        # Before replace: rows=[1,1,2,2,0], cols=[1,2,1,3,0], values=[1,2,3,4,0]
        @test Array(coo_replace._rows) == [1, 1, 2, 2, 0]
        @test Array(coo_replace._cols) == [1, 2, 1, 3, 0]
        @test Array(coo_replace._values) == [1.0, 2.0, 3.0, 4.0, 0.0]
        @test (Array(coo_replace._NEntries), Array(coo_replace._NEntriesCache), Array(coo_replace._NEntriesNonzero)) == ([4], [5], [4])
        @test (Array(coo_replace._NOverflowInsert), Array(coo_replace._NOverflowErase)) == ([0], [0])
        @test (Array(coo_replace._NEntriesFree), Array(coo_replace._NEntriesFreeNextInit), Array(coo_replace._NEntriesFreeNext)) == ([1], [6], [0])
        @test Array(coo_replace._entriesFree) == [5, 0, 0, 0, 0]
        # Test same-row column replacement: [1,1] -> [1,5] (4-arg convenience form)
        result = CellBasedModels.replaceIndex!(coo_replace, 1, 1, 5)
        @test result == true
        @test Array(coo_replace._rows) == [1, 1, 2, 2, 0]  # row unchanged
        @test Array(coo_replace._cols) == [5, 2, 1, 3, 0]  # col 1->5 at position 1
        @test Array(coo_replace._values) == [1.0, 2.0, 3.0, 4.0, 0.0]  # values unchanged
        @test (Array(coo_replace._NEntries), Array(coo_replace._NEntriesCache), Array(coo_replace._NEntriesNonzero)) == ([4], [5], [4])
        @test (Array(coo_replace._NOverflowInsert), Array(coo_replace._NOverflowErase)) == ([0], [0])
        @test (Array(coo_replace._NEntriesFree), Array(coo_replace._NEntriesFreeNextInit), Array(coo_replace._NEntriesFreeNext)) == ([1], [6], [0])
        @test Array(coo_replace._entriesFree) == [5, 0, 0, 0, 0]
        # Test cross-row replacement: [2,1] -> [3,7] (5-arg full form)
        result = CellBasedModels.replaceIndex!(coo_replace, 2, 1, 3, 7)
        @test result == true
        @test Array(coo_replace._rows) == [1, 1, 3, 2, 0]  # row 2->3 at position 3
        @test Array(coo_replace._cols) == [5, 2, 7, 3, 0]  # col 1->7 at position 3
        @test Array(coo_replace._values) == [1.0, 2.0, 3.0, 4.0, 0.0]  # values unchanged
        @test (Array(coo_replace._NEntries), Array(coo_replace._NEntriesCache), Array(coo_replace._NEntriesNonzero)) == ([4], [5], [4])
        @test (Array(coo_replace._NOverflowInsert), Array(coo_replace._NOverflowErase)) == ([0], [0])
        @test (Array(coo_replace._NEntriesFree), Array(coo_replace._NEntriesFreeNextInit), Array(coo_replace._NEntriesFreeNext)) == ([1], [6], [0])
        @test Array(coo_replace._entriesFree) == [5, 0, 0, 0, 0]
        # Test replacement on non-existent entry returns false
        result = CellBasedModels.replaceIndex!(coo_replace, 99, 99, 100, 100)
        @test result == false
        @test Array(coo_replace._rows) == [1, 1, 3, 2, 0]  # unchanged
        @test Array(coo_replace._cols) == [5, 2, 7, 3, 0]  # unchanged
        @test Array(coo_replace._values) == [1.0, 2.0, 3.0, 4.0, 0.0]  # unchanged
        @test (Array(coo_replace._NEntries), Array(coo_replace._NEntriesCache), Array(coo_replace._NEntriesNonzero)) == ([4], [5], [4])
        @test (Array(coo_replace._NOverflowInsert), Array(coo_replace._NOverflowErase)) == ([0], [0])
        @test (Array(coo_replace._NEntriesFree), Array(coo_replace._NEntriesFreeNextInit), Array(coo_replace._NEntriesFreeNext)) == ([1], [6], [0])
        @test Array(coo_replace._entriesFree) == [5, 0, 0, 0, 0]
        # Test replaceIndex! with zero value entry (should still work)
        coo_replace._values[2] = 0.0  # Make [1,2]=0 (still in COO but zero value)
        Atomix.@atomic coo_replace._NEntriesNonzero[1] -= 1
        @test Array(coo_replace._values) == [1.0, 0.0, 3.0, 4.0, 0.0]
        @test (Array(coo_replace._NEntriesNonzero)) == ([3])
        result = CellBasedModels.replaceIndex!(coo_replace, 1, 2, 1, 10)
        @test result == true
        @test Array(coo_replace._rows) == [1, 1, 3, 2, 0]  # row unchanged
        @test Array(coo_replace._cols) == [5, 10, 7, 3, 0]  # col 2->10 at position 2
        @test Array(coo_replace._values) == [1.0, 0.0, 3.0, 4.0, 0.0]  # value still zero
        @test (Array(coo_replace._NEntries), Array(coo_replace._NEntriesCache), Array(coo_replace._NEntriesNonzero)) == ([4], [5], [3])  # nonzero count unchanged
        @test (Array(coo_replace._NOverflowInsert), Array(coo_replace._NOverflowErase)) == ([0], [0])
        @test (Array(coo_replace._NEntriesFree), Array(coo_replace._NEntriesFreeNextInit), Array(coo_replace._NEntriesFreeNext)) == ([1], [6], [0])
        @test Array(coo_replace._entriesFree) == [5, 0, 0, 0, 0]
    end

end