module CellBasedModels

    using DataFrames: AbstractAggregate, getiterator
    # using CUDA
    # using CUDA: findfirst, atomic_add!
    using Printf
    using Base: add_with_overflow
    using Random
    using OrderedCollections
    using LinearAlgebra
    using Distributions
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
    import Accessors: @reset, @delete

    export DifferentialEquations, OrderedDict

    #AbstractTypes
    include("./abstractTypes.jl")

    #Constants
    export UNITS
    include("./constants.jl")

    include("./baseStructs.jl")
    export ValueUnits, Parameter, cartesian2DToMortonLinear, cartesian3DToMortonLinear, mortonLinearToCartesian2D, mortonLinearToCartesian3D, mortonLinear2DNeighbors, cartesian2DNeighbors, mortonLinear3DNeighbors
    include("./baseFunctions.jl")

    include("./auxiliar/indexing.jl")
    export mortonToLinear

    # #Custom integrators
    # export CBMIntegrators
    # include("./integrators.jl")
    # using .CBMIntegrators

    # #Random
    # export CBMDistributions
    # include("./random.jl")
    # using .CBMDistributions

    # #Distance functions
    # export CBMMetrics
    # include("./metrics.jl")
    # using .CBMMetrics

    # #Platforms
    # export CPU, GPU
    # include("./platforms.jl")

    # #Auxiliar
    # export cellInMesh, new
    # include("./AgentStructure/auxiliar.jl")

    # #Neighbors
    # export CBMNeighbors, computeNeighbors!
    # include("./neighbors.jl")
    # using .CBMNeighbors

    #Agent
    export AgentPoint, setAgentDimensions!, addAgentProperty!, addAgentProperties!, removeAgentProperty!, removeAgentProperties!, CommunityPoint, preallocate!, freePreallocations!, addAgent!, removeAgent!, getParameter
    include("./AgentStructure/AgentPoint.jl")
    # export ABM#, compileABM!
    #     #Macros and custom code
    # export @addAgent, @removeAgent, @loopOverNeighbors, @mediumInside, @mediumBorder, @∂, @∂2, @distanceEuclidean, @distanceManhattan
    # include("./AgentStructure/macros.jl")   
        #Structure
    # include("./AgentStructure/agentStructure.jl")
    #     #Rule
    # include("./AgentStructure/functionRule.jl")
    #     #DE
    # include("./AgentStructure/functionDE.jl")

    export CBMNeighbors
    include("./neighbors/neighbors.jl")

    # #Community
    # export Community, loadToPlatform!, bringFromPlatform!, getParameter
    # include("./CommunityStructure/communityStructure.jl")
    #     #IO
    # export saveJLD2, saveRAM!, loadJLD2
    # include("./CommunityStructure/IO.jl")
    #     #Update
    # export update!
    # include("./CommunityStructure/update.jl")
    #     #Step
    # export agentStepRule!, modelStepRule!, mediumStepRule!
    # export agentStepDE!, modelStepDE!, mediumStepDE!
    # export step!, evolve!
    # include("./CommunityStructure/step.jl")

    # #Optimization tools
    # export CBMFitting
    # include("./fitting/fitting.jl")

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