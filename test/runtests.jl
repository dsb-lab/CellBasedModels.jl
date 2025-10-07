# using CUDA
using CellBasedModels
using Test
using DataFrames
import MacroTools: prettify
using OrderedCollections
using Distributions
using Random

verbose = true

@testset verbose=true "CellBasedModels.jl" begin
    include("testIndexing.jl")
    include("testParameter.jl")
    include("testAgentGlobal.jl")
    include("testABM.jl")
end

# include("testUnits.jl")
# include("testAgent.jl")
# include("testCommunity.jl")
# include("testFitting.jl")
