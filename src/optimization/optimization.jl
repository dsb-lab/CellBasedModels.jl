module Optimization

    #    using AgentBasedModels
    import ...AgentBasedModels: Model, Community, DataFrame, CSV

    include("./gridSearch.jl")
    include("./stochasticDescentAlgorithm.jl")
    include("./geneticAlgorithm.jl")
    include("./swarmAlgorithm.jl")
    include("./beeColonyAlgorithm.jl")

end