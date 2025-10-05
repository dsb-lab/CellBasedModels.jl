module CellBasedModels

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

    #Auxiliar
    # export cellInMesh, new
    # include("./AgentStructure/auxiliar.jl")

    #Neighbors
    include("./neighbors/abstractTypes.jl")
    # export CBMNeighbors, computeNeighbors!
    # include("./neighbors.jl")
    # using .CBMNeighbors

    #Agent
    include("./AgentStructure/abstractTypes.jl")
        #Point
    # export AgentPoint
    # include("./AgentStructure/agentPoint.jl")
        #Structure
    # export ABM, compileABM!
    # include("./AgentStructure/abm.jl")
    #     #Rule
    # include("./AgentStructure/functionRule.jl")
    #     #DE
    # include("./AgentStructure/functionDE.jl")

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

    # #Implemented Models
    # export CBMModels
    # include("./models/models.jl")

    # module CBMUtils
    #     include("./CommunityStructure/initializers.jl")
    # end
    # #Visualization functions
    # export CBMPlots
    # include("./plotting/plotting.jl")

end