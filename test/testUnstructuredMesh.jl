using BenchmarkTools
using CUDA
using DifferentialEquations
using Adapt
import StaticArrays: SizedVector
using KernelAbstractions

@testset verbose = verbose "ABM - UnstructuredMesh" begin

    #######################################################################
    # HELPERS
    #######################################################################
    props = (
            a = Parameter(Float64, description="param a", dimensions=:M, defaultValue=1.0),
            b = Parameter(Int, description="param b", dimensions=:count, defaultValue=0),
        )

    all_scopes = (Node, Edge, Face, Volume, Agent)
    all_scopes_index = (:n, :e, :f, :v, :a)

    #######################################################################
    # TEST 1: UnstructuredMesh
    #######################################################################
    @testset "UnstructuredMesh - full coverage" begin
        for dims in 0:3
            for scope in all_scopes
                mesh = nothing
                if scope === Node
                    mesh = UnstructuredMesh(dims; n  = Node(props))
                elseif scope === Edge
                    mesh = UnstructuredMesh(dims; n = Node(), e  = Edge((:n,:n), props))
                elseif scope === Face
                    mesh = UnstructuredMesh(dims; n = Node(), f  = Face(:n, props))
                elseif scope === Volume
                    mesh = UnstructuredMesh(dims; n = Node(), v  = Volume(:n, props))
                elseif scope === Agent
                    mesh = UnstructuredMesh(dims; n = Node(), a  = Agent(props))
                end
                @test mesh isa UnstructuredMesh
                @test CellBasedModels.spatialDims(mesh) == dims
                @test CellBasedModels.specialization(mesh) === Nothing
            end
        end

        # Invalid dimension
        @test_throws ErrorException UnstructuredMesh(-1)
        @test_throws ErrorException UnstructuredMesh(4)

        # Duplicate protected parameter name (e.g., x)
        bad_props = (x = Parameter(Float64, description="duplicate", dimensions=:L, defaultValue=0.0),)
        @test_throws ErrorException UnstructuredMesh(1; n=Node(bad_props))

        # Show output test
        io = IOBuffer()
        show(io, UnstructuredMesh(2; n=Node(props)))
        output = String(take!(io))
        # show(UnstructuredMesh(2; n=Node(props)))
        @test occursin("UnstructuredMesh with dimensions 2", output)

        # Show output test
        io = IOBuffer()
        show(io, typeof(UnstructuredMesh(2; n=Node(props))))
        output = String(take!(io))
        # show(typeof(UnstructuredMesh(2; n=Node(props))))
        @test occursin("UnstructuredMesh{dims=2", output)
    end

    #######################################################################
    # TEST 2: UnstructuredMeshField
    #######################################################################
    @testset "UnstructuredMeshField - construction and logic" begin

        # Valid case
        meshProperty = Node(props)
        field = UnstructuredMeshField(meshProperty; N=3, NCache=5)
        @test field isa UnstructuredMeshField
        @test field._N[] == 3
        @test field._NCache[] == 5
        @test length(field._FlagsSurvived) == 5
        @test field._NOverflow[] == 0
        @test field._idMax[] == 3
        @test field._NP == length(props)
        @test field._pReference isa SizedVector

        # Get properties
        @test field.a == zeros(Float64, 3)
        @test field._p.a == zeros(Float64, 5)

        # With id=false
        field2 = UnstructuredMeshField(meshProperty; N=2, NCache=5, id=false)
        @test field2._id === nothing
        @test field2._idMax === nothing

        # Show output formatting
        io = IOBuffer()
        show(io, field)
        txt = String(take!(io))
        @test occursin("_id", txt)

        # Copy
        field = UnstructuredMeshField(meshProperty; N=3, NCache=5)
        field._pReference .= [true, false]
        fieldCopy = copy(field)
        field.a .= 7.0
        field.b .= 2
        @test fieldCopy.a == fill(7.0, 3)
        @test fieldCopy.b == zeros(Int, 3)

        # zero
        field = UnstructuredMeshField(meshProperty; N=3, NCache=5)
        field._pReference .= [true, false]
        field.a .= 7.0
        field.b .= 2        
        fieldZero = zero(field)
        @test fieldZero.a == fill(7.0, 3)
        @test fieldZero.b == zeros(Int, 3)

        # toGPU/toCPU
        if CUDA.has_cuda()
            field = UnstructuredMeshField(meshProperty; N=3, NCache=5)
            field._pReference .= [true, false]
            field.a .= 7.0
            field.b .= 2

            field_gpu = toBackend(field, CUDA.CUDABackend)

            @test typeof(field_gpu._id) <: CUDA.CuArray
            @test typeof(field_gpu.a) <: CUDA.CuArray

            field_cpu = toBackend(field_gpu, CPU)

            @test typeof(field_cpu) == typeof(field)
        end

        # Copyto!
        field = UnstructuredMeshField(meshProperty; N=3, NCache=5)
        field._pReference .= [false, true]
        field.a .= 7.0
        field.b .= 2
        field2 = UnstructuredMeshField(meshProperty; N=3, NCache=5)
        copyto!(field2, field)
        @test field2.a == fill(7.0, 3)
        @test field2.b == fill(0, 3)
        if CUDA.has_cuda()
            field_gpu = toBackend(field, CUDA.CUDABackend)
            field2_gpu = toBackend(field2, CUDA.CUDABackend)
            copyto!(field2_gpu, field_gpu)
            @test Array(field2_gpu.a) == fill(7.0, 3)
            @test Array(field2_gpu.b) == fill(0, 3)
        end

        # Broadcast
        field = UnstructuredMeshField(meshProperty; N=3, NCache=5)
        field._pReference .= [false, true]
        field.a .= 7.0
        field.b .= 2
        field2 = UnstructuredMeshField(meshProperty; N=3, NCache=5)
        field2._pReference .= [false, true]
        @. field2 = field * 0.1 + 3.0
        @test field2.a == fill(3.7, 3)
        @test field2.b == fill(0, 3)
        if CUDA.has_cuda()
            field_gpu = toBackend(field, CUDA.CUDABackend)
            field2_gpu = toBackend(field2, CUDA.CUDABackend)
            @. field2_gpu = field_gpu * 0.1 + 3.0
            @test Array(field2_gpu.a) == fill(3.7, 3)
            @test Array(field2_gpu.b) == fill(0, 3)
        end

        # Broadcast @..
        field = UnstructuredMeshField(meshProperty; N=3, NCache=5)
        field._pReference .= [false, true]
        field.a .= 7.0
        field.b .= 2
        field2 = UnstructuredMeshField(meshProperty; N=3, NCache=5)
        field2._pReference .= [false, true]
        DifferentialEquations.DiffEqBase.@.. field2 = field * 0.1 + 3.0
        @test field2.a == fill(3.7, 3)
        @test field2.b == fill(0, 3)
        if CUDA.has_cuda()
            field_gpu = toBackend(field, CUDA.CUDABackend)
            field2_gpu = toBackend(field2, CUDA.CUDABackend)
            DifferentialEquations.DiffEqBase.@.. field2_gpu = field_gpu * 0.1 + 3.0
            @test Array(field2_gpu.a) == fill(3.7, 3)
            @test Array(field2_gpu.b) == fill(0, 3)
        end

        # Kernel works
        if CUDA.has_cuda()

            function test_kernel_field!(x)
                x.a[1]
                nothing
            end

            field = UnstructuredMeshField(meshProperty; N=3, NCache=5)
            field._pReference .= [true, false]
            field_gpu = toBackend(field, CUDA.CUDABackend)

            @test_nowarn CUDA.@cuda test_kernel_field!(field_gpu)

        end

    end

    #######################################################################
    # TEST 3: UnstructuredMeshObject
    #######################################################################
    @testset "UnstructuredMeshObject - construction" begin
        for dims in 0:3
            for (scope, scope_index) in zip(all_scopes, all_scopes_index)
                mesh = nothing
                if scope === Node
                    mesh = UnstructuredMesh(dims; n  = Node(props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4))
                    @test obj isa UnstructuredMeshObject
                    @test obj.n isa UnstructuredMeshField
                elseif scope === Edge
                    mesh = UnstructuredMesh(dims; n = Node(), e  = Edge((:n,:n), props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), e = (2,4))
                    @test obj isa UnstructuredMeshObject
                    @test obj.n isa UnstructuredMeshField
                    @test obj.e isa UnstructuredMeshField
                elseif scope === Face
                    mesh = UnstructuredMesh(dims; n = Node(), f  = Face(:n, props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), f = (2,4))
                    @test obj isa UnstructuredMeshObject
                    @test obj.n isa UnstructuredMeshField
                    @test obj.f isa UnstructuredMeshField
                elseif scope === Volume
                    mesh = UnstructuredMesh(dims; n = Node(), v  = Volume(:n, props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), v = (2,4))
                    @test obj isa UnstructuredMeshObject
                    @test obj.n isa UnstructuredMeshField
                    @test obj.v isa UnstructuredMeshField
                elseif scope === Agent
                    mesh = UnstructuredMesh(dims; n = Node(), a  = Agent(props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), a = (2,4))
                    @test obj isa UnstructuredMeshObject
                    @test obj.n isa UnstructuredMeshField
                    @test obj.a isa UnstructuredMeshField
                end

                # Invalid cache values
                @test_throws ErrorException UnstructuredMeshObject(mesh, agentN=4, agentNCache=2)
                @test_throws ErrorException UnstructuredMeshObject(mesh, agentN=-1, agentNCache=0)
            end
        end
    end

    @testset "UnstructuredMeshObject - copy" begin
        for dims in 0:3
            for (scope, scope_index) in zip(all_scopes, all_scopes_index)
                mesh = nothing
                obj = nothing
                if scope === Node
                    mesh = UnstructuredMesh(dims; n  = Node(props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4))
                elseif scope === Edge
                    mesh = UnstructuredMesh(dims; n = Node(), e  = Edge((:n,:n), props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), e = (2,4))
                elseif scope === Face
                    mesh = UnstructuredMesh(dims; n = Node(), f  = Face(:n, props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), f = (2,4))
                elseif scope === Volume
                    mesh = UnstructuredMesh(dims; n = Node(), v  = Volume(:n, props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), v = (2,4))
                elseif scope === Agent
                    mesh = UnstructuredMesh(dims; n = Node(), a  = Agent(props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), a = (2,4))
                end
                if scope == Node
                    obj[scope_index]._pReference .= [[true, true, true][1:1:dims]..., true, false]
                else
                    obj[scope_index]._pReference .= [true, false]
                end
                objCopy = copy(obj)
                obj[scope_index].a .= 7.0
                obj[scope_index].b .= 2
                @test objCopy[scope_index].a == fill(7.0, 2)
                @test objCopy[scope_index]._p.a == [7.0, 7.0, 0.0, 0.0]
                @test objCopy[scope_index].b == zeros(Int, 2)
                @test objCopy[scope_index]._p.b == [0, 0, 0, 0]
            end
        end
    end

    @testset "UnstructuredMeshObject - zero" begin
        for dims in 0:3
            for (scope, scope_index) in zip(all_scopes, all_scopes_index)
                mesh = nothing
                obj = nothing
                if scope === Node
                    mesh = UnstructuredMesh(dims; n  = Node(props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4))
                elseif scope === Edge
                    mesh = UnstructuredMesh(dims; n = Node(), e  = Edge((:n,:n), props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), e = (2,4))
                elseif scope === Face
                    mesh = UnstructuredMesh(dims; n = Node(), f  = Face(:n, props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), f = (2,4))
                elseif scope === Volume
                    mesh = UnstructuredMesh(dims; n = Node(), v  = Volume(:n, props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), v = (2,4))
                elseif scope === Agent
                    mesh = UnstructuredMesh(dims; n = Node(), a  = Agent(props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), a = (2,4))
                end
                if scope == Node
                    obj[scope_index]._pReference .= [[true, true, true][1:1:dims]..., true, false]
                else
                    obj[scope_index]._pReference .= [true, false]
                end
                obj[scope_index].a .= 7.0
                obj[scope_index].b .= 2
                objZero = zero(obj)
                @test objZero[scope_index].a == fill(7.0, 2)
                @test objZero[scope_index]._p.a == [7.0, 7.0, 0.0, 0.0]
                @test objZero[scope_index].b == zeros(Int, 2)
                @test objZero[scope_index]._p.b == [0, 0, 0, 0]
            end
        end
    end

    @testset "UnstructuredMeshObject - toGPU/toCPU" begin
        for dims in 0:3
            for (scope, scope_index) in zip(all_scopes, all_scopes_index)
                # toGPU/toCPU
                if CUDA.has_cuda()
                    mesh = nothing
                    obj = nothing
                    if scope === Node
                        mesh = UnstructuredMesh(dims; n  = Node(props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4))
                    elseif scope === Edge
                        mesh = UnstructuredMesh(dims; n = Node(), e  = Edge((:n,:n), props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), e = (2,4))
                    elseif scope === Face
                        mesh = UnstructuredMesh(dims; n = Node(), f  = Face(:n, props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), f = (2,4))
                    elseif scope === Volume
                        mesh = UnstructuredMesh(dims; n = Node(), v  = Volume(:n, props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), v = (2,4))
                    elseif scope === Agent
                        mesh = UnstructuredMesh(dims; n = Node(), a  = Agent(props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), a = (2,4))
                    end
                    if scope == Node
                        obj[scope_index]._pReference .= [[true, true, true][1:1:dims]..., true, false]
                    else
                        obj[scope_index]._pReference .= [true, false]
                    end
                    obj[scope_index].a .= 7.0
                    obj[scope_index].b .= 2
                    obj_gpu = toBackend(obj, CUDA.CUDABackend)
                    @test typeof(obj_gpu[scope_index]._id) <: CUDA.CuArray
                    @test typeof(obj_gpu[scope_index].a) <: CUDA.CuArray
                    obj_cpu = toBackend(obj_gpu, CPU)
                    @test typeof(obj_cpu) == typeof(obj)
                end
            end
        end
    end

    @testset "UnstructuredMeshObject - copyto!" begin
        for dims in 0:3
            for (scope, scope_index) in zip(all_scopes, all_scopes_index)
                    mesh = nothing
                    obj = nothing
                    if scope === Node
                        mesh = UnstructuredMesh(dims; n  = Node(props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4))
                        obj2 = UnstructuredMeshObject(mesh, n = (2,4))
                    elseif scope === Edge
                        mesh = UnstructuredMesh(dims; n = Node(), e  = Edge((:n,:n), props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), e = (2,4))
                        obj2 = UnstructuredMeshObject(mesh, n = (2,4), e = (2,4))
                    elseif scope === Face
                        mesh = UnstructuredMesh(dims; n = Node(), f  = Face(:n, props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), f = (2,4))
                        obj2 = UnstructuredMeshObject(mesh, n = (2,4), f = (2,4))
                    elseif scope === Volume
                        mesh = UnstructuredMesh(dims; n = Node(), v  = Volume(:n, props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), v = (2,4))
                        obj2 = UnstructuredMeshObject(mesh, n = (2,4), v = (2,4))
                    elseif scope === Agent
                        mesh = UnstructuredMesh(dims; n = Node(), a  = Agent(props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), a = (2,4))
                        obj2 = UnstructuredMeshObject(mesh, n = (2,4), a = (2,4))
                    end
                if scope == Node
                    obj[scope_index]._pReference .= [[true, true, true][1:1:dims]..., true, false]
                else
                    obj[scope_index]._pReference .= [true, false]
                end
                obj[scope_index].a .= 7.0
                obj[scope_index].b .= 2
                if scope == Node
                    obj2[scope_index]._pReference .= [[true, true, true][1:1:dims]..., true, false]
                else
                    obj2[scope_index]._pReference .= [true, false]
                end
                copyto!(obj2, obj)
                @test obj2[scope_index].a == fill(0.0, 2)
                @test obj2[scope_index]._p.a == [0.0, 0.0, 0.0, 0.0]
                @test obj2[scope_index].b == fill(2, 2)
                @test obj2[scope_index]._p.b == [2, 2, 0, 0]
                if CUDA.has_cuda()
                    obj_gpu = toBackend(obj, CUDA.CUDABackend)
                    obj2_gpu = toBackend(obj2, CUDA.CUDABackend)
                    copyto!(obj2_gpu, obj_gpu)
                    @test Array(obj2_gpu[scope_index].a) == fill(0.0, 2)
                    @test Array(obj2_gpu[scope_index]._p.a) == [0.0, 0.0, 0.0, 0.0]
                    @test Array(obj2_gpu[scope_index].b) == fill(2, 2)
                    @test Array(obj2_gpu[scope_index]._p.b) == [2, 2, 0, 0]
                end
            end
        end
    end

    @testset "UnstructuredMeshObject - broadcasting" begin
        for dims in 0:3
            for (scope, scope_index) in zip(all_scopes, all_scopes_index)
                mesh = nothing
                obj = nothing
                if scope === Node
                    mesh = UnstructuredMesh(dims; n  = Node(props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4))
                    obj2 = UnstructuredMeshObject(mesh, n = (2,4))
                elseif scope === Edge
                    mesh = UnstructuredMesh(dims; n = Node(), e  = Edge((:n,:n), props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), e = (2,4))
                    obj2 = UnstructuredMeshObject(mesh, n = (2,4), e = (2,4))
                elseif scope === Face
                    mesh = UnstructuredMesh(dims; n = Node(), f  = Face(:n, props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), f = (2,4))
                    obj2 = UnstructuredMeshObject(mesh, n = (2,4), f = (2,4))
                elseif scope === Volume
                    mesh = UnstructuredMesh(dims; n = Node(), v  = Volume(:n, props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), v = (2,4))
                    obj2 = UnstructuredMeshObject(mesh, n = (2,4), v = (2,4))
                elseif scope === Agent
                    mesh = UnstructuredMesh(dims; n = Node(), a  = Agent(props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), a = (2,4))
                    obj2 = UnstructuredMeshObject(mesh, n = (2,4), a = (2,4))
                end
                if scope == Node
                    obj[scope_index]._pReference .= [[true, true, true][1:1:dims]..., false, true]
                else
                    obj[scope_index]._pReference .= [false, true]
                end
                obj[scope_index].a .= 7.0
                obj[scope_index].b .= 2
                if scope == Node
                    obj2[scope_index]._pReference .= [[true, true, true][1:1:dims]..., false, true]
                else
                    obj2[scope_index]._pReference .= [false, true]
                end
                @. obj2 = obj * 0.1 + 3.0
                @test obj2[scope_index].a == fill(3.7, 2)
                @test obj2[scope_index]._p.a == [3.7, 3.7, 0.0, 0.0]
                @test obj2[scope_index].b == fill(0, 2)
                @test obj2[scope_index]._p.b == [0, 0, 0, 0]
                if CUDA.has_cuda()
                    obj_gpu = toBackend(obj, CUDA.CUDABackend)
                    obj2_gpu = toBackend(obj2, CUDA.CUDABackend)
                    obj2_gpu[scope_index].a .= 0.0
                    @. obj2_gpu = obj_gpu * 0.1 + 3.0
                    @test Array(obj2_gpu[scope_index].a) == fill(3.7, 2)
                    @test Array(obj2_gpu[scope_index]._p.a) == [3.7, 3.7, 0.0, 0.0]
                    @test Array(obj2_gpu[scope_index].b) == fill(0, 2)
                    @test Array(obj2_gpu[scope_index]._p.b) == [0, 0, 0, 0]
                end

                # Broadcast @..
                mesh = nothing
                obj = nothing
                if scope === Node
                    mesh = UnstructuredMesh(dims; n  = Node(props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4))
                    obj2 = UnstructuredMeshObject(mesh, n = (2,4))
                elseif scope === Edge
                    mesh = UnstructuredMesh(dims; n = Node(), e  = Edge((:n,:n), props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), e = (2,4))
                    obj2 = UnstructuredMeshObject(mesh, n = (2,4), e = (2,4))
                elseif scope === Face
                    mesh = UnstructuredMesh(dims; n = Node(), f  = Face(:n, props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), f = (2,4))
                    obj2 = UnstructuredMeshObject(mesh, n = (2,4), f = (2,4))
                elseif scope === Volume
                    mesh = UnstructuredMesh(dims; n = Node(), v  = Volume(:n, props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), v = (2,4))
                    obj2 = UnstructuredMeshObject(mesh, n = (2,4), v = (2,4))
                elseif scope === Agent
                    mesh = UnstructuredMesh(dims; n = Node(), a  = Agent(props))
                    obj = UnstructuredMeshObject(mesh, n = (2,4), a = (2,4))
                    obj2 = UnstructuredMeshObject(mesh, n = (2,4), a = (2,4))
                end
                if scope == Node
                    obj[scope_index]._pReference .= [[true, true, true][1:1:dims]..., false, true]
                else
                    obj[scope_index]._pReference .= [false, true]
                end
                obj[scope_index].a .= 7.0
                obj[scope_index].b .= 2
                if scope == Node
                    obj2[scope_index]._pReference .= [[true, true, true][1:1:dims]..., false, true]
                else
                    obj2[scope_index]._pReference .= [false, true]
                end
                DifferentialEquations.DiffEqBase.@.. obj2 = obj * 0.1 + 3.0
                @test obj2[scope_index].a == fill(3.7, 2)
                @test obj2[scope_index]._p.a == [3.7, 3.7, 0.0, 0.0]
                @test obj2[scope_index].b == fill(0, 2)
                @test obj2[scope_index]._p.b == [0, 0, 0, 0]
                if CUDA.has_cuda()
                    obj_gpu = toBackend(obj, CUDA.CUDABackend)
                    obj2_gpu = toBackend(obj2, CUDA.CUDABackend)
                    obj2_gpu[scope_index].a .= 0.0
                    DifferentialEquations.DiffEqBase.@.. obj2_gpu = obj_gpu * 0.1 + 3.0
                    @test Array(obj2_gpu[scope_index].a) == fill(3.7, 2)
                    @test Array(obj2_gpu[scope_index]._p.a) == [3.7, 3.7, 0.0, 0.0]
                    @test Array(obj2_gpu[scope_index].b) == fill(0, 2)
                    @test Array(obj2_gpu[scope_index]._p.b) == [0, 0, 0, 0]
                end
            end
        end
    end

    @testset "UnstructuredMeshObject - GPU kernels" begin
        for dims in 0:3
            for (scope, scope_index) in zip(all_scopes, all_scopes_index)            
                # Kernel works
                if CUDA.has_cuda()
                    function test_kernel_object!(x)
                        x.n
                        nothing
                    end

                    mesh = nothing
                    obj = nothing
                    if scope === Node
                        mesh = UnstructuredMesh(dims; n  = Node(props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4))
                    elseif scope === Edge
                        mesh = UnstructuredMesh(dims; n = Node(), e  = Edge((:n,:n), props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), e = (2,4))
                    elseif scope === Face
                        mesh = UnstructuredMesh(dims; n = Node(), f  = Face(:n, props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), f = (2,4))
                    elseif scope === Volume
                        mesh = UnstructuredMesh(dims; n = Node(), v  = Volume(:n, props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), v = (2,4))
                    elseif scope === Agent
                        mesh = UnstructuredMesh(dims; n = Node(), a  = Agent(props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), a = (2,4))
                    end
                    obj_gpu = toBackend(obj, CUDA.CUDABackend)

                    @test_nowarn CUDA.@cuda test_kernel_object!(obj_gpu)
                end
            end
        end
    end

    @testset "UnstructuredMeshObject - DifferentialEquations compatibility" begin
        for dims in 0:3
            for (scope, scope_index) in zip(all_scopes, all_scopes_index)
                for integratorAlg in (Euler(), RK4())#, Tsit5())

                    # DifferentialEquations.jl compatibility
                    function fODE!(du, u, p, t)
                        @. du[scope_index].a = 1
                        return
                    end
                    mesh = nothing
                    obj = nothing
                    if scope === Node
                        mesh = UnstructuredMesh(dims; n  = Node(props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4))
                    elseif scope === Edge
                        mesh = UnstructuredMesh(dims; n = Node(), e  = Edge((:n,:n), props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), e = (2,4))
                    elseif scope === Face
                        mesh = UnstructuredMesh(dims; n = Node(), f  = Face(:n, props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), f = (2,4))
                    elseif scope === Volume
                        mesh = UnstructuredMesh(dims; n = Node(), v  = Volume(:n, props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), v = (2,4))
                    elseif scope === Agent
                        mesh = UnstructuredMesh(dims; n = Node(), a  = Agent(props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), a = (2,4))
                    end
                    if scope == Node
                        obj[scope_index]._pReference .= [[true, true, true][1:1:dims]..., false, true]
                    else
                        obj[scope_index]._pReference .= [false, true]
                    end
                    prob = ODEProblem(fODE!, obj, (0.0, 1.0))
                    integrator = init(prob, integratorAlg, dt=0.1, save_everystep=false)
                    for i in 1:10
                        step!(integrator, 0.1, true)
                    end
                    @test all(integrator.u[scope_index].a .≈ 1.0)
                    if CUDA.has_cuda()
                        mesh = nothing
                        obj = nothing
                        if scope === Node
                            mesh = UnstructuredMesh(dims; n  = Node(props))
                            obj = UnstructuredMeshObject(mesh, n = (2,4))
                        elseif scope === Edge
                            mesh = UnstructuredMesh(dims; n = Node(), e  = Edge((:n,:n), props))
                            obj = UnstructuredMeshObject(mesh, n = (2,4), e = (2,4))
                        elseif scope === Face
                            mesh = UnstructuredMesh(dims; n = Node(), f  = Face(:n, props))
                            obj = UnstructuredMeshObject(mesh, n = (2,4), f = (2,4))
                        elseif scope === Volume
                            mesh = UnstructuredMesh(dims; n = Node(), v  = Volume(:n, props))
                            obj = UnstructuredMeshObject(mesh, n = (2,4), v = (2,4))
                        elseif scope === Agent
                            mesh = UnstructuredMesh(dims; n = Node(), a  = Agent(props))
                            obj = UnstructuredMeshObject(mesh, n = (2,4), a = (2,4))
                        end
                        if scope == Node
                            obj[scope_index]._pReference .= [[true, true, true][1:1:dims]..., false, true]
                        else
                            obj[scope_index]._pReference .= [false, true]
                        end
                        obj_gpu = toBackend(obj, CUDA.CUDABackend)
                        prob = ODEProblem(fODE!, obj_gpu, (0.0, 1.0))
                        integrator = init(prob, integratorAlg, dt=0.1, save_everystep=false)
                        for i in 1:10
                            step!(integrator, 0.1, true)
                        end
                        @test all(Array(integrator.u[scope_index].a) .≈ 1.0)
                    end
                end
            end
        end
    end

    @testset "UnstructuredMeshObject - neighbors" begin

        @testset "UnstructuredMeshObject - NeighborsFull" begin
            for dims in 1:3  # Skip dims=0 as neighbor algorithms require spatial coordinates
                for (scope, scope_index) in zip(all_scopes, all_scopes_index)
                    mesh = nothing
                    obj = nothing
                    if scope === Node
                        mesh = UnstructuredMesh(dims; n  = Node(props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), neighbors=NeighborsFull())
                    elseif scope === Edge
                        mesh = UnstructuredMesh(dims; n = Node(), e  = Edge((:n,:n), props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), e = (2,4), neighbors=NeighborsFull())
                    elseif scope === Face
                        mesh = UnstructuredMesh(dims; n = Node(), f  = Face(:n, props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), f = (2,4), neighbors=NeighborsFull())
                    elseif scope === Volume
                        mesh = UnstructuredMesh(dims; n = Node(), v  = Volume(:n, props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), v = (2,4), neighbors=NeighborsFull())
                    elseif scope === Agent
                        mesh = UnstructuredMesh(dims; n = Node(), a  = Agent(props))
                        obj = UnstructuredMeshObject(mesh, n = (2,4), a = (2,4), neighbors=NeighborsFull())
                    end

                    l = []
                    for i in iterateOverNeighbors(obj, scope_index, 1)
                        push!(l, i)
                    end

                    @test length(l) == 2
                
                end
            end
        end

        @testset "UnstructuredMeshObject - NeighborsCellLinked" begin
            # Cell-linked neighbors only make sense for spatial dimensions >= 1
            # 1D
            box = [0.0 1.0]
            cellSize = [0.1]
            mesh = UnstructuredMesh(1; n  = Node((nnCL=Int,nnFull=Int)))
            @addRule model=mesh function get_neighbors1D(uNew, u, p, t)
                @kernel function get_neighbors1D_kernel!(uNew, u, p, t)
                    x1 = 0.0
                    x2 = 0.0
                    i = @index(Global)

                    if i < length(u.n.x)
                        u.n.nnFull[i] = 0
                        u.n.nnCL[i] = 0
                        x1 = u.n.x[i]
                        # Full neighbors
                        for j in iterateOver(u.n)
                            i == j ? continue : nothing
                            x2 = u.n.x[j]
                            dist = sqrt((x2 - x1)^2)
                            if dist <= 0.1
                                uNew.n.nnFull[i] += 1
                            end
                        end
                        # Cell-linked neighbors
                        for j in iterateOverNeighbors(u, :n, x1)
                            i == j ? continue : nothing
                            x2 = u.n.x[j]
                            dist = sqrt((x2 - x1)^2)
                            if dist <= 0.1
                                uNew.n.nnCL[i] += 1
                            end
                        end
                    end
                end

                dev = get_backend(uNew)
                nthreads = 256
                if dev == CPU()
                    nthreads = Threads.nthreads()
                end
                get_neighbors1D_kernel!(dev, nthreads)(uNew, u, p, t, ndrange=length(u.n.x))
                KernelAbstractions.synchronize(dev)
            end
            obj = UnstructuredMeshObject(mesh, n = 10000, neighbors=NeighborsCellLinked(box=box, cellSize=cellSize))

            obj.n.x .= rand(10000)

            problem = CBProblem(mesh, obj, (0.0, 1.0))
            integrator = init(problem, dt=0.1)
            step!(integrator)

            @test all(integrator.u.n.nnCL .== integrator.u.n.nnFull)

            if CUDA.has_cuda()
                obj_gpu = toBackend(obj, CUDA.CUDABackend)
                problem_gpu = CBProblem(mesh, obj_gpu, (0.0, 1.0))
                integrator_gpu = init(problem_gpu, dt=0.1)
                step!(integrator_gpu)

                @test all(Array(integrator_gpu.u.n.nnCL) .== Array(integrator_gpu.u.n.nnFull))
            end

            # 2D
            box = [0.0 1.0; 0.0 1.0]
            cellSize = [0.1, 0.1]
            mesh = UnstructuredMesh(2; n  = Node((nnCL=Int,nnFull=Int)))
            @addRule model=mesh function get_neighbors2D(uNew, u, p, t)
                @kernel function get_neighbors2D_kernel!(uNew, u, p, t)
                    x1 = y1 = 0.0
                    x2 = y2 = 0.0
                    i = @index(Global)

                    if i < length(u.n.x)
                        u.n.nnFull[i] = 0
                        u.n.nnCL[i] = 0
                        x1 = u.n.x[i]
                        y1 = u.n.y[i]
                        # Full neighbors
                        for j in iterateOver(u.n)
                            i == j ? continue : nothing
                            x2 = u.n.x[j]
                            y2 = u.n.y[j]
                            dist = sqrt((x2 - x1)^2 + (y2 - y1)^2)
                            if dist <= 0.1
                                uNew.n.nnFull[i] += 1
                            end
                        end
                        # Cell-linked neighbors
                        for j in iterateOverNeighbors(u, :n, x1, y1)
                            i == j ? continue : nothing
                            x2 = u.n.x[j]
                            y2 = u.n.y[j]
                            dist = sqrt((x2 - x1)^2 + (y2 - y1)^2)
                            if dist <= 0.1
                                uNew.n.nnCL[i] += 1
                            end
                        end
                    end
                end

                dev = get_backend(uNew)
                nthreads = 256
                if dev == CPU()
                    nthreads = Threads.nthreads()
                end
                get_neighbors2D_kernel!(dev, nthreads)(uNew, u, p, t, ndrange=length(u.n.x))
                KernelAbstractions.synchronize(dev)
            end
            obj = UnstructuredMeshObject(mesh, n = 10000, neighbors=NeighborsCellLinked(box=box, cellSize=cellSize))

            obj.n.x .= rand(10000)
            obj.n.y .= rand(10000)

            problem = CBProblem(mesh, obj, (0.0, 1.0))
            integrator = init(problem, dt=0.1)
            step!(integrator)

            @test all(integrator.u.n.nnCL .== integrator.u.n.nnFull)

            if CUDA.has_cuda()
                obj_gpu = toBackend(obj, CUDA.CUDABackend)
                problem_gpu = CBProblem(mesh, obj_gpu, (0.0, 1.0))
                integrator_gpu = init(problem_gpu, dt=0.1)
                step!(integrator_gpu)

                @test all(Array(integrator_gpu.u.n.nnCL) .== Array(integrator_gpu.u.n.nnFull))
            end

            # 3D
            box = [0.0 1.0; 0.0 1.0; 0.0 1.0]
            cellSize = [0.1, 0.1, 0.1]
            mesh = UnstructuredMesh(3; n  = Node((nnCL=Int,nnFull=Int)))
            @addRule model=mesh function get_neighbors3D(uNew, u, p, t)
                @kernel function get_neighbors3D_kernel!(uNew, u, p, t)
                    x1 = y1 = z1 = 0.0
                    x2 = y2 = z2 = 0.0
                    i = @index(Global)

                    if i < length(u.n.x)
                        u.n.nnFull[i] = 0
                        u.n.nnCL[i] = 0
                        x1 = u.n.x[i]
                        y1 = u.n.y[i]
                        z1 = u.n.z[i]
                        # Full neighbors
                        for j in iterateOver(u.n)
                            i == j ? continue : nothing
                            x2 = u.n.x[j]
                            y2 = u.n.y[j]
                            z2 = u.n.z[j]
                            dist = sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)
                            if dist <= 0.1
                                uNew.n.nnFull[i] += 1
                            end
                        end
                        # Cell-linked neighbors
                        for j in iterateOverNeighbors(u, :n, x1, y1, z1)
                            i == j ? continue : nothing
                            x2 = u.n.x[j]
                            y2 = u.n.y[j]
                            z2 = u.n.z[j]
                            dist = sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)
                            if dist <= 0.1
                                uNew.n.nnCL[i] += 1
                            end
                        end
                    end
                end

                dev = get_backend(uNew)
                nthreads = 256
                if dev == CPU()
                    nthreads = Threads.nthreads()
                end
                get_neighbors3D_kernel!(dev, nthreads)(uNew, u, p, t, ndrange=length(u.n.x))
                KernelAbstractions.synchronize(dev)
            end
            obj = UnstructuredMeshObject(mesh, n = 10000, neighbors=NeighborsCellLinked(box=box, cellSize=cellSize))

            obj.n.x .= rand(10000)
            obj.n.y .= rand(10000)
            obj.n.z .= rand(10000)

            problem = CBProblem(mesh, obj, (0.0, 1.0))
            integrator = init(problem, dt=0.1)
            step!(integrator)

            @test all(integrator.u.n.nnCL .== integrator.u.n.nnFull)

            if CUDA.has_cuda()
                obj_gpu = toBackend(obj, CUDA.CUDABackend)
                problem_gpu = CBProblem(mesh, obj_gpu, (0.0, 1.0))
                integrator_gpu = init(problem_gpu, dt=0.1)
                step!(integrator_gpu)

                @test all(Array(integrator_gpu.u.n.nnCL) .== Array(integrator_gpu.u.n.nnFull))
            end

        end
    end

    @testset "UnstructuredMeshObject - removing elements" begin

        @testset "NeighborsFull - element removal and compaction" begin
            n = (5,10)
            mesh = UnstructuredMesh(3; n  = Node(props))
            obj = UnstructuredMeshObject(mesh, n = n, neighbors=NeighborsFull())

            # Set up data with distinct values
            obj.n.x .= rand(n[1])
            obj.n.z .= rand(n[1])
            obj.n.y .= rand(n[1])
            obj.n.a .= rand(n[1])
            obj.n.b .= Int.(round.(100*rand(n[1])))
            
            # Mark some elements for removal (elements 2 and 4 will be removed)
            obj.n._FlagsSurvived .= [i for i in rand(Bool, n[2])]
            n_survived = sum(obj.n._FlagsSurvived[1:n[1]])
            
            # Store original values for surviving elements
            surviving_a = [obj.n.a[i] for i in 1:n[1] if obj.n._FlagsSurvived[i]]
            surviving_b = [obj.n.b[i] for i in 1:n[1] if obj.n._FlagsSurvived[i]]
            
            # Perform compaction via update!
            CellBasedModels.update!(obj)
            
            # After compaction, N should be 3 (3 surviving elements)
            @test CellBasedModels.lengthProperties(obj.n) == n_survived
            
            # Check that the surviving elements have been compacted correctly
            @test obj.n.a[1:n_survived] == surviving_a
            @test obj.n.b[1:n_survived] == surviving_b
            
            # Check that flags are reset to true
            @test all(obj.n._FlagsSurvived[1:n_survived] .== true)

            if CUDA.has_cuda()

                n = (5,10)
                mesh = UnstructuredMesh(3; n  = Node(props))
                obj = UnstructuredMeshObject(mesh, n = n, neighbors=NeighborsFull())

                # Set up data with distinct values
                obj.n.x .= rand(n[1])
                obj.n.z .= rand(n[1])
                obj.n.y .= rand(n[1])
                obj.n.a .= rand(n[1])
                obj.n.b .= Int.(round.(100*rand(n[1])))
                
                # Mark some elements for removal (elements 2 and 4 will be removed)
                obj.n._FlagsSurvived .= [i for i in rand(Bool, n[2])]
                n_survived = sum(obj.n._FlagsSurvived[1:n[1]])
                
                # Store original values for surviving elements
                surviving_a = [obj.n.a[i] for i in 1:n[1] if obj.n._FlagsSurvived[i]]
                surviving_b = [obj.n.b[i] for i in 1:n[1] if obj.n._FlagsSurvived[i]]
                
                # Perform compaction via update!
                obj_gpu = toBackend(obj, CUDA.CUDABackend)
                CellBasedModels.update!(obj_gpu)
                
                # After compaction, N should be 3 (3 surviving elements)
                @test CellBasedModels.lengthProperties(obj.n) == n_survived
                
                # Check that the surviving elements have been compacted correctly
                @test Array(obj_gpu.n.a[1:n_survived]) == surviving_a
                @test Array(obj_gpu.n.b[1:n_survived]) == surviving_b
                
                # Check that flags are reset to true
                @test all(Array(obj_gpu.n._FlagsSurvived[1:n_survived]) .== true)
            end
        end

    end

    @testset "UnstructuredMeshField - preallocate!" begin
        meshProperty = Node(props)
        field = UnstructuredMeshField(meshProperty; N=3, NCache=5)
        
        # Test preallocating with additional cache
        initialNCache = field._NCache[]
        initialLength = length(field._p.a)
        
        preallocate!(field, 10)
        
        @test field._NCache[] == initialNCache + 10
        @test length(field._p.a) == initialLength + 10
        @test length(field._FlagsSurvived) == initialNCache + 10
        
        # Test that data is preserved
        field._p.a[1:3] .= [1.0, 2.0, 3.0]
        @test field._p.a[1:3] == [1.0, 2.0, 3.0]
    end

    @testset "UnstructuredMeshObject - preallocate!" begin
        for dims in 0:2  # Test a subset of dimensions
            # Test Node scope
            mesh = UnstructuredMesh(dims; n = Node(props))
            obj = UnstructuredMeshObject(mesh, n = (3, 5))
            
            # Set some initial data
            field = obj.n
            field.a[1:3] .= [1.0, 2.0, 3.0]
            initialNCache = field._NCache[]
            
            # Preallocate with per-field allocation
            preallocate!(obj, (n = 10,))
            
            # Check that only the specified field was preallocated
            @test obj.n._NCache[] == initialNCache + 10
            
            # Check that data is preserved
            @test obj.n.a[1:3] == [1.0, 2.0, 3.0]
            
            # Test Agent scope with multiple fields
            mesh2 = UnstructuredMesh(dims; n = Node(), a = Agent(props))
            obj2 = UnstructuredMeshObject(mesh2, n = (3, 5), a = (3, 5))
            
            obj2.a.a[1:3] .= [4.0, 5.0, 6.0]
            a_initialNCache = obj2.a._NCache[]
            n_initialNCache = obj2.n._NCache[]
            
            # Preallocate multiple fields
            preallocate!(obj2, (a=20, n=15))
            @test obj2.a._NCache[] == a_initialNCache + 20
            @test obj2.n._NCache[] == n_initialNCache + 15
            @test obj2.a.a[1:3] == [4.0, 5.0, 6.0]
        end
    end

    @testset "CBIntegrator - preallocate!" begin
        # Create a simple test with AgentGlobal
        model = AgentGlobal(
            (
                a = AbstractFloat,
                b = Integer
            ),
        )

        @addODE model=model function evolution!(du, u, p, t)
            @. du.g.a = -0.1 * u.g.a
        end

        # Initialize
        obj = createObject(model)
        obj.g.a .= 1.0
        obj.g.b .= 0

        problem = CBProblem(model, obj)
        integrator = init(problem, dt=0.1)
        
        # Get initial cache size
        initialNCache = integrator.u.g._NCache[]
        initialNAddedCache = length(integrator.u.g._NAdded)
        
        # Preallocate with per-field allocation
        preallocate!(integrator, (g=50,))
        
        # Check that cache was increased
        @test integrator.u.g._NCache[] == initialNCache + 50
        
        # Check that data is still valid
        @test integrator.u.g.a[1] > 0
        
        # Check that sub-integrators are still functional
        step!(integrator)
        @test integrator.t == 0.1

        if CUDA.has_cuda()
            obj_gpu = toBackend(obj, CUDA.CUDABackend)
            problem_gpu = CBProblem(model, obj_gpu)
            integrator_gpu = init(problem_gpu, dt=0.1)
            
            initialNCache_gpu = CUDA.@allowscalar integrator_gpu.u.g._NCache[1]
            
            preallocate!(integrator_gpu, (g=50,))
            
            @test CUDA.@allowscalar integrator_gpu.u.g._NCache[1] == initialNCache_gpu + 50
            
            step!(integrator_gpu)
            @test integrator_gpu.t == 0.1
        end
    end

end