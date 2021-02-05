"""
    function addGlobal!(agentModel::Model, addvar::Symbol; updates="", randVar = Tuple{Symbol,String}[])

Add a global variable to the model with optional update rules.

# Examples
```
m = Model();

addGlobal!(m,:x);
```
```
m = Model();
update = "
x= r #r is a random variable with μ=0. and σ=1.
"

addGlobal!(m,:x,updates=update,randVar=[(:r,Normal(0.,1.))]);
```
"""
function addGlobal!(agentModel::Model, addvar::Symbol; updates="", randVar = Tuple{Symbol,<:Distribution}[])
    
    agentModel.evolve = needCompilation

    if updates != ""
        newUpdates = Meta.parse(string("begin ",updates," end"))
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
        
    globUpdates = copy(agentModel.glob)
    
    #Check vars except RESERVEDVARS
    checkDeclared(agentModel,addvar)
    
    if updates != ""
        push!(globUpdates,newUpdates)
    end
        
    agentModel.glob = globUpdates
    push!(agentModel.declaredSymb["glob"],addvar)
    append!(agentModel.declaredRandSymb["globRand"],randVar)
    
    return
end

"""
    function addGlobal!(agentModel::Model, addvar::Array{Symbol}; updates="", randVar = Tuple{Symbol,String}[])

Add a set of global variables to the model with optional update rules.

# Examples
```
m = Model();

addGlobal!(m,[:x,:y]);
```

```
m = Model();
update = " #We update x but not y
x= r
"

addGlobal!(m,[:x,:y],updates=update,randVar=[(:r,Normal,0,1)]);
```
"""
function addGlobal!(agentModel::Model, addvar::Array{Symbol}; updates="", randVar = Tuple{Symbol,<:Distribution}[])

    agentModel.evolve = needCompilation
    
    #Check repeated declarations in addvar
    for i in addvar
        if length(findall(addvar.==i))>1
            error("Parameter ", i, " declared with more than once.")
        end
    end

    if updates != ""
        newUpdates = Meta.parse(string("begin ",updates," end"))
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
        checkDeclared(agentModel,i)
    end
    
    globUpdates = copy(agentModel.glob)    
    
    if updates != ""
        push!(globUpdates,newUpdates)
    end
    
    agentModel.glob = globUpdates
    append!(agentModel.declaredSymb["glob"],addvar)
    append!(agentModel.declaredRandSymb["globRand"],randVar)
    
    return
end