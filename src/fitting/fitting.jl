module CBMFitting

    #    using CellBasedModels
    import ...CellBasedModels: Community, DataFrame, CSV
    import ...CellBasedModels: @showprogress, next!, Progress

    include("./gridSearch.jl")
    # include("./stochasticDescentAlgorithm.jl")
    include("./geneticAlgorithm.jl")
    include("./swarmAlgorithm.jl")
    include("./beeColonyAlgorithm.jl")

end