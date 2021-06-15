"""
    function clean(a)

Cleans the complex print of an expression to make it more clear to see.
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
