using CUDA
using AgentBasedModels
using Test
using Distributions
using CUDA
using DataFrames
import MacroTools: prettify
using PyPlot

if CUDA.has_cuda()
    testplatforms = ["cpu","gpu"]
else
    testplatforms = ["cpu"]
    println("CUDA was not found, only checking cpu.")
end

# include("testAgent.jl")
# include("testSubstitution.jl")
# include("testAuxiliar.jl")
# include("testModel.jl")
# include("testRandom.jl")
# include("testCommunity.jl")
# include("testUpdates.jl")
# include("testIntegrator.jl")
# include("testEvent.jl")
# include("testSimulationSpace.jl")
# include("testBound.jl")
# include("testSave.jl")
include("testMedium.jl")
# include("testConstructors.jl")

