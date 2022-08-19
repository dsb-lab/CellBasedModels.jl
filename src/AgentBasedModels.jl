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
include("./AgentStructures/Agent/agentStructure.jl")
include("./AgentStructures/Agent/checkDeclared.jl")
include("./AgentStructures/Agent/constructAgent.jl")
include("./AgentStructures/Agent/updates.jl")
    #Neighbors
export NeighborsFull
include("./AgentStructures/Agent/neighbors/neighborsFull.jl")
# include("./AgentStructures/Agent/neighbors/neighborsGrid.jl")
include("./AgentStructures/Agent/neighbors/neighbors.jl")
    #Integrators
export Euler
include("./AgentStructures/Agent/integrator/integrators.jl")
include("./AgentStructures/Agent/integrator/euler.jl")
# include("./AgentStructures/AgentCompiled/integrator/heun.jl")
# include("./AgentStructures/AgentCompiled/integrator/rungeKutta4.jl")
# include("./AgentStructures/AgentCompiled/integrator/implicitEuler.jl")
# include("./AgentStructures/AgentCompiled/integrator/verletVelocity.jl")

#CompiledAgent
    #Base
export Model, AgentCompiled, compile
include("./AgentStructures/AgentCompiled/agentCompiled.jl")
include("./AgentStructures/AgentCompiled/base/addMediumCode.jl")
include("./AgentStructures/AgentCompiled/base/addParameters.jl")
include("./AgentStructures/AgentCompiled/base/cudaAdapt.jl")
include("./AgentStructures/AgentCompiled/base/eventAddAgent.jl")
include("./AgentStructures/AgentCompiled/base/eventRemoveAgent.jl")
include("./AgentStructures/AgentCompiled/base/randomAdapt.jl")
include("./AgentStructures/AgentCompiled/base/vectorize.jl")
include("./AgentStructures/AgentCompiled/base/wrapping.jl")
include("./AgentStructures/AgentCompiled/base/createFunction.jl")
    #Updates
include("./AgentStructures/AgentCompiled/updates/updateGlobal.jl")
include("./AgentStructures/AgentCompiled/updates/updateInteraction.jl")
include("./AgentStructures/AgentCompiled/updates/updateLocal.jl")
include("./AgentStructures/AgentCompiled/updates/updateMediumBoundaries.jl")
include("./AgentStructures/AgentCompiled/updates/updateMediumInteraction.jl")
    #Integrators Medium
include("./AgentStructures/AgentCompiled/medium/integratorMedium/ftcs.jl")
include("./AgentStructures/AgentCompiled/medium/integratorMedium/lax.jl")
include("./AgentStructures/AgentCompiled/medium/integratorMedium/implicitEuler.jl")
include("./AgentStructures/AgentCompiled/medium/integratorMedium/integratorsMedium.jl")
include("./AgentStructures/AgentCompiled/medium/medium.jl")
    #Saving
include("./AgentStructures/AgentCompiled/saving/saveRAM.jl")
include("./AgentStructures/AgentCompiled/saving/saveCSV.jl")
include("./AgentStructures/AgentCompiled/saving/saveJLD.jl")
include("./AgentStructures/AgentCompiled/saving/saving.jl")

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