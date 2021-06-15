validDistributions = [i for i in names(Distributions) if uppercasefirst(string(i)) == string(i)]
validDistributionsCUDA = [:Normal,:Uniform,:Poisson]

function dist(expr,l=[],it=[1])
    for i in validDistributions
        expr,_ = change_dist(expr,i,l,it)
    end
    
    return expr, l
end

function change_dist(expr,symb,l=[],it=[1])
    if typeof(expr) == Expr
        for (j,i) in enumerate(expr.args)
            if i == symb && j == 1
                name = Meta.parse(string("dist",it[1]))
                it[1] = it[1] + 1
                push!(l,(name,expr))
                expr = name
            elseif typeof(i) == Expr
                expr.args[j],_ = change_dist(i,symb,l,it)
            end
        end
    end
    
    return expr,l
end