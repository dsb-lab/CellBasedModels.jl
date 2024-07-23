module CellBasedModels

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
    import MacroTools: postwalk, prewalk, @capture, inexpr, prettify, gensym, flatten, unblock, isexpr
    export prettify
    import SpecialFunctions
    using ProgressMeter
    using Test
    using DifferentialEquations
    import UUIDs: uuid1
    import Accessors: @reset

    export DifferentialEquations, OrderedDict

    #Constants
    include("./baseStructs.jl")
    include("./constants.jl")

    #Custom integrators
    export CBMIntegrators
    include("./integrators.jl")
    using .CBMIntegrators

    #Random
    export CBMDistributions
    include("./random.jl")
    using .CBMDistributions

    #Distance functions
    export CBMMetrics
    include("./metrics.jl")
    using .CBMMetrics

    #Platforms
    export CPU, GPU
    include("./platforms.jl")

    #Auxiliar
    export cellInMesh, new
    include("./AgentStructure/auxiliar.jl")

    #Neighbors
    export CBMNeighbors, computeNeighbors!
    include("./neighbors.jl")
    using .CBMNeighbors

    #Agent
    export ABM, Agent
        #Macros and custom code
    export @addAgent, @removeAgent, @loopOverNeighbors, @mediumInside, @mediumBorder, @∂, @∂2, @distanceEuclidean, @distanceManhattan
    include("./AgentStructure/macros.jl")   
        #Structure
    include("./AgentStructure/agentStructure.jl")
        #Rule
    include("./AgentStructure/functionRule.jl")
        #DE
    include("./AgentStructure/functionDE.jl")

    #Community
    export Community, loadToPlatform!, bringFromPlatform!, getParameter
    include("./CommunityStructure/communityStructure.jl")
        #IO
    export saveJLD2, saveRAM!, loadJLD2
    include("./CommunityStructure/IO.jl")
        #Update
    export update!
    include("./CommunityStructure/update.jl")
        #Step
    export agentStepRule!, modelStepRule!, mediumStepRule!
    export agentStepDE!, modelStepDE!, mediumStepDE!
    export step!, evolve!
    include("./CommunityStructure/step.jl")

    #Optimization tools
    export CBMFitting
    include("./fitting/fitting.jl")

    #Implemented Models
    # export CBMModels
    # include("./models/models.jl")

    # module CBMUtils
    #     include("./CommunityStructure/initializers.jl")
    # end
    # #Visualization functions
    # export CBMPlots
    # include("./plotting/plotting.jl")

end