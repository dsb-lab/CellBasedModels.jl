struct Neighbors
    additionArguments::DataFrame
    loopFunction::Function
    neighborsCompute::Function
end

struct Integrator
    steps
    args
    createFunction
end