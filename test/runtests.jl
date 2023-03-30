using CUDA
using AgentBasedModels
using Test
using DataFrames
import MacroTools: prettify
using OrderedCollections

if CUDA.has_cuda()
    TESTPLATFORMS = ["CPU","GPU"]
else
    TESTPLATFORMS = ["CPU"]
    println("CUDA was not found, only checking cpu.")
end

# testplatforms = ["gpu"]

include("testAgent.jl")
# include("testCommunity.jl")
# include("testOptimization.jl")
# include("testModels.jl")
# include("testMedium.jl")

# include("testGPU.jl")
