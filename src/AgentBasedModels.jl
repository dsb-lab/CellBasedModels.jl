module AgentBasedModels

using Random
using Distributions
using CUDA
using DataFrames
using CSV
#using WriteVTK

export Model
export @agent, agent!, @add
export NeighborsFull, NeighborsGrid

#Constants
include("./constants/abstractStructures.jl")
include("./constants/constants.jl")

#Model
include("./agent/model.jl")

#Auxiliar variables
include("./auxiliar/checkDeclared.jl")
include("./auxiliar/clean.jl")
include("./auxiliar/substitution.jl")
include("./auxiliar/vectorize.jl")
include("./auxiliar/arguments.jl")

#Agent
include("./model/agent.jl")

#Neighbours
include("./neighborhoods/neighbors.jl")
include("./neighborhoods/neighborsFull.jl")
include("./neighborhoods/neighborsGrid2.jl")

end