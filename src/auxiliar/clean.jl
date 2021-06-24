"""
    function clean(a)

Cleans the complex print of an expression to make it more clear to see.

Code reused from comments on [Julia](https://discourse.julialang.org/t/code-generation-unnecessary-comment-lines-when-using-quote/398/2)
"""
function clean(ex::Expr)
    filter!(ex.args) do e
        isa(e, LineNumberNode) && return false
        if isa(e, Expr)
            (e::Expr).head === :line && return false
            clean(e::Expr)
        end
        return true
    end
    return ex
end

function clean2(ex::Expr)
    filter!(e->typeof(e)!=LineNumberNode,ex.args)
    for i in ex.args
        if typeof(i) == Expr
            clean2(i)
        end
    end
    return ex
end

