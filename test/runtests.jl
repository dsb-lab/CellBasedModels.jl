using CUDA
using AgentBasedModels
using Test
using Distributions
using CUDA
using DataFrames
using MacroTools

#include("testAgent.jl")
#include("testAuxiliar.jl")
#include("testSimulation.jl")
#include("testRandom.jl")
#include("testModel.jl")
#include("testCommunity.jl")
#include("testUpdates.jl")
#include("testIntegrator.jl")
include("testEvent.jl")

