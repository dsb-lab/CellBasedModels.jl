module AgentBasedModels

using Random
using Distributions
using CUDA
using DataFrames
using CSV
using MacroTools
#using WriteVTK

export Agent, @agent, add
export Model, compile
export Community
export SimulationFree, SimulationGrid
export SimulationSpace, FlatBoundary, Periodic, NonPeriodic, Open, Hard, Reflecting, OpenReflecting, ReflectingOpen, OpenHard, HardOpen, HardReflecting, ReflectingHard
export configurator_

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

#Community
include("./community/community.jl")

#Model
include("./model/model.jl")
include("./model/agentCode.jl")
include("./model/compile.jl")

#Random
include("./random/distribution.jl")
include("./random/randomAdapt.jl")

#Auxiliar function
include("./auxiliar/checkDeclared.jl")
include("./auxiliar/clean.jl")
include("./auxiliar/substitution.jl")
include("./auxiliar/vectorize.jl")
include("./auxiliar/arguments.jl")
include("./auxiliar/wrapping.jl")
include("./auxiliar/emptyquote.jl")
include("./auxiliar/symbols.jl")

#Cuda specific functions
include("./cuda/cudaAdapt.jl")
include("./cuda/cudaConfigurator.jl")

end