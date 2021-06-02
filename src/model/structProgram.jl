"""
    mutable struct Program_

Structure that contains all the pieces of code before they are finally assembled into the final evolve function.
"""
mutable struct Program_

    declareVar::Array{Expr,1}
    declareF::Array{Expr,1}
    args::Array{Symbol,1}
    argsEval::Array{Symbol,1}
    execInit::Array{Expr,1}
    execInloop::Array{Expr,1}
    execAfter::Array{Expr,1}

end

function Program_()
    return Program_(Array{Expr,1}(),Array{Expr,1}(),Array{Symbol,1}(),Array{Symbol,1}(),Array{Expr,1}(),Array{Expr,1}(),Array{Expr,1}())
end