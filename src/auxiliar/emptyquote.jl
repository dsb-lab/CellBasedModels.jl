"""
    function emptyquote_(exp)

Function that returns true if a quote expression has any arguments.
"""
function emptyquote_(exp::Expr)
    return [i for i in exp.args if typeof(i) != LineNumberNode] == []
end