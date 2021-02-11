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
function addVariable!(agentModel::Model, addvar::Symbol, addeqs::String)

    agentModel.evolve = needCompilation
    addeqs = eval(Meta.parse(string("quote ",addeqs," end")))
    
    #Check vars except RESERVEDVARS
    checkDeclared(agentModel,addvar,eqs=true)

    eqs = agentModel.equations
    if eqs == :()
        eqs = addeqs
    else
        append!(eqs.args,addeqs.args)
    end
    agentModel.equations = eqs

    push!(agentModel.declaredSymb["var"],addvar)
    
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
function addVariable!(agentModel::Model, addvar::Array{Symbol}, addeqs::String)

    agentModel.evolve = needCompilation
    addeqs = eval(Meta.parse(string("quote ",addeqs," end")))
    
    for i in addvar
        if length(findall(addvar.==i))>1
            error("Parameter ", i, " declared with more than once.")
        end
    end
        
    #Check vars except RESERVEDVARS
    for i in addvar
        checkDeclared(agentModel,i,eqs=true)
    end

    eqs = agentModel.equations
    if eqs == :()
        eqs = addeqs
    else
        append!(eqs.args,addeqs.args)
    end
    agentModel.equations = eqs

    append!(agentModel.declaredSymb["var"],addvar)
    
    return
end