@testset "DynamicalOrderedELL" begin

    # Kernel wrapper functions for GPU compatibility

    function _doell_pushfirst(ell, row, col, value)
        @kernel function pushfirst_kernel!(ell, row, col, value)
            Base.pushfirst!(ell, row, col, value)
        end
        backend = KernelAbstractions.get_backend(ell._values)
        threads = backend === CPU() ? 1 : 256
        pushfirst_kernel!(backend, threads)(ell, row, col, value, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _doell_append(ell, row, col, value)
        @kernel function append_kernel!(ell, row, col, value)
            Base.append!(ell, row, col, value)
        end
        backend = KernelAbstractions.get_backend(ell._values)
        threads = backend === CPU() ? 1 : 256
        append_kernel!(backend, threads)(ell, row, col, value, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _doell_insertafter_k(ell, row, k_ref, col, value)
        @kernel function insertafter_kernel!(ell, row, k_ref, col, value)
            CellBasedModels.insertafter_k!(ell, row, k_ref, col, value)
        end
        backend = KernelAbstractions.get_backend(ell._values)
        threads = backend === CPU() ? 1 : 256
        insertafter_kernel!(backend, threads)(ell, row, k_ref, col, value, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _doell_insertbefore_k(ell, row, k_ref, col, value)
        @kernel function insertbefore_kernel!(ell, row, k_ref, col, value)
            CellBasedModels.insertbefore_k!(ell, row, k_ref, col, value)
        end
        backend = KernelAbstractions.get_backend(ell._values)
        threads = backend === CPU() ? 1 : 256
        insertbefore_kernel!(backend, threads)(ell, row, k_ref, col, value, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _doell_delete_k(ell, row, k)
        @kernel function delete_kernel!(ell, row, k)
            CellBasedModels.delete_k!(ell, row, k)
        end
        backend = KernelAbstractions.get_backend(ell._values)
        threads = backend === CPU() ? 1 : 256
        delete_kernel!(backend, threads)(ell, row, k, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    function _doell_setvalue_k(ell, k, value)
        @kernel function setvalue_kernel!(ell, k, value)
            CellBasedModels.setvalue_k!(ell, k, value)
        end
        backend = KernelAbstractions.get_backend(ell._values)
        threads = backend === CPU() ? 1 : 256
        setvalue_kernel!(backend, threads)(ell, k, value, ndrange=1)
        KernelAbstractions.synchronize(backend)
    end

    # Helper function to collect ordered entries for a row
    function collect_row_entries(ell, row)
        entries = Tuple{Int, Float64}[]
        ell_cpu = CellBasedModels.toBackend(CPU(), ell)
        k = CellBasedModels.getrowhead(ell_cpu, row)
        while k != 0
            push!(entries, CellBasedModels.getentry(ell_cpu, k))
            k = CellBasedModels.getnext(ell_cpu, k)
        end
        return entries
    end

    for backend in backends
        @testset "Backend: $(backend)" begin
            
            @testset "Construction" begin
                ell = CellBasedModels.doell_zeros(Float64, 3, 4, 5)  # 3 rows, 4 cols per row, 5 overflow
                @test Array(ell._rowHead) == zeros(Int, 3)
                @test Array(ell._rowTail) == zeros(Int, 3)
                @test Array(ell._NEntries) == [0]
                @test Array(ell._NEntriesCache) == [12]  # 3 rows * 4 cols per row
                @test Array(ell._nRows) == [3]
                @test Array(ell._nColsPerRow) == [4]
                @test length(ell._values) == 12
                
                ell = CellBasedModels.toBackend(backend, ell)
                @test KernelAbstractions.get_backend(ell._values) === backend
            end

            @testset "pushfirst! single row" begin
                ell = CellBasedModels.doell_zeros(Float64, 3, 4, 5)
                ell = CellBasedModels.toBackend(backend, ell)
                
                # Insert first element in row 1
                _doell_pushfirst(ell, 1, 1, 10.0)
                entries = collect_row_entries(ell, 1)
                @test length(entries) == 1
                @test entries[1] == (1, 10.0)
                
                # Insert at front of row 1
                _doell_pushfirst(ell, 1, 2, 20.0)
                entries = collect_row_entries(ell, 1)
                @test length(entries) == 2
                @test entries[1] == (2, 20.0)
                @test entries[2] == (1, 10.0)
                
                # Row 2 should still be empty
                entries = collect_row_entries(ell, 2)
                @test length(entries) == 0
            end

            @testset "append! single row" begin
                ell = CellBasedModels.doell_zeros(Float64, 3, 4, 5)
                ell = CellBasedModels.toBackend(backend, ell)
                
                # Append to row 2
                _doell_append(ell, 2, 1, 10.0)
                _doell_append(ell, 2, 2, 20.0)
                _doell_append(ell, 2, 3, 30.0)
                
                entries = collect_row_entries(ell, 2)
                @test length(entries) == 3
                @test entries[1] == (1, 10.0)
                @test entries[2] == (2, 20.0)
                @test entries[3] == (3, 30.0)
                
                # Other rows should be empty
                @test length(collect_row_entries(ell, 1)) == 0
                @test length(collect_row_entries(ell, 3)) == 0
            end

            @testset "Multiple rows" begin
                ell = CellBasedModels.doell_zeros(Float64, 3, 3, 5)
                ell = CellBasedModels.toBackend(backend, ell)
                
                # Fill each row differently
                _doell_append(ell, 1, 1, 11.0)
                _doell_append(ell, 1, 2, 12.0)
                
                _doell_append(ell, 2, 3, 23.0)
                
                _doell_append(ell, 3, 1, 31.0)
                _doell_append(ell, 3, 2, 32.0)
                _doell_append(ell, 3, 3, 33.0)
                
                # Verify each row
                entries = collect_row_entries(ell, 1)
                @test length(entries) == 2
                @test entries[1] == (1, 11.0)
                @test entries[2] == (2, 12.0)
                
                entries = collect_row_entries(ell, 2)
                @test length(entries) == 1
                @test entries[1] == (3, 23.0)
                
                entries = collect_row_entries(ell, 3)
                @test length(entries) == 3
                @test entries[1] == (1, 31.0)
                @test entries[2] == (2, 32.0)
                @test entries[3] == (3, 33.0)
            end

            @testset "insertafter_k!" begin
                ell = CellBasedModels.doell_zeros(Float64, 2, 4, 5)
                ell = CellBasedModels.toBackend(backend, ell)
                
                # Build row 1: A -> C
                _doell_append(ell, 1, 1, 10.0)  # A
                _doell_append(ell, 1, 3, 30.0)  # C
                
                # Get head of row 1
                ell_cpu = CellBasedModels.toBackend(CPU(), ell)
                head = CellBasedModels.getrowhead(ell_cpu, 1)
                
                # Insert B after A
                _doell_insertafter_k(ell, 1, head, 2, 20.0)
                
                entries = collect_row_entries(ell, 1)
                @test length(entries) == 3
                @test entries[1] == (1, 10.0)  # A
                @test entries[2] == (2, 20.0)  # B (inserted)
                @test entries[3] == (3, 30.0)  # C
            end

            @testset "insertbefore_k!" begin
                ell = CellBasedModels.doell_zeros(Float64, 2, 4, 5)
                ell = CellBasedModels.toBackend(backend, ell)
                
                # Build row 1: A -> C
                _doell_append(ell, 1, 1, 10.0)  # A
                _doell_append(ell, 1, 3, 30.0)  # C
                
                # Get tail of row 1
                ell_cpu = CellBasedModels.toBackend(CPU(), ell)
                tail = CellBasedModels.getrowtail(ell_cpu, 1)
                
                # Insert B before C
                _doell_insertbefore_k(ell, 1, tail, 2, 20.0)
                
                entries = collect_row_entries(ell, 1)
                @test length(entries) == 3
                @test entries[1] == (1, 10.0)  # A
                @test entries[2] == (2, 20.0)  # B (inserted)
                @test entries[3] == (3, 30.0)  # C
            end

            @testset "delete_k! middle" begin
                ell = CellBasedModels.doell_zeros(Float64, 2, 4, 5)
                ell = CellBasedModels.toBackend(backend, ell)
                
                # Build row 1: A -> B -> C
                _doell_append(ell, 1, 1, 10.0)  # A
                _doell_append(ell, 1, 2, 20.0)  # B
                _doell_append(ell, 1, 3, 30.0)  # C
                
                # Get head and find B
                ell_cpu = CellBasedModels.toBackend(CPU(), ell)
                head = CellBasedModels.getrowhead(ell_cpu, 1)
                k_b = CellBasedModels.getnext(ell_cpu, head)
                
                # Delete B
                _doell_delete_k(ell, 1, k_b)
                
                entries = collect_row_entries(ell, 1)
                @test length(entries) == 2
                @test entries[1] == (1, 10.0)  # A
                @test entries[2] == (3, 30.0)  # C
            end

            @testset "delete_k! head" begin
                ell = CellBasedModels.doell_zeros(Float64, 2, 4, 5)
                ell = CellBasedModels.toBackend(backend, ell)
                
                # Build row 1: A -> B -> C
                _doell_append(ell, 1, 1, 10.0)
                _doell_append(ell, 1, 2, 20.0)
                _doell_append(ell, 1, 3, 30.0)
                
                # Delete head
                ell_cpu = CellBasedModels.toBackend(CPU(), ell)
                head = CellBasedModels.getrowhead(ell_cpu, 1)
                _doell_delete_k(ell, 1, head)
                
                entries = collect_row_entries(ell, 1)
                @test length(entries) == 2
                @test entries[1] == (2, 20.0)  # B is now head
                @test entries[2] == (3, 30.0)  # C
            end

            @testset "delete_k! tail" begin
                ell = CellBasedModels.doell_zeros(Float64, 2, 4, 5)
                ell = CellBasedModels.toBackend(backend, ell)
                
                # Build row 1: A -> B -> C
                _doell_append(ell, 1, 1, 10.0)
                _doell_append(ell, 1, 2, 20.0)
                _doell_append(ell, 1, 3, 30.0)
                
                # Delete tail
                ell_cpu = CellBasedModels.toBackend(CPU(), ell)
                tail = CellBasedModels.getrowtail(ell_cpu, 1)
                _doell_delete_k(ell, 1, tail)
                
                entries = collect_row_entries(ell, 1)
                @test length(entries) == 2
                @test entries[1] == (1, 10.0)  # A
                @test entries[2] == (2, 20.0)  # B is now tail
            end

            @testset "setvalue_k!" begin
                ell = CellBasedModels.doell_zeros(Float64, 2, 4, 5)
                ell = CellBasedModels.toBackend(backend, ell)
                
                _doell_append(ell, 1, 1, 10.0)
                _doell_append(ell, 1, 2, 20.0)
                
                # Modify value at head
                ell_cpu = CellBasedModels.toBackend(CPU(), ell)
                head = CellBasedModels.getrowhead(ell_cpu, 1)
                
                _doell_setvalue_k(ell, head, 100.0)
                
                entries = collect_row_entries(ell, 1)
                @test entries[1] == (1, 100.0)  # Value changed
                @test entries[2] == (2, 20.0)   # Unchanged
            end

            @testset "getindex" begin
                ell = CellBasedModels.doell_zeros(Float64, 3, 3, 5)
                ell = CellBasedModels.toBackend(backend, ell)
                
                _doell_append(ell, 1, 2, 12.0)
                _doell_append(ell, 2, 3, 23.0)
                _doell_append(ell, 3, 1, 31.0)
                
                ell_cpu = CellBasedModels.toBackend(CPU(), ell)
                @test ell_cpu[1, 2] == 12.0
                @test ell_cpu[2, 3] == 23.0
                @test ell_cpu[3, 1] == 31.0
                @test ell_cpu[1, 1] == 0.0  # Non-existent
            end

            @testset "todense" begin
                ell = CellBasedModels.doell_zeros(Float64, 3, 3, 5)
                ell = CellBasedModels.toBackend(backend, ell)
                
                _doell_append(ell, 1, 1, 11.0)
                _doell_append(ell, 1, 3, 13.0)
                _doell_append(ell, 2, 2, 22.0)
                _doell_append(ell, 3, 1, 31.0)
                _doell_append(ell, 3, 3, 33.0)
                
                dense = CellBasedModels.todense(ell)
                @test dense[1, 1] == 11.0
                @test dense[1, 3] == 13.0
                @test dense[2, 2] == 22.0
                @test dense[3, 1] == 31.0
                @test dense[3, 3] == 33.0
                @test dense[1, 2] == 0.0
                @test dense[2, 1] == 0.0
            end

            @testset "Empty row operations" begin
                ell = CellBasedModels.doell_zeros(Float64, 3, 4, 5)
                ell = CellBasedModels.toBackend(backend, ell)
                
                # All rows should have 0 head/tail
                ell_cpu = CellBasedModels.toBackend(CPU(), ell)
                for row in 1:3
                    @test CellBasedModels.getrowhead(ell_cpu, row) == 0
                    @test CellBasedModels.getrowtail(ell_cpu, row) == 0
                end
                
                # Add one element to row 2
                _doell_append(ell, 2, 1, 10.0)
                
                ell_cpu = CellBasedModels.toBackend(CPU(), ell)
                head = CellBasedModels.getrowhead(ell_cpu, 2)
                tail = CellBasedModels.getrowtail(ell_cpu, 2)
                
                # Single element: head == tail
                @test head == tail
                @test head != 0
                
                # Delete it
                _doell_delete_k(ell, 2, head)
                
                # Back to empty
                ell_cpu = CellBasedModels.toBackend(CPU(), ell)
                @test CellBasedModels.getrowhead(ell_cpu, 2) == 0
                @test CellBasedModels.getrowtail(ell_cpu, 2) == 0
            end

            @testset "Backward traversal" begin
                ell = CellBasedModels.doell_zeros(Float64, 2, 4, 5)
                ell = CellBasedModels.toBackend(backend, ell)
                
                _doell_append(ell, 1, 1, 1.0)
                _doell_append(ell, 1, 2, 2.0)
                _doell_append(ell, 1, 3, 3.0)
                
                # Traverse backwards from tail
                ell_cpu = CellBasedModels.toBackend(CPU(), ell)
                entries = Tuple{Int, Float64}[]
                k = CellBasedModels.getrowtail(ell_cpu, 1)
                while k != 0
                    push!(entries, CellBasedModels.getentry(ell_cpu, k))
                    k = CellBasedModels.getprev(ell_cpu, k)
                end
                
                @test length(entries) == 3
                @test entries[1] == (3, 3.0)  # tail
                @test entries[2] == (2, 2.0)
                @test entries[3] == (1, 1.0)  # head
            end

            @testset "Mixed operations in multiple rows" begin
                ell = CellBasedModels.doell_zeros(Float64, 3, 5, 10)
                ell = CellBasedModels.toBackend(backend, ell)
                
                # Fill row 1: 1 -> 2 -> 3
                _doell_append(ell, 1, 1, 1.0)
                _doell_append(ell, 1, 2, 2.0)
                _doell_append(ell, 1, 3, 3.0)
                
                # Fill row 2: 4 -> 5
                _doell_append(ell, 2, 4, 4.0)
                _doell_append(ell, 2, 5, 5.0)
                
                # Delete middle of row 1
                ell_cpu = CellBasedModels.toBackend(CPU(), ell)
                head = CellBasedModels.getrowhead(ell_cpu, 1)
                k_middle = CellBasedModels.getnext(ell_cpu, head)
                _doell_delete_k(ell, 1, k_middle)
                
                # Insert at front of row 1
                _doell_pushfirst(ell, 1, 10, 10.0)
                
                # Row 1 should be: 10 -> 1 -> 3
                entries = collect_row_entries(ell, 1)
                @test length(entries) == 3
                @test entries[1] == (10, 10.0)
                @test entries[2] == (1, 1.0)
                @test entries[3] == (3, 3.0)
                
                # Row 2 should be unchanged: 4 -> 5
                entries = collect_row_entries(ell, 2)
                @test length(entries) == 2
                @test entries[1] == (4, 4.0)
                @test entries[2] == (5, 5.0)
            end

            @testset "ELL column-major layout" begin
                # ELL stores in column-major: slot = (row-1) * n_cols_per_row + col_slot
                ell = CellBasedModels.doell_zeros(Float64, 2, 3, 5)  # 2 rows, 3 cols per row
                ell = CellBasedModels.toBackend(backend, ell)
                
                # Fill both rows
                _doell_append(ell, 1, 10, 1.0)
                _doell_append(ell, 1, 20, 2.0)
                _doell_append(ell, 2, 30, 3.0)
                _doell_append(ell, 2, 40, 4.0)
                
                # Verify iteration order is correct per row
                entries1 = collect_row_entries(ell, 1)
                @test entries1[1] == (10, 1.0)
                @test entries1[2] == (20, 2.0)
                
                entries2 = collect_row_entries(ell, 2)
                @test entries2[1] == (30, 3.0)
                @test entries2[2] == (40, 4.0)
            end
        end
    end
end
