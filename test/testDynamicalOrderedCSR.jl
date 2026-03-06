@testset "DynamicalOrderedCSR" begin

    # Kernel wrapper functions for GPU compatibility

    function _docsr_pushfirst(csr, row, col, value)
        @kernel function pushfirst_kernel!(csr, row, col, value)
            Base.pushfirst!(csr, row, col, value)
        end
        backend = KernelAbstractions.get_backend(csr._values)
        threads = backend === CPU() ? 1 : 256
        pushfirst_kernel!(backend, threads)(csr, row, col, value, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _docsr_append(csr, row, col, value)
        @kernel function append_kernel!(csr, row, col, value)
            Base.append!(csr, row, col, value)
        end
        backend = KernelAbstractions.get_backend(csr._values)
        threads = backend === CPU() ? 1 : 256
        append_kernel!(backend, threads)(csr, row, col, value, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _docsr_insertafter_k(csr, row, k_ref, col, value)
        @kernel function insertafter_kernel!(csr, row, k_ref, col, value)
            CellBasedModels.insertafter_k!(csr, row, k_ref, col, value)
        end
        backend = KernelAbstractions.get_backend(csr._values)
        threads = backend === CPU() ? 1 : 256
        insertafter_kernel!(backend, threads)(csr, row, k_ref, col, value, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _docsr_insertbefore_k(csr, row, k_ref, col, value)
        @kernel function insertbefore_kernel!(csr, row, k_ref, col, value)
            CellBasedModels.insertbefore_k!(csr, row, k_ref, col, value)
        end
        backend = KernelAbstractions.get_backend(csr._values)
        threads = backend === CPU() ? 1 : 256
        insertbefore_kernel!(backend, threads)(csr, row, k_ref, col, value, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _docsr_delete_k(csr, row, k)
        @kernel function delete_kernel!(csr, row, k)
            CellBasedModels.delete_k!(csr, row, k)
        end
        backend = KernelAbstractions.get_backend(csr._values)
        threads = backend === CPU() ? 1 : 256
        delete_kernel!(backend, threads)(csr, row, k, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _docsr_setvalue_k(csr, k, value)
        @kernel function setvalue_kernel!(csr, k, value)
            CellBasedModels.setvalue_k!(csr, k, value)
        end
        backend = KernelAbstractions.get_backend(csr._values)
        threads = backend === CPU() ? 1 : 256
        setvalue_kernel!(backend, threads)(csr, k, value, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    # Helper function to collect ordered entries for a row
    function collect_row_entries(csr, row)
        entries = Tuple{Int, Float64}[]
        csr_cpu = CellBasedModels.toBackend(CPU(), csr)
        k = CellBasedModels.getrowhead(csr_cpu, row)
        while k != 0
            push!(entries, CellBasedModels.getentry(csr_cpu, k))
            k = CellBasedModels.getnext(csr_cpu, k)
        end
        return entries
    end

    for backend in backends
        @testset "Backend: $(backend)" begin
            
            @testset "Construction" begin
                csr = CellBasedModels.docsr_zeros(Float64, 3, 4, 5)  # 3 rows, 4 cols per row, 5 overflow
                @test Array(csr._rowHead) == zeros(Int, 3)
                @test Array(csr._rowTail) == zeros(Int, 3)
                @test Array(csr._NEntries) == [0]
                @test Array(csr._NEntriesCache) == [12]  # 3 rows * 4 cols
                @test length(csr._values) == 12
                
                csr = CellBasedModels.toBackend(backend, csr)
                @test KernelAbstractions.get_backend(csr._values) === backend
            end

            @testset "pushfirst! single row" begin
                csr = CellBasedModels.docsr_zeros(Float64, 3, 4, 5)
                csr = CellBasedModels.toBackend(backend, csr)
                
                # Insert first element in row 1
                _docsr_pushfirst(csr, 1, 1, 10.0)
                entries = collect_row_entries(csr, 1)
                @test length(entries) == 1
                @test entries[1] == (1, 10.0)
                
                # Insert at front of row 1 - should become first
                _docsr_pushfirst(csr, 1, 2, 20.0)
                entries = collect_row_entries(csr, 1)
                @test length(entries) == 2
                @test entries[1] == (2, 20.0)
                @test entries[2] == (1, 10.0)
                
                # Row 2 should still be empty
                entries = collect_row_entries(csr, 2)
                @test length(entries) == 0
            end

            @testset "append! single row" begin
                csr = CellBasedModels.docsr_zeros(Float64, 3, 4, 5)
                csr = CellBasedModels.toBackend(backend, csr)
                
                # Append to row 2
                _docsr_append(csr, 2, 1, 10.0)
                _docsr_append(csr, 2, 2, 20.0)
                _docsr_append(csr, 2, 3, 30.0)
                
                entries = collect_row_entries(csr, 2)
                @test length(entries) == 3
                @test entries[1] == (1, 10.0)
                @test entries[2] == (2, 20.0)
                @test entries[3] == (3, 30.0)
                
                # Other rows should be empty
                @test length(collect_row_entries(csr, 1)) == 0
                @test length(collect_row_entries(csr, 3)) == 0
            end

            @testset "Multiple rows" begin
                csr = CellBasedModels.docsr_zeros(Float64, 3, 3, 5)
                csr = CellBasedModels.toBackend(backend, csr)
                
                # Fill each row differently
                _docsr_append(csr, 1, 1, 11.0)
                _docsr_append(csr, 1, 2, 12.0)
                
                _docsr_append(csr, 2, 3, 23.0)
                
                _docsr_append(csr, 3, 1, 31.0)
                _docsr_append(csr, 3, 2, 32.0)
                _docsr_append(csr, 3, 3, 33.0)
                
                # Verify each row
                entries = collect_row_entries(csr, 1)
                @test length(entries) == 2
                @test entries[1] == (1, 11.0)
                @test entries[2] == (2, 12.0)
                
                entries = collect_row_entries(csr, 2)
                @test length(entries) == 1
                @test entries[1] == (3, 23.0)
                
                entries = collect_row_entries(csr, 3)
                @test length(entries) == 3
                @test entries[1] == (1, 31.0)
                @test entries[2] == (2, 32.0)
                @test entries[3] == (3, 33.0)
            end

            @testset "insertafter_k!" begin
                csr = CellBasedModels.docsr_zeros(Float64, 2, 4, 5)
                csr = CellBasedModels.toBackend(backend, csr)
                
                # Build row 1: A -> C
                _docsr_append(csr, 1, 1, 10.0)  # A
                _docsr_append(csr, 1, 3, 30.0)  # C
                
                # Get head of row 1
                csr_cpu = CellBasedModels.toBackend(CPU(), csr)
                head = CellBasedModels.getrowhead(csr_cpu, 1)
                
                # Insert B after A
                _docsr_insertafter_k(csr, 1, head, 2, 20.0)
                
                entries = collect_row_entries(csr, 1)
                @test length(entries) == 3
                @test entries[1] == (1, 10.0)  # A
                @test entries[2] == (2, 20.0)  # B (inserted)
                @test entries[3] == (3, 30.0)  # C
            end

            @testset "insertbefore_k!" begin
                csr = CellBasedModels.docsr_zeros(Float64, 2, 4, 5)
                csr = CellBasedModels.toBackend(backend, csr)
                
                # Build row 1: A -> C
                _docsr_append(csr, 1, 1, 10.0)  # A
                _docsr_append(csr, 1, 3, 30.0)  # C
                
                # Get tail of row 1
                csr_cpu = CellBasedModels.toBackend(CPU(), csr)
                tail = CellBasedModels.getrowtail(csr_cpu, 1)
                
                # Insert B before C
                _docsr_insertbefore_k(csr, 1, tail, 2, 20.0)
                
                entries = collect_row_entries(csr, 1)
                @test length(entries) == 3
                @test entries[1] == (1, 10.0)  # A
                @test entries[2] == (2, 20.0)  # B (inserted)
                @test entries[3] == (3, 30.0)  # C
            end

            @testset "delete_k! middle" begin
                csr = CellBasedModels.docsr_zeros(Float64, 2, 4, 5)
                csr = CellBasedModels.toBackend(backend, csr)
                
                # Build row 1: A -> B -> C
                _docsr_append(csr, 1, 1, 10.0)  # A
                _docsr_append(csr, 1, 2, 20.0)  # B
                _docsr_append(csr, 1, 3, 30.0)  # C
                
                # Get head and find B
                csr_cpu = CellBasedModels.toBackend(CPU(), csr)
                head = CellBasedModels.getrowhead(csr_cpu, 1)
                k_b = CellBasedModels.getnext(csr_cpu, head)
                
                # Delete B
                _docsr_delete_k(csr, 1, k_b)
                
                entries = collect_row_entries(csr, 1)
                @test length(entries) == 2
                @test entries[1] == (1, 10.0)  # A
                @test entries[2] == (3, 30.0)  # C
            end

            @testset "delete_k! head" begin
                csr = CellBasedModels.docsr_zeros(Float64, 2, 4, 5)
                csr = CellBasedModels.toBackend(backend, csr)
                
                # Build row 1: A -> B -> C
                _docsr_append(csr, 1, 1, 10.0)
                _docsr_append(csr, 1, 2, 20.0)
                _docsr_append(csr, 1, 3, 30.0)
                
                # Delete head
                csr_cpu = CellBasedModels.toBackend(CPU(), csr)
                head = CellBasedModels.getrowhead(csr_cpu, 1)
                _docsr_delete_k(csr, 1, head)
                
                entries = collect_row_entries(csr, 1)
                @test length(entries) == 2
                @test entries[1] == (2, 20.0)  # B is now head
                @test entries[2] == (3, 30.0)  # C
            end

            @testset "delete_k! tail" begin
                csr = CellBasedModels.docsr_zeros(Float64, 2, 4, 5)
                csr = CellBasedModels.toBackend(backend, csr)
                
                # Build row 1: A -> B -> C
                _docsr_append(csr, 1, 1, 10.0)
                _docsr_append(csr, 1, 2, 20.0)
                _docsr_append(csr, 1, 3, 30.0)
                
                # Delete tail
                csr_cpu = CellBasedModels.toBackend(CPU(), csr)
                tail = CellBasedModels.getrowtail(csr_cpu, 1)
                _docsr_delete_k(csr, 1, tail)
                
                entries = collect_row_entries(csr, 1)
                @test length(entries) == 2
                @test entries[1] == (1, 10.0)  # A
                @test entries[2] == (2, 20.0)  # B is now tail
            end

            @testset "setvalue_k!" begin
                csr = CellBasedModels.docsr_zeros(Float64, 2, 4, 5)
                csr = CellBasedModels.toBackend(backend, csr)
                
                _docsr_append(csr, 1, 1, 10.0)
                _docsr_append(csr, 1, 2, 20.0)
                
                # Modify value at head
                csr_cpu = CellBasedModels.toBackend(CPU(), csr)
                head = CellBasedModels.getrowhead(csr_cpu, 1)
                
                _docsr_setvalue_k(csr, head, 100.0)
                
                entries = collect_row_entries(csr, 1)
                @test entries[1] == (1, 100.0)  # Value changed
                @test entries[2] == (2, 20.0)   # Unchanged
            end

            @testset "getindex" begin
                csr = CellBasedModels.docsr_zeros(Float64, 3, 3, 5)
                csr = CellBasedModels.toBackend(backend, csr)
                
                _docsr_append(csr, 1, 2, 12.0)
                _docsr_append(csr, 2, 3, 23.0)
                _docsr_append(csr, 3, 1, 31.0)
                
                csr_cpu = CellBasedModels.toBackend(CPU(), csr)
                @test csr_cpu[1, 2] == 12.0
                @test csr_cpu[2, 3] == 23.0
                @test csr_cpu[3, 1] == 31.0
                @test csr_cpu[1, 1] == 0.0  # Non-existent
            end

            @testset "todense" begin
                csr = CellBasedModels.docsr_zeros(Float64, 3, 3, 5)
                csr = CellBasedModels.toBackend(backend, csr)
                
                _docsr_append(csr, 1, 1, 11.0)
                _docsr_append(csr, 1, 3, 13.0)
                _docsr_append(csr, 2, 2, 22.0)
                _docsr_append(csr, 3, 1, 31.0)
                _docsr_append(csr, 3, 3, 33.0)
                
                dense = CellBasedModels.todense(csr)
                @test dense[1, 1] == 11.0
                @test dense[1, 3] == 13.0
                @test dense[2, 2] == 22.0
                @test dense[3, 1] == 31.0
                @test dense[3, 3] == 33.0
                @test dense[1, 2] == 0.0
                @test dense[2, 1] == 0.0
            end

            @testset "Empty row operations" begin
                csr = CellBasedModels.docsr_zeros(Float64, 3, 4, 5)
                csr = CellBasedModels.toBackend(backend, csr)
                
                # All rows should have 0 head/tail
                csr_cpu = CellBasedModels.toBackend(CPU(), csr)
                for row in 1:3
                    @test CellBasedModels.getrowhead(csr_cpu, row) == 0
                    @test CellBasedModels.getrowtail(csr_cpu, row) == 0
                end
                
                # Add one element to row 2
                _docsr_append(csr, 2, 1, 10.0)
                
                csr_cpu = CellBasedModels.toBackend(CPU(), csr)
                head = CellBasedModels.getrowhead(csr_cpu, 2)
                tail = CellBasedModels.getrowtail(csr_cpu, 2)
                
                # Single element: head == tail
                @test head == tail
                @test head != 0
                
                # Delete it
                _docsr_delete_k(csr, 2, head)
                
                # Back to empty
                csr_cpu = CellBasedModels.toBackend(CPU(), csr)
                @test CellBasedModels.getrowhead(csr_cpu, 2) == 0
                @test CellBasedModels.getrowtail(csr_cpu, 2) == 0
            end

            @testset "Backward traversal" begin
                csr = CellBasedModels.docsr_zeros(Float64, 2, 4, 5)
                csr = CellBasedModels.toBackend(backend, csr)
                
                _docsr_append(csr, 1, 1, 1.0)
                _docsr_append(csr, 1, 2, 2.0)
                _docsr_append(csr, 1, 3, 3.0)
                
                # Traverse backwards from tail
                csr_cpu = CellBasedModels.toBackend(CPU(), csr)
                entries = Tuple{Int, Float64}[]
                k = CellBasedModels.getrowtail(csr_cpu, 1)
                while k != 0
                    push!(entries, CellBasedModels.getentry(csr_cpu, k))
                    k = CellBasedModels.getprev(csr_cpu, k)
                end
                
                @test length(entries) == 3
                @test entries[1] == (3, 3.0)  # tail
                @test entries[2] == (2, 2.0)
                @test entries[3] == (1, 1.0)  # head
            end

            @testset "Mixed operations in multiple rows" begin
                csr = CellBasedModels.docsr_zeros(Float64, 3, 5, 10)
                csr = CellBasedModels.toBackend(backend, csr)
                
                # Fill row 1: 1 -> 2 -> 3
                _docsr_append(csr, 1, 1, 1.0)
                _docsr_append(csr, 1, 2, 2.0)
                _docsr_append(csr, 1, 3, 3.0)
                
                # Fill row 2: 4 -> 5
                _docsr_append(csr, 2, 4, 4.0)
                _docsr_append(csr, 2, 5, 5.0)
                
                # Delete middle of row 1
                csr_cpu = CellBasedModels.toBackend(CPU(), csr)
                head = CellBasedModels.getrowhead(csr_cpu, 1)
                k_middle = CellBasedModels.getnext(csr_cpu, head)
                _docsr_delete_k(csr, 1, k_middle)
                
                # Insert at front of row 1
                _docsr_pushfirst(csr, 1, 10, 10.0)
                
                # Row 1 should be: 10 -> 1 -> 3
                entries = collect_row_entries(csr, 1)
                @test length(entries) == 3
                @test entries[1] == (10, 10.0)
                @test entries[2] == (1, 1.0)
                @test entries[3] == (3, 3.0)
                
                # Row 2 should be unchanged: 4 -> 5
                entries = collect_row_entries(csr, 2)
                @test length(entries) == 2
                @test entries[1] == (4, 4.0)
                @test entries[2] == (5, 5.0)
            end
        end
    end
end
