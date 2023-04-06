using CUDA
using AgentBasedModels
using Test
using DataFrames
import MacroTools: prettify
using OrderedCollections
using Distributions
using Random

if CUDA.has_cuda()
    TESTPLATFORMS = ["CPU","GPU"]
else
    TESTPLATFORMS = ["CPU"]
    println("CUDA was not found, only checking cpu.")
end

include("testAgent.jl")
include("testCommunity.jl")
# include("testFitting.jl")
