"""
    function extractEquations(model::interpretedData,variables::Array{String})

Function that returns an array equations of the model. Useful for debugging equations.
"""
function extractEquations(model::interpretedData,variables::Array{String})

    #Check if variables are in the model
    notvariables = []
    for i in variables
        if length(findall(x->x==i,model.variables["Variables:"])) == 0
            push!(notvariables,i)
        end
    end
    if length(notvariables)>0
        error("Variables ", notvariables, " not present in the model.")
    end
    vars = copy(variables)
    for i in variables
        for j in ParameterHeaders[2:end]
            aux = []
            findVariables!(model.equations[i],model.variables[j],aux)
            for k in aux
                push!(vars,k)
            end
        end
    end

    #Construct function
    text = "function equations("
    if length(vars) == 1
        text = string(text,vars[1],"::Number)\n\treturn ", model.equations[vars[1]],"\nend")
    else
        for i in vars[1:end-1]
            text = string(text,i,"::Number,")            
        end
        text = string(text,vars[end],"::Number)\n")
        text = string(text,"\treturn [")
        for i in variables[1:end-1]
            text  = string(text,split(model.equations[i],"=")[2],",")
        end    
        text = string(text,split(model.equations[variables[end]],"=")[2],"]\nend")
    end

    println("Variables of the function: ", vars)

    return Meta.eval(Meta.parse(text))
end

function findVariables!(expression,list,variables)
    for i in 1:length(expression.args)
        if typeof(expression.args[i]) == Symbol
            if length(findall(x->x==string(expression.args[i]),list)) > 0
                push!(variables,string(expression.args[i]))
            end
        elseif typeof(expression.args[i]) == Expr
            findVariables!(expression.args[i],list,variables)
        end
    end

    return
end

function findVariables!(text::String,list,variables)
    expression = Meta.parse(text)

    return findVariables!(expression, list,variables)
end






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

function findParse(text::String,list)
    expression = Meta.parse(text)

    findParse(expression,list)

    return string(expression)
end