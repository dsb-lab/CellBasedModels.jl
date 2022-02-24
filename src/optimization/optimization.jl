module Optimization

    #    using AgentBasedModels
    import ...AgentBasedModels: Model, Community, DataFrame

    include("./gridSearch.jl")
    include("./stochasticDescent.jl")
    include("./geneticAlgorithm.jl")
    
end