"""
    function subs_(exp,ob,tar)

Substitutes all encounters of a symbolic expression or symbol **ob** by a target expression **tar** in **exp**.
Is update true, only substitutes those symbols **ob** that are being assigned.

Example
```@Julia
> subs_(:(x += 3*x),:x,:y,update=false)
:(y+=3*y)
> subs_(:(x += 3*x),:x,:y,update=true)
:(y+=3*x)
```
"""
function subs_(exp::Expr,ob::Union{Expr,Symbol},tar::Union{Expr,Symbol,<:Number};update=false)
    for (pos,a) in enumerate(exp.args)
        if a == ob && !update
            exp.args[pos] = tar
        elseif a == ob && exp.head in [:(=),:(+=),:(-=),:(%=),:(/=)] && pos == 1
            exp.args[pos] = tar
        elseif typeof(a) == Expr
            a = subs_(a,ob,tar,update=update)
        end
    end
    return exp
end

"""
    function subsArguments_(exp,ob,tar)

Substitutes all encounters of a symbol **ob** by an expanded list of symbols **tar** in **exp**. 
Mainly used to put a list of arguments into a function argument list.
"""
function subsArguments_(exp::Expr,ob::Symbol,tar::Array{Symbol,1})

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