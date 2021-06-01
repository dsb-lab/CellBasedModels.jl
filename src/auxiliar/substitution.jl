function subs_(exp,ob,tar)
    for (pos,a) in enumerate(exp.args)
        if a == ob
            exp.args[pos] = tar
        elseif typeof(a) == Expr
            a = subs_(a,ob,tar)
        end
    end
    return exp
end

function subsArguments_(exp,ob,tar)

    if typeof(tar) == Symbol
        return subs_(exp,ob,tar)
    elseif typeof(tar) <: Array
        add = ""
        for i in tar
            add = string(add,i,",")
        end
        
        return Meta.parse(replace(string(exp),string(ob)=>add[1:end-1]))
    else
        error("Arguments sent are wrong.")
    end
end