module AgentBasedModels

using Random
using Distributions
using CUDA
using DataFrames
using CSV
#using WriteVTK

export Agent, @createAgent, addToAgent!, @add
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

#Auxiliar variables
include("./auxiliar/checkDeclared.jl")
include("./auxiliar/clean.jl")
include("./auxiliar/substitution.jl")
include("./auxiliar/vectorize.jl")
include("./auxiliar/arguments.jl")
include("./auxiliar/wrapping.jl")

#Cuda specific functions
include("./cuda/cudaAdapt.jl")
include("./cuda/cudaConfigurator.jl")

#Simulation Space
include("./simulationSpace/abstractTypes.jl")
include("./simulationSpace/simulationFree.jl")
include("./simulationSpace/simulationGrid.jl")

end