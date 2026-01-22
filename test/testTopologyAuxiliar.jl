function f(csr)
    for i in csr
        i
    end
end

# addElement!
function operations_csrtuple_test(csr)
    @kernel function _kernel!(csr, v)
        v[1] = hasElement(csr, 1, 1)
        v[2] = lengthRowCache(csr, 2)
        v[3] = lengthRowActive(csr, 3)
        substitute!(csr, 4, 7, 5)
        substitutePos!(csr, 5, 1, 11)
        remove!(csr, 6, 11)
        removePos!(csr, 7, 2)
    end

    backend = KernelAbstractions.get_backend(csr)
    v = Adapt.adapt(backend, zeros(Int, 3))
    _kernel!(backend, 1)(csr, v, ndrange=1)
    KernelAbstractions.synchronize(backend)

    return v
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

    @testset "CSRTuple" begin

        #Start
        csr = CSRTuple(2, 3, 10)
        csr._map .= 0:19
        csr._NEntries[] = 5
        @test csr._NRows[] == 3
        @test csr._NBlock == 2
        @test csr._NRowsCache[] == 10
        @test length(csr._map) == 20
        @test numberOfRows(csr) == 3
        @test numberOfRowsCache(csr) == 10
        
        # Test iterator returns all elements (no active section filtering)
        results = [i for i in csr]
        @test length(results) == 5  # 3 blocks * 2 elements each
        
        # Check all blocks iterate through all elements
        @test results[1] == (1, 1)
        @test results[2] == (2, 2)
        @test results[3] == (2, 3)
        @test results[4] == (3, 4)
        @test results[5] == (3, 5)
        
        # Test with larger block size
        csr2 = CSRTuple(5, 2, 10)
        csr2._map[1:10] .= 1:10
        csr2._NEntries[] = 10
        
        results2 = [f for f in csr2]
        @test length(results2) == 10  # 2 blocks * 5 elements each
        @test results2[1] == (1, 1)
        @test results2[5] == (1, 5)
        @test results2[6] == (2, 6)
        @test results2[10] == (2, 10)

        # Test matrix constructor
        mat = reshape(1:12, 4, 3)
        csrMat = CSRTuple(mat, additionalCache=5)
        @test csrMat._NRows[] == 4
        @test csrMat._NBlock == 3
        @test csrMat._NRowsCache[] == 9
        @test csrMat._map[1:12] == collect(1:12)

        # Test nested vectors constructor
        nestedVec = [[1,2], [3,4], [5,6]]
        csrNested = CSRTuple(nestedVec, additionalCache=4)
        @test csrNested._NRows[] == 3
        @test csrNested._NBlock == 2
        @test csrNested._NRowsCache[] == 7
        @test csrNested._map[1:6] == collect(1:6)
        
        nestedVec2 = [[10,20,30], [40,50], [60,70,80,90]]
        @test_throws AssertionError CSRTuple(nestedVec2, additionalCache=5)

        # Test operators
        for device in devices

            nestedVec = [[1,2], [3,4], [0,6], [7,8], [9,10], [11,12], [13,14]]
            csr = CSRTuple(nestedVec, additionalCache=4)
            csr_device = CellBasedModels.toDevice(csr, device)
            v = operations_csrtuple_test(csr_device)
            v_host = Array(v)
            csr_host = toDevice(csr_device, CPU())
            @test v_host[1] == true        # isInRow
            @test v_host[2] == 2           # lengthRowCache
            @test v_host[3] == 1           # lengthRowActive
            @test getColumnAtRowPos(csr_host, 4, 1) == 5  # substitute!
            @test getColumnAtRowPos(csr_host, 5, 1) == 11 # substitutePos!
            @test getColumnAtRowPos(csr_host, 6, 1) == 0  # remove!
            @test getColumnAtRowPos(csr_host, 7, 2) == 0  # removePos!

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