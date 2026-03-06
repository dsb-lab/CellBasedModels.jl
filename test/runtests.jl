# using CUDA
using CellBasedModels
using Test
using CUDA   
using BenchmarkTools
using KernelAbstractions
using Printf
using Adapt
using DifferentialEquations
using Atomix

verbose = true
benchmark = true #just for internal optimizations

backends = CUDA.has_cuda() ? [CPU(), CUDA.CUDABackend()] : [CPU()]

@testset verbose=true "CellBasedModels.jl" begin
    # include("testIndexing.jl")
    # include("testParameter.jl")
    # include("testDiffSym.jl")
    # include("testDiffAuto.jl")
    include("testDynamicalCOO.jl")
    include("testDynamicalCSR.jl")
    include("testDynamicalELL.jl")
    include("testDynamicalOrderedCOO.jl")
    include("testDynamicalOrderedCSR.jl")
    include("testDynamicalOrderedELL.jl")
    include("testTopology.jl")
    # include("testTopologyAuxiliar.jl")

    # include("testUnstructuredMesh.jl")
    # include("testStructuredMesh.jl")
    # include("testMultiMesh.jl")
    # include("testAddFunctions.jl")

    # include("testNeighbors.jl")
    # include("testCustomIntegrators.jl")

    # include("testAgentGlobal.jl")
    # include("testAgentPoint.jl")

    # include("test.jl")
end

if benchmark

    # include("test.jl")
    # include("debug_periodic.jl")

    N = 100000
    n = 10000

    # include("benchmarkNeighborsAlgorithms.jl")

    # include("benchmarkCommunityIndices.jl")
    # include("benchmarkRecursiveCachedArrays.jl")
    # include("benchmarkCommunityPoint.jl")
    # include("benchmarkPointGPUIterator.jl")

end