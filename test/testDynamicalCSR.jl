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
            @test Array(csr._cols) == [1,0,3,0]
            @test Array(csr._values) == [5.0, 0.0, 7.0, 0.0]
            @test Array(csr._rowOffsets) == [1,3,5]
            @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([2],[4],[2])
            @test Array(csr._coo._rows) == [3]
            @test Array(csr._coo._cols) == [5]
            @test Array(csr._coo._values) == [12.0]
            @test CellBasedModels.allocationRatio(csr) == 0.75
        else
            @test Array(csr._cols) == [1,0,3,0]
            @test Array(csr._values) == [5.0, 0.0, 7.0, 0.0]
            @test Array(csr._rowOffsets) == [1,3,5]
            @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([2],[4],[2])
            @test Array(csr._coo._rows) == []
            @test Array(csr._coo._cols) == []
            @test Array(csr._coo._values) == []
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
        # # lengths number of entries
        # @test length(csr) == 3
        # @test CellBasedModels.numberOfEntries(csr) == 3
        # @test CellBasedModels.numberOfEntriesCache(csr) == 3
        # @test CellBasedModels.numberOfEntriesNonzero(csr) == 3
        # @test CellBasedModels.numberOfRows(csr) == 10
        # @test CellBasedModels.numberOfCols(csr) == 15
        # # Modify 
        # _dcsr_change(csr)
        # @test Array(csr._rows) == [1,10,2]
        # @test Array(csr._cols) == [1,15,3]
        # @test Array(csr._values) == [7.0, 11.0, 0.0]
        # @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([3],[3],[2])
        # @test (Array(csr._NOverflowInsert), Array(csr._NOverflowErase)) == ([0],[0])
        # @test (Array(csr._NEntriesFree), Array(csr._NEntriesFreeNextInit), Array(csr._NEntriesFreeNext)) == ([0],[4],[0])
        # @test (Array(csr._entriesFree)) == [0,0,0]
        # # Remove with overflow
        # _dcsr_remove(csr)
        # @test CellBasedModels.overflow(csr) == true
        # @test CellBasedModels.overflowEntries(csr) == 0
        # @test CellBasedModels.overflowRows(csr) == 0
        # if CellBasedModels.allocationsFailed(csr) #In GPU should fail so you have to repeat
        #     @test Array(csr._rows) == [0,10,2]
        #     @test Array(csr._cols) == [0,15,3]
        #     @test Array(csr._values) == [0.0, 11.0, 0.0]
        #     @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([2],[3],[1])
        #     @test (Array(csr._NOverflowInsert), Array(csr._NOverflowErase)) == ([0],[1])
        #     @test (Array(csr._NEntriesFree), Array(csr._NEntriesFreeNextInit), Array(csr._NEntriesFreeNext)) == ([0],[4],[0])
        #     @test (Array(csr._entriesFree)) == [0,0,0]
        # else
        #     @test Array(csr._rows) == [0,10,2]
        #     @test Array(csr._cols) == [0,15,3]
        #     @test Array(csr._values) == [0.0, 11.0, 0.0]
        #     @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([2],[3],[1])
        #     @test (Array(csr._NOverflowInsert), Array(csr._NOverflowErase)) == ([0],[1])
        #     @test (Array(csr._NEntriesFree), Array(csr._NEntriesFreeNextInit), Array(csr._NEntriesFreeNext)) == ([0],[4],[1])
        #     @test (Array(csr._entriesFree)) == [0,0,0,1]
        # end
        # # synchronize
        # csr = dcsr_zeros(Float64, 3)
        # csr = toBackend(backend, csr)
        # _dcsr_insert(csr)
        # _dcsr_change(csr)
        # CellBasedModels.synchronize(csr)
        # @test Array(csr._rows) == [1,10,2]
        # @test Array(csr._cols) == [1,15,3]
        # @test Array(csr._values) == [7.0, 11.0, 0.0]
        # @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([3],[3],[2])
        # @test (Array(csr._NOverflowInsert), Array(csr._NOverflowErase)) == ([0],[0])
        # @test (Array(csr._NEntriesFree), Array(csr._NEntriesFreeNextInit), Array(csr._NEntriesFreeNext)) == ([0],[1],[0])
        # @test (Array(csr._entriesFree)) == [0,0,0]
        # # Remove without overflow
        # _dcsr_remove(csr)
        # @test Array(csr._rows) == [0,10,2]
        # @test Array(csr._cols) == [0,15,3]
        # @test Array(csr._values) == [0.0, 11.0, 0.0]
        # @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([2],[3],[1])
        # @test (Array(csr._NOverflowInsert), Array(csr._NOverflowErase)) == ([0],[0])
        # @test (Array(csr._NEntriesFree), Array(csr._NEntriesFreeNextInit), Array(csr._NEntriesFreeNext)) == ([0],[1],[1])
        # @test (Array(csr._entriesFree)) == [1,0,0]
        # # synchronize
        # CellBasedModels.synchronize(csr)
        # @test Array(csr._rows) == [0,10,2]
        # @test Array(csr._cols) == [0,15,3]
        # @test Array(csr._values) == [0.0, 11.0, 0.0]
        # @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([2],[3],[1])
        # @test (Array(csr._NOverflowInsert), Array(csr._NOverflowErase)) == ([0],[0])
        # @test (Array(csr._NEntriesFree), Array(csr._NEntriesFreeNextInit), Array(csr._NEntriesFreeNext)) == ([1],[2],[0])
        # @test (Array(csr._entriesFree)) == [1,0,0]
        # # dropzeros!
        # CellBasedModels.dropzeros!(csr)
        # @test Array(csr._rows) == [0,10,0]
        # @test Array(csr._cols) == [0,15,0]
        # @test Array(csr._values) == [0.0, 11.0, 0.0]
        # @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([1],[3],[1])
        # @test (Array(csr._NOverflowInsert), Array(csr._NOverflowErase)) == ([0],[0])
        # @test (Array(csr._NEntriesFree), Array(csr._NEntriesFreeNextInit), Array(csr._NEntriesFreeNext)) == ([2],[3],[0])
        # @test (Array(csr._entriesFree)) == [1,3,0]
        # # preallocate!
        # CellBasedModels.preallocate!(csr, n_rows=2)
        # @test Array(csr._rows) == [0,10,0,0,0]
        # @test Array(csr._cols) == [0,15,0,0,0]
        # @test Array(csr._values) == [0.0, 11.0, 0.0, 0.0, 0.0]
        # @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([1],[5],[1])
        # @test (Array(csr._NOverflowInsert), Array(csr._NOverflowErase)) == ([0],[0])
        # @test (Array(csr._NEntriesFree), Array(csr._NEntriesFreeNextInit), Array(csr._NEntriesFreeNext)) == ([4],[5],[0])
        # @test (Array(csr._entriesFree)) == [1,3,4,5,0]
        # # similar
        # csr2 = similar(csr)
        # @test eltype(csr2._values) == eltype(csr._values)
        # @test length(csr2._values) == length(csr._values)
        # @test length(csr2._rows) == length(csr._rows)
        # @test length(csr2._cols) == length(csr._cols)
        # @test length(csr2._entriesFree) == length(csr._entriesFree)
        # # compactto!
        # CellBasedModels.compactto!(csr2, csr)
        # @test Array(csr2._rows) == [10,0,0,0,0]
        # @test Array(csr2._cols) == [15,0,0,0,0]
        # @test Array(csr2._values) == [11.0, 0.0, 0.0, 0.0, 0.0]
        # @test (Array(csr2._NEntries), Array(csr2._NEntriesCache), Array(csr2._NEntriesNonzero)) == ([1],[5],[1])
        # @test (Array(csr2._NOverflowInsert), Array(csr2._NOverflowErase)) == ([0],[0])
        # @test (Array(csr2._NEntriesFree), Array(csr2._NEntriesFreeNextInit), Array(csr2._NEntriesFreeNext)) == ([4],[5],[0])
        # @test (Array(csr2._entriesFree)) == [5,4,3,2,0]
        # # compact!
        # CellBasedModels.compact!(csr)
        # @test Array(csr._rows) == [10,0,0,0,0]
        # @test Array(csr._cols) == [15,0,0,0,0]
        # @test Array(csr._values) == [11.0, 0.0, 0.0, 0.0, 0.0]
        # @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([1],[5],[1])
        # @test (Array(csr._NOverflowInsert), Array(csr._NOverflowErase)) == ([0],[0])
        # @test (Array(csr._NEntriesFree), Array(csr._NEntriesFreeNextInit), Array(csr._NEntriesFreeNext)) == ([4],[5],[0])
        # @test (Array(csr._entriesFree)) == [5,4,3,2,0]
        # # copyto!
        # csr3 = similar(csr)
        # copyto!(csr3, csr)
        # @test Array(csr3._rows) == [10,0,0,0,0]
        # @test Array(csr3._cols) == [15,0,0,0,0]
        # @test Array(csr3._values) == [11.0, 0.0, 0.0, 0.0, 0.0]
        # @test (Array(csr3._NEntries), Array(csr3._NEntriesCache), Array(csr3._NEntriesNonzero)) == ([1],[5],[1])
        # @test (Array(csr3._NOverflowInsert), Array(csr3._NOverflowErase)) == ([0],[0])
        # @test (Array(csr3._NEntriesFree), Array(csr3._NEntriesFreeNextInit), Array(csr3._NEntriesFreeNext)) == ([4],[5],[0])
        # @test (Array(csr3._entriesFree)) == [5,4,3,2,0]
        # # copy
        # csr4 = copy(csr)
        # @test Array(csr4._rows) == [10,0,0,0,0]
        # @test Array(csr4._cols) == [15,0,0,0,0]
        # @test Array(csr4._values) == [11.0, 0.0, 0.0, 0.0, 0.0]
        # @test (Array(csr4._NEntries), Array(csr4._NEntriesCache), Array(csr4._NEntriesNonzero)) == ([1],[5],[1])
        # @test (Array(csr4._NOverflowInsert), Array(csr4._NOverflowErase)) == ([0],[0])
        # @test (Array(csr4._NEntriesFree), Array(csr4._NEntriesFreeNextInit), Array(csr4._NEntriesFreeNext)) == ([4],[5],[0])
        # @test (Array(csr4._entriesFree)) == [5,4,3,2,0]
        # # dropcacheto!
        # csr5 = similar(csr)
        # CellBasedModels.dropcacheto!(csr5, csr)
        # @test Array(csr5._rows) == [10]
        # @test Array(csr5._cols) == [15]
        # @test Array(csr5._values) == [11.0]
        # @test (Array(csr5._NEntries), Array(csr5._NEntriesCache), Array(csr5._NEntriesNonzero)) == ([1],[1],[1])
        # @test (Array(csr5._NOverflowInsert), Array(csr5._NOverflowErase)) == ([0],[0])
        # @test (Array(csr5._NEntriesFree), Array(csr5._NEntriesFreeNextInit), Array(csr5._NEntriesFreeNext)) == ([1],[2],[0])
        # @test (Array(csr5._entriesFree)) == [0]
        # # dropcache!
        # CellBasedModels.dropcache!(csr)
        # @test Array(csr._rows) == [10]
        # @test Array(csr._cols) == [15]
        # @test Array(csr._values) == [11.0]
        # @test (Array(csr._NEntries), Array(csr._NEntriesCache), Array(csr._NEntriesNonzero)) == ([1],[1],[1])
        # @test (Array(csr._NOverflowInsert), Array(csr._NOverflowErase)) == ([0],[0])
        # @test (Array(csr._NEntriesFree), Array(csr._NEntriesFreeNextInit), Array(csr._NEntriesFreeNext)) == ([1],[2],[0])
        # @test (Array(csr._entriesFree)) == [0]
        # # remaprows!
        # CellBasedModels.remaprows!(csr, [i for i in 10:-1:1])
        # @test Array(csr._rows) == [1]
        # # remapcols!
        # CellBasedModels.remapcols!(csr, [i for i in 15:-1:1])
        # @test Array(csr._cols) == [1]
        # # To Device back
        # csr_cpu = toBackend(CPU(), csr)
        # @test Array(csr_cpu._rows) == [1]
        # @test Array(csr_cpu._cols) == [1]
        # @test Array(csr_cpu._values) == [11.0]
        # @test (Array(csr_cpu._NEntries), Array(csr_cpu._NEntriesCache), Array(csr_cpu._NEntriesNonzero)) == ([1],[1],[1])
        # @test (Array(csr_cpu._NOverflowInsert), Array(csr_cpu._NOverflowErase)) == ([0],[0])
        # @test (Array(csr_cpu._NEntriesFree), Array(csr_cpu._NEntriesFreeNextInit), Array(csr_cpu._NEntriesFreeNext)) == ([1],[2],[0])
        # @test (Array(csr_cpu._entriesFree)) == [0]
    end

end