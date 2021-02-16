"""
Check if a symbol or expression is present in a block of code

# Arguments
 - **exp** (Expr, String) Block of code where to check for the symbol
 - **ob** (Symbol or Expr) Symbol or Expression to look for in the block of code

# Returns
Bool
"""
function findSymbol(exp,ob)
    found = false
    for (pos,a) in enumerate(exp.args)
        if a == ob
            found = true
            break
        elseif typeof(a) == Expr
            found = findSymbol(a,ob)
        end
    end
    return found
end

function findSymbol(exp::String,ob)
    found = findSymbol(Meta.parse(exp),ob)
    return found
end