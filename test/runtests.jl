# using CUDA
using CellBasedModels
using Test
using CUDA   
using BenchmarkTools
using KernelAbstractions
using Printf

verbose = true
benchmark = true #just for internal optimizations

devices = CUDA.has_cuda() ? [CPU, CUDA.CUDABackend] : [CPU]

@testset verbose=true "CellBasedModels.jl" begin
    # include("testIndexing.jl")
    # include("testParameter.jl")
    # include("testDiffSym.jl")
    # include("testDiffAuto.jl")
    # include("testDebugAutodif.jl")
    include("testTopologyAuxiliar.jl")

    # include("testUnstructuredMesh.jl")
    # include("testUnstructuredMeshSCE.jl")
    # include("testStructuredMesh.jl")
    # include("testMultiMesh.jl")
    # include("testAddFunctions.jl")

    # include("testAgentGlobal.jl")
    # include("testAgentPoint.jl")
end

if benchmark

    # include("test.jl")
    # include("debug_periodic.jl")

    N = 100000
    n = 10000

    # include("benchmarkCommunityIndices.jl")
    # include("benchmarkRecursiveCachedArrays.jl")
    # include("benchmarkCommunityPoint.jl")
    # include("benchmarkPointGPUIterator.jl")

end