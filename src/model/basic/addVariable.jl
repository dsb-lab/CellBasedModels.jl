"""
    function addVariable!(agentModel::Model, addvar::Symbol, addeqs::String)

Add a variable described by an Ordinary or Stochastic Differential Equation.

# Examples
```
m = Model();
eq = "
dxdt = -x #Exponential decay
"
addVariable!(m,:x,eq);
```
```
m = Model();
eq = "
dxdt = -x+ξ #Wiener process
"
addVariable!(m,:x,eq);
```
"""
function addVariable!(agentModel::Model, addvar::Symbol, addeqs::String; randVar = Tuple{Symbol,<:Distribution}[])

    agentModel.evolve = needCompilation
    addeqs = Meta.parse(string("begin ",addeqs," end"))
    
    if length(randVar) > 0
        randSymb = [i[1] for i in randVar]
        for i in randSymb #Check double declarations
            if length(findall(randSymb.==i))>1
                error("Random variable ", i, " declared more then once.")
            end
            #Check if already declared
            checkDeclared(agentModel,i)
        end
    end
    
    #Check vars except RESERVEDVARS
    checkDeclared(agentModel,addvar,eqs=true)

    push!(agentModel.equations,addeqs)

    push!(agentModel.declaredSymb["var"],addvar)
    append!(agentModel.declaredRandSymb["varRand"],randVar)
    
    return
end

"""
    function addVariable!(agentModel::Model, addvar::Symbol, addeqs::String)

Add a variable described by an Ordinary or Stochastic Differential Equations.

# Examples
```
m = Model();
eq = "
dxdt = -x #Exponential decay
dydt = -y + ξ #Wiener process
"
addVariable!(m,[:x,:y],eq);
```
"""
function addVariable!(agentModel::Model, addvar::Array{Symbol}, addeqs::String; randVar = Tuple{Symbol,<:Distribution}[])

    agentModel.evolve = needCompilation
    addeqs = Meta.parse(string("begin ",addeqs," end"))
    
    for i in addvar
        if length(findall(addvar.==i))>1
            error("Parameter ", i, " declared with more than once.")
        end
    end

    if length(randVar) > 0
        randSymb = [i[1] for i in randVar]
        for i in randSymb #Check double declarations
            if length(findall(randSymb.==i))>1
                error("Random variable ", i, " declared more then once.")
            end
            #Check if already declared
            checkDeclared(agentModel,i)
        end
    end
        
    #Check vars except RESERVEDVARS
    for i in addvar
        checkDeclared(agentModel,i,eqs=true)
    end
    push!(agentModel.equations,addeqs)

    append!(agentModel.declaredSymb["var"],addvar)
    append!(agentModel.declaredRandSymb["varRand"],randVar)
    
    return
end