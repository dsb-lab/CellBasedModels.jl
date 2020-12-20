
"""
    function subs(expr,ob,tar)

Substitute ob expression or symbol by tar expression or symbol into expression expr.
"""
function subs(exp,ob,tar)
    for (pos,a) in enumerate(exp.args)
        if a == ob
            exp.args[pos] = tar
        elseif typeof(a) == Expr
            a = subs(a,ob,tar)
        end
    end
    return exp
end

"""
    function subs(expr,ob,tar)

Substitute ob expression or symbol by tar expression or symbol into expression expr.
"""
function subs(exp::String,ob,tar)
    expE = subs(Meta.parse(exp),ob,tar)
    return expE
end

function subs(exp::Array,ob,tar)
    expL = []
    for i in exp
        push!(expL,subs(i,ob,tar))
    end
    return expL
end

function subs(exp,obVec::Array,tarVec::Array)
    for (ob,tar) in zip(obVec,tarVec)
        subs(exp,ob,tar)
    end
    return exp
end

function subs(exp::Array,obVec::Array,tarVec::Array)
    expL = [] 
    for i in exp
        for (ob,tar) in zip(obVec,tarVec)
            push!(expL,subs(i,ob,tar))
        end
    end
    return expL
end

function subs(vars,varsOb,varsTar,exp)
    for (pos,name) in enumerate(vars)
        lOb = [Meta.parse(replace(i,"NAME_"=>string(name))) for i in varsOb]
        lVar = [Meta.parse(replace(i,"POS_"=>string(pos))) for i in varsTar]
        exp = subs(exp,lOb,lVar)
    end
    
    return exp
end

function subs(vars,varsOb,varsTar,exp::Array)
    expL = [] 
    for expi in exp
        push!(expL,subs(vars,varsOb,varsTar,expi))
    end
    
    return expL
end

function subs(vars,varsOb,varsTar,text::String)
    exp = Meta.parse(text)
    for (pos,name) in enumerate(vars)
        lOb = [Meta.parse(replace(i,"NAME_"=>string(name))) for i in varsOb]
        lVar = [Meta.parse(replace(i,"POS_"=>string(pos))) for i in varsTar]
        exp = subs(exp,lOb,lVar)
    end
    
    return exp
end