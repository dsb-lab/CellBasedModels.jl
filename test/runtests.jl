using CUDA
using AgentBasedModels
using Test
using DataFrames
import MacroTools: prettify
using JLD

if CUDA.has_cuda()
    TESTPLATFORMS = ["CPU","GPU"]
else
    TESTPLATFORMS = ["CPU"]
    println("CUDA was not found, only checking cpu.")
end

# testplatforms = ["gpu"]

# include("testAgent.jl")
include("testCommunity.jl")
# include("testCompile.jl")
# include("testSubstitution.jl")
# include("testAuxiliar.jl")
# include("testAgentCompiled.jl")
# include("testRandom.jl")
# include("testCommunity.jl")
# include("testUpdates.jl")
# include("testIntegrator.jl")
# include("testEvent.jl")
# include("testNeighborsFull.jl")
# include("testNeighborsGrid.jl")
# include("testSave.jl")
# include("testOptimization.jl")
# include("testMedium.jl")