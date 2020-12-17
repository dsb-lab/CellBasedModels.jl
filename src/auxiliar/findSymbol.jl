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