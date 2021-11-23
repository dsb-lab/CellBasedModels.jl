"""
    mutable struct Program_

Structure that contains all the pieces of code before they are finally assembled into the final evolve function.
"""
mutable struct Program_

    agent::Agent
    integrator::String
    integratorMedium::String
    neighbors::String

    declareVar::Expr
    declareF::Expr
    args::Array{Symbol,1}
    execInit::Expr
    execInloop::Expr
    execAfter::Expr
    returning::Expr

    update::Dict{String,Dict{Symbol,Int}}
end

function Program_(abm::Agent)
    return Program_(abm,"Euler","FTCS","full",quote end,quote end,Array{Symbol,1}([:t,:N,:dt]),
                    quote end,quote end,quote end,quote end,Dict{String,Dict{Symbol,Int}}())
end