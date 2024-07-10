using CUDA
using CellBasedModels
using Test
using DataFrames
import MacroTools: prettify
using OrderedCollections
using Distributions
using Random

include("testAgent.jl")
include("testCommunity.jl")
include("testFitting.jl")
