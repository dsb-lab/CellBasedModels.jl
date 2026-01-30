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

    coo = dcoo_zeros(Float64, 2)
    # Build
    @test Array(coo._rows) == [0,0]
    @test Array(coo._cols) == [0,0]
    @test Array(coo._values) == [0.0, 0.0]
    @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([0],[2],[0])
    @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([2],[3],[0])
    @test (Array(coo._entriesFree)) == [2,1]
    for device in devices
        # To Device
        coo = toDevice(device, coo)
        @test Array(coo._rows) == [0,0]
        @test Array(coo._cols) == [0,0]
        @test Array(coo._values) == [0.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([0],[2],[0])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([2],[3],[0])
        @test (Array(coo._entriesFree)) == [2,1]
        # Repeat To Device
        coo = toDevice(device, coo)
        @test Array(coo._rows) == [0,0]
        @test Array(coo._cols) == [0,0]
        @test Array(coo._values) == [0.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([0],[2],[0])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([2],[3],[0])
        @test (Array(coo._entriesFree)) == [2,1]
        # Insert
        _dcoo_insert(coo)
        @test Array(coo._rows) == [1,10,2]
        @test Array(coo._cols) == [1,15,3]
        @test Array(coo._values) == [5.0, 12.0, 7.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([3],[3],[3])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([-1],[3],[0])
        @test (Array(coo._entriesFree)) == [0,0,0]
        # overflow
        @test CellBasedModels.overflow(coo) == true
        @test CellBasedModels.overflowEntries(coo) == 1
        @test CellBasedModels.overflowRows(coo) == 1
        # allocation ratio
        if device === CPU
            @test CellBasedModels.allocationsFailed(coo) == false
            @test CellBasedModels.allocationRatio(coo) == 1.0
        else
            @test CellBasedModels.allocationsFailed(coo) == true
            @test CellBasedModels.allocationRatio(coo) == 3.0/2.0
        end
        if CellBasedModels.allocationsFailed(coo)
            coo = CellBasedModels.reallocate(coo, n_rows=3)
            _dcoo_insert(coo)
        end
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
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([-1],[3],[0])
        @test (Array(coo._entriesFree)) == [0,0,0]
        # Remove
        _dcoo_remove(coo)
        @test Array(coo._rows) == [0,10,2]
        @test Array(coo._cols) == [0,15,3]
        @test Array(coo._values) == [0.0, 11.0, 0.0]
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([-1],[3],[1])
        @test (Array(coo._entriesFree)) == [0,0,1]
        # synchronize
        CellBasedModels.synchronize(coo)
        @test Array(coo._rows) == [0,10,2]
        @test Array(coo._cols) == [0,15,3]
        @test Array(coo._values) == [0.0, 11.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([2],[3],[1])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([1],[2],[0])
        @test (Array(coo._entriesFree)) == [1,0,0]
        # dropzeros!
        CellBasedModels.dropzeros!(coo)
        @test Array(coo._rows) == [0,10,0]
        @test Array(coo._cols) == [0,15,0]
        @test Array(coo._values) == [0.0, 11.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([1],[3],[1])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([2],[3],[0])
        @test (Array(coo._entriesFree)) == [1,3,0]
        # preallocate!
        CellBasedModels.preallocate!(coo, n_rows=2)
        @test Array(coo._rows) == [0,10,0,0,0]
        @test Array(coo._cols) == [0,15,0,0,0]
        @test Array(coo._values) == [0.0, 11.0, 0.0, 0.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([1],[5],[1])
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
        @test (Array(coo2._NEntriesFree), Array(coo2._NEntriesFreeNextInit), Array(coo2._NEntriesFreeNext)) == ([4],[5],[0])
        @test (Array(coo2._entriesFree)) == [5,4,3,2,0]
        # compact!
        CellBasedModels.compact!(coo)
        @test Array(coo._rows) == [10,0,0,0,0]
        @test Array(coo._cols) == [15,0,0,0,0]
        @test Array(coo._values) == [11.0, 0.0, 0.0, 0.0, 0.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([1],[5],[1])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([4],[5],[0])
        @test (Array(coo._entriesFree)) == [5,4,3,2,0]
        # copy
        coo3 = copy(coo)
        @test Array(coo3._rows) == [10,0,0,0,0]
        @test Array(coo3._cols) == [15,0,0,0,0]
        @test Array(coo3._values) == [11.0, 0.0, 0.0, 0.0, 0.0]
        @test (Array(coo3._NEntries), Array(coo3._NEntriesCache), Array(coo3._NEntriesNonzero)) == ([1],[5],[1])
        @test (Array(coo3._NEntriesFree), Array(coo3._NEntriesFreeNextInit), Array(coo3._NEntriesFreeNext)) == ([4],[5],[0])
        @test (Array(coo3._entriesFree)) == [5,4,3,2,0]
        # copyto!
        coo4 = similar(coo)
        copyto!(coo4, coo)
        @test Array(coo4._rows) == [10,0,0,0,0]
        @test Array(coo4._cols) == [15,0,0,0,0]
        @test Array(coo4._values) == [11.0, 0.0, 0.0, 0.0, 0.0]
        @test (Array(coo4._NEntries), Array(coo4._NEntriesCache), Array(coo4._NEntriesNonzero)) == ([1],[5],[1])
        @test (Array(coo4._NEntriesFree), Array(coo4._NEntriesFreeNextInit), Array(coo4._NEntriesFreeNext)) == ([4],[5],[0])
        @test (Array(coo4._entriesFree)) == [5,4,3,2,0]
        # dropcacheto!
        CellBasedModels.dropcacheto!(coo4, coo)
        @test Array(coo4._rows) == [10]
        @test Array(coo4._cols) == [15]
        @test Array(coo4._values) == [11.0]
        @test (Array(coo4._NEntries), Array(coo4._NEntriesCache), Array(coo4._NEntriesNonzero)) == ([1],[1],[1])
        @test (Array(coo4._NEntriesFree), Array(coo4._NEntriesFreeNextInit), Array(coo4._NEntriesFreeNext)) == ([1],[2],[0])
        @test (Array(coo4._entriesFree)) == [0]
        # dropcache!
        CellBasedModels.dropcache!(coo)
        @test Array(coo._rows) == [10]
        @test Array(coo._cols) == [15]
        @test Array(coo._values) == [11.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([1],[1],[1])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([1],[2],[0])
        @test (Array(coo._entriesFree)) == [0]
        # remaprows!
        CellBasedModels.remaprows!(coo, [i for i in 10:-1:1])
        @test Array(coo._rows) == [1]
        # remapcols!
        CellBasedModels.remapcols!(coo, [i for i in 15:-1:1])
        @test Array(coo._cols) == [1]
        # To Device back
        coo = toDevice(CPU, coo)
        @test Array(coo._rows) == [1]
        @test Array(coo._cols) == [1]
        @test Array(coo._values) == [11.0]
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([1],[1],[1])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([1],[2],[0])
        @test (Array(coo._entriesFree)) == [0]
    end

end