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

#Constants
include("./baseStructs.jl")
include("./constants.jl")
export euclideanDistance, manhattanDistance
include("./AgentStructure/functions/auxiliar.jl")

#Agent
export Agent
include("./AgentStructure/agentStructure.jl")
#     #Local
export localStep!
include("./AgentStructure/functions/local.jl")
#     #Global
export globalStep!
include("./AgentStructure/functions/global.jl")
#     #Neighbors
export computeNeighbors!
include("./AgentStructure/functions/neighbors.jl")
#     #Local interactions
export interactionStep!
include("./AgentStructure/functions/interactions.jl")
    #Local update
export update!
include("./AgentStructure/functions/update.jl")
    #Integrators
export integrationStep!
include("./AgentStructure/functions/integrators.jl")
    #Medium
export integrationMediumStep!
include("./AgentStructure/functions/medium.jl")
    #Step
export step!, evolve!
include("./AgentStructure/functions/step.jl")
# include("./AgentStructure/compile/integrator/implicitEuler.jl")
# include("./AgentStructure/compile/integrator/verletVelocity.jl")

#Community
export Community, loadToPlatform!, bringFromPlatform!, getParameter
include("./CommunityStructure/communityStructure.jl")
export saveJLD2, saveRAM!, loadJLD2
include("./CommunityStructure/IO.jl")
export initializeSpheresCommunity, packagingCompactHexagonal, packagingCubic
include("./CommunityStructure/initializers.jl")

#Optimization tools
export Fitting
include("./fitting/fitting.jl")

#Implemented Models
export Models
include("./implementedModels/models.jl")

# #Visualization functions
# export plotSpheres, plotRods, videoRods
# include("./plotting/rods.jl")
# include("./plotting/spheres.jl")

end