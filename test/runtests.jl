using CUDA
using AgentBasedModels
using Test
using Distributions
using CUDA
using DataFrames
using MacroTools

#include("testAgent.jl")
#include("testAuxiliar.jl")
#include("testSimulationFree.jl")
include("testSimulationGrid.jl")
#include("testRandom.jl")
#include("testModel.jl")

