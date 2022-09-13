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
#using WriteVTK

export MediumFlat, δMedium_
export configurator_

#Constants
include("./constants.jl")
include("./baseStructs.jl")

#Agent
export @agent, Agent
include("./AgentStructure/agentStructure.jl")
include("./AgentStructure/checkDeclared.jl")
include("./AgentStructure/constructAgent.jl")
include("./AgentStructure/updates.jl")
    #Neighbors
export NeighborsFull, NeighborsCell
include("./AgentStructure/neighbors/neighborsFull.jl")
include("./AgentStructure/neighbors/neighborsCell.jl")
include("./AgentStructure/neighbors/neighbors.jl")
    #Integrators
export Euler
include("./AgentStructure/integrator/integrators.jl")
include("./AgentStructure/integrator/euler.jl")
# include("./AgentStructure/AgentCompiled/integrator/heun.jl")
# include("./AgentStructure/AgentCompiled/integrator/rungeKutta4.jl")
# include("./AgentStructure/AgentCompiled/integrator/implicitEuler.jl")
# include("./AgentStructure/AgentCompiled/integrator/verletVelocity.jl")

#CompiledAgent
    #Base
export Model, AgentCompiled, compile
include("./AgentStructure/AgentCompiled/agentCompiled.jl")
include("./AgentStructure/AgentCompiled/base/addMediumCode.jl")
include("./AgentStructure/AgentCompiled/base/addParameters.jl")
include("./AgentStructure/AgentCompiled/base/cudaAdapt.jl")
include("./AgentStructure/AgentCompiled/base/eventAddAgent.jl")
include("./AgentStructure/AgentCompiled/base/eventRemoveAgent.jl")
include("./AgentStructure/AgentCompiled/base/randomAdapt.jl")
include("./AgentStructure/AgentCompiled/base/vectorize.jl")
include("./AgentStructure/AgentCompiled/base/wrapping.jl")
include("./AgentStructure/AgentCompiled/base/createFunction.jl")
    #Updates
include("./AgentStructure/AgentCompiled/updates/updateGlobal.jl")
include("./AgentStructure/AgentCompiled/updates/updateInteraction.jl")
include("./AgentStructure/AgentCompiled/updates/updateLocal.jl")
include("./AgentStructure/AgentCompiled/updates/updateMediumBoundaries.jl")
include("./AgentStructure/AgentCompiled/updates/updateMediumInteraction.jl")
    #Integrators Medium
include("./AgentStructure/AgentCompiled/medium/integratorMedium/ftcs.jl")
include("./AgentStructure/AgentCompiled/medium/integratorMedium/lax.jl")
include("./AgentStructure/AgentCompiled/medium/integratorMedium/implicitEuler.jl")
include("./AgentStructure/AgentCompiled/medium/integratorMedium/integratorsMedium.jl")
include("./AgentStructure/AgentCompiled/medium/medium.jl")
    #Saving
include("./AgentStructure/AgentCompiled/saving/saveRAM.jl")
include("./AgentStructure/AgentCompiled/saving/saveCSV.jl")
include("./AgentStructure/AgentCompiled/saving/saveJLD.jl")
include("./AgentStructure/AgentCompiled/saving/saving.jl")

#Community
export setParameters!
export Community, CommunityInTime, saveCSV, loadCommunityFromCSV, loadCommunityInTimeFromCSV, loadCommunityInTimeFromJLD
export initialiseCommunityCompactHexagonal, initialiseCommunityCompactCubic
include("./CommunityStructures/community.jl")
include("./CommunityStructures/baseModuleExtensions.jl")
include("./CommunityStructures/setParameters.jl")
include("./CommunityStructures/constructors/latices/compactHexagonal.jl")
include("./CommunityStructures/constructors/latices/cubic.jl")
include("./CommunityStructures/constructors/extrude.jl")
include("./CommunityStructures/constructors/initialisers.jl")
include("./CommunityStructures/IO/save.jl")
include("./CommunityStructures/IO/load.jl")

# #Visualization functions
export plotSpheres, plotRods, videoRods
include("./plotting/rods.jl")
# include("./plotting/spheres.jl")

#Cuda
include("./cuda/cudaConfigurator.jl")

#Implemented Models
# include("./implementedModels/models.jl")

#Optimization tools
include("./optimization/optimization.jl")

end