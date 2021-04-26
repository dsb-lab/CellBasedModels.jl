"""
    addIdentifier!(agentModel::Model, addvar::Symbol; updates="", randVar = Tuple{Symbol,String}[])

Add a local variable to the model with optional update rules.

# Examples
```
m = Model();

addIdentifier!(m,:id);
```
"""
function addIdentifier!(agentModel::Model, addvar::Symbol; updates="", randVar = Tuple{Symbol,<:Distribution}[])

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
    
    idUpdates = copy(agentModel.ids)
    
    #Check vars except RESERVEDVARS
    checkDeclared(agentModel,addvar)
    
    if updates != ""
        push!(idUpdates,newUpdates)
    end
        
    agentModel.ids = idUpdates
    push!(agentModel.declaredIds,addvar)
    append!(agentModel.declaredRandSymb["idsRand"],randVar)
    
    return
end

"""
    addIdentifier!(agentModel::Model, addvar::Array{Symbol}; updates="", randVar = Tuple{Symbol,String}[])

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
function addIdentifier!(agentModel::Model, addvar::Array{Symbol}; updates="", randVar = Tuple{Symbol,<:Distribution}[])

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
    
    idsUpdates = copy(agentModel.ids)    
    
    if updates != ""
        push!(idsUpdates,newUpdates)
    end
    
    agentModel.ids = idsUpdates
    append!(agentModel.declaredIds,addvar)
    append!(agentModel.declaredRandSymb["idsRand"],randVar)
    
    return
end