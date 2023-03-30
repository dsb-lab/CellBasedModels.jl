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

export DifferentialEquations, OrderedDict

#Constants
include("./baseStructs.jl")
include("./constants.jl")

#Custom integrators
export CustomEuler, CustomHeun, CustomRungeKutta4, CustomEM, CustomEulerHeun
include("./customIntegrators.jl")

#Platforms
export CPU, GPU
include("./platforms.jl")

#Auxiliar
export cellInMesh, euclideanDistance, manhattanDistance, new
include("./AgentStructure/functions/auxiliar.jl")

#Neighbors
export computeNeighbors!, Full, VerletTime, VerletDisplacement, CellLinked, CLVD
include("./neighbors.jl")

#Agent
export ABM
include("./AgentStructure/agentStructure.jl")
    #Rule
export agentStepRule!, modelStepRule!, mediumStepRule!, @addAgent, @removeAgent, @loopOverNeighbors, @loopOverAgents, @loopOverMedium
include("./AgentStructure/functions/functionRule.jl")
    #DE
export agentStepDE!, modelStepDE!, mediumStepDE!
include("./AgentStructure/functions/functionDE.jl")
    #Update
export update!
include("./AgentStructure/functions/update.jl")
#     #Step
# export step!, evolve!
# include("./AgentStructure/functions/step.jl")   

#Community
export Community, loadToPlatform!, bringFromPlatform!, getParameter
include("./CommunityStructure/communityStructure.jl")
export saveJLD2, saveRAM!, loadJLD2
include("./CommunityStructure/IO.jl")
# export initializeSpheresCommunity, packagingCompactHexagonal, packagingCubic
# include("./CommunityStructure/initializers.jl")

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