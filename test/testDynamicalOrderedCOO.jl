@testset "DynamicalOrderedCOO" begin

    # Kernel wrapper functions for GPU compatibility

    function _docoo_pushfirst(coo, i, j, value)
        @kernel function pushfirst_kernel!(coo, i, j, value)
            Base.pushfirst!(coo, i, j, value)
        end
        backend = KernelAbstractions.get_backend(coo._values)
        threads = backend === CPU() ? 1 : 256
        pushfirst_kernel!(backend, threads)(coo, i, j, value, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _docoo_append(coo, i, j, value)
        @kernel function append_kernel!(coo, i, j, value)
            Base.append!(coo, i, j, value)
        end
        backend = KernelAbstractions.get_backend(coo._values)
        threads = backend === CPU() ? 1 : 256
        append_kernel!(backend, threads)(coo, i, j, value, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _docoo_insertafter_k(coo, k_ref, i, j, value)
        @kernel function insertafter_kernel!(coo, k_ref, i, j, value)
            CellBasedModels.insertafter_k!(coo, k_ref, i, j, value)
        end
        backend = KernelAbstractions.get_backend(coo._values)
        threads = backend === CPU() ? 1 : 256
        insertafter_kernel!(backend, threads)(coo, k_ref, i, j, value, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _docoo_insertbefore_k(coo, k_ref, i, j, value)
        @kernel function insertbefore_kernel!(coo, k_ref, i, j, value)
            CellBasedModels.insertbefore_k!(coo, k_ref, i, j, value)
        end
        backend = KernelAbstractions.get_backend(coo._values)
        threads = backend === CPU() ? 1 : 256
        insertbefore_kernel!(backend, threads)(coo, k_ref, i, j, value, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _docoo_delete_k(coo, k)
        @kernel function delete_kernel!(coo, k)
            CellBasedModels.delete_k!(coo, k)
        end
        backend = KernelAbstractions.get_backend(coo._values)
        threads = backend === CPU() ? 1 : 256
        delete_kernel!(backend, threads)(coo, k, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _docoo_setvalue_k(coo, k, value)
        @kernel function setvalue_kernel!(coo, k, value)
            CellBasedModels.setvalue_k!(coo, k, value)
        end
        backend = KernelAbstractions.get_backend(coo._values)
        threads = backend === CPU() ? 1 : 256
        setvalue_kernel!(backend, threads)(coo, k, value, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    # Helper function to collect ordered entries
    function collect_ordered_entries(coo)
        entries = Tuple{Int, Int, Float64}[]
        coo_cpu = CellBasedModels.toBackend(CPU(), coo)
        k = CellBasedModels.gethead(coo_cpu)
        while k != 0
            push!(entries, CellBasedModels.getentry(coo_cpu, k))
            k = CellBasedModels.getnext(coo_cpu, k)
        end
        return entries
    end

    for backend in backends
        @testset "Backend: $(backend)" begin
            
            @testset "Construction" begin
                coo = CellBasedModels.docoo_zeros(Float64, 10)
                @test Array(coo._head) == [0]
                @test Array(coo._tail) == [0]
                @test Array(coo._prev) == zeros(Int, 10)
                @test Array(coo._next) == zeros(Int, 10)
                @test Array(coo._NEntries) == [0]
                @test Array(coo._NEntriesCache) == [10]
                
                coo = CellBasedModels.toBackend(backend, coo)
                @test KernelAbstractions.get_backend(coo._values) === backend
            end

            @testset "pushfirst!" begin
                coo = CellBasedModels.docoo_zeros(Float64, 5)
                coo = CellBasedModels.toBackend(backend, coo)
                
                # Insert first element
                _docoo_pushfirst(coo, 1, 1, 10.0)
                entries = collect_ordered_entries(coo)
                @test length(entries) == 1
                @test entries[1] == (1, 1, 10.0)
                
                # Insert at front - should become first
                _docoo_pushfirst(coo, 2, 2, 20.0)
                entries = collect_ordered_entries(coo)
                @test length(entries) == 2
                @test entries[1] == (2, 2, 20.0)
                @test entries[2] == (1, 1, 10.0)
                
                # Insert another at front
                _docoo_pushfirst(coo, 3, 3, 30.0)
                entries = collect_ordered_entries(coo)
                @test length(entries) == 3
                @test entries[1] == (3, 3, 30.0)
                @test entries[2] == (2, 2, 20.0)
                @test entries[3] == (1, 1, 10.0)
            end

            @testset "append!" begin
                coo = CellBasedModels.docoo_zeros(Float64, 5)
                coo = CellBasedModels.toBackend(backend, coo)
                
                # Insert first element
                _docoo_append(coo, 1, 1, 10.0)
                entries = collect_ordered_entries(coo)
                @test length(entries) == 1
                @test entries[1] == (1, 1, 10.0)
                
                # Append at end
                _docoo_append(coo, 2, 2, 20.0)
                entries = collect_ordered_entries(coo)
                @test length(entries) == 2
                @test entries[1] == (1, 1, 10.0)
                @test entries[2] == (2, 2, 20.0)
                
                # Append another at end
                _docoo_append(coo, 3, 3, 30.0)
                entries = collect_ordered_entries(coo)
                @test length(entries) == 3
                @test entries[1] == (1, 1, 10.0)
                @test entries[2] == (2, 2, 20.0)
                @test entries[3] == (3, 3, 30.0)
            end

            @testset "insertafter_k!" begin
                coo = CellBasedModels.docoo_zeros(Float64, 5)
                coo = CellBasedModels.toBackend(backend, coo)
                
                # Build list: A -> B -> C
                _docoo_append(coo, 1, 1, 10.0)  # A
                _docoo_append(coo, 3, 3, 30.0)  # C
                
                # Get head slot
                coo_cpu = CellBasedModels.toBackend(CPU(), coo)
                head = CellBasedModels.gethead(coo_cpu)
                
                # Insert B after A (after head)
                _docoo_insertafter_k(coo, head, 2, 2, 20.0)
                
                entries = collect_ordered_entries(coo)
                @test length(entries) == 3
                @test entries[1] == (1, 1, 10.0)  # A
                @test entries[2] == (2, 2, 20.0)  # B (inserted)
                @test entries[3] == (3, 3, 30.0)  # C
            end

            @testset "insertbefore_k!" begin
                coo = CellBasedModels.docoo_zeros(Float64, 5)
                coo = CellBasedModels.toBackend(backend, coo)
                
                # Build list: A -> C
                _docoo_append(coo, 1, 1, 10.0)  # A
                _docoo_append(coo, 3, 3, 30.0)  # C
                
                # Get tail slot
                coo_cpu = CellBasedModels.toBackend(CPU(), coo)
                tail = CellBasedModels.gettail(coo_cpu)
                
                # Insert B before C (before tail)
                _docoo_insertbefore_k(coo, tail, 2, 2, 20.0)
                
                entries = collect_ordered_entries(coo)
                @test length(entries) == 3
                @test entries[1] == (1, 1, 10.0)  # A
                @test entries[2] == (2, 2, 20.0)  # B (inserted)
                @test entries[3] == (3, 3, 30.0)  # C
            end

            @testset "delete_k!" begin
                coo = CellBasedModels.docoo_zeros(Float64, 5)
                coo = CellBasedModels.toBackend(backend, coo)
                
                # Build list: A -> B -> C
                _docoo_append(coo, 1, 1, 10.0)  # A
                _docoo_append(coo, 2, 2, 20.0)  # B
                _docoo_append(coo, 3, 3, 30.0)  # C
                
                # Get head and find B (second element)
                coo_cpu = CellBasedModels.toBackend(CPU(), coo)
                head = CellBasedModels.gethead(coo_cpu)
                k_b = CellBasedModels.getnext(coo_cpu, head)  # B is after head
                
                # Delete B (middle element)
                _docoo_delete_k(coo, k_b)
                
                entries = collect_ordered_entries(coo)
                @test length(entries) == 2
                @test entries[1] == (1, 1, 10.0)  # A
                @test entries[2] == (3, 3, 30.0)  # C
            end

            @testset "delete head" begin
                coo = CellBasedModels.docoo_zeros(Float64, 5)
                coo = CellBasedModels.toBackend(backend, coo)
                
                # Build list: A -> B -> C
                _docoo_append(coo, 1, 1, 10.0)  # A
                _docoo_append(coo, 2, 2, 20.0)  # B
                _docoo_append(coo, 3, 3, 30.0)  # C
                
                # Delete head (A)
                coo_cpu = CellBasedModels.toBackend(CPU(), coo)
                head = CellBasedModels.gethead(coo_cpu)
                _docoo_delete_k(coo, head)
                
                entries = collect_ordered_entries(coo)
                @test length(entries) == 2
                @test entries[1] == (2, 2, 20.0)  # B is now head
                @test entries[2] == (3, 3, 30.0)  # C
            end

            @testset "delete tail" begin
                coo = CellBasedModels.docoo_zeros(Float64, 5)
                coo = CellBasedModels.toBackend(backend, coo)
                
                # Build list: A -> B -> C
                _docoo_append(coo, 1, 1, 10.0)  # A
                _docoo_append(coo, 2, 2, 20.0)  # B
                _docoo_append(coo, 3, 3, 30.0)  # C
                
                # Delete tail (C)
                coo_cpu = CellBasedModels.toBackend(CPU(), coo)
                tail = CellBasedModels.gettail(coo_cpu)
                _docoo_delete_k(coo, tail)
                
                entries = collect_ordered_entries(coo)
                @test length(entries) == 2
                @test entries[1] == (1, 1, 10.0)  # A
                @test entries[2] == (2, 2, 20.0)  # B is now tail
            end

            @testset "setvalue_k!" begin
                coo = CellBasedModels.docoo_zeros(Float64, 5)
                coo = CellBasedModels.toBackend(backend, coo)
                
                _docoo_append(coo, 1, 1, 10.0)
                _docoo_append(coo, 2, 2, 20.0)
                
                # Get head slot and modify value
                coo_cpu = CellBasedModels.toBackend(CPU(), coo)
                head = CellBasedModels.gethead(coo_cpu)
                
                _docoo_setvalue_k(coo, head, 100.0)
                
                entries = collect_ordered_entries(coo)
                @test entries[1] == (1, 1, 100.0)  # Value changed
                @test entries[2] == (2, 2, 20.0)   # Unchanged
            end

            @testset "getindex" begin
                coo = CellBasedModels.docoo_zeros(Float64, 5)
                coo = CellBasedModels.toBackend(backend, coo)
                
                _docoo_append(coo, 1, 2, 10.0)
                _docoo_append(coo, 3, 4, 30.0)
                
                # Copy to CPU for getindex
                coo_cpu = CellBasedModels.toBackend(CPU(), coo)
                @test coo_cpu[1, 2] == 10.0
                @test coo_cpu[3, 4] == 30.0
                @test coo_cpu[5, 5] == 0.0  # Non-existent entry
            end

            @testset "todense" begin
                coo = CellBasedModels.docoo_zeros(Float64, 5)
                coo = CellBasedModels.toBackend(backend, coo)
                
                _docoo_append(coo, 1, 1, 10.0)
                _docoo_append(coo, 1, 3, 15.0)
                _docoo_append(coo, 2, 2, 20.0)
                
                dense = CellBasedModels.todense(coo)
                @test dense[1, 1] == 10.0
                @test dense[1, 3] == 15.0
                @test dense[2, 2] == 20.0
                @test dense[1, 2] == 0.0
            end

            @testset "Ordered iteration" begin
                coo = CellBasedModels.docoo_zeros(Float64, 10)
                coo = CellBasedModels.toBackend(backend, coo)
                
                # Insert in a specific order
                _docoo_append(coo, 1, 1, 1.0)
                _docoo_append(coo, 2, 2, 2.0)
                _docoo_append(coo, 3, 3, 3.0)
                _docoo_append(coo, 4, 4, 4.0)
                _docoo_append(coo, 5, 5, 5.0)
                
                # Verify iteration order
                entries = collect_ordered_entries(coo)
                @test length(entries) == 5
                for i in 1:5
                    @test entries[i] == (i, i, Float64(i))
                end
            end

            @testset "Mixed operations" begin
                coo = CellBasedModels.docoo_zeros(Float64, 10)
                coo = CellBasedModels.toBackend(backend, coo)
                
                # Build: 1 -> 2 -> 3
                _docoo_append(coo, 1, 1, 1.0)
                _docoo_append(coo, 2, 2, 2.0)
                _docoo_append(coo, 3, 3, 3.0)
                
                # Delete middle (2)
                coo_cpu = CellBasedModels.toBackend(CPU(), coo)
                head = CellBasedModels.gethead(coo_cpu)
                k_middle = CellBasedModels.getnext(coo_cpu, head)
                _docoo_delete_k(coo, k_middle)
                
                # Now: 1 -> 3
                # Insert 4 at front, 5 at end
                _docoo_pushfirst(coo, 4, 4, 4.0)
                _docoo_append(coo, 5, 5, 5.0)
                
                # Expected: 4 -> 1 -> 3 -> 5
                entries = collect_ordered_entries(coo)
                @test length(entries) == 4
                @test entries[1] == (4, 4, 4.0)
                @test entries[2] == (1, 1, 1.0)
                @test entries[3] == (3, 3, 3.0)
                @test entries[4] == (5, 5, 5.0)
                
                # Insert between 1 and 3
                coo_cpu = CellBasedModels.toBackend(CPU(), coo)
                # Find the slot with (1,1)
                k = CellBasedModels.gethead(coo_cpu)
                k = CellBasedModels.getnext(coo_cpu, k)  # This is (1,1)
                
                _docoo_insertafter_k(coo, k, 6, 6, 6.0)
                
                # Expected: 4 -> 1 -> 6 -> 3 -> 5
                entries = collect_ordered_entries(coo)
                @test length(entries) == 5
                @test entries[1] == (4, 4, 4.0)
                @test entries[2] == (1, 1, 1.0)
                @test entries[3] == (6, 6, 6.0)
                @test entries[4] == (3, 3, 3.0)
                @test entries[5] == (5, 5, 5.0)
            end

            @testset "Slot reuse after deletion" begin
                coo = CellBasedModels.docoo_zeros(Float64, 3)
                coo = CellBasedModels.toBackend(backend, coo)
                
                # Fill all slots
                _docoo_append(coo, 1, 1, 1.0)
                _docoo_append(coo, 2, 2, 2.0)
                _docoo_append(coo, 3, 3, 3.0)
                
                @test CellBasedModels.numberOfEntries(coo) == 3
                
                # Synchronize to make slot available
                CellBasedModels.synchronize(coo)
                
                # Delete one
                coo_cpu = CellBasedModels.toBackend(CPU(), coo)
                head = CellBasedModels.gethead(coo_cpu)
                _docoo_delete_k(coo, head)
                
                @test CellBasedModels.numberOfEntries(coo) == 2
                
                # Synchronize to make slot available
                CellBasedModels.synchronize(coo)
                
                # Insert new one - should reuse freed slot
                _docoo_append(coo, 4, 4, 4.0)
                
                @test CellBasedModels.numberOfEntries(coo) == 3
                
                entries = collect_ordered_entries(coo)
                @test length(entries) == 3
            end

            @testset "Empty list operations" begin
                coo = CellBasedModels.docoo_zeros(Float64, 5)
                coo = CellBasedModels.toBackend(backend, coo)
                
                # Head and tail should be 0 for empty list
                coo_cpu = CellBasedModels.toBackend(CPU(), coo)
                @test CellBasedModels.gethead(coo_cpu) == 0
                @test CellBasedModels.gettail(coo_cpu) == 0
                
                # Add one element
                _docoo_append(coo, 1, 1, 10.0)
                
                coo_cpu = CellBasedModels.toBackend(CPU(), coo)
                head = CellBasedModels.gethead(coo_cpu)
                tail = CellBasedModels.gettail(coo_cpu)
                
                # Single element: head == tail
                @test head == tail
                @test head != 0
                
                # Delete it
                _docoo_delete_k(coo, head)
                
                # Back to empty
                coo_cpu = CellBasedModels.toBackend(CPU(), coo)
                @test CellBasedModels.gethead(coo_cpu) == 0
                @test CellBasedModels.gettail(coo_cpu) == 0
            end

            @testset "Backward traversal" begin
                coo = CellBasedModels.docoo_zeros(Float64, 5)
                coo = CellBasedModels.toBackend(backend, coo)
                
                _docoo_append(coo, 1, 1, 1.0)
                _docoo_append(coo, 2, 2, 2.0)
                _docoo_append(coo, 3, 3, 3.0)
                
                # Traverse backwards from tail
                coo_cpu = CellBasedModels.toBackend(CPU(), coo)
                entries = Tuple{Int, Int, Float64}[]
                k = CellBasedModels.gettail(coo_cpu)
                while k != 0
                    push!(entries, CellBasedModels.getentry(coo_cpu, k))
                    k = CellBasedModels.getprev(coo_cpu, k)
                end
                
                @test length(entries) == 3
                @test entries[1] == (3, 3, 3.0)  # tail
                @test entries[2] == (2, 2, 2.0)
                @test entries[3] == (1, 1, 1.0)  # head
            end
        end
    end
end
