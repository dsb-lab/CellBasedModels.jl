function f(csr)
    for i in csr
        i
    end
end

function kernel_checkBounds(csr, pos, nPos, nActive, nBlock)
    KernelAbstractions.@kernel function check_kernel(csr, pos, nPos, nActive, nBlock)
        CellBasedModels.checkBounds(csr, pos, nPos, nActive, nBlock)
    end

    backend = KernelAbstractions.get_backend(csr)
    threads = 1

    check_kernel(backend, threads)(csr, pos, nPos, nActive, nBlock, ndrange=1)
    KernelAbstractions.synchronize(backend)
end

function kernel_addElement1!(csr)
    KernelAbstractions.@kernel function add_kernel(csr)
        pos = CellBasedModels.addElement!(csr)
    end

    backend = KernelAbstractions.get_backend(csr)
    threads = 1

    add_kernel(backend, threads)(csr, ndrange=1)
    KernelAbstractions.synchronize(backend)
end

function kernel_addElementN!(csr, n)
    KernelAbstractions.@kernel function add_kernel(csr, n)
        pos = CellBasedModels.addElement!(csr, n)
    end

    backend = KernelAbstractions.get_backend(csr)
    threads = 1

    add_kernel(backend, threads)(csr, n, ndrange=1)
    KernelAbstractions.synchronize(backend)
end

function kernel_addElementTuple!(csr, tuple)
    KernelAbstractions.@kernel function add_kernel(csr, tuple)
        pos = CellBasedModels.addElement!(csr, tuple)
    end

    backend = KernelAbstractions.get_backend(csr)
    threads = 1

    add_kernel(backend, threads)(csr, tuple, ndrange=1)
    KernelAbstractions.synchronize(backend)
end

function kernel_pushToElement!(csr, ePos, value)
    KernelAbstractions.@kernel function push_kernel(csr, ePos, value)
        pos = CellBasedModels.pushToElement!(csr, ePos, value)
    end

    backend = KernelAbstractions.get_backend(csr)
    threads = 1

    push_kernel(backend, threads)(csr, ePos, value, ndrange=1)
    KernelAbstractions.synchronize(backend)
end

function kernel_replaceIndexFromElement!(csr, ePos, bPos, value)
    KernelAbstractions.@kernel function replace_kernel(csr, ePos, bPos, value)
        pos = CellBasedModels.replaceIndexFromElement!(csr, ePos, bPos, value)
    end

    backend = KernelAbstractions.get_backend(csr)
    threads = 1

    replace_kernel(backend, threads)(csr, ePos, bPos, value, ndrange=1)
    KernelAbstractions.synchronize(backend)
end

function kernel_insertIndexAtElement!(csr, ePos, bPos, value)
    KernelAbstractions.@kernel function insert_kernel(csr, ePos, bPos, value)
        pos = CellBasedModels.insertIndexAtElement!(csr, ePos, bPos, value)
    end

    backend = KernelAbstractions.get_backend(csr)
    threads = 1

    insert_kernel(backend, threads)(csr, ePos, bPos, value, ndrange=1)
    KernelAbstractions.synchronize(backend)
end

function kernel_removeIndexFromElement!(csr, ePos, bPos)
    KernelAbstractions.@kernel function remove_kernel(csr, ePos, bPos)
        CellBasedModels.removeIndexFromElement!(csr, ePos, bPos)
    end

    backend = KernelAbstractions.get_backend(csr)
    threads = 1

    remove_kernel(backend, threads)(csr, ePos, bPos, ndrange=1)
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

    @testset "CSRBlock" begin
        csr = CSRBlock(N=3,NBlock=2,NCache=10)
        csr._ActiveSection .= 2
        csr._map .= 1:20
        @test csr._N[] == 3
        @test csr._NBlock[] == 2
        @test csr._NCache[] == 10
        @test length(csr._map) == 20
        @test length(csr._ActiveSection) == 10
        @test all(csr._FlagsSurvived .== false)
        
        # Test iterator returns (blockId, map_value)
        results = [i for i in csr]
        @test length(results) == 20  # 3 blocks * 2 active elements each
        
        # Check first block
        @test results[1] == (1, 1)  # block 1, position 1
        @test results[2] == (1, 2)  # block 1, position 2
        
        # Check second block
        @test results[3] == (2, 3)  # block 2, position 1
        @test results[4] == (2, 4)  # block 2, position 2
        
        # Check third block
        @test results[5] == (3, 5)  # block 3, position 1
        @test results[6] == (3, 6)  # block 3, position 2
        
        # Test with different active sections
        csr2 = CSRBlock(N=3,NBlock=4,NCache=10)
        csr2._ActiveSection[1] = 2
        csr2._ActiveSection[2] = 1
        csr2._ActiveSection[3] = 3
        csr2._map[1:12] .= 1:12
        
        results2 = [i for i in csr2]
        @test length(results2) == 40  # 2 + 1 + 3
        @test results2[1] == (1, 1)
        @test results2[2] == (1, 2)
        @test results2[3] == (2, 5)  # block 2, position 1: (2-1)*4 + 1 = 5
        @test results2[4] == (3, 9)  # block 3, position 1: (3-1)*4 + 1 = 9
        @test results2[5] == (3, 10)
        @test results2[6] == (3, 11)

        # Test operators
        for device in devices
            # Check checkBounds
            csr = CSRBlock(N=2, NBlock=3, NCache=4)
            csr_device = CellBasedModels.toDevice(csr, device)      
            kernel_checkBounds(csr_device, 5, 2, 2, 4)
            @test Array(csr_device._NOverflow)[1] == 2
            @test Array(csr_device._NOverflowBlock)[1] == 1

            # addElement! 1
            csr = CSRBlock(N=2, NBlock=3, NCache=3)
            csr_device = CellBasedModels.toDevice(csr, device)
            kernel_addElement1!(csr_device)
            @test Array(csr_device._NAdded)[1] == 1
            kernel_addElement1!(csr_device)
            @test Array(csr_device._NAdded)[1] == 2
            @test Array(csr_device._NOverflow)[1] == 1

            # addElement! N
            csr = CSRBlock(N=2, NBlock=3, NCache=5)
            csr_device = CellBasedModels.toDevice(csr, device)
            kernel_addElementN!(csr_device, 2)
            @test Array(csr_device._NAdded)[1] == 2
            kernel_addElementN!(csr_device, 5)
            @test Array(csr_device._NAdded)[1] == 7
            @test Array(csr_device._NOverflow)[1] == 4

            # addElement! tuple
            csr = CSRBlock(N=2, NBlock=3, NCache=5)
            csr_device = CellBasedModels.toDevice(csr, device)
            kernel_addElementTuple!(csr_device, (1,2))
            @test Array(csr_device._NAdded)[1] == 1
            @test Array(csr_device._map)[7] == 1
            @test Array(csr_device._map)[8] == 2
            @test Array(csr_device._ActiveSection)[3] == 2

            # pushToElement!
            csr = CSRBlock(N=2, NBlock=3, NCache=5)
            csr_device = CellBasedModels.toDevice(csr, device)
            kernel_pushToElement!(csr_device, 1, 10)
            @test Array(csr_device._map)[1] == 10
            @test Array(csr_device._ActiveSection)[1] == 1

            # replaceIndexFromElement!
            csr = CSRBlock(N=2, NBlock=3, NCache=5)
            csr._ActiveSection[1] = 2
            csr._map[1] = 5
            csr._map[2] = 10
            csr_device = CellBasedModels.toDevice(csr, device)
            kernel_replaceIndexFromElement!(csr_device, 1, 2, 20)
            @test Array(csr_device._map)[2] == 20

            # insertIndexAtElement!
            csr = CSRBlock(N=2, NBlock=3, NCache=5)
            csr._ActiveSection[1] = 2
            csr._map[1] = 5
            csr._map[2] = 10
            csr_device = CellBasedModels.toDevice(csr, device)
            kernel_insertIndexAtElement!(csr_device, 1, 2, 15)
            @test Array(csr_device._map)[1] == 5
            @test Array(csr_device._map)[2] == 15
            @test Array(csr_device._map)[3] == 10
            @test Array(csr_device._ActiveSection)[1] == 3

            # removeIndexFromElement!
            csr = CSRBlock(N=2, NBlock=3, NCache=5)
            csr._ActiveSection[1] = 3
            csr._map[1] = 5
            csr._map[2] = 10
            csr._map[3] = 15
            csr_device = CellBasedModels.toDevice(csr, device)
            kernel_removeIndexFromElement!(csr_device, 1, 2)
            @test Array(csr_device._map)[1] == 5
            @test Array(csr_device._map)[2] == 15
            @test Array(csr_device._ActiveSection)[1] == 2

        end

    end
    
    # @testset "CSRTuple" begin
    #     csr = CSRTuple(N=3,NBlock=2,NCache=10)
    #     csr._map .= 1:20
    #     @test csr._N[] == 3
    #     @test csr._NBlock[] == 2
    #     @test csr._NCache[] == 10
    #     @test length(csr._map) == 20
    #     @test csr._ActiveSection === nothing
    #     @test all(csr._FlagsSurvived .== false)
        
    #     # Test iterator returns all elements (no active section filtering)
    #     results = [i for i in csr]
    #     @test length(results) == 20  # 3 blocks * 2 elements each
        
    #     # Check all blocks iterate through all elements
    #     @test results[1] == (1, 1)
    #     @test results[2] == (1, 2)
    #     @test results[3] == (2, 3)
    #     @test results[4] == (2, 4)
    #     @test results[5] == (3, 5)
    #     @test results[6] == (3, 6)
        
    #     # Test with larger block size
    #     csr2 = CSRTuple(N=2,NBlock=5,NCache=10)
    #     csr2._map[1:10] .= 1:10
        
    #     results2 = [f for f in csr2]
    #     @test length(results2) == 50  # 2 blocks * 5 elements each
    #     @test results2[1] == (1, 1)
    #     @test results2[5] == (1, 5)
    #     @test results2[6] == (2, 6)
    #     @test results2[10] == (2, 10)
    # end
    
    # @testset "CSRSlack" begin
    #     # Test with variable-sized blocks
    #     csr = CSRSlack(dtype=Int, N=3, sizes=[5, 10, 7])
    #     csr._map .= 1:22
    #     csr._ActiveSection[1] = 3
    #     csr._ActiveSection[2] = 8
    #     csr._ActiveSection[3] = 5
        
    #     @test csr._N[] == 3
    #     @test length(csr._map) == 22
        
    #     # Test iterator returns (blockId, map_value) for active elements
    #     results = [i for i in csr]
    #     @test length(results) == 22
        
    #     # Check first block (starts at position 1, has 3 active)
    #     @test results[1] == (1, 1)
    #     @test results[2] == (1, 2)
    #     @test results[3] == (1, 3)
        
    #     # Check second block (starts at position 6, has 8 active)
    #     @test results[4] == (2, 6)
    #     @test results[5] == (2, 7)
    #     @test results[11] == (2, 13)
        
    #     # Check third block (starts at position 16, has 5 active)
    #     @test results[12] == (3, 16)
    #     @test results[13] == (3, 17)
    #     @test results[16] == (3, 20)
        
    #     # Test with different active sections
    #     csr2 = CSRSlack(dtype=Int, N=4, sizes=[3, 2, 6, 4])
    #     csr2._map .= 1:15
    #     csr2._ActiveSection[1] = 2
    #     csr2._ActiveSection[2] = 2
    #     csr2._ActiveSection[3] = 4
    #     csr2._ActiveSection[4] = 3
        
    #     results2 = [i for i in csr2]
    #     @test length(results2) == 15
    #     @test results2[1] == (1, 1)   # block 1, position 1
    #     @test results2[2] == (1, 2)   # block 1, position 2
    #     @test results2[3] == (2, 4)   # block 2, position 1 (starts at 4)
    #     @test results2[4] == (2, 5)   # block 2, position 2
    #     @test results2[5] == (3, 6)   # block 3, position 1 (starts at 6)
    #     @test results2[8] == (3, 9)   # block 3, position 4
    #     @test results2[9] == (4, 12)  # block 4, position 1 (starts at 12)
    #     @test results2[11] == (4, 14) # block 4, position 3
                
    #     # Test with empty blocks (0 active)
    #     csr3 = CSRSlack(dtype=Int, N=3, sizes=[4, 4, 4])
    #     csr3._map .= 1:12
    #     csr3._ActiveSection[1] = 2
    #     csr3._ActiveSection[2] = 0  # Empty block
    #     csr3._ActiveSection[3] = 3
        
    #     results3 = [i for i in csr3]
    #     @test length(results3) == 12
    #     @test results3[1] == (1, 1)
    #     @test results3[2] == (1, 2)
    #     @test results3[3] == (3, 9)   # skips block 2, starts at block 3 position 9
    #     @test results3[4] == (3, 10)
    #     @test results3[5] == (3, 11)
        
    #     # Test with NCache at the end
    #     csr4 = CSRSlack(dtype=Int, N=3, sizes=[5, 10, 7], NCache=3)
    #     @test length(csr4._map) == 25  # 5 + 10 + 7 + 3
        
    #     csr4._map .= 1:25
    #     csr4._ActiveSection[1] = 5
    #     csr4._ActiveSection[2] = 10
    #     csr4._ActiveSection[3] = 7
        
    #     results4 = [i for i in csr4]
    #     @test length(results4) == 25  # Only active elements, not the cache
    #     @test results4[1] == (1, 1)
    #     @test results4[5] == (1, 5)
    #     @test results4[6] == (2, 6)
    #     @test results4[15] == (2, 15)
    #     @test results4[16] == (3, 16)
    #     @test results4[22] == (3, 22)
    #     # Elements 23-25 are cache and not iterated over
    # end
    
    # @testset "CSRCache" begin
    #     # Test with variable-sized blocks, no active section tracking
    #     csr = CSRCache(dtype=Int, N=3, sizes=[5, 10, 7])
    #     csr._map .= 1:22
        
    #     @test csr._N[] == 3
    #     @test length(csr._map) == 22
    #     @test csr._ActiveSection === nothing
        
    #     # Test iterator returns all elements (no active section filtering)
    #     results = [i for i in csr]
    #     @test length(results) == 22  # All elements
        
    #     # Check first block (all 5 elements)
    #     @test results[1] == (1, 1)
    #     @test results[2] == (1, 2)
    #     @test results[5] == (1, 5)
        
    #     # Check second block (all 10 elements)
    #     @test results[6] == (2, 6)
    #     @test results[7] == (2, 7)
    #     @test results[15] == (2, 15)
        
    #     # Check third block (all 7 elements)
    #     @test results[16] == (3, 16)
    #     @test results[17] == (3, 17)
    #     @test results[22] == (3, 22)
        
    #     # Test with different sizes
    #     csr2 = CSRCache(dtype=Int, N=4, sizes=[3, 2, 6, 4])
    #     csr2._map .= 1:15
        
    #     results2 = [i for i in csr2]
    #     @test length(results2) == 15  # All elements
    #     @test results2[1] == (1, 1)
    #     @test results2[3] == (1, 3)
    #     @test results2[4] == (2, 4)   # block 2, position 1 (starts at 4)
    #     @test results2[5] == (2, 5)   # block 2, position 2
    #     @test results2[6] == (3, 6)   # block 3, position 1 (starts at 6)
    #     @test results2[11] == (3, 11) # block 3, position 6
    #     @test results2[12] == (4, 12) # block 4, position 1 (starts at 12)
    #     @test results2[15] == (4, 15) # block 4, position 4
                        
    #     # Test with uniform sizes
    #     csr3 = CSRCache(dtype=Int, N=3, sizes=[4, 4, 4])
    #     csr3._map .= 1:12
        
    #     results3 = [i for i in csr3]
    #     @test length(results3) == 12
    #     @test results3[1] == (1, 1)
    #     @test results3[4] == (1, 4)
    #     @test results3[5] == (2, 5)
    #     @test results3[8] == (2, 8)
    #     @test results3[9] == (3, 9)
    #     @test results3[12] == (3, 12)
    # end

    # @testset "Topology Creation" begin
        
    #     mesh = UnstructuredMesh(
    #             3,
    #             n = Node(),
    #             e = Edge(:n),
    #             a = Agent(:e),
    #         )

    #     @addODE model = mesh function f(du, u, p, t)
    #         @kernel_launch ndrange=u.n function step(du, u, p, t)
    #             n = CellBasedModels.@index(Global)
    #             for ns in loopOverTopology(model, :n, :e, n)
    #                 # n1, n2 = ns
    #                 # if u.e.length[e] > 1.0 # Edge division
    #                 #     #Explicit relations divideEdge!(model, e)
    #                 #     a = model.topology.e.a[1]
    #                 #     remove!(model.topology.e, e)

    #                 #     #Add elements
    #                 #     n = addElement!(model.n)
    #                 #     e1 = addElement!(model.e)
    #                 #     e2 = addElement!(model.e)

    #                 #     #Add topological relations
    #                 #     n = addElement!(model.topology.n)
    #                 #     e1 = addElement!(model.topology.e.n, (n1, n))
    #                 #     e2 = addElement!(model.topology.e.n, (n, n2))
    #                 #     replace!(model.topology.a.e, e, (e1, e2))

    #                 #     n, e1, e2

    #                 #     #if e->a exists 
    #                 #     replace!(model.topology.e.a, e1, a)
    #                 #     replace!(model.topology.e.a, e2, a)
    #                 #     replace!(model.topology.n.a, a, e)

    #                 #     #if n->a exists
    #                 #     replace!(model.topology.n.a, n, a)

    #                 #     #if a->n exists
    #                 #     push!(model.topology.a.n, a, n)
    #                 # end
    #             end

    #             for (n, a) in loopOverTopology(model, :a, :n, n)
    #                 # du.n.value[n] = length(du.a.e[a])
    #             end

    #         end
    #     end

    #     e_n = CSRTuple([
    #             [1,2],
    #             [2,3],
    #             [3,4],
    #             [4,5]
    #         ])
    #     a_e = CSRSlack([
    #             [1,2,3,4]
    #         ])

    #     obj = UnstructuredMeshObject(
    #         mesh;
    #         n = 5,
    #         e = e_n,
    #         a = a_e,
    #     )        

    #     println(obj._topology)
    #     println(CellBasedModels.checkTopologyConsistency(obj._topology))
    #     println("a.e\n", [i for i in obj._topology._relations.a.e])
    #     println("e.n\n", [i for i in obj._topology._relations.e.n])
    #     println("n.e\n", [i for i in obj._topology._relations.n.e])
    #     println("a.n\n", [i for i in obj._topology._relations.a.n])


    # end

end