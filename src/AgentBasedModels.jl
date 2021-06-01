module AgentBasedModels

using Random
using Distributions
using CUDA
using DataFrames
using CSV
#using WriteVTK

export Model
export @agent, agent!, @add
export clean, checkDeclared

#Constants
include("./constants/abstractStructures.jl")
include("./constants/constants.jl")

#Model 
include("./model/model.jl")

#Auxiliar variables
include("./auxiliar/checkDeclared.jl")
include("./auxiliar/clean.jl")

#Agent
include("./model/agent.jl")

end