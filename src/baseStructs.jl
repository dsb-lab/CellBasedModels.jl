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
    saveLevel::Int
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
    positiondt::Int
    positiondW::Int
    deterministic::Union{Expr,Symbol,Number}
    stochastic::Union{Expr,Symbol,Number}
end

struct Integrator
    length
    stochasticImplemented
    weight
end