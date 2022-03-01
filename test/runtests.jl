using CUDA
using AgentBasedModels
using Test
using DataFrames
import MacroTools: prettify
using JLD

if CUDA.has_cuda()
    testplatforms = ["cpu","gpu"]
else
    testplatforms = ["cpu"]
    println("CUDA was not found, only checking cpu.")
end

testplatforms = ["cpu"]

# include("testAgent.jl")
# include("testSubstitution.jl")
# include("testAuxiliar.jl")
# include("testModel.jl")
# include("testRandom.jl")
# include("testCommunity.jl")
# include("testUpdates.jl")
# include("testIntegrator.jl")
# include("testEvent.jl")
# include("testNeighbors.jl")
# include("testSave.jl")
# include("testOptimization.jl")

include("testMedium.jl")

