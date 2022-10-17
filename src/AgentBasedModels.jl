module AgentBasedModels

using DataFrames: AbstractAggregate, getiterator
using CUDA: findfirst, atomic_add!
using Base: add_with_overflow
using Random
using LinearAlgebra
using Distributions
using CUDA
using DataFrames
using CSV
using JLD
import GeometryBasics, GLMakie
import MacroTools: postwalk, prewalk, @capture, inexpr, prettify, gensym, flatten, unblock, isexpr
import SpecialFunctions
using ProgressMeter
using Test
#using WriteVTK

#Constants
include("./constants.jl")
include("./baseStructs.jl")

#Agent
export Agent
include("./AgentStructure/agentStructure.jl")
    #Neighbors
export computeNeighbors!
include("./AgentStructure/functions/neighbors.jl")
# include("./AgentStructure/neighbors/neighborsCell.jl")
# include("./AgentStructure/neighbors/neighbors.jl")
#     #Integrators
export Euler
include("./AgentStructure/compile/integrator/integrators.jl")
include("./AgentStructure/compile/integrator/euler.jl")
# include("./AgentStructure/compile/integrator/heun.jl")
# include("./AgentStructure/compile/integrator/rungeKutta4.jl")
# include("./AgentStructure/compile/integrator/implicitEuler.jl")
# include("./AgentStructure/compile/integrator/verletVelocity.jl")

#CompiledAgent
    #Base
# include("./AgentStructure/compile/addMediumCode.jl")
# include("./AgentStructure/compile/addParameters.jl")
# include("./AgentStructure/compile/cudaAdapt.jl")
# include("./AgentStructure/compile/eventAddAgent.jl")
# include("./AgentStructure/compile/eventRemoveAgent.jl")
# include("./AgentStructure/compile/randomAdapt.jl")
# include("./AgentStructure/compile/vectorize.jl")
# include("./AgentStructure/compile/wrapping.jl")
# include("./AgentStructure/compile/createFunction.jl")
    #Updates
# include("./AgentStructure/compile/updates/updateGlobal.jl")
# include("./AgentStructure/compile/updates/updateInteraction.jl")
# include("./AgentStructure/compile/updates/updateLocal.jl")
# include("./AgentStructure/compile/updates/updateMediumBoundaries.jl")
# include("./AgentStructure/compile/updates/updateMediumInteraction.jl")
    #Integrators Medium
# include("./AgentStructure/compile/medium/integratorMedium/ftcs.jl")
# include("./AgentStructure/compile/medium/integratorMedium/lax.jl")
# include("./AgentStructure/compile/medium/integratorMedium/implicitEuler.jl")
# include("./AgentStructure/compile/medium/integratorMedium/integratorsMedium.jl")
# include("./AgentStructure/compile/medium/medium.jl")
    #Saving
# include("./AgentStructure/compile/saving/saveRAM.jl")
# include("./AgentStructure/compile/saving/saveCSV.jl")
# include("./AgentStructure/compile/saving/saveJLD.jl")
# include("./AgentStructure/compile/saving/saving.jl")

#Community
# export setParameters!
export Community, loadToPlatform!
# export Community, CommunityInTime, saveCSV, loadCommunityFromCSV, loadCommunityInTimeFromCSV, loadCommunityInTimeFromJLD
# export initialiseCommunityCompactHexagonal, initialiseCommunityCompactCubic
include("./CommunityStructure/communityStructure.jl")
# include("./CommunityStructure/baseModuleExtensions.jl")
# include("./CommunityStructure/setParameters.jl")
# include("./CommunityStructure/constructors/latices/compactHexagonal.jl")
# include("./CommunityStructure/constructors/latices/cubic.jl")
# include("./CommunityStructure/constructors/extrude.jl")
# include("./CommunityStructure/constructors/initialisers.jl")
# include("./CommunityStructure/IO/save.jl")
# include("./CommunityStructure/IO/load.jl")

# #Visualization functions
# export plotSpheres, plotRods, videoRods
# include("./plotting/rods.jl")
# include("./plotting/spheres.jl")

#Cuda
# include("./cuda/cudaConfigurator.jl")

#Implemented Models
# include("./implementedModels/models.jl")

#Optimization tools
# include("./optimization/optimization.jl")

end