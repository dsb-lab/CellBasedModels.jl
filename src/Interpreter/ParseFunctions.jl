function changeParse(variable,list,name)
    for i in 1:length(list)
        if variable == Meta.parse(list[i])
            return Meta.parse(string(name,i,"]"))
            break
        end
    end
end

function findParse(expression,list)
    for i in 1:length(expression.args)
        if typeof(expression.args[i]) == Symbol
            returned = changeParse(expression.args[i],list,"dsparams[i,")
            if returned !== nothing
                expression.args[i]=returned
            end
            #println("Symbol")
        elseif typeof(expression.args[i]) == Expr
            findParse(expression.args[i],list)
        end
    end
end
