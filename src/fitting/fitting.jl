module Fitting

    #    using AgentBasedModels
    import ...AgentBasedModels: Model, Community, DataFrame, CSV
    import ...AgentBasedModels: @showprogress, next!, Progress

    include("./gridSearch.jl")
    # include("./stochasticDescentAlgorithm.jl")
    include("./geneticAlgorithm.jl")
    include("./swarmAlgorithm.jl")
    include("./beeColonyAlgorithm.jl")

end