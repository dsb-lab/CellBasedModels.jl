function f(csr)
    for i in csr
        i
    end
end

# addElement!
function kernel_csrtuple_memclaim_addElement(csr, n)
    @kernel function memclaim_addElement_kernel!(csr, n)
        i = @index(Global)
        CellBasedModels.memclaim_addElement!(csr, N=n)
    end

    backend = KernelAbstractions.get_backend(csr)
    kernel = memclaim_addElement_kernel!(backend, 1)
    kernel(csr, n, ndrange=1)
    KernelAbstractions.synchronize(backend)
end

function kernel_csrtuple_allocate_addElement(csr, n)
    @kernel function allocate_addElement_kernel!(csr, n)
        i = @index(Global)
        CellBasedModels.allocate_addElement!(csr, N=n)
    end

    backend = KernelAbstractions.get_backend(csr)
    kernel = allocate_addElement_kernel!(backend, 1)
    kernel(csr, n, ndrange=1)
    KernelAbstractions.synchronize(backend)
end

function kernel_csrtuple_execute_addElement(csr, n)
    @kernel function execute_addElement_kernel!(csr, n)
        i = @index(Global)
        pos = CellBasedModels.execute_addElement!(csr) 
        setElement!(csr, pos, pos)
    end

    backend = KernelAbstractions.get_backend(csr)
    kernel = execute_addElement_kernel!(backend, 1)
    kernel(csr, n, ndrange=1)
    KernelAbstractions.synchronize(backend)
    return
end

# addElement_i! kernels
function kernel_csrtuple_memclaim_addElement_i(csr, n)
    @kernel function memclaim_addElement_kernel!(csr, n)
        i = @index(Global)
        CellBasedModels.memclaim_addElement!(csr, i, N=n)
    end

    backend = KernelAbstractions.get_backend(csr)
    kernel = memclaim_addElement_kernel!(backend, CellBasedModels.lengthElements(csr))
    kernel(csr, n, ndrange=CellBasedModels.lengthElements(csr))
    KernelAbstractions.synchronize(backend)
end

function kernel_csrtuple_allocate_addElement_i(csr, n)
    @kernel function allocate_addElement_kernel!(csr, n)
        i = @index(Global)
        CellBasedModels.allocate_addElement!(csr, i, N=n)
    end

    backend = KernelAbstractions.get_backend(csr)
    kernel = allocate_addElement_kernel!(backend, CellBasedModels.lengthElements(csr))
    kernel(csr, n, ndrange=CellBasedModels.lengthElements(csr))
    KernelAbstractions.synchronize(backend)
end

function kernel_csrtuple_execute_addElement_i(csr, n)
    @kernel function execute_addElement_kernel!(csr, n)
        i = @index(Global)
        pos = CellBasedModels.execute_addElement!(csr, i) 
        setElement!(csr, pos, (pos,pos,pos))
    end

    backend = KernelAbstractions.get_backend(csr)
    kernel = execute_addElement_kernel!(backend, CellBasedModels.lengthElements(csr))
    kernel(csr, n, ndrange=CellBasedModels.lengthElements(csr))
    KernelAbstractions.synchronize(backend)
    return
end

# removeElement kernels
function kernel_csrtuple_memclaim_removeElement(csr, n)
    @kernel function memclaim_removeElement_kernel!(csr, n)
        i = @index(Global)
        if i % 2 == 1
            CellBasedModels.memclaim_removeElement!(csr, i)
        end
    end

    backend = KernelAbstractions.get_backend(csr)
    kernel = memclaim_removeElement_kernel!(backend, CellBasedModels.lengthElements(csr))
    kernel(csr, n, ndrange=CellBasedModels.lengthElements(csr))
    KernelAbstractions.synchronize(backend)
end

function kernel_csrtuple_allocate_removeElement(csr, n)
    @kernel function allocate_removeElement_kernel!(csr, n)
        i = @index(Global)
        if i % 2 == 1
            CellBasedModels.allocate_removeElement!(csr, i)
        end
    end

    backend = KernelAbstractions.get_backend(csr)
    kernel = allocate_removeElement_kernel!(backend, CellBasedModels.lengthElements(csr))
    kernel(csr, n, ndrange=CellBasedModels.lengthElements(csr))
    KernelAbstractions.synchronize(backend)
end

function kernel_csrtuple_execute_removeElement(csr, n)
    @kernel function execute_removeElement_kernel!(csr, n)
        i = @index(Global)
        if i % 2 == 1
            pos = CellBasedModels.execute_removeElement!(csr, i) 
        end
    end

    backend = KernelAbstractions.get_backend(csr)
    kernel = execute_removeElement_kernel!(backend, CellBasedModels.lengthElements(csr))
    kernel(csr, n, ndrange=CellBasedModels.lengthElements(csr))
    KernelAbstractions.synchronize(backend)
    return
end

# CSRCache

# addElement!
function kernel_cachetuple_memclaim_addElement(csr, l)
    @kernel function memclaim_addElement_kernel!(csr, l)
        i = @index(Global)
        CellBasedModels.memclaim_addElement!(csr, l=l)
    end

    backend = KernelAbstractions.get_backend(csr)
    kernel = memclaim_addElement_kernel!(backend, l)
    kernel(csr, l, ndrange=1)
    KernelAbstractions.synchronize(backend)
end

function kernel_csrtuple_allocate_addElement(csr, l)
    @kernel function allocate_addElement_kernel!(csr, l)
        i = @index(Global)
        CellBasedModels.allocate_addElement!(csr, l=l)
    end

    backend = KernelAbstractions.get_backend(csr)
    kernel = allocate_addElement_kernel!(backend, 1)
    kernel(csr, l, ndrange=1)
    KernelAbstractions.synchronize(backend)
end

function kernel_csrtuple_execute_addElement(csr, l)
    @kernel function execute_addElement_kernel!(csr, l)
        i = @index(Global)
        pos = CellBasedModels.execute_addElement!(csr, l=l) 
        setElement!(csr, pos, pos)
    end

    backend = KernelAbstractions.get_backend(csr)
    kernel = execute_addElement_kernel!(backend, 1)
    kernel(csr, l, ndrange=1)
    KernelAbstractions.synchronize(backend)
    return
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
        csr._map .= 1:20
        @test csr._N[] == 3
        @test csr._NBlock[] == 2
        @test csr._NCache[] == 10
        @test csr._NAdded[] == 0
        @test csr._addElementOffsets == zeros(Int, 11)
        @test csr._childs == zeros(Int, 11)
        @test CellBasedModels.length(csr._map) == 20
        @test CellBasedModels.CellBasedModels.lengthElements(csr) == 3
        @test CellBasedModels.CellBasedModels.lengthElementsCache(csr) == 10
        @test CellBasedModels.CellBasedModels.lengthElementsAdded(csr) == 0
        @test CellBasedModels.lengthAdded(csr) == 0
        
        # Test iterator returns all elements (no active section filtering)
        results = [i for i in csr]
        @test length(results) == 6  # 3 blocks * 2 elements each
        
        # Check all blocks iterate through all elements
        @test results[1] == (1, 1)
        @test results[2] == (1, 2)
        @test results[3] == (2, 3)
        @test results[4] == (2, 4)
        @test results[5] == (3, 5)
        @test results[6] == (3, 6)
        
        # Test with larger block size
        csr2 = CSRTuple(5, 2, 10)
        csr2._map[1:10] .= 1:10
        
        results2 = [f for f in csr2]
        @test length(results2) == 10  # 2 blocks * 5 elements each
        @test results2[1] == (1, 1)
        @test results2[5] == (1, 5)
        @test results2[6] == (2, 6)
        @test results2[10] == (2, 10)

        # Test matrix constructor
        mat = reshape(1:12, 4, 3)
        csrMat = CSRTuple(mat, additionalCache=5)
        @test csrMat._N[] == 4
        @test csrMat._NBlock[] == 3
        @test csrMat._NCache[] == 9
        @test csrMat._map[1:12] == collect(1:12)

        # Test nested vectors constructor
        nestedVec = [[1,2], [3,4], [5,6]]
        csrNested = CSRTuple(nestedVec, additionalCache=4)
        @test csrNested._N[] == 3
        @test csrNested._NBlock[] == 2
        @test csrNested._NCache[] == 7
        @test csrNested._map[1:6] == collect(1:6)
        
        nestedVec2 = [[10,20,30], [40,50], [60,70,80,90]]
        @test_throws AssertionError CSRTuple(nestedVec2, additionalCache=5)

        # Test operators
        for device in devices

            # addElement!
            csr = CSRTuple(3, 2, 5)
            csr_device = CellBasedModels.toDevice(csr, device)

            kernel_csrtuple_memclaim_addElement(csr_device, 4)
            @test Array(csr_device._NAdded)[1] == 4
            @test Array(csr_device._childs)[1] == 0

            preallocate!(csr_device)

            kernel_csrtuple_allocate_addElement(csr_device, 4)
            @test Array(csr_device._NCache)[1] == 6
            @test Array(csr_device._NAdded)[1] == 4
            @test Array(csr_device._childs)[1] == 4
            @test Array(csr_device._addElementOffsets)[1] == 0

            remap!(csr_device)

            kernel_csrtuple_execute_addElement(csr_device, 4)
            @test Array(csr_device._NAdded)[1] == 4
            @test Array(csr_device._map)[7:9] == [3,0,0]

            reset!(csr_device)

            @test Array(csr_device._NAdded)[1] == 0
            @test Array(csr_device._childs)[1] == 0
            @test Array(csr_device._addElementOffsets)[1] == 0

            # addElement!
            csr = CSRTuple(3, 2, 5)
            csr_device = CellBasedModels.toDevice(csr, device)

            kernel_csrtuple_memclaim_addElement_i(csr_device, 4)
            @test Array(csr_device._NAdded)[1] == 8
            @test Array(csr_device._childs)[1] == 0

            preallocate!(csr_device)

            kernel_csrtuple_allocate_addElement_i(csr_device, 4)
            @test Array(csr_device._NCache)[1] == 10
            @test Array(csr_device._NAdded)[1] == 8
            @test Array(csr_device._childs)[1:3] == [0,4,4]
            @test Array(csr_device._addElementOffsets)[1:3] == [0,0,0]

            remap!(csr_device)

            kernel_csrtuple_execute_addElement_i(csr_device, 4)
            @test Array(csr_device._NAdded)[1] == 8
            @test Array(csr_device._childs)[1:3] == [0,4,8]
            @test Array(csr_device._map)[7:9] == [3,3,3]
            @test Array(csr_device._map)[19:21] == [7,7,7]
            
            reset!(csr_device)

            @test Array(csr_device._NAdded)[1] == 0
            @test Array(csr_device._childs)[1:3] == [0,0,0]
            @test Array(csr_device._addElementOffsets)[1:3] == [0,0,0]

            # removeElement!
            csr = CSRTuple(4, 2, 10)
            csr._map .= 1:40
            csr_device = CellBasedModels.toDevice(csr, device)

            kernel_csrtuple_memclaim_removeElement(csr_device, 4)
            @test Array(csr_device._NAdded)[1] == 0
            @test Array(csr_device._addElementOffsets)[1:3] == [0,0,0] 

            preallocate!(csr_device)

            kernel_csrtuple_allocate_removeElement(csr_device, 4)
            @test Array(csr_device._NAdded)[1] == -1
            @test Array(csr_device._addElementOffsets)[1:3] == [0,-1,0] 

            remap!(csr_device)

            kernel_csrtuple_execute_removeElement(csr_device, 4)
            @test Array(csr_device._NAdded)[1] == -1
            @test Array(csr_device._map)[1:4] == [5,6,7,8]

        end

    end

    @testset "CSRCache" begin

        #Constructor
        csr = CSRCache(30, 3; dtype=Int)
        @test CellBasedModels.lengthElements(csr) == 0
        @test CellBasedModels.lengthElementsCache(csr) == 3
        @test CellBasedModels.fullLength(csr) == 30

        csr = CSRCache([1,4,3]; additionalNCache=2, additionalL=5, dtype=Int)
        @test CellBasedModels.lengthElements(csr) == 3
        @test CellBasedModels.lengthElementsCache(csr) == 5
        @test CellBasedModels.fullLength(csr) == 13
        @test csr._elementOffsets == [1,2,6,9,0,0]

        csr = CSRCache([[1,2,3], [4,5], [6]]; additionalNCache=2, additionalL=3)
        @test CellBasedModels.lengthElements(csr) == 3
        @test CellBasedModels.lengthElementsCache(csr) == 5
        @test CellBasedModels.fullLength(csr) == 9
        @test csr._elementOffsets == [1,4,6,7,0,0]

        #Iterators
        csr = CSRCache([[1,2,3], [4,5], [6]]; additionalNCache=2, additionalL=3)
        csr._map[1:6] .= 1:6

        results = [i for i in csr]
        @test length(results) == 6
        @test results == [(1, 1), (1, 2), (1, 3), (2, 4), (2, 5), (3, 6)]

        # Test operators
        for device in devices

            # addElement!
            csr = CSRCache([2, 3]; additionalNCache=5, additionalL=10, dtype=Int)
            csr_device = CellBasedModels.toDevice(csr, device)

            kernel_csrtuple_memclaim_addElement(csr_device, 4)
            @test Array(csr_device._NAdded)[1] == 1
            @test Array(csr_device._lAdded)[1] == 4
            @test Array(csr_device._addElementOffsets)[1] == 0
            @test Array(csr_device._childs)[1] == 0

            # preallocate!(csr_device)

            # kernel_csrtuple_allocate_addElement(csr_device, 4)
            # @test Array(csr_device._NCache)[1] == 8
            # @test Array(csr_device._NAdded)[1] == 4
            # @test Array(csr_device._childs)[1] == 4
            # @test Array(csr_device._addElementOffsets)[1] == 0

            # remap!(csr_device)

            # kernel_csrtuple_execute_addElement(csr_device, 4)
            # @test Array(csr_device._NAdded)[1] == 4
            # @test Array(csr_device._map)[7:10] == [0,0,0,0]

            # reset!(csr_device)

            # @test Array(csr_device._NAdded)[1] == 0
            # @test Array(csr_device._childs)[1] == 0
            # @test Array(csr_device._addElementOffsets)[1] == 0

        end
    end

end