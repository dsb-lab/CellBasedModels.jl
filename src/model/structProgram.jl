"""
    mutable struct Program_

Structure that contains all the pieces of code before they are finally assembled into the final evolve function.
"""
mutable struct Program_

    declareVar::Expr
    declareF::Expr
    args::Array{Symbol,1}
    argsEval::Array{Union{Symbol,Expr},1}
    execInit::Expr
    execInloop::Expr
    execAfter::Expr
    returning::Expr

    update::Array{Symbol,1}
end

function Program_()
    return Program_(quote end,quote end,Array{Symbol,1}([:t,:N]),Array{Union{Symbol,Expr},1}(),quote end,quote end,quote end,quote end,Array{Symbol,1}())
end