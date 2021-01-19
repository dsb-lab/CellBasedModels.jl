"""
    function addLocalInteraction!(agentModel::Model, addvar::Symbol, addeqs::String; randVar = Tuple{Symbol,String}[])

Add a local interaction to the model.

# Examples
```
m = Model();
addLocal!(m,[:x,:y]);


interaction = "
d₁ = sqrt((x₁-x₂)^2+(y₁-y₂)^2)
"
addLocalInteraction!(m,:d,interaction);
```
"""
function addLocalInteraction!(agentModel::Model, addvar::Symbol, addeqs::String; randVar = Tuple{Symbol,String}[])

    agentModel.evolve = needCompilation
    
    newEqs = Meta.parse(string("begin ", addeqs, " end"))

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
            if findfirst(RESERVEDCALLS.==i[2]) == nothing
                error("Probabily distribution assigned to random variable ", i[1], " ", i[2], " does not exist.")
            end
        end
    end
    
    eqs = copy(agentModel.locInter)
    
    #Check vars except RESERVEDVARS
    checkDeclared(agentModel,addvar)

    push!(eqs,newEqs)

    agentModel.locInter = eqs
    push!(agentModel.declaredSymb["locInter"],addvar)
    append!(agentModel.declaredRandSymb["locInterRand"],randVar)
    
    return
end

"""
    function addLocalInteraction!(agentModel::Model, addvar::Symbol, addeqs::String; randVar = Tuple{Symbol,String}[])

Add a local interaction to the model.

# Examples
```
m = Model();
addLocal!(m,[:x,:y]);


interaction = "
d₁ = sqrt((x₁-x₂)^2+(y₁-y₂)^2)
dAbs₁ = abs(x₁-x₂)+abs(y₁-y₂)
"
addLocalInteraction!(m,[:d,:dAbs],interaction);
```
"""
function addLocalInteraction!(agentModel::Model, addvar::Array{Symbol}, addeqs::String; randVar = Tuple{Symbol,String}[])

    agentModel.evolve = needCompilation
    
    newEqs = Meta.parse(string("begin ", addeqs, " end"))

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
    
    eqs = copy(agentModel.locInter)
    
    #Check vars except RESERVEDVARS
    for i in addvar
        checkDeclared(agentModel,i)
    end
    push!(eqs,newEqs)

    agentModel.locInter = eqs
    append!(agentModel.declaredSymb["locInter"],addvar)
    append!(agentModel.declaredRandSymb["locInterRand"],randVar)
    
    return
end