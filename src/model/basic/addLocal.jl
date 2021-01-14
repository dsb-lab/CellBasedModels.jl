"""
    addLocal!(agentModel::Model, addvar::Symbol; updates="", randVar = Tuple{Symbol,String}[])

Add a local variable to the model with optional update rules.

# Examples
```
m = Model();

addLocal!(m,:x);
```
```
m = Model();
update = "
x= r #r is a random variable with μ=0. and σ=1.
"

addLocal!(m,:x,updates=update,randVar=[(:r,Normal,0.,1.)]);
```
"""
function addLocal!(agentModel::Model, addvar::Symbol; updates="", randVar = Tuple{Symbol,String}[])

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

        #Check if distribution exists
        for i in randVar
            if findfirst(RESERVEDCALLS.==i[2])==nothing
                error("Probabily distribution assigned to random variable ", i[1], " ", i[2], " does not exist.")
            end
        end
    end
    
    globUpdates = copy(agentModel.loc)
    
    #Check vars except RESERVEDVARS
    checkDeclared(agentModel,addvar)
    
    if updates != ""
        push!(globUpdates,newUpdates)
    end
        
    agentModel.loc = globUpdates
    push!(agentModel.declaredSymb["loc"],addvar)
    append!(agentModel.declaredRandSymb["locRand"],randVar)
    
    return
end

"""
    addLocal!(agentModel::Model, addvar::Array{Symbol}; updates="", randVar = Tuple{Symbol,String}[])

Add a local variable to the model with optional update rules.

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
function addLocal!(agentModel::Model, addvar::Array{Symbol}; updates="", randVar = Tuple{Symbol,String}[])

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

        #Check if distribution exists
        for i in randVar
            if findfirst(RESERVEDCALLS.==i[2])==nothing
                error("Probabily distribution assigned to random variable ", i[1], " ", i[2], " does not exist.")
            end
        end
    end
    
    #Check vars except RESERVEDVARS
    for i in addvar
        checkDeclared(agentModel,i)
    end
    
    globUpdates = copy(agentModel.loc)    
    
    if updates != ""
        push!(globUpdates,newUpdates)
    end
    
    agentModel.loc = globUpdates
    append!(agentModel.declaredSymb["loc"],addvar)
    append!(agentModel.declaredRandSymb["locRand"],randVar)
    
    return
end