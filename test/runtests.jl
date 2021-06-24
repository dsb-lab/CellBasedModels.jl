using CUDA
using AgentBasedModels
using Test
using Distributions
using CUDA
using DataFrames
using MacroTools

if CUDA.has_cuda()
    testplatforms = ["cpu","gpu"]
else
    testplatforms = ["cpu"]
end

include("testAgent.jl")
include("testAuxiliar.jl")
include("testModel.jl")
include("testRandom.jl")
include("testCommunity.jl")
include("testUpdates.jl")
include("testIntegrator.jl")
include("testEvent.jl")
include("testSimulationSpace.jl")
include("testBound.jl")

