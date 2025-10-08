module CellBasedModels

    hasCuda() = false

    #Auxiliar
    # export Unit, UnitScalar, UnitArray
    # include("./auxiliar/units.jl")ç
    export Parameter
    include("./auxiliar/parameter.jl")
    include("./auxiliar/indexing.jl")

    # include("./baseStructs.jl")
    # include("./constants.jl")

    #Custom integrators
    # export CBMIntegrators
    include("./integrators/abstractTypes.jl")

    # #Random
    # export CBMDistributions
    # include("./random.jl")
    # using .CBMDistributions

    # #Distance functions
    # export CBMMetrics
    # include("./metrics.jl")
    # using .CBMMetrics

    #Platforms
    export CPU, GPU
    include("./platforms.jl")

    #Abstraact types
    include("./neighbors/abstractTypes.jl")
    include("./AgentStructure/abstractTypes.jl")
    include("./CommunityStructure/abstractTypes.jl")

    #Auxiliar
    # export cellInMesh, new
    # include("./AgentStructure/auxiliar.jl")

    #Agent
    export AgentGlobal
    include("./AgentStructure/agentGlobal.jl")
    export AgentPoint
    include("./AgentStructure/agentPoint.jl")
        #Structure
    export ABM
    include("./AgentStructure/abm.jl")
    #     #Rule
    # include("./AgentStructure/functionRule.jl")
    #     #DE
    # include("./AgentStructure/functionDE.jl")

    #Neighbors
    NEIGHBORS_ALGS = (:NeighborsFull, :NeighborsCellLinked)
    export NeighborsFull
    include("./neighbors/neighborsFull.jl")
    export NeighborsCellLinked
    include("./neighbors/neighborsCellLinked.jl")
    # export CBMNeighbors, computeNeighbors!
    # include("./neighbors.jl")
    # using .CBMNeighbors

    #Community
    export update!
    export CommunityGlobal
    include("./CommunityStructure/communityGlobal.jl")
    export CommunityABM
    include("./CommunityStructure/communityABM.jl")
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

    # #Implemented Models
    # export CBMModels
    # include("./models/models.jl")

    # module CBMUtils
    #     include("./CommunityStructure/initializers.jl")
    # end
    # #Visualization functions
    # export CBMPlots
    # include("./plotting/plotting.jl")

    module CustomFunctions

        using ..CellBasedModels
        
    end

end