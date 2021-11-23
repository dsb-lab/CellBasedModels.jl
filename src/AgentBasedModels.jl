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

export Model, compile
export Community, CommunityInTime, saveCSV, loadCommunityFromCSV, loadCommunityInTimeFromCSV
export MediumFlat, δMedium_
export configurator_
export extrude
export compactHexagonal

#Constants
include("./constants/constants.jl")
include("./constants/abstractTypes.jl")

#Agent
include("./agent/boundary/boundaryAbstract.jl")
include("./agent/boundary/boundaryFlatStructures.jl")
include("./agent/agentStructure.jl")
include("./agent/constructAgent.jl")
include("./model/structProgram.jl") #Structure
include("./agent/boundary/boundaryFlatFunctions.jl")

#Model
include("./model/model.jl")
include("./model/agentCode/addParameters.jl")
include("./model/agentCode/checkBounds.jl")
include("./model/agentCode/cleanInteraction.jl")
include("./model/agentCode/eventDeath.jl")
include("./model/agentCode/eventDivision.jl")
include("./model/agentCode/updateGlobal.jl")
include("./model/agentCode/updateLocal.jl")
include("./model/agentCode/updateLocalInteraction.jl")
include("./model/compile.jl")

#Community
include("./community/community.jl")
include("./community/baseModuleExtensions.jl")
include("./community/constructors/latices/hexagonal.jl")
include("./community/constructors/extrude.jl")
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
include("./model/agentCode/updateMediumInteraction.jl")

#Saving
include("./model/agentCode/saving/saveRAM.jl")
include("./model/agentCode/saving/saveCSV.jl")
include("./model/agentCode/saving/saving.jl")

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

#Cuda specific functions
include("./cuda/cudaAdapt.jl")
include("./cuda/cudaConfigurator.jl")

end