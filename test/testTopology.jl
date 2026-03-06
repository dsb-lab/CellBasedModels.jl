@testset "Topology" begin
    
    @testset "Basic topology construction" begin
        # Define mesh schema
        model = UnstructuredMesh(
            3,
            n=Node(
                (
                    a = AbstractFloat,
                    b = Integer,
                )
            ),
            e=Edge(
                :n,
                (
                    w = AbstractFloat,
                )
            ),
            c=Agent(
                (:n, :e),
                (
                    cc = AbstractFloat,
                )
            )
        )

        # Create sparse matrices for topology relations
        # Edge -> Node: each edge connects to 2 nodes
        # Using DynamicalCSR: 20 edges, 2 nodes per edge
        e_to_n = dcsr_zeros(Int, 20, 2, 10)
        
        # Agent -> Node: each agent connects to some nodes
        c_to_n = dcsr_zeros(Int, 30, 3, 10)
        
        # Agent -> Edge: each agent connects to some edges  
        c_to_e = dcsr_zeros(Int, 30, 2, 10)

        # Create the object
        object = UnstructuredMeshObject(
            model, 
            n=10, 
            e=e_to_n, 
            c=(n=c_to_n, e=c_to_e)
        )

        # Check topology was created
        @test object._topology !== nothing
        @test !isa(object._topology, CellBasedModels.TopologyEmpty)
        
        # Check entities
        @test :n in CellBasedModels.entities(object._topology)
        @test :e in CellBasedModels.entities(object._topology)
        @test :c in CellBasedModels.entities(object._topology)
        
        # Check basic relations
        br = CellBasedModels.basicRelations(object._topology)
        @test (:e, :n) in br
        @test (:c, :n) in br
        @test (:c, :e) in br
        
        # Check relations exist
        @test CellBasedModels.hasrelation(object._topology, :e, :n)
        @test CellBasedModels.hasrelation(object._topology, :c, :n)
        @test CellBasedModels.hasrelation(object._topology, :c, :e)
        
        # Check we can get relations
        rel_e_n = CellBasedModels.getrelation(object._topology, :e, :n)
        @test rel_e_n isa CellBasedModels.AbstractSparseMatrix
        @test CellBasedModels.numberOfRows(rel_e_n) == 20
    end

    @testset "Topology with populated relations" begin
        # Define a simpler mesh (use property names that don't conflict with position params x,y,z)
        model = UnstructuredMesh(
            2,
            n=Node((nodeVal = AbstractFloat,)),
            e=Edge(:n, (edgeW = AbstractFloat,))
        )

        # Create edge->node relation: 3 edges
        # Edge 1: connects to nodes 1, 2
        # Edge 2: connects to nodes 2, 3
        # Edge 3: connects to nodes 1, 3
        e_to_n = dcsr_zeros(Int, 3, 2, 5)
        
        # Populate the sparse matrix
        e_to_n[1, 1] = 1  # Edge 1 -> Node 1
        e_to_n[1, 2] = 2  # Edge 1 -> Node 2
        CellBasedModels.synchronize(e_to_n)
        
        e_to_n[2, 1] = 2  # Edge 2 -> Node 2
        e_to_n[2, 2] = 3  # Edge 2 -> Node 3
        CellBasedModels.synchronize(e_to_n)
        
        e_to_n[3, 1] = 1  # Edge 3 -> Node 1
        e_to_n[3, 2] = 3  # Edge 3 -> Node 3
        CellBasedModels.synchronize(e_to_n)

        # Create mesh object
        object = UnstructuredMeshObject(
            model, 
            n=3, 
            e=e_to_n
        )

        # Check topology
        @test object._topology !== nothing
        
        # Verify the relation data
        rel = CellBasedModels.getrelation(object._topology, :e, :n)
        
        # Check dense representation
        dense = todense(rel)
        @test dense[1, 1] == 1
        @test dense[1, 2] == 2
        @test dense[2, 1] == 2
        @test dense[2, 2] == 3
        @test dense[3, 1] == 1
        @test dense[3, 2] == 3
    end

    @testset "Topology iteration" begin
        model = UnstructuredMesh(
            2,
            n=Node((nodeVal = AbstractFloat,)),
            e=Edge(:n, (edgeW = AbstractFloat,))
        )

        # Edge 1 connects nodes 1, 2
        # Edge 2 connects nodes 2, 3
        e_to_n = dcsr_zeros(Int, 2, 2, 5)
        e_to_n[1, 1] = 1
        e_to_n[1, 2] = 2  
        CellBasedModels.synchronize(e_to_n)
        
        e_to_n[2, 1] = 2
        e_to_n[2, 2] = 3
        CellBasedModels.synchronize(e_to_n)

        object = UnstructuredMeshObject(model, n=3, e=e_to_n)
        
        # Test iterating over neighbors
        rel = CellBasedModels.getrelation(object._topology, :e, :n)
        
        # Iterate over edge 1's neighbors using iterateRow
        iter1 = iterateRow(rel, 1)
        neighbors1 = Tuple{Int,Int}[]
        for k in iter1._startIdx:iter1._endIdx
            col, val = CellBasedModels.getentry(iter1, k)
            if col > 0
                push!(neighbors1, (col, val))
            end
        end
        @test length(neighbors1) == 2
        # Check nodes 1 and 2 are neighbors (values in the sparse matrix)
        vals = [n[2] for n in neighbors1]
        @test 1 in vals
        @test 2 in vals
        
        # Iterate over edge 2's neighbors
        iter2 = iterateRow(rel, 2)
        neighbors2 = Tuple{Int,Int}[]
        for k in iter2._startIdx:iter2._endIdx
            col, val = CellBasedModels.getentry(iter2, k)
            if col > 0
                push!(neighbors2, (col, val))
            end
        end
        @test length(neighbors2) == 2
        vals2 = [n[2] for n in neighbors2]
        @test 2 in vals2
        @test 3 in vals2
    end

    @testset "Empty topology (no relations)" begin
        # Mesh with only nodes has no topology relations
        model = UnstructuredMesh(
            3,
            n=Node((nodeVal = AbstractFloat,))
        )
        
        object = UnstructuredMeshObject(model, n=10)
        
        # Topology should be empty
        @test isa(object._topology, CellBasedModels.TopologyEmpty)
    end

    @testset "Inference table" begin
        # Test that inference paths are correctly computed
        model = UnstructuredMesh(
            3,
            n=Node((nodeVal = AbstractFloat,)),
            e=Edge(:n, (edgeW = AbstractFloat,)),
            c=Agent((:e,), (cc = AbstractFloat,))  # Agent connects to edges only
        )

        e_to_n = dcsr_zeros(Int, 5, 2, 5)
        c_to_e = dcsr_zeros(Int, 3, 2, 5)

        object = UnstructuredMeshObject(
            model, 
            n=4, 
            e=e_to_n,
            c=c_to_e
        )

        topology = object._topology
        
        # Direct relations should exist
        @test CellBasedModels.hasrelation(topology, :e, :n)
        @test CellBasedModels.hasrelation(topology, :c, :e)
        
        # Check inference path from c to n (through e)
        path = CellBasedModels.getpath(topology, :c, :n)
        @test length(path) == 2
        @test path[1] == (:c, :e, :d)  # c -> e direct
        @test path[2] == (:e, :n, :d)  # e -> n direct
    end
end
