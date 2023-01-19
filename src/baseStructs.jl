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

struct Platform
    threads
    blocks
end
struct BaseParameter
    dtype::Symbol
    scope::Symbol
    origin::Symbol
    reassign::Bool
    protected::Bool
    reset::Bool
    necessaryFor::Vector{Symbol}
    initialize
end
struct UserParameter
    dtype::Symbol
    scope::Symbol
    reset::Bool
    basePar::Symbol
    position::Int64
end