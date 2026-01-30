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

# Unsorted operators
function operations_CSRStruct_execute(csr, csrOld)

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

function operations_CSRStruct_execute2(csr, csrOld)
    
    @kernel function _kernel!(csr)
        insertRowCol!(csr, 3, 11)
        insertRowCol!(csr, 3, 14)
    end

    backend = KernelAbstractions.get_backend(csr)
    _kernel!(backend, 1)(csr, ndrange=1)
    KernelAbstractions.synchronize(backend)

end

function operations_CSRStruct_execute3(csr, csrOld)
    
    @kernel function _kernel!(csr)
        insertRowCol!(csr, 3, 5)
        pushRow!(csr, (3,15,7))
    end

    backend = KernelAbstractions.get_backend(csr)
    _kernel!(backend, 1)(csr, ndrange=1)
    KernelAbstractions.synchronize(backend)

end

# Sorted operators
function operations_CSRStruct_execute_sorted(csr, csrOld)

    @kernel function _kernel!(csr, csrOld)
        pushRow!(csr, 1)
        removeRow!(csr, 4)

        insertRowCol!(csr, 1, 2, 10)
        insertRowCol!(csr, 2, 5, 10)
        removeRowCol!(csr, 3, 7)
    end

    backend = KernelAbstractions.get_backend(csr)
    _kernel!(backend, 1)(csr, csrOld, ndrange=1)
    KernelAbstractions.synchronize(backend)

end

function operations_CSRStruct_execute2_sorted(csr, csrOld)
    
    @kernel function _kernel!(csr)
        insertRowCol!(csr, 3, 11)
        insertRowCol!(csr, 3, 14)
    end

    backend = KernelAbstractions.get_backend(csr)
    _kernel!(backend, 1)(csr, ndrange=1)
    KernelAbstractions.synchronize(backend)

end

function operations_CSRStruct_execute3_sorted(csr, csrOld)
    
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
# println("CSRStruct:")
# CSRStruct = CSRStruct(N=3,NBlock=2,NCache=10)
# CSRStruct._ActiveSection .= 2
# CSRStruct._map .= 1:20
# @btime f(CSRStruct)

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

# using Atomix

# @kernel function test(x)
#     i = @index(Global)
#     j = Atomix.@atomicreplace x[i] 0 => 1
#     @print j.success "\n" 
# end
# for device in devices
#    x = toDevice(device, zeros(Int, 10))
#    @views(x[1:10]) .= 1:10
#    @views(x[1:10]) .= @views(x[10:-1:1])
#    println(x) 
# #    backend = KernelAbstractions.get_backend(x)
# #    println(x)
# #    test(backend, 1)(x, ndrange=1)
# end

@testset "Topology" begin

    @testset "DynamicalCOO" begin

        # Build
        coo = dcoo_zeros(Float64, 2)
        @test Array(coo._rows) == [0,0]
        @test Array(coo._cols) == [0,0]
        @test Array(coo._values) == [0.0, 0.0]
        @test (Array(coo._NRows), Array(coo._NCols)) == ([0], [0])
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([0],[2],[0])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([2],[3],[0])
        @test (Array(coo._entriesFree)) == [2,1]
        # Insert
        coo[1,1] = 5
        coo[10,15] = 12
        coo[2,3] = 7
        @test Array(coo._rows) == [1,10,2]
        @test Array(coo._cols) == [1,15,3]
        @test Array(coo._values) == [5.0, 12.0, 7.0]
        @test (Array(coo._NRows), Array(coo._NCols)) == ([10], [15])
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([3],[3],[3])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([-1],[3],[0])
        @test (Array(coo._entriesFree)) == [0,0,0]
        # Modify 
        coo[1,1] = 7
        coo[10,15] = 11
        coo[2,3] = 0
        @test Array(coo._rows) == [1,10,2]
        @test Array(coo._cols) == [1,15,3]
        @test Array(coo._values) == [7.0, 11.0, 0.0]
        @test (Array(coo._NRows), Array(coo._NCols)) == ([10], [15])
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([3],[3],[2])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([-1],[3],[0])
        @test (Array(coo._entriesFree)) == [0,0,0]
        # Remove
        coo[1,1] = nothing
        coo[1,3] = nothing
        @test Array(coo._rows) == [0,10,2]
        @test Array(coo._cols) == [0,15,3]
        @test Array(coo._values) == [0.0, 11.0, 0.0]
        @test (Array(coo._NRows), Array(coo._NCols)) == ([10], [15])
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([2],[3],[1])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([-1],[3],[1])
        @test (Array(coo._entriesFree)) == [0,0,1]
        # synchronize
        CellBasedModels.synchronize(coo)
        @test Array(coo._rows) == [0,10,2]
        @test Array(coo._cols) == [0,15,3]
        @test Array(coo._values) == [0.0, 11.0, 0.0]
        @test (Array(coo._NRows), Array(coo._NCols)) == ([10], [15])
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([2],[3],[1])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([1],[2],[0])
        @test (Array(coo._entriesFree)) == [1,0,0]
        # dropzeros!
        CellBasedModels.dropzeros!(coo)
        @test Array(coo._rows) == [0,10,0]
        @test Array(coo._cols) == [0,15,0]
        @test Array(coo._values) == [0.0, 11.0, 0.0]
        @test (Array(coo._NRows), Array(coo._NCols)) == ([10], [15])
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([1],[3],[1])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([2],[3],[0])
        @test (Array(coo._entriesFree)) == [1,3,0]
        # preallocate!
        CellBasedModels.preallocate!(coo, n_rows=2)
        @test Array(coo._rows) == [0,10,0,0,0]
        @test Array(coo._cols) == [0,15,0,0,0]
        @test Array(coo._values) == [0.0, 11.0, 0.0, 0.0, 0.0]
        @test (Array(coo._NRows), Array(coo._NCols)) == ([10], [15])
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([1],[5],[1])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([4],[5],[0])
        @test (Array(coo._entriesFree)) == [1,3,4,5,0]
        # compact!
        CellBasedModels.compact!(coo)
        @test Array(coo._rows) == [10,0,0,0,0]
        @test Array(coo._cols) == [15,0,0,0,0]
        @test Array(coo._values) == [11.0, 0.0, 0.0, 0.0, 0.0]
        @test (Array(coo._NRows), Array(coo._NCols)) == ([10], [15])
        @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([1],[5],[1])
        @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([4],[5],[0])
        @test (Array(coo._entriesFree)) == [5,4,3,2,0]
        # compactto!
        # copyto!
        # dropcache!
        # remaprows!
        # remapcols!

        # @test Array(coo._coo) == [(10,15,12.0), (2,3,7.0), (0,0,0.0)]
        # @test Array(coo._NEntries) == [2,3,2]
        # @test Array(coo._NRows) == [10]
        # @test Array(coo._NCols) == [15]

        # preallocate!(coo, n_entries=2)
        # coo[5,5] = 3
        # @test Array(coo._coo) == [(10,15,12.0), (2,3,7.0), (5,5,3.0), (0,0,0.0), (0,0,0.0)]
        # @test Array(coo._NEntries) == [3,5,3]
        # @test Array(coo._NRows) == [10]
        # @test Array(coo._NCols) == [15]
        # dropcache!(coo)
        # @test Array(coo._coo) == [(10,15,12.0), (2,3,7.0), (5,5,3.0)]
        # @test Array(coo._NEntries) == [3,3,3]
        # @test Array(coo._NRows) == [10]
        # @test Array(coo._NCols) == [15]
        
        for device in devices
            # coo = dcoo_zeros(Float64, 2)
            # @test Array(coo._rows) == [1,10,2]
            # @test Array(coo._cols) == [1,15,3]
            # @test Array(coo._values) == [5.0, 12.0, 7.0]
            # @test (Array(coo._NRows), Array(coo._NCols)) == ([10], [15])
            # @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([2],[3],[2])
            # @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([-1],[2],[0])
            # coo = toDevice(coo, device)
            # coo[1,1] = 5
            # coo[10,15] = 12
            # coo[2,3] = 7
            # @test Array(coo._rows) == [1,10,2]
            # @test Array(coo._cols) == [1,15,3]
            # @test Array(coo._values) == [5.0, 12.0, 7.0]
            # @test (Array(coo._NRows), Array(coo._NCols)) == ([10], [15])
            # @test (Array(coo._NEntries), Array(coo._NEntriesCache), Array(coo._NEntriesNonzero)) == ([2],[3],[2])
            # @test (Array(coo._NEntriesFree), Array(coo._NEntriesFreeNextInit), Array(coo._NEntriesFreeNext)) == ([-1],[2],[0])
            # dropzeros!(coo)
            # @test Array(coo._coo) == [(10,15,12.0), (2,3,7.0), (0,0,0.0)]
            # @test Array(coo._NEntries) == [2,3,2]
            # @test Array(coo._NRows) == [10]
            # @test Array(coo._NCols) == [15]
            # preallocate!(coo, n_entries=2)
            # coo[5,5] = 3
            # @test Array(coo._coo) == [(10,15,12.0), (2,3,7.0), (5,5,3.0), (0,0,0.0), (0,0,0.0)]
            # @test Array(coo._NEntries) == [3,5,3]
            # @test Array(coo._NRows) == [10]
            # @test Array(coo._NCols) == [15]
            # dropcache!(coo)
            # @test Array(coo._coo) == [(10,15,12.0), (2,3,7.0), (5,5,3.0)]
            # @test Array(coo._NEntries) == [3,3,3]
            # @test Array(coo._NRows) == [10]
            # @test Array(coo._NCols) == [15]

            # println(coo._coo)
        end

    end

    @testset "DynamicalCSR" begin

        # csr = dcsr_zeros(2, 2, n_coo=2)
        # println(csr)
        # @test csr._values == zeros(4)
        # @test csr._cols == zeros(Int, 4)
        # @test csr._rowOffsets == [1,3,5]
        # @test csr._NRows == [2,2]
        # @test csr._NCols == [0]
        # @test csr._NEntries == [0,4,0]
        # @test csr._NEntriesRow == [0 2 0;0 2 0]
        # @test csr._cooN == [0, 2, 0]
        # @test csr._coo == [(0,0,0.0), (0,0,0.0)]

        # csr[1,1] = 1
        # csr[1,2] = 0
        # csr[1,5] = 7
        # csr[2,3] = 5
        # @test csr._values == [1.,0.,5.,0.]
        # @test csr._cols == [1,2,3,0]
        # @test csr._rowOffsets == [1,3,5]
        # @test csr._NRows == [2,2]
        # @test csr._NCols == [5]
        # @test csr._NEntries == [4,4,3]
        # @test csr._NEntriesRow == [3 2 2;1 2 1]
        # @test csr._cooN == [1, 2, 1]
        # @test csr._coo == [(1,5,7.0), (0,0,0.0)]

        # dropzeros!(csr)
        # @test csr._values == [1.,7.,5.,0.]
        # @test csr._cols == [1,5,3,0]
        # @test csr._rowOffsets == [1,3,5]
        # @test csr._NRows == [2,2]
        # @test csr._NCols == [5]
        # @test csr._NEntries == [3,4,3]
        # @test csr._NEntriesRow == [2 2 2;1 2 1]
        # @test csr._cooN == [0, 2, 0]
        # @test csr._coo == [(0,0,0.0), (0,0,0.0)]

        # compact!(csr)
        # println(csr._NEntriesRowCache)
        # println(csr._values)
        # println(csr._cols)
        # println(csr._rowOffsets)
        # print(csr)

        # #Start
        # csr = CSRStruct(2, 3, 10)
        # @test numberOfEntries(csr) == 0
        # @test numberOfEntriesCache(csr) == 20
        # @test numberOfRows(csr) == 3
        # @test numberOfRowsCache(csr) == 10
        # @test numberOfEntriesInRow(csr, 1) == 0
        # @test numberOfEntriesInRow(csr, 2) == 0
        # @test numberOfEntriesInRowCache(csr, 1) == 2
        # @test csr._map == zeros(Int, 20)
        # @test csr._NRowsCompacted[] == 3
        # @test csr._NEntriesRow == zeros(Int, 10)
        # @test csr._NEntriesRowAdd == zeros(Int, 10)
        # @test csr._NEntriesRowCompacted == zeros(Int, 10)

        # # Test matrix constructor
        # mat = reshape([i for i in 1:12], 4, 3)
        # mat[2, 3] = 0  # Introduce a zero to test sparsity
        # csrMat = CSRStruct(mat, NRowsCache=5, NBlock=4)
        # @test numberOfEntries(csrMat) == 11
        # @test numberOfEntriesCache(csrMat) == 20
        # @test numberOfRows(csrMat) == 4
        # @test numberOfRowsCache(csrMat) == 5
        # @test numberOfEntriesInRow(csrMat, 1) == 3
        # @test numberOfEntriesInRow(csrMat, 2) == 2
        # @test numberOfEntriesInRow(csrMat, 3) == 3
        # @test numberOfEntriesInRow(csrMat, 4) == 3
        # @test numberOfEntriesInRowCache(csrMat, 1) == 4
        # @test csrMat._map == [1,5,9,0,2,6,0,0,3,7,11,0,4,8,12,0,0,0,0,0]
        # @test csrMat._NRowsCompacted[] == 4
        # @test csrMat._NEntriesRow == [3,2,3,3,0]
        # @test csrMat._NEntriesRowAdd == [3,2,3,3,0]
        # @test csrMat._NEntriesRowCompacted == [3,2,3,3,0]        

        # # Test nested vector constructor
        # mat = [[1,2,3], [4,5], [6,7,8], [9,10,11]]
        # csrMat = CSRStruct(mat, NRowsCache=5, NBlock=4)
        # @test numberOfEntries(csrMat) == 11
        # @test numberOfEntriesCache(csrMat) == 20
        # @test numberOfRows(csrMat) == 4
        # @test numberOfRowsCache(csrMat) == 5
        # @test numberOfEntriesInRow(csrMat, 1) == 3
        # @test numberOfEntriesInRow(csrMat, 2) == 2
        # @test numberOfEntriesInRow(csrMat, 3) == 3
        # @test numberOfEntriesInRow(csrMat, 4) == 3
        # @test numberOfEntriesInRowCache(csrMat, 1) == 4
        # @test csrMat._map == [1,2,3,0,4,5,0,0,6,7,8,0,9,10,11,0,0,0,0,0]
        # @test csrMat._NRowsCompacted[] == 4
        # @test csrMat._NEntriesRow == [3,2,3,3,0]
        # @test csrMat._NEntriesRowAdd == [3,2,3,3,0]
        # @test csrMat._NEntriesRowCompacted == [3,2,3,3,0]        
        
        # # Test accessors
        # mat = [[1,2,3], [1,2], [1,5]]
        # csrMat = CSRStruct(mat, NRowsCache=10, NBlock=4)
        # csrMat._map[5] = 0
        # csrMat._map[6] = 0
        # csrMat._map[9] = 0
        # csrMat._rowSurvived[2] = 0
        # # getEntryAtRowPos
        # @test getEntryAtRowPos(csrMat, 0, 1) == 0
        # @test getEntryAtRowPos(csrMat, 1, 0) == 0
        # @test getEntryAtRowPos(csrMat, 1, 1) == 1
        # @test getEntryAtRowPos(csrMat, 1, 2) == 2
        # @test getEntryAtRowPos(csrMat, 1, 3) == 3
        # @test getEntryAtRowPos(csrMat, 1, 4) == 4
        # @test getEntryAtRowPos(csrMat, 1, 5) == 0
        # @test getEntryAtRowPos(csrMat, 2, 1) == 5
        # @test getEntryAtRowPos(csrMat, 2, 2) == 6
        # @test getEntryAtRowPos(csrMat, 2, 3) == 7
        # @test getEntryAtRowPos(csrMat, 2, 4) == 8
        # @test getEntryAtRowPos(csrMat, 3, 1) == 9
        # @test getEntryAtRowPos(csrMat, 3, 2) == 10
        # @test getEntryAtRowPos(csrMat, 3, 3) == 11
        # @test getEntryAtRowPos(csrMat, 3, 4) == 12
        # @test getEntryAtRowPos(csrMat, 3, 5) == 0
        # @test getEntryAtRowPos(csrMat, 4, 1) == 0
        # # getEntryAtRowCol
        # @test getEntryAtRowCol(csrMat, 0, 1) == 0
        # @test getEntryAtRowCol(csrMat, 1, 0) == 0
        # @test getEntryAtRowCol(csrMat, 1, 1) == 1
        # @test getEntryAtRowCol(csrMat, 1, 2) == 2
        # @test getEntryAtRowCol(csrMat, 1, 3) == 3
        # @test getEntryAtRowCol(csrMat, 1, 4) == 0
        # @test getEntryAtRowCol(csrMat, 2, 5) == 0
        # @test getEntryAtRowCol(csrMat, 3, 4) == 0
        # @test getEntryAtRowCol(csrMat, 3, 5) == 10
        # @test getEntryAtRowCol(csrMat, 4, 1) == 0
        # # getPosAtRowCol
        # @test getPosAtRowCol(csrMat, 0, 1) == 0
        # @test getPosAtRowCol(csrMat, 1, 0) == 0
        # @test getPosAtRowCol(csrMat, 1, 1) == 1
        # @test getPosAtRowCol(csrMat, 1, 2) == 2
        # @test getPosAtRowCol(csrMat, 1, 3) == 3
        # @test getPosAtRowCol(csrMat, 1, 4) == 0
        # @test getPosAtRowCol(csrMat, 2, 5) == 0
        # @test getPosAtRowCol(csrMat, 3, 5) == 2
        # @test getPosAtRowCol(csrMat, 3, 4) == 0
        # @test getPosAtRowCol(csrMat, 4, 1) == 0
        # # getPosAtEntry
        # @test getPosAtEntry(csrMat, 0) == 0
        # @test getPosAtEntry(csrMat, 1) == 1
        # @test getPosAtEntry(csrMat, 2) == 2
        # @test getPosAtEntry(csrMat, 3) == 3
        # @test getPosAtEntry(csrMat, 4) == 4
        # @test getPosAtEntry(csrMat, 5) == 1
        # @test getPosAtEntry(csrMat, 6) == 2
        # @test getPosAtEntry(csrMat, 7) == 3
        # @test getPosAtEntry(csrMat, 8) == 4
        # @test getPosAtEntry(csrMat, 9) == 1
        # @test getPosAtEntry(csrMat, 10) == 2
        # @test getPosAtEntry(csrMat, 11) == 3
        # @test getPosAtEntry(csrMat, 12) == 4
        # @test getPosAtEntry(csrMat, 13) == 0
        # # getColAtRowPos
        # @test getColAtRowPos(csrMat, 0, 1) == 0
        # @test getColAtRowPos(csrMat, 1, 0) == 0
        # @test getColAtRowPos(csrMat, 1, 1) == 1
        # @test getColAtRowPos(csrMat, 1, 2) == 2
        # @test getColAtRowPos(csrMat, 1, 3) == 3
        # @test getColAtRowPos(csrMat, 1, 4) == 0
        # @test getColAtRowPos(csrMat, 1, 5) == 0
        # @test getColAtRowPos(csrMat, 2, 1) == 0
        # @test getColAtRowPos(csrMat, 2, 2) == 0
        # @test getColAtRowPos(csrMat, 2, 3) == 0
        # @test getColAtRowPos(csrMat, 2, 4) == 0
        # @test getColAtRowPos(csrMat, 2, 5) == 0
        # @test getColAtRowPos(csrMat, 3, 1) == 0
        # @test getColAtRowPos(csrMat, 3, 2) == 5
        # @test getColAtRowPos(csrMat, 3, 3) == 0
        # @test getColAtRowPos(csrMat, 3, 4) == 0
        # @test getColAtRowPos(csrMat, 3, 5) == 0
        # @test getColAtRowPos(csrMat, 4, 1) == 0
        # # getColAtEntry
        # @test getColAtEntry(csrMat, 0) == 0
        # @test getColAtEntry(csrMat, 1) == 1
        # @test getColAtEntry(csrMat, 2) == 2
        # @test getColAtEntry(csrMat, 3) == 3
        # @test getColAtEntry(csrMat, 4) == 0
        # @test getColAtEntry(csrMat, 5) == 0
        # @test getColAtEntry(csrMat, 6) == 0
        # @test getColAtEntry(csrMat, 7) == 0
        # @test getColAtEntry(csrMat, 8) == 0
        # @test getColAtEntry(csrMat, 9) == 0
        # @test getColAtEntry(csrMat, 10) == 5
        # @test getColAtEntry(csrMat, 11) == 0
        # @test getColAtEntry(csrMat, 12) == 0
        # @test getColAtEntry(csrMat, 13) == 0
        # # getRowAtEntry
        # @test getRowAtEntry(csrMat, 0) == 0
        # @test getRowAtEntry(csrMat, 1) == 1
        # @test getRowAtEntry(csrMat, 2) == 1
        # @test getRowAtEntry(csrMat, 3) == 1
        # @test getRowAtEntry(csrMat, 4) == 1
        # @test getRowAtEntry(csrMat, 5) == 0
        # @test getRowAtEntry(csrMat, 6) == 0
        # @test getRowAtEntry(csrMat, 7) == 0
        # @test getRowAtEntry(csrMat, 8) == 0
        # @test getRowAtEntry(csrMat, 9) == 3
        # @test getRowAtEntry(csrMat, 10) == 3
        # @test getRowAtEntry(csrMat, 11) == 3
        # @test getRowAtEntry(csrMat, 12) == 3
        # @test getRowAtEntry(csrMat, 13) == 0

        # # Test next accessors
        # mat = [[1,5], [1,2], [1,2,3]]
        # csrMat = CSRStruct(mat, NRowsCache=10, NBlock=4)
        # csrMat._map[5] = 0
        # csrMat._map[6] = 0
        # csrMat._map[9] = 0
        # csrMat._rowSurvived[2] = 0

        # mat = [[1,5], [1,2], [1,2,3]]
        # csrMat_sorted = CSRStruct(mat, NRowsCache=3, NBlock=4, sorted=true)
        # csrMat_sorted._map[1] = 0
        # csrMat_sorted._map[5] = 0
        # csrMat_sorted._map[6] = 0
        # csrMat_sorted._rowSurvived[2] = 0
        # csrMat_sorted._rowFirstEntry .= [2,1,2]
        # csrMat_sorted._rowEntryNext .= [
        #         2,0,0,0,
        #         0,0,0,0,
        #         3,1,0,0,
        #     ]

        # # getNextEntryAtRowPos Unsorted
        # @test getNextEntryAtRowPos(csrMat, 0, 1) == 0
        # @test getNextEntryAtRowPos(csrMat, 1, 0) == 0
        # @test getNextEntryAtRowPos(csrMat, 1, 1) == 2
        # @test getNextEntryAtRowPos(csrMat, 1, 2) == 3
        # @test getNextEntryAtRowPos(csrMat, 1, 3) == 0
        # @test getNextEntryAtRowPos(csrMat, 1, 4) == 0
        # @test getNextEntryAtRowPos(csrMat, 1, 5) == 0
        # @test getNextEntryAtRowPos(csrMat, 2, 1) == 0
        # @test getNextEntryAtRowPos(csrMat, 2, 2) == 0
        # @test getNextEntryAtRowPos(csrMat, 2, 3) == 0
        # @test getNextEntryAtRowPos(csrMat, 2, 4) == 0
        # @test getNextEntryAtRowPos(csrMat, 3, 1) == 0
        # @test getNextEntryAtRowPos(csrMat, 3, 2) == 0
        # @test getNextEntryAtRowPos(csrMat, 3, 3) == 0
        # @test getNextEntryAtRowPos(csrMat, 3, 4) == 0
        # @test getNextEntryAtRowPos(csrMat, 3, 5) == 0
        # @test getNextEntryAtRowPos(csrMat, 4, 1) == 0
        # # getNextEntryAtRowPos Sorted
        # @test getNextEntryAtRowPos(csrMat_sorted, 0, 1) == 0
        # @test getNextEntryAtRowPos(csrMat_sorted, 1, 0) == 0
        # @test getNextEntryAtRowPos(csrMat_sorted, 1, 1) == 3
        # @test getNextEntryAtRowPos(csrMat_sorted, 1, 2) == 1
        # @test getNextEntryAtRowPos(csrMat_sorted, 1, 3) == 0
        # @test getNextEntryAtRowPos(csrMat_sorted, 1, 4) == 0
        # @test getNextEntryAtRowPos(csrMat_sorted, 1, 5) == 0
        # @test getNextEntryAtRowPos(csrMat_sorted, 2, 1) == 6
        # @test getNextEntryAtRowPos(csrMat_sorted, 2, 2) == 0
        # @test getNextEntryAtRowPos(csrMat_sorted, 2, 3) == 0
        # @test getNextEntryAtRowPos(csrMat_sorted, 2, 4) == 0
        # @test getNextEntryAtRowPos(csrMat_sorted, 3, 1) == 0
        # @test getNextEntryAtRowPos(csrMat_sorted, 3, 2) == 0
        # @test getNextEntryAtRowPos(csrMat_sorted, 3, 3) == 0
        # @test getNextEntryAtRowPos(csrMat_sorted, 3, 4) == 0
        # @test getNextEntryAtRowPos(csrMat_sorted, 3, 5) == 0
        # @test getNextEntryAtRowPos(csrMat_sorted, 4, 1) == 0
        # # getNextEntryAtRowCol Unsorted
        # @test getNextEntryAtRowCol(csrMat, 0, 1) == 0
        # @test getNextEntryAtRowCol(csrMat, 1, 0) == 0
        # @test getNextEntryAtRowCol(csrMat, 1, 1) == 2
        # @test getNextEntryAtRowCol(csrMat, 1, 2) == 3
        # @test getNextEntryAtRowCol(csrMat, 1, 3) == 0
        # @test getNextEntryAtRowCol(csrMat, 1, 4) == 0
        # @test getNextEntryAtRowCol(csrMat, 2, 5) == 0
        # @test getNextEntryAtRowCol(csrMat, 3, 4) == 0
        # @test getNextEntryAtRowCol(csrMat, 3, 5) == 0
        # @test getNextEntryAtRowCol(csrMat, 4, 1) == 0
        # # getNextEntryAtRowCol Sorted
        # @test getNextEntryAtRowCol(csrMat_sorted, 0, 1) == 0
        # @test getNextEntryAtRowCol(csrMat_sorted, 1, 0) == 0
        # @test getNextEntryAtRowCol(csrMat_sorted, 1, 1) == 3
        # @test getNextEntryAtRowCol(csrMat_sorted, 1, 2) == 1
        # @test getNextEntryAtRowCol(csrMat_sorted, 1, 3) == 0
        # @test getNextEntryAtRowCol(csrMat_sorted, 1, 4) == 0
        # @test getNextEntryAtRowCol(csrMat_sorted, 2, 5) == 0
        # @test getNextEntryAtRowCol(csrMat_sorted, 3, 4) == 0
        # @test getNextEntryAtRowCol(csrMat_sorted, 3, 5) == 0
        # @test getNextEntryAtRowCol(csrMat_sorted, 4, 1) == 0
        # # getNextPosAtRowCol Unsorted
        # @test getNextPosAtRowCol(csrMat, 0, 1) == 0
        # @test getNextPosAtRowCol(csrMat, 1, 0) == 0
        # @test getNextPosAtRowCol(csrMat, 1, 1) == 2
        # @test getNextPosAtRowCol(csrMat, 1, 2) == 3
        # @test getNextPosAtRowCol(csrMat, 1, 3) == 0
        # @test getNextPosAtRowCol(csrMat, 1, 4) == 0
        # @test getNextPosAtRowCol(csrMat, 2, 5) == 0
        # @test getNextPosAtRowCol(csrMat, 3, 5) == 0
        # @test getNextPosAtRowCol(csrMat, 3, 4) == 0
        # @test getNextPosAtRowCol(csrMat, 4, 1) == 0
        # # getNextPosAtRowCol Sorted
        # @test getNextPosAtRowCol(csrMat_sorted, 0, 1) == 0
        # @test getNextPosAtRowCol(csrMat_sorted, 1, 0) == 0
        # @test getNextPosAtRowCol(csrMat_sorted, 1, 1) == 3
        # @test getNextPosAtRowCol(csrMat_sorted, 1, 2) == 1
        # @test getNextPosAtRowCol(csrMat_sorted, 1, 3) == 0
        # @test getNextPosAtRowCol(csrMat_sorted, 1, 4) == 0
        # @test getNextPosAtRowCol(csrMat_sorted, 2, 5) == 0
        # @test getNextPosAtRowCol(csrMat_sorted, 3, 5) == 0
        # @test getNextPosAtRowCol(csrMat_sorted, 3, 4) == 0
        # @test getNextPosAtRowCol(csrMat_sorted, 4, 1) == 0
        # # getNextPosAtEntry Unsorted
        # @test getPosAtEntry(csrMat, 0) == 0
        # @test getPosAtEntry(csrMat, 1) == 1
        # @test getPosAtEntry(csrMat, 2) == 2
        # @test getPosAtEntry(csrMat, 3) == 3
        # @test getPosAtEntry(csrMat, 4) == 4
        # @test getPosAtEntry(csrMat, 5) == 1
        # @test getPosAtEntry(csrMat, 6) == 2
        # @test getPosAtEntry(csrMat, 7) == 3
        # @test getPosAtEntry(csrMat, 8) == 4
        # @test getPosAtEntry(csrMat, 9) == 1
        # @test getPosAtEntry(csrMat, 10) == 2
        # @test getPosAtEntry(csrMat, 11) == 3
        # @test getPosAtEntry(csrMat, 12) == 4
        # @test getPosAtEntry(csrMat, 13) == 0
        # # getNextPosAtEntry Sorted
        # @test getPosAtEntry(csrMat, 0) == 0
        # @test getPosAtEntry(csrMat, 1) == 1
        # @test getPosAtEntry(csrMat, 2) == 2
        # @test getPosAtEntry(csrMat, 3) == 3
        # @test getPosAtEntry(csrMat, 4) == 4
        # @test getPosAtEntry(csrMat, 5) == 1
        # @test getPosAtEntry(csrMat, 6) == 2
        # @test getPosAtEntry(csrMat, 7) == 3
        # @test getPosAtEntry(csrMat, 8) == 4
        # @test getPosAtEntry(csrMat, 9) == 1
        # @test getPosAtEntry(csrMat, 10) == 2
        # @test getPosAtEntry(csrMat, 11) == 3
        # @test getPosAtEntry(csrMat, 12) == 4
        # @test getPosAtEntry(csrMat, 13) == 0
        # # getColAtRowPos
        # @test getColAtRowPos(csrMat, 0, 1) == 0
        # @test getColAtRowPos(csrMat, 1, 0) == 0
        # @test getColAtRowPos(csrMat, 1, 1) == 1
        # @test getColAtRowPos(csrMat, 1, 2) == 2
        # @test getColAtRowPos(csrMat, 1, 3) == 3
        # @test getColAtRowPos(csrMat, 1, 4) == 0
        # @test getColAtRowPos(csrMat, 1, 5) == 0
        # @test getColAtRowPos(csrMat, 2, 1) == 0
        # @test getColAtRowPos(csrMat, 2, 2) == 0
        # @test getColAtRowPos(csrMat, 2, 3) == 0
        # @test getColAtRowPos(csrMat, 2, 4) == 0
        # @test getColAtRowPos(csrMat, 2, 5) == 0
        # @test getColAtRowPos(csrMat, 3, 1) == 0
        # @test getColAtRowPos(csrMat, 3, 2) == 5
        # @test getColAtRowPos(csrMat, 3, 3) == 0
        # @test getColAtRowPos(csrMat, 3, 4) == 0
        # @test getColAtRowPos(csrMat, 3, 5) == 0
        # @test getColAtRowPos(csrMat, 4, 1) == 0
        # # getColAtEntry
        # @test getColAtEntry(csrMat, 0) == 0
        # @test getColAtEntry(csrMat, 1) == 1
        # @test getColAtEntry(csrMat, 2) == 2
        # @test getColAtEntry(csrMat, 3) == 3
        # @test getColAtEntry(csrMat, 4) == 0
        # @test getColAtEntry(csrMat, 5) == 0
        # @test getColAtEntry(csrMat, 6) == 0
        # @test getColAtEntry(csrMat, 7) == 0
        # @test getColAtEntry(csrMat, 8) == 0
        # @test getColAtEntry(csrMat, 9) == 0
        # @test getColAtEntry(csrMat, 10) == 5
        # @test getColAtEntry(csrMat, 11) == 0
        # @test getColAtEntry(csrMat, 12) == 0
        # @test getColAtEntry(csrMat, 13) == 0
        # # getRowAtEntry
        # @test getRowAtEntry(csrMat, 0) == 0
        # @test getRowAtEntry(csrMat, 1) == 1
        # @test getRowAtEntry(csrMat, 2) == 1
        # @test getRowAtEntry(csrMat, 3) == 1
        # @test getRowAtEntry(csrMat, 4) == 1
        # @test getRowAtEntry(csrMat, 5) == 0
        # @test getRowAtEntry(csrMat, 6) == 0
        # @test getRowAtEntry(csrMat, 7) == 0
        # @test getRowAtEntry(csrMat, 8) == 0
        # @test getRowAtEntry(csrMat, 9) == 3
        # @test getRowAtEntry(csrMat, 10) == 3
        # @test getRowAtEntry(csrMat, 11) == 3
        # @test getRowAtEntry(csrMat, 12) == 3
        # @test getRowAtEntry(csrMat, 13) == 0

        # @test getNextEntryAtRowCol(csrMat, 2, 5) == 7
        # @test getNextEntryAtRowCol(csrMat, 2, 7) == 0
        # @test getNextPosAtRowCol(csrMat, 3, 7) == 2
        # @test getNextPosAtRowCol(csrMat, 3, 1) == 0
        # @test getNextPosAtEntry(csrMat, 5) == 1
        # @test getNextColAtRowPos(csrMat, 3, 3) == 8
        # @test getNextColAtRowPos(csrMat, 3, 5) == 0
        # @test getNextColAtEntry(csrMat, 10) == 7

        # # Test iterator returns all elements (no active section filtering)
        # mat = [[1,2,3], [4,5], [6,7,8], [9,10,11]]
        # csrMat = CSRStruct(mat, NRowsCache=10, NBlock=4)
        # results = [i for i in csrMat]
        # @test length(results) == 11  # 4 blocks with a total of 11 elements
        # # Check all blocks iterate through all elements
        # @test results == [(1, 1), (1, 2), (1, 3), (2, 4), (2, 5), (3, 6), (3, 7), (3, 8), (4, 9), (4, 10), (4, 11)]
        
        # #Test row iterator "Unassigned"
        # mat = [[1,2,3], [4,5], [6,7,8], [9,10,11]]
        # csrMat = CSRStruct(mat, NRowsCache=10, NBlock=4)
        # row_results = [i for i in iterateRowEntries(csrMat, 2)]
        # @test length(row_results) == 2
        # @test row_results == [4, 5]

        # #Test rows iterator "Sorted"
        # mat = [[2,3,1], [5,4], [8,6,7], [11,10,9]]
        # csrMat = CSRStruct(mat, NRowsCache=10, NBlock=4, sorted=true)
        # rows_results = [i for i in csrMat]
        # @test length(rows_results) == 11
        # @test rows_results == [(1, 1), (1, 2), (1, 3), (2, 4), (2, 5), (3, 6), (3, 7), (3, 8), (4, 9), (4, 10), (4, 11)]

        # # Test iterators in kernel
        # mat = [[1,2,3], [4,5], [6,7,8], [9,10,11]]
        # csrMat = CSRStruct(mat, NRowsCache=10, NBlock=4)
        # for sorted_flag in [false, true]
        #     csrMat = CSRStruct(mat, NRowsCache=10, NBlock=4, sorted=sorted_flag)
        #     for device in devices
        #         csr_device = CellBasedModels.toDevice(csrMat, device)
        #         v1, v2, v3 = test_iterators_in_kernel(csr_device)
        #         @test v1 == 11
        #         @test v2 == 3
        #         @test v3 == 4
        #     end
        # end

        # # Unsorted: Test operators and compactions
        # for device in devices

        #     mat = [[1,2,3], [4,5], [6,7,8], [9,10,11]]
        #     csrMat = CSRStruct(mat, NRowsCache=5, NBlock=4)
        #     csr_device = CellBasedModels.toDevice(csrMat, device)
        #     csrNew_device = copy(csrMat)
            
        #     @test Array(csr_device._map) == [
        #             1,2,3,0,
        #             4,5,0,0,
        #             6,7,8,0,
        #             9,10,11,0,
        #             0,0,0,0
        #         ]
        #     @test Array(csr_device._NEntries) == [11]
        #     @test Array(csr_device._NRows) == [4]
        #     @test Array(csr_device._NRowsCache) == [5]
        #     @test Array(csr_device._NRowsCompacted) == [4]
        #     @test Array(csr_device._NEntriesRow) == [3,2,3,3,0]
        #     @test Array(csr_device._NEntriesRowAdd) == [3,2,3,3,0]
        #     @test Array(csr_device._NEntriesRowCompacted) == [3,2,3,3,0]
        #     @test Array(csr_device._rowSurvived) == [1,1,1,1,0]

        #     operations_CSRStruct_execute(csrNew_device, csr_device)
        #     @test Array(csrNew_device._map) == [
        #             1,2,3,10,
        #             4,5,10,0,
        #             6,0,8,0,
        #             0,0,0,0,
        #             1,0,0,0
        #         ]
        #     @test Array(csrNew_device._NEntries) == [10]
        #     @test Array(csrNew_device._NRows) == [5]
        #     @test Array(csrNew_device._NRowsCache) == [5]
        #     @test Array(csrNew_device._NRowsCompacted) == [4]
        #     @test Array(csrNew_device._NEntriesRow) == [4,3,3,0,1]
        #     @test Array(csrNew_device._NEntriesRowAdd) == [4,3,3,0,1]
        #     @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,2,0,1]
        #     @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
        #     @test CellBasedModels.overflow(csrNew_device) == false

        #     preallocate!(csrNew_device, csr_device)
        #     @test Array(csrNew_device._map) == [
        #             1,2,3,10,
        #             4,5,10,0,
        #             6,0,8,0,
        #             0,0,0,0,
        #             1,0,0,0
        #         ]
        #     @test Array(csrNew_device._NEntries) == [10]
        #     @test Array(csrNew_device._NRows) == [5]
        #     @test Array(csrNew_device._NRowsCache) == [5]
        #     @test Array(csrNew_device._NRowsCompacted) == [4]
        #     @test Array(csrNew_device._NEntriesRow) == [4,3,3,0,1]
        #     @test Array(csrNew_device._NEntriesRowAdd) == [4,3,3,0,1]
        #     @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,2,0,1]
        #     @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
        #     @test CellBasedModels.overflow(csrNew_device) == false
            
        #     copyto!(csr_device, csrNew_device)
        #     @test all(csrNew_device._NBlock .== csr_device._NBlock)
        #     @test all(csrNew_device._sorted .== csr_device._sorted)
        #     @test all(csrNew_device._map .== csr_device._map)
        #     @test all(csrNew_device._rowEntryNext .== csr_device._rowEntryNext)
        #     @test all(csrNew_device._rowEntryPrevious .== csr_device._rowEntryPrevious)
        #     @test all(csrNew_device._rowFirstEntry .== csr_device._rowFirstEntry)
        #     @test all(csrNew_device._rowLastEntry .== csr_device._rowLastEntry)
        #     @test all(csrNew_device._NRows .== csr_device._NRows)
        #     @test all(csrNew_device._NRowsCache .== csr_device._NRowsCache)
        #     @test all(csrNew_device._NRowsCompacted .== csr_device._NRowsCompacted)
        #     @test all(csrNew_device._NEntries .== csr_device._NEntries)
        #     @test all(csrNew_device._NEntriesRow .== csr_device._NEntriesRow)
        #     @test all(csrNew_device._NEntriesRowAdd .== csr_device._NEntriesRowAdd)
        #     @test all(csrNew_device._NEntriesRowCompacted .== csr_device._NEntriesRowCompacted)
        #     @test all(csrNew_device._rowSurvived .== csr_device._rowSurvived)

        #     operations_CSRStruct_execute2(csrNew_device, csr_device)
        #     @test Array(csrNew_device._map) == [
        #             1,2,3,10,
        #             4,5,10,0,
        #             6,0,8,11,
        #             0,0,0,0,
        #             1,0,0,0
        #         ]
        #     @test Array(csrNew_device._NEntries) == [12]
        #     @test Array(csrNew_device._NRows) == [5]
        #     @test Array(csrNew_device._NRowsCache) == [5]
        #     @test Array(csrNew_device._NRowsCompacted) == [4]
        #     @test Array(csrNew_device._NEntriesRow) == [4,3,5,0,1]
        #     @test Array(csrNew_device._NEntriesRowAdd) == [4,3,5,0,1]
        #     @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,4,0,1]
        #     @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
        #     @test CellBasedModels.overflow(csrNew_device) == true

        #     preallocate!(csrNew_device, csr_device)
        #     @test Array(csrNew_device._map) == [
        #             1,2,3,10,
        #             4,5,10,0,
        #             6,8,0,0,
        #             0,0,0,0,
        #             1,0,0,0
        #         ]
        #     @test Array(csrNew_device._NEntries) == [10]
        #     @test Array(csrNew_device._NRows) == [5]
        #     @test Array(csrNew_device._NRowsCache) == [5]
        #     @test Array(csrNew_device._NRowsCompacted) == [4]
        #     @test Array(csrNew_device._NEntriesRow) == [4,3,2,0,1]
        #     @test Array(csrNew_device._NEntriesRowAdd) == [4,3,2,0,1]
        #     @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,2,0,1]
        #     @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
        #     @test CellBasedModels.overflow(csrNew_device) == false

        #     operations_CSRStruct_execute2(csrNew_device, csr_device)
        #     @test Array(csrNew_device._map) == [
        #             1,2,3,10,
        #             4,5,10,0,
        #             6,8,11,14,
        #             0,0,0,0,
        #             1,0,0,0
        #         ]
        #     @test Array(csrNew_device._NEntries) == [12]
        #     @test Array(csrNew_device._NRows) == [5]
        #     @test Array(csrNew_device._NRowsCache) == [5]
        #     @test Array(csrNew_device._NRowsCompacted) == [4]
        #     @test Array(csrNew_device._NEntriesRow) == [4,3,4,0,1]
        #     @test Array(csrNew_device._NEntriesRowAdd) == [4,3,4,0,1]
        #     @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,4,0,1]
        #     @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
        #     @test CellBasedModels.overflow(csrNew_device) == false

        #     copyto!(csr_device, csrNew_device)
        #     @test all(csrNew_device._NBlock .== csr_device._NBlock)
        #     @test all(csrNew_device._sorted .== csr_device._sorted)
        #     @test all(csrNew_device._map .== csr_device._map)
        #     @test all(csrNew_device._rowEntryNext .== csr_device._rowEntryNext)
        #     @test all(csrNew_device._rowEntryPrevious .== csr_device._rowEntryPrevious)
        #     @test all(csrNew_device._rowFirstEntry .== csr_device._rowFirstEntry)
        #     @test all(csrNew_device._rowLastEntry .== csr_device._rowLastEntry)
        #     @test all(csrNew_device._NRows .== csr_device._NRows)
        #     @test all(csrNew_device._NRowsCache .== csr_device._NRowsCache)
        #     @test all(csrNew_device._NRowsCompacted .== csr_device._NRowsCompacted)
        #     @test all(csrNew_device._NEntries .== csr_device._NEntries)
        #     @test all(csrNew_device._NEntriesRow .== csr_device._NEntriesRow)
        #     @test all(csrNew_device._NEntriesRowAdd .== csr_device._NEntriesRowAdd)
        #     @test all(csrNew_device._NEntriesRowCompacted .== csr_device._NEntriesRowCompacted)
        #     @test all(csrNew_device._rowSurvived .== csr_device._rowSurvived)

        #     operations_CSRStruct_execute3(csrNew_device, csr_device)
        #     @test Array(csrNew_device._map) == [
        #             1,2,3,10,
        #             4,5,10,0,
        #             6,8,11,14,
        #             0,0,0,0,
        #             1,0,0,0
        #         ]
        #     @test Array(csrNew_device._NEntries) == [13]
        #     @test Array(csrNew_device._NRows) == [6]
        #     @test Array(csrNew_device._NRowsCache) == [5]
        #     @test Array(csrNew_device._NRowsCompacted) == [5]
        #     @test Array(csrNew_device._NEntriesRow) == [4,3,5,0,1]
        #     @test Array(csrNew_device._NEntriesRowAdd) == [4,3,5,0,1]
        #     @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,5,0,1]
        #     @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
        #     @test CellBasedModels.overflow(csrNew_device) == true

        #     preallocate!(csrNew_device, csr_device)
        #     @test Array(csrNew_device._map) == [
        #             1,2,3,10,0,
        #             4,5,10,0,0,
        #             6,8,11,14,0,
        #             1,0,0,0,0,
        #             0,0,0,0,0,
        #         ]
        #     @test Array(csrNew_device._NEntries) == [12]
        #     @test Array(csrNew_device._NRows) == [4]
        #     @test Array(csrNew_device._NRowsCache) == [5]
        #     @test Array(csrNew_device._NRowsCompacted) == [4]
        #     @test Array(csrNew_device._NEntriesRow) == [4,3,4,1,0]
        #     @test Array(csrNew_device._NEntriesRowAdd) == [4,3,4,1,0]
        #     @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,4,1,0]
        #     @test Array(csrNew_device._rowSurvived) == [1,1,1,1,0]
        #     @test CellBasedModels.overflow(csrNew_device) == false

        # end

        # # Sorted: Test operators and compactions
        # for device in devices

        #     mat = [[1,2,3], [4,5], [6,7,8], [9,10,11]]
        #     csrMat = CSRStruct(mat, NRowsCache=5, NBlock=4, sorted=true)
        #     csr_device = CellBasedModels.toDevice(csrMat, device)
        #     csrNew_device = copy(csrMat)
            
        #     @test Array(csr_device._map) == [
        #             1,2,3,0,
        #             4,5,0,0,
        #             6,7,8,0,
        #             9,10,11,0,
        #             0,0,0,0
        #         ]
        #     @test Array(csr_device._rowEntryNext) == [
        #             2,3,0,0,
        #             2,0,0,0,
        #             2,3,0,0,
        #             2,3,0,0,
        #             0,0,0,0
        #         ]
        #     @test Array(csr_device._rowFirstEntry) == [1,1,1,1,0]
        #     @test Array(csr_device._rowLastEntry) == [3,2,3,3,0]
        #     @test Array(csr_device._NEntries) == [11]
        #     @test Array(csr_device._NRows) == [4]
        #     @test Array(csr_device._NRowsCache) == [5]
        #     @test Array(csr_device._NRowsCompacted) == [4]
        #     @test Array(csr_device._NEntriesRow) == [3,2,3,3,0]
        #     @test Array(csr_device._NEntriesRowAdd) == [3,2,3,3,0]
        #     @test Array(csr_device._NEntriesRowCompacted) == [3,2,3,3,0]
        #     @test Array(csr_device._rowSurvived) == [1,1,1,1,0]

        #     operations_CSRStruct_execute_sorted(csrNew_device, csr_device)
        #     @test Array(csrNew_device._map) == [
        #             1,2,3,10,
        #             4,5,10,0,
        #             6,0,8,0,
        #             0,0,0,0,
        #             1,0,0,0
        #         ]
        #     @test Array(csrNew_device._rowEntryNext) == [
        #             2,4,0,3,
        #             2,3,0,0,
        #             3,0,0,0,
        #             0,0,0,0,
        #             0,0,0,0
        #         ]
        #     @test Array(csrNew_device._NEntries) == [10]
        #     @test Array(csrNew_device._NRows) == [5]
        #     @test Array(csrNew_device._NRowsCache) == [5]
        #     @test Array(csrNew_device._NRowsCompacted) == [4]
        #     @test Array(csrNew_device._NEntriesRow) == [4,3,3,0,1]
        #     @test Array(csrNew_device._NEntriesRowAdd) == [4,3,3,0,1]
        #     @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,2,0,1]
        #     @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
        #     @test CellBasedModels.overflow(csrNew_device) == false

            # preallocate!(csrNew_device, csr_device)
            # @test Array(csrNew_device._map) == [
            #         1,2,3,10,
            #         4,5,10,0,
            #         6,0,8,0,
            #         0,0,0,0,
            #         1,0,0,0
            #     ]
            # @test Array(csrNew_device._NEntries) == [10]
            # @test Array(csrNew_device._NRows) == [5]
            # @test Array(csrNew_device._NRowsCache) == [5]
            # @test Array(csrNew_device._NRowsCompacted) == [4]
            # @test Array(csrNew_device._NEntriesRow) == [4,3,3,0,1]
            # @test Array(csrNew_device._NEntriesRowAdd) == [4,3,3,0,1]
            # @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,2,0,1]
            # @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
            # @test CellBasedModels.overflow(csrNew_device) == false
            
            # copyto!(csr_device, csrNew_device)
            # @test all(csrNew_device._NBlock .== csr_device._NBlock)
            # @test all(csrNew_device._sorted .== csr_device._sorted)
            # @test all(csrNew_device._map .== csr_device._map)
            # @test all(csrNew_device._rowEntryNext .== csr_device._rowEntryNext)
            # @test all(csrNew_device._rowEntryPrevious .== csr_device._rowEntryPrevious)
            # @test all(csrNew_device._rowFirstEntry .== csr_device._rowFirstEntry)
            # @test all(csrNew_device._rowLastEntry .== csr_device._rowLastEntry)
            # @test all(csrNew_device._NRows .== csr_device._NRows)
            # @test all(csrNew_device._NRowsCache .== csr_device._NRowsCache)
            # @test all(csrNew_device._NRowsCompacted .== csr_device._NRowsCompacted)
            # @test all(csrNew_device._NEntries .== csr_device._NEntries)
            # @test all(csrNew_device._NEntriesRow .== csr_device._NEntriesRow)
            # @test all(csrNew_device._NEntriesRowAdd .== csr_device._NEntriesRowAdd)
            # @test all(csrNew_device._NEntriesRowCompacted .== csr_device._NEntriesRowCompacted)
            # @test all(csrNew_device._rowSurvived .== csr_device._rowSurvived)

            # operations_CSRStruct_execute2(csrNew_device, csr_device)
            # @test Array(csrNew_device._map) == [
            #         1,2,3,10,
            #         4,5,10,0,
            #         6,0,8,11,
            #         0,0,0,0,
            #         1,0,0,0
            #     ]
            # @test Array(csrNew_device._NEntries) == [12]
            # @test Array(csrNew_device._NRows) == [5]
            # @test Array(csrNew_device._NRowsCache) == [5]
            # @test Array(csrNew_device._NRowsCompacted) == [4]
            # @test Array(csrNew_device._NEntriesRow) == [4,3,5,0,1]
            # @test Array(csrNew_device._NEntriesRowAdd) == [4,3,5,0,1]
            # @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,4,0,1]
            # @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
            # @test CellBasedModels.overflow(csrNew_device) == true

            # preallocate!(csrNew_device, csr_device)
            # @test Array(csrNew_device._map) == [
            #         1,2,3,10,
            #         4,5,10,0,
            #         6,8,0,0,
            #         0,0,0,0,
            #         1,0,0,0
            #     ]
            # @test Array(csrNew_device._NEntries) == [10]
            # @test Array(csrNew_device._NRows) == [5]
            # @test Array(csrNew_device._NRowsCache) == [5]
            # @test Array(csrNew_device._NRowsCompacted) == [4]
            # @test Array(csrNew_device._NEntriesRow) == [4,3,2,0,1]
            # @test Array(csrNew_device._NEntriesRowAdd) == [4,3,2,0,1]
            # @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,2,0,1]
            # @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
            # @test CellBasedModels.overflow(csrNew_device) == false

            # operations_CSRStruct_execute2(csrNew_device, csr_device)
            # @test Array(csrNew_device._map) == [
            #         1,2,3,10,
            #         4,5,10,0,
            #         6,8,11,14,
            #         0,0,0,0,
            #         1,0,0,0
            #     ]
            # @test Array(csrNew_device._NEntries) == [12]
            # @test Array(csrNew_device._NRows) == [5]
            # @test Array(csrNew_device._NRowsCache) == [5]
            # @test Array(csrNew_device._NRowsCompacted) == [4]
            # @test Array(csrNew_device._NEntriesRow) == [4,3,4,0,1]
            # @test Array(csrNew_device._NEntriesRowAdd) == [4,3,4,0,1]
            # @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,4,0,1]
            # @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
            # @test CellBasedModels.overflow(csrNew_device) == false

            # copyto!(csr_device, csrNew_device)
            # @test all(csrNew_device._NBlock .== csr_device._NBlock)
            # @test all(csrNew_device._sorted .== csr_device._sorted)
            # @test all(csrNew_device._map .== csr_device._map)
            # @test all(csrNew_device._rowEntryNext .== csr_device._rowEntryNext)
            # @test all(csrNew_device._rowEntryPrevious .== csr_device._rowEntryPrevious)
            # @test all(csrNew_device._rowFirstEntry .== csr_device._rowFirstEntry)
            # @test all(csrNew_device._rowLastEntry .== csr_device._rowLastEntry)
            # @test all(csrNew_device._NRows .== csr_device._NRows)
            # @test all(csrNew_device._NRowsCache .== csr_device._NRowsCache)
            # @test all(csrNew_device._NRowsCompacted .== csr_device._NRowsCompacted)
            # @test all(csrNew_device._NEntries .== csr_device._NEntries)
            # @test all(csrNew_device._NEntriesRow .== csr_device._NEntriesRow)
            # @test all(csrNew_device._NEntriesRowAdd .== csr_device._NEntriesRowAdd)
            # @test all(csrNew_device._NEntriesRowCompacted .== csr_device._NEntriesRowCompacted)
            # @test all(csrNew_device._rowSurvived .== csr_device._rowSurvived)

            # operations_CSRStruct_execute3(csrNew_device, csr_device)
            # @test Array(csrNew_device._map) == [
            #         1,2,3,10,
            #         4,5,10,0,
            #         6,8,11,14,
            #         0,0,0,0,
            #         1,0,0,0
            #     ]
            # @test Array(csrNew_device._NEntries) == [13]
            # @test Array(csrNew_device._NRows) == [6]
            # @test Array(csrNew_device._NRowsCache) == [5]
            # @test Array(csrNew_device._NRowsCompacted) == [5]
            # @test Array(csrNew_device._NEntriesRow) == [4,3,5,0,1]
            # @test Array(csrNew_device._NEntriesRowAdd) == [4,3,5,0,1]
            # @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,5,0,1]
            # @test Array(csrNew_device._rowSurvived) == [1,1,1,0,1]
            # @test CellBasedModels.overflow(csrNew_device) == true

            # preallocate!(csrNew_device, csr_device)
            # @test Array(csrNew_device._map) == [
            #         1,2,3,10,0,
            #         4,5,10,0,0,
            #         6,8,11,14,0,
            #         1,0,0,0,0,
            #         0,0,0,0,0,
            #     ]
            # @test Array(csrNew_device._NEntries) == [12]
            # @test Array(csrNew_device._NRows) == [4]
            # @test Array(csrNew_device._NRowsCache) == [5]
            # @test Array(csrNew_device._NRowsCompacted) == [4]
            # @test Array(csrNew_device._NEntriesRow) == [4,3,4,1,0]
            # @test Array(csrNew_device._NEntriesRowAdd) == [4,3,4,1,0]
            # @test Array(csrNew_device._NEntriesRowCompacted) == [4,3,4,1,0]
            # @test Array(csrNew_device._rowSurvived) == [1,1,1,1,0]
            # @test CellBasedModels.overflow(csrNew_device) == false

        # end

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