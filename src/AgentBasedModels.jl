module AgentBasedModels

using DataFrames: AbstractAggregate
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

export Agent, @agent, add
export Model, compile
export Community, CommunityInTime
export SimulationFree, SimulationGrid
export SimulationSpace, FlatBoundary, Periodic, NonPeriodic, Bound
export configurator_
export compactHexagonal

#Constants
include("./constants/constants.jl")

#Agent
include("./agent/agentStructure.jl")
include("./agent/constructAgent.jl")

#Model
include("./model/structProgram.jl")

#Simulation Space
include("./simulationSpace/abstractTypes.jl")
include("./simulationSpace/simulationFree.jl")
include("./simulationSpace/simulationGrid.jl")

#Model
include("./model/model.jl")
include("./model/agentCode.jl")
include("./model/compile.jl")

#Community
include("./community/community.jl")
include("./community/baseModuleExtensions.jl")
include("./community/constructors/latices/hexagonal.jl")

#Random
include("./model//random/distribution.jl")
include("./model//random/randomAdapt.jl")

#Integrators
include("./model/integrator/euler.jl")
include("./model/integrator/heun.jl")
include("./model/integrator/integrators.jl")

#Saving
include("./model/saving/saveRAM.jl")
#include("./model/saving/saveCSV.jl")
include("./model/saving/saving.jl")

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

#Cuda specific functions
include("./cuda/cudaAdapt.jl")
include("./cuda/cudaConfigurator.jl")

end