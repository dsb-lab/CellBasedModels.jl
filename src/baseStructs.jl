struct Neighbors
    additionArguments::DataFrame
    loopFunction::Function
    neighborsCompute::Function
end

mutable struct Platform
    threads::Int
    blocks::Int
end
struct BaseParameter
    dtype::Symbol
    shape::Tuple
    origin::Symbol
    reassign::Bool
    protected::Bool
    reset::Bool
    necessaryFor::Vector{Symbol}
    initialize
end

struct BaseSymbol
    symbol::Symbol
    type::Symbol
end
mutable struct UserParameter
    dtype::Symbol
    scope::Symbol
    reset::Bool
    basePar::Symbol
    position::Int64
end

mutable struct Equation
    position::Int
    deterministic::Union{Expr,Symbol}
    stochastic::Union{Expr,Symbol}
end

struct Integrator
    length
    dt
    dW
    weight
    finalWeights
end