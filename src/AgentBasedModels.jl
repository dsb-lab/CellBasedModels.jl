module AgentBasedModels

using DataFrames: AbstractAggregate, getiterator
using CUDA: findfirst, atomic_add!
using Base: add_with_overflow
using Random
using OrderedCollections
using LinearAlgebra
using Distributions
using CUDA
using DataFrames
using CSV
using JLD2
# import GeometryBasics, GLMakie
import MacroTools: postwalk, prewalk, @capture, inexpr, prettify, gensym, flatten, unblock, isexpr
export prettify
import SpecialFunctions
using ProgressMeter
using Test
using DifferentialEquations

export DifferentialEquations

#Constants
include("./baseStructs.jl")
include("./constants.jl")
export euclideanDistance, manhattanDistance, new
include("./AgentStructure/functions/auxiliar.jl")

#Agent
export ABM
include("./AgentStructure/agentStructure.jl")
    #Agent Rule
export agentStepRule!, @addAgent, @removeAgent, @loopOverNeighbors
include("./AgentStructure/functions/agentRule.jl")
    #Agent DE
export agentStepDE!
include("./AgentStructure/functions/agentDE.jl")
    #Medium DE
export mediumStepDE!
include("./AgentStructure/functions/mediumDE.jl")
#     #Global
# export globalStep!
# include("./AgentStructure/functions/global.jl")
    #Neighbors
export computeNeighbors!
include("./AgentStructure/functions/neighbors.jl")
    #Update
export update!
include("./AgentStructure/functions/update.jl")
#     #Step
# export step!, evolve!
# include("./AgentStructure/functions/step.jl")

#Community
export Community, loadToPlatform!, bringFromPlatform!, getParameter
include("./CommunityStructure/communityStructure.jl")
# export saveJLD2, saveRAM!, loadJLD2
# include("./CommunityStructure/IO.jl")
# export initializeSpheresCommunity, packagingCompactHexagonal, packagingCubic
# include("./CommunityStructure/initializers.jl")

#Custom integrators
include("./customIntegrators.jl")

# #Optimization tools
# export Fitting
# include("./fitting/fitting.jl")

#Implemented Models
# export Models
# include("./implementedModels/models.jl")

# #Visualization functions
# export plotSpheres, plotRods, videoRods
# include("./plotting/rods.jl")
# include("./plotting/spheres.jl")

end