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
import MacroTools: postwalk, @capture, inexpr, prettify, gensym_ids, flatten, unblock
#using WriteVTK

export MediumFlat, δMedium_
export configurator_

#Constants
include("./constants/constants.jl")

#Agent
export @agent, Agent
export BoundaryFlat, Periodic, Bounded, Free
export PeriodicBoundaryCondition, DirichletBoundaryCondition, DirichletBoundaryCondition_NewmannBoundaryCondition, NewmannBoundaryCondition, NewmannBoundaryCondition_DirichletBoundaryCondition
include("./agent/boundary/boundaryAbstract.jl")
include("./agent/boundary/boundaryFlatStructures.jl")
include("./agent/agentStructure.jl")
include("./agent/constructAgent.jl")
include("./model/structProgram.jl") #Structure
include("./agent/boundary/boundaryFlatFunctions.jl")

#Model
export Model, compile
include("./model/model.jl")
include("./model/agentCode/basic/addParameters.jl")
include("./model/agentCode/basic/checkBounds.jl")
include("./model/agentCode/basic/cleanInteraction.jl")
include("./model/agentCode/basic/eventDeath.jl")
include("./model/agentCode/basic/eventDivision.jl")
include("./model/agentCode/basic/updateGlobal.jl")
include("./model/agentCode/basic/updateLocal.jl")
include("./model/agentCode/basic/updateLocalInteraction.jl")
include("./model/compile.jl")

#Community
export Community, CommunityInTime, saveCSV, loadCommunityFromCSV, loadCommunityInTimeFromCSV
export initialiseCommunityCompactHexagonal, initialiseCommunityCompactCubic
include("./community/community.jl")
include("./community/baseModuleExtensions.jl")
include("./community/constructors/latices/compactHexagonal.jl")
include("./community/constructors/latices/cubic.jl")
include("./community/constructors/extrude.jl")
include("./community/constructors/initialisers.jl")
include("./community/IO/save.jl")
include("./community/IO/load.jl")

#Random
include("./model/random/distribution.jl")
include("./model/random/randomAdapt.jl")

#Neighbors
include("./model/agentCode/neighbors/neighborsFull.jl")
include("./model/agentCode/neighbors/neighborsGrid.jl")
include("./model/agentCode/neighbors/neighbors.jl")

#Integrators
include("./model/agentCode/integrator/euler.jl")
include("./model/agentCode/integrator/heun.jl")
include("./model/agentCode/integrator/integrators.jl")

#Integrators Medium
include("./model/agentCode/integratorMedium/ftcs.jl")
include("./model/agentCode/integratorMedium/lax.jl")
include("./model/agentCode/integratorMedium/leapfrog.jl")
include("./model/agentCode/integratorMedium/integratorsMedium.jl")
include("./model/agentCode/basic/updateMediumInteraction.jl")

#Saving
include("./model/agentCode/saving/saveRAM.jl")
include("./model/agentCode/saving/saveCSV.jl")
include("./model/agentCode/saving/saving.jl")

#Cuda specific functions
include("./model/cuda/cudaAdapt.jl")
include("./model/cuda/cudaConfigurator.jl")

#Auxiliar function
include("./auxiliar/checkDeclared.jl")
include("./auxiliar/clean.jl")
include("./auxiliar/substitution.jl")
include("./auxiliar/vectorize.jl")
include("./auxiliar/arguments.jl")
include("./auxiliar/wrapping.jl")
include("./auxiliar/emptyquote.jl")
include("./auxiliar/symbols.jl")
include("./auxiliar/updates.jl")
include("./auxiliar/substitution2.jl")
include("./auxiliar/extract.jl")

end