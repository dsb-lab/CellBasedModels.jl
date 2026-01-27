function f(csr)
    for i in csr
        i
    end
end

function test_iterators_in_kernel(csr)
    @kernel function _kernel!(csr, v1, v2, v3)
        idx = @index(Global)
        c = 1
        for (i,j) in csr
            v1[c] = 1
            c += 1
        end
        for i in iterateRowEntries(csr, 1)
            v2[i] = 1
        end
        for i in iterateRows(csr)
            v3[i] = 1
        end
    end

    backend = KernelAbstractions.get_backend(csr)
    v1 = Adapt.adapt(backend, zeros(Int, 20))
    v2 = Adapt.adapt(backend, zeros(Int, 20))
    v3 = Adapt.adapt(backend, zeros(Int, 20))
    _kernel!(backend, 1)(csr, v1, v2, v3, ndrange=1)
    KernelAbstractions.synchronize(backend)

    return sum(v1), sum(v2), sum(v3)
end

# operators
function operations_csrblock_execute(csr, csrOld)

    @kernel function _kernel!(csr, csrOld)
        pushRow!(csr, 1)
        removeRow!(csr, 4)

        insertRowCol!(csr, 1, 10)
        insertRowCol!(csr, 2, 10)
        removeRowCol!(csr, 3, 7)
    end

    backend = KernelAbstractions.get_backend(csr)
    _kernel!(backend, 1)(csr, csrOld, ndrange=1)
    KernelAbstractions.synchronize(backend)

end

function operations_csrblock_execute2(csr, csrOld)
    
    @kernel function _kernel!(csr)
        insertRowCol!(csr, 3, 11)
        insertRowCol!(csr, 3, 14)
    end

    backend = KernelAbstractions.get_backend(csr)
    _kernel!(backend, 1)(csr, ndrange=1)
    KernelAbstractions.synchronize(backend)

end

function operations_csrblock_execute3(csr, csrOld)
    
    @kernel function _kernel!(csr)
        insertRowCol!(csr, 3, 5)
        pushRow!(csr, (3,15,7))
    end

    backend = KernelAbstractions.get_backend(csr)
    _kernel!(backend, 1)(csr, ndrange=1)
    KernelAbstractions.synchronize(backend)

end

# println("Benchmarking CSR Structures")
# println("================================")
# println("CSRBlock:")
# csrBlock = CSRBlock(N=3,NBlock=2,NCache=10)
# csrBlock._ActiveSection .= 2
# csrBlock._map .= 1:20
# @btime f(csrBlock)

# println("CSRTuple:")
# csrTuple = CSRTuple(N=3,NBlock=2,NCache=10)
# csrTuple._map .= 1:20
# @btime f(csrTuple)

# println("CSRSlack:")
# csrSlack = CSRSlack(dtype=Int, N=3, sizes=[5, 10, 7])
# csrSlack._map .= 1:22
# csrSlack._ActiveSection[1] = 3
# csrSlack._ActiveSection[2] = 8
# csrSlack._ActiveSection[3] = 5
# @btime f(csrSlack)

# println("CSRCache:")
# csrCache = CSRCache(dtype=Int, N=3, sizes=[5, 10, 7])
# csrCache._map .= 1:22
# @btime f(csrCache)

@testset "Topology" begin

    # @testset "CSRTuple" begin

    #     #Start
    #     csr = CSRTuple(2, 3, 10)
    #     csr._map .= 0:19
    #     csr._NEntries[] = 5
    #     @test csr._NRows[] == 3
    #     @test csr._NBlock == 2
    #     @test csr._NRowsCache[] == 10
    #     @test length(csr._map) == 20
    #     @test numberOfRows(csr) == 3
    #     @test numberOfRowsCache(csr) == 10
        
    #     # Test iterator returns all elements (no active section filtering)
    #     results = [i for i in csr]
    #     @test length(results) == 5  # 3 blocks * 2 elements each
        
    #     # Check all blocks iterate through all elements
    #     @test results[1] == (1, 1)
    #     @test results[2] == (2, 2)
    #     @test results[3] == (2, 3)
    #     @test results[4] == (3, 4)
    #     @test results[5] == (3, 5)
        
    #     # Test with larger block size
    #     csr2 = CSRTuple(5, 2, 10)
    #     csr2._map[1:10] .= 1:10
    #     csr2._NEntries[] = 10
        
    #     results2 = [f for f in csr2]
    #     @test length(results2) == 10  # 2 blocks * 5 elements each
    #     @test results2[1] == (1, 1)
    #     @test results2[5] == (1, 5)
    #     @test results2[6] == (2, 6)
    #     @test results2[10] == (2, 10)

    #     # Test matrix constructor
    #     mat = reshape(1:12, 4, 3)
    #     csrMat = CSRTuple(mat, additionalCache=5)
    #     @test csrMat._NRows[] == 4
    #     @test csrMat._NBlock == 3
    #     @test csrMat._NRowsCache[] == 9
    #     @test csrMat._map[1:12] == collect(1:12)

    #     # Test nested vectors constructor
    #     nestedVec = [[1,2], [3,4], [5,6]]
    #     csrNested = CSRTuple(nestedVec, additionalCache=4)
    #     @test csrNested._NRows[] == 3
    #     @test csrNested._NBlock == 2
    #     @test csrNested._NRowsCache[] == 7
    #     @test csrNested._map[1:6] == collect(1:6)
        
    #     nestedVec2 = [[10,20,30], [40,50], [60,70,80,90]]
    #     @test_throws AssertionError CSRTuple(nestedVec2, additionalCache=5)

    #     # Test operators
    #     for device in devices

    #         nestedVec = [[1,2], [3,4], [0,6], [7,8], [9,10], [11,12], [13,14]]
    #         csr = CSRTuple(nestedVec, additionalCache=4)
    #         csr_device = CellBasedModels.toDevice(csr, device)
    #         v = operations_csrtuple_test(csr_device)
    #         v_host = Array(v)
    #         csr_host = toDevice(csr_device, CPU())
    #         @test v_host[1] == true        # isInRow
    #         @test v_host[2] == 2           # lengthRowCache
    #         @test v_host[3] == 1           # lengthRowActive
    #         @test getColumnAtRowPos(csr_host, 4, 1) == 5  # substitute!
    #         @test getColumnAtRowPos(csr_host, 5, 1) == 11 # substitutePos!
    #         @test getColumnAtRowPos(csr_host, 6, 1) == 0  # remove!
    #         @test getColumnAtRowPos(csr_host, 7, 2) == 0  # removePos!

    #     end

    # end

    @testset "CSRBlock" begin

        #Start
        csr = CSRBlock(2, 3, 10)
        @test numberOfEntries(csr) == 0
        @test numberOfEntriesCache(csr) == 20
        @test numberOfRows(csr) == 3
        @test numberOfRowsCache(csr) == 10
        @test numberOfEntriesInRow(csr, 1) == 0
        @test numberOfEntriesInRow(csr, 2) == 0
        @test numberOfEntriesInRowCache(csr, 1) == 2
        @test csr._map == zeros(Int, 20)
        @test csr._NRowsCompacted[] == 3
        @test csr._NEntriesRow == zeros(Int, 10)
        @test csr._NEntriesRowAdd == zeros(Int, 10)
        @test csr._NEntriesRowCompacted == zeros(Int, 10)

        # Test matrix constructor
        mat = reshape([i for i in 1:12], 4, 3)
        mat[2, 3] = 0  # Introduce a zero to test sparsity
        csrMat = CSRBlock(mat, NRowsCache=5, NBlock=4)
        @test numberOfEntries(csrMat) == 11
        @test numberOfEntriesCache(csrMat) == 20
        @test numberOfRows(csrMat) == 4
        @test numberOfRowsCache(csrMat) == 5
        @test numberOfEntriesInRow(csrMat, 1) == 3
        @test numberOfEntriesInRow(csrMat, 2) == 2
        @test numberOfEntriesInRow(csrMat, 3) == 3
        @test numberOfEntriesInRow(csrMat, 4) == 3
        @test numberOfEntriesInRowCache(csrMat, 1) == 4
        @test csrMat._map == [1,5,9,0,2,6,0,0,3,7,11,0,4,8,12,0,0,0,0,0]
        @test csrMat._NRowsCompacted[] == 4
        @test csrMat._NEntriesRow == [3,2,3,3,0]
        @test csrMat._NEntriesRowAdd == [3,2,3,3,0]
        @test csrMat._NEntriesRowCompacted == [3,2,3,3,0]        

        # Test nested vector constructor
        mat = [[1,2,3], [4,5], [6,7,8], [9,10,11]]
        csrMat = CSRBlock(mat, NRowsCache=5, NBlock=4)
        @test numberOfEntries(csrMat) == 11
        @test numberOfEntriesCache(csrMat) == 20
        @test numberOfRows(csrMat) == 4
        @test numberOfRowsCache(csrMat) == 5
        @test numberOfEntriesInRow(csrMat, 1) == 3
        @test numberOfEntriesInRow(csrMat, 2) == 2
        @test numberOfEntriesInRow(csrMat, 3) == 3
        @test numberOfEntriesInRow(csrMat, 4) == 3
        @test numberOfEntriesInRowCache(csrMat, 1) == 4
        @test csrMat._map == [1,2,3,0,4,5,0,0,6,7,8,0,9,10,11,0,0,0,0,0]
        @test csrMat._NRowsCompacted[] == 4
        @test csrMat._NEntriesRow == [3,2,3,3,0]
        @test csrMat._NEntriesRowAdd == [3,2,3,3,0]
        @test csrMat._NEntriesRowCompacted == [3,2,3,3,0]        
        
        # Test accessors
        mat = [[1,2,3], [4,5], [6,7,8], [9,10,11]]
        csrMat = CSRBlock(mat, NRowsCache=10, NBlock=4)
        @test getEntryAtRowPos(csrMat, 1, 2) == 2
        @test getEntryAtRowCol(csrMat, 2, 5) == 6
        @test getColumnAtRowPos(csrMat, 3, 3) == 8
        @test getColumnAtEntry(csrMat, 10) == 7

        # Test iterator returns all elements (no active section filtering)
        mat = [[1,2,3], [4,5], [6,7,8], [9,10,11]]
        csrMat = CSRBlock(mat, NRowsCache=10, NBlock=4)
        results = [i for i in csrMat]
        @test length(results) == 11  # 4 blocks with a total of 11 elements
        # Check all blocks iterate through all elements
        @test results == [(1, 1), (1, 2), (1, 3), (2, 4), (2, 5), (3, 6), (3, 7), (3, 8), (4, 9), (4, 10), (4, 11)]
        
        #Test row iterator "Unassigned"
        mat = [[1,2,3], [4,5], [6,7,8], [9,10,11]]
        csrMat = CSRBlock(mat, NRowsCache=10, NBlock=4)
        row_results = [i for i in iterateRowEntries(csrMat, 2)]
        @test length(row_results) == 2
        @test row_results == [4, 5]

        #Test rows iterator "Sorted"
        mat = [[2,3,1], [5,4], [8,6,7], [11,10,9]]
        csrMat = CSRBlock(mat, NRowsCache=10, NBlock=4, sortingFlavor="Sorted")
        rows_results = [i for i in csrMat]
        @test length(rows_results) == 11
        @test rows_results == [(1, 1), (1, 2), (1, 3), (2, 4), (2, 5), (3, 6), (3, 7), (3, 8), (4, 9), (4, 10), (4, 11)]

        #Test rows iterator "CustomSorted"
        mat = [[2,3,1], [5,4], [8,6,7], [11,10,9]]
        csrMat = CSRBlock(mat, NRowsCache=10, NBlock=4, sortingFlavor="CustomSorted")
        rows_results = [i for i in csrMat]
        @test length(rows_results) == 11
        @test rows_results == [(1, 2), (1, 3), (1, 1), (2, 5), (2, 4), (3, 8), (3, 6), (3, 7), (4, 11), (4, 10), (4, 9)]

        # Test iterators in kernel
        mat = [[1,2,3], [4,5], [6,7,8], [9,10,11]]
        csrMat = CSRBlock(mat, NRowsCache=10, NBlock=4)
        for flavors in ["Unsorted", "Sorted", "CustomSorted"]
            csrMat = CSRBlock(mat, NRowsCache=10, NBlock=4, sortingFlavor=flavors)
            for device in devices
                csr_device = CellBasedModels.toDevice(csrMat, device)
                v1, v2, v3 = test_iterators_in_kernel(csr_device)
                @test v1 == 11
                @test v2 == 3
                @test v3 == 4
            end
        end

        # Test operators and compactions unsorted
        for device in devices

            mat = [[1,2,3], [4,5], [6,7,8], [9,10,11]]
            csrMat = CSRBlock(mat, NRowsCache=5, NBlock=4)
            csr_device = CellBasedModels.toDevice(csrMat, device)
            csrNew_device = copy(csrMat)
            
            @test Array(csr_device._map) == [
                    1,2,3,0,
                    4,5,0,0,
                    6,7,8,0,
                    9,10,11,0,
                    0,0,0,0
                ]
            @test Array(csr_device._NEntries) == [11]
            @test Array(csr_device._NRows) == [4]
            @test Array(csr_device._NRowsCache) == [5]
            @test Array(csr_device._NRowsCompacted) == [4]
            @test Array(csr_device._NEntriesRow) == [3,2,3,3,0]
            @test Array(csr_device._NEntriesRowAdd) == [3,2,3,3,0]
            @test Array(csr_device._NEntriesRowCompacted) == [3,2,3,3,0]
            @test Array(csr_device._rowSurvived) == [1,1,1,1,0]

            operations_csrblock_execute(csrNew_device, csr_device)
            @test Array(csrNew_device._map) == [
                    1,2,3,10,
                    4,5,10,0,
                    6,0,8,0,
                    0,0,0,0,
                    1,0,0,0
                ]
            @test Array(csrNew_device._NEntries) == [10]
            @test Array(csrNew_device._NRows) == [5]
            @test Array(csrNew_device._NRowsCache) == [5]
            @test Array(csrNew_device._NRowsCompacted) == [4]
            @test Array(csrNew_device._NEntriesRow) == [4,3,3,0,1]
            @test Array(csrNew_device._NEntriesRowAdd) == [4,3,3,0,1]
            @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,2,0,1]
            @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
            @test CellBasedModels.overflow(csrNew_device) == false

            preallocate!(csrNew_device, csr_device)
            @test Array(csrNew_device._map) == [
                    1,2,3,10,
                    4,5,10,0,
                    6,0,8,0,
                    0,0,0,0,
                    1,0,0,0
                ]
            @test Array(csrNew_device._NEntries) == [10]
            @test Array(csrNew_device._NRows) == [5]
            @test Array(csrNew_device._NRowsCache) == [5]
            @test Array(csrNew_device._NRowsCompacted) == [4]
            @test Array(csrNew_device._NEntriesRow) == [4,3,3,0,1]
            @test Array(csrNew_device._NEntriesRowAdd) == [4,3,3,0,1]
            @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,2,0,1]
            @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
            @test CellBasedModels.overflow(csrNew_device) == false
            
            copyto!(csr_device, csrNew_device)
            @test all(csrNew_device._NBlock .== csr_device._NBlock)
            @test all(csrNew_device._sortingFlavor .== csr_device._sortingFlavor)
            @test all(csrNew_device._map .== csr_device._map)
            @test all(csrNew_device._rowEntryNext .== csr_device._rowEntryNext)
            @test all(csrNew_device._rowEntryPrevious .== csr_device._rowEntryPrevious)
            @test all(csrNew_device._rowFirstEntry .== csr_device._rowFirstEntry)
            @test all(csrNew_device._rowLastEntry .== csr_device._rowLastEntry)
            @test all(csrNew_device._NRows .== csr_device._NRows)
            @test all(csrNew_device._NRowsCache .== csr_device._NRowsCache)
            @test all(csrNew_device._NRowsAdd .== csr_device._NRowsAdd)
            @test all(csrNew_device._NRowsCompacted .== csr_device._NRowsCompacted)
            @test all(csrNew_device._NEntries .== csr_device._NEntries)
            @test all(csrNew_device._NEntriesRow .== csr_device._NEntriesRow)
            @test all(csrNew_device._NEntriesRowAdd .== csr_device._NEntriesRowAdd)
            @test all(csrNew_device._NEntriesRowCompacted .== csr_device._NEntriesRowCompacted)
            @test all(csrNew_device._rowSurvived .== csr_device._rowSurvived)

            operations_csrblock_execute2(csrNew_device, csr_device)
            @test Array(csrNew_device._map) == [
                    1,2,3,10,
                    4,5,10,0,
                    6,0,8,11,
                    0,0,0,0,
                    1,0,0,0
                ]
            @test Array(csrNew_device._NEntries) == [12]
            @test Array(csrNew_device._NRows) == [5]
            @test Array(csrNew_device._NRowsCache) == [5]
            @test Array(csrNew_device._NRowsCompacted) == [4]
            @test Array(csrNew_device._NEntriesRow) == [4,3,5,0,1]
            @test Array(csrNew_device._NEntriesRowAdd) == [4,3,5,0,1]
            @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,4,0,1]
            @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
            @test CellBasedModels.overflow(csrNew_device) == true

            preallocate!(csrNew_device, csr_device)
            @test Array(csrNew_device._map) == [
                    1,2,3,10,
                    4,5,10,0,
                    6,8,0,0,
                    0,0,0,0,
                    1,0,0,0
                ]
            @test Array(csrNew_device._NEntries) == [10]
            @test Array(csrNew_device._NRows) == [5]
            @test Array(csrNew_device._NRowsCache) == [5]
            @test Array(csrNew_device._NRowsCompacted) == [4]
            @test Array(csrNew_device._NEntriesRow) == [4,3,2,0,1]
            @test Array(csrNew_device._NEntriesRowAdd) == [4,3,2,0,1]
            @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,2,0,1]
            @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
            @test CellBasedModels.overflow(csrNew_device) == false

            operations_csrblock_execute2(csrNew_device, csr_device)
            @test Array(csrNew_device._map) == [
                    1,2,3,10,
                    4,5,10,0,
                    6,8,11,14,
                    0,0,0,0,
                    1,0,0,0
                ]
            @test Array(csrNew_device._NEntries) == [12]
            @test Array(csrNew_device._NRows) == [5]
            @test Array(csrNew_device._NRowsCache) == [5]
            @test Array(csrNew_device._NRowsCompacted) == [4]
            @test Array(csrNew_device._NEntriesRow) == [4,3,4,0,1]
            @test Array(csrNew_device._NEntriesRowAdd) == [4,3,4,0,1]
            @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,4,0,1]
            @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
            @test CellBasedModels.overflow(csrNew_device) == false

            copyto!(csr_device, csrNew_device)
            @test all(csrNew_device._NBlock .== csr_device._NBlock)
            @test all(csrNew_device._sortingFlavor .== csr_device._sortingFlavor)
            @test all(csrNew_device._map .== csr_device._map)
            @test all(csrNew_device._rowEntryNext .== csr_device._rowEntryNext)
            @test all(csrNew_device._rowEntryPrevious .== csr_device._rowEntryPrevious)
            @test all(csrNew_device._rowFirstEntry .== csr_device._rowFirstEntry)
            @test all(csrNew_device._rowLastEntry .== csr_device._rowLastEntry)
            @test all(csrNew_device._NRows .== csr_device._NRows)
            @test all(csrNew_device._NRowsCache .== csr_device._NRowsCache)
            @test all(csrNew_device._NRowsAdd .== csr_device._NRowsAdd)
            @test all(csrNew_device._NRowsCompacted .== csr_device._NRowsCompacted)
            @test all(csrNew_device._NEntries .== csr_device._NEntries)
            @test all(csrNew_device._NEntriesRow .== csr_device._NEntriesRow)
            @test all(csrNew_device._NEntriesRowAdd .== csr_device._NEntriesRowAdd)
            @test all(csrNew_device._NEntriesRowCompacted .== csr_device._NEntriesRowCompacted)
            @test all(csrNew_device._rowSurvived .== csr_device._rowSurvived)

            operations_csrblock_execute3(csrNew_device, csr_device)
            @test Array(csrNew_device._map) == [
                    1,2,3,10,
                    4,5,10,0,
                    6,8,11,14,
                    0,0,0,0,
                    1,0,0,0
                ]
            @test Array(csrNew_device._NEntries) == [13]
            @test Array(csrNew_device._NRows) == [6]
            @test Array(csrNew_device._NRowsCache) == [5]
            @test Array(csrNew_device._NRowsCompacted) == [5]
            @test Array(csrNew_device._NEntriesRow) == [4,3,5,0,1]
            @test Array(csrNew_device._NEntriesRowAdd) == [4,3,5,0,1]
            @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,5,0,1]
            @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
            @test CellBasedModels.overflow(csrNew_device) == true

            preallocate!(csrNew_device, csr_device)
            @test Array(csrNew_device._map) == [
                    1,2,3,10,0,
                    4,5,10,0,0,
                    6,8,11,14,0,
                    1,0,0,0,0,
                    0,0,0,0,0,
                ]
            @test Array(csrNew_device._NEntries) == [12]
            @test Array(csrNew_device._NRows) == [4]
            @test Array(csrNew_device._NRowsCache) == [5]
            @test Array(csrNew_device._NRowsCompacted) == [4]
            @test Array(csrNew_device._NEntriesRow) == [4,3,4,1,0]
            @test Array(csrNew_device._NEntriesRowAdd) == [4,3,4,1,0]
            @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,4,1,0]
            @test Array(csrNew_device._rowSurvived) == [1,1,1,1,0]
            @test CellBasedModels.overflow(csrNew_device) == false

        end

    end

    # @testset "CSRCache" begin

    #     #Constructor
    #     csr = CSRCache(30, 3; dtype=Int)
    #     @test CellBasedModels.numberOfRows(csr) == 0
    #     @test CellBasedModels.numberOfRowsCache(csr) == 3
    #     @test CellBasedModels.fullLength(csr) == 30
    #     @test csr._map == zeros(Int, 30)
    #     @test csr._elementOffsets == zeros(Int, 4)
    #     @test csr._N[] == 0
    #     @test csr._NCache[] == 3
    #     @test csr._NAdded[] == 0
    #     @test csr._lAdded[] == 0
    #     @test csr._addOffsets == zeros(Int, 31)
    #     @test csr._addElementOffsets == zeros(Int, 4)
    #     @test csr._childs == zeros(Int, 4)

    #     csr = CSRCache([1,4,3]; additionalNCache=2, additionalL=5, dtype=Int)
    #     @test CellBasedModels.numberOfRows(csr) == 3
    #     @test CellBasedModels.numberOfRowsCache(csr) == 5
    #     @test CellBasedModels.fullLength(csr) == 13
    #     @test csr._map == zeros(Int, 13)
    #     @test csr._elementOffsets == [1,2,6,9,0,0]
    #     @test csr._N[] == 3
    #     @test csr._NCache[] == 5
    #     @test csr._NAdded[] == 0
    #     @test csr._lAdded[] == 0
    #     @test csr._addOffsets == zeros(Int, 14)
    #     @test csr._addElementOffsets == zeros(Int, 6)
    #     @test csr._childs == zeros(Int, 6)

    #     csr = CSRCache([[1,2,3], [4,5], [6]]; additionalNCache=2, additionalL=3)
    #     @test CellBasedModels.numberOfRows(csr) == 3
    #     @test CellBasedModels.numberOfRowsCache(csr) == 5
    #     @test CellBasedModels.fullLength(csr) == 9
    #     @test csr._map == [1,2,3,4,5,6,0,0,0]
    #     @test csr._elementOffsets == [1,4,6,7,0,0]
    #     @test csr._N[] == 3
    #     @test csr._NCache[] == 5
    #     @test csr._NAdded[] == 0
    #     @test csr._lAdded[] == 0
    #     @test csr._addOffsets == zeros(Int, 10)
    #     @test csr._addElementOffsets == zeros(Int, 6)
    #     @test csr._childs == zeros(Int, 6)

    #     #Iterators
    #     csr = CSRCache([[1,2,3], [4,5], [6]]; additionalNCache=2, additionalL=3)
    #     csr._map[1:6] .= 1:6

    #     results = [i for i in csr]
    #     @test length(results) == 6
    #     @test results == [(1, 1), (1, 2), (1, 3), (2, 4), (2, 5), (3, 6)]

    #     # Test operators
    #     for device in devices

    #         # addElement!
    #         csr = CSRCache([2, 3]; additionalNCache=5, additionalL=0, dtype=Int)
    #         csr_device = CellBasedModels.toDevice(csr, device)

    #         kernel_csrcache_memclaim_addElement(csr_device, 4)
    #         @test Array(csr_device._N)[1] == 2         
    #         @test Array(csr_device._NCache)[1] == 7
    #         @test Array(csr_device._NAdded)[1] == 1
    #         @test Array(csr_device._lAdded)[1] == 4
    #         @test Array(csr_device._addElementOffsets)[1] == 0
    #         @test Array(csr_device._childs)[1] == 0

    #         preallocate!(csr_device)

    #         kernel_csrcache_allocate_addElement(csr_device, 4)
    #         @test Array(csr_device._N)[1] == 2         
    #         @test Array(csr_device._NCache)[1] == 7
    #         @test Array(csr_device._NAdded)[1] == 1
    #         @test Array(csr_device._lAdded)[1] == 4
    #         @test Array(csr_device._addOffsets)[1] == 4
    #         @test Array(csr_device._childs)[1] == 1

    #         remap!(csr_device)

    #         kernel_csrcache_execute_addElement(csr_device, 4)
    #         @test Array(csr_device._N)[1] == 2         
    #         @test Array(csr_device._NCache)[1] == 7
    #         @test Array(csr_device._NAdded)[1] == 1
    #         @test Array(csr_device._lAdded)[1] == 4
    #         @test Array(csr_device._addElementOffsets)[1] == 4
    #         @test Array(csr_device._childs)[1] == 1
    #         @test Array(csr_device._elementOffsets)[1:4] == [1,3,6,10]

    #         # reset!(csr_device)

    #         # @test Array(csr_device._NAdded)[1] == 0
    #         # @test Array(csr_device._childs)[1] == 0
    #         # @test Array(csr_device._addElementOffsets)[1] == 0

    #     end
    # end

end