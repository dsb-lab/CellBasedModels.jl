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
#using WriteVTK

export MediumFlat, δMedium_
export configurator_

#Constants
include("./constants.jl")

#Agent
export @agent, Agent
include("./agent/agentStructure.jl")
include("./agent/constructAgent.jl")
include("./agentCompiled/structProgram.jl") #Structure

#Model
export Model, compile
include("./agentCompiled/agentCompiled.jl")
include("./agentCompiled/agentCode/basic/addParameters.jl")
include("./agentCompiled/agentCode/basic/eventRemoveAgent.jl")
include("./agentCompiled/agentCode/basic/eventAddAgent.jl")
include("./agentCompiled/agentCode/basic/updateGlobal.jl")
include("./agentCompiled/agentCode/basic/updateLocal.jl")
include("./agentCompiled/agentCode/basic/updateInteraction.jl")
include("./agentCompiled/compile.jl")
#Neighbors
include("./agentCompiled/agentCode/neighbors/neighborsFull.jl")
include("./agentCompiled/agentCode/neighbors/neighborsGrid.jl")
include("./agentCompiled/agentCode/neighbors/neighbors.jl")
#Integrators
include("./agentCompiled/agentCode/integrator/euler.jl")
include("./agentCompiled/agentCode/integrator/heun.jl")
include("./agentCompiled/agentCode/integrator/rungeKutta4.jl")
include("./agentCompiled/agentCode/integrator/implicitEuler.jl")
include("./agentCompiled/agentCode/integrator/verletVelocity.jl")
include("./agentCompiled/agentCode/integrator/integrators.jl")
#Integrators Medium
include("./agentCompiled/agentCode/basic/updateMediumBoundaries.jl")
include("./agentCompiled/agentCode/integratorMedium/ftcs.jl")
include("./agentCompiled/agentCode/integratorMedium/lax.jl")
include("./agentCompiled/agentCode/integratorMedium/implicitEuler.jl")
include("./agentCompiled/agentCode/integratorMedium/integratorsMedium.jl")
include("./agentCompiled/agentCode/basic/updateMediumInteraction.jl")
#Saving
include("./agentCompiled/agentCode/saving/saveRAM.jl")
include("./agentCompiled/agentCode/saving/saveCSV.jl")
include("./agentCompiled/agentCode/saving/saveJLD.jl")
include("./agentCompiled/agentCode/saving/saving.jl")

#Random
include("./distributions/distribution.jl")

#Community
export Community, CommunityInTime, saveCSV, loadCommunityFromCSV, loadCommunityInTimeFromCSV, loadCommunityInTimeFromJLD
export initialiseCommunityCompactHexagonal, initialiseCommunityCompactCubic
include("./community/community.jl")
include("./community/baseModuleExtensions.jl")
include("./community/constructors/latices/compactHexagonal.jl")
include("./community/constructors/latices/cubic.jl")
include("./community/constructors/extrude.jl")
include("./community/constructors/initialisers.jl")
include("./community/IO/save.jl")
include("./community/IO/load.jl")

# #Visualization functions
export plotSpheres, plotRods, videoRods
include("./plotting/rods.jl")
# include("./plotting/spheres.jl")

#Auxiliar function
include("./auxiliar/checkDeclared.jl")
include("./auxiliar/vectorize.jl")
include("./auxiliar/wrapping.jl")
include("./auxiliar/updates.jl")
include("./auxiliar/addMediumCode.jl")
include("./auxiliar/cudaAdapt.jl")
include("./auxiliar/cudaConfigurator.jl")
include("./auxiliar/randomAdapt.jl")

#Implemented Models
include("./implementedModels/models.jl")

#Optimization tools
include("./optimization/optimization.jl")

end