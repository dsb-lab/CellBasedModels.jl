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
    
    newEqs = splitUpdating(addeqs)
    if length(newEqs) == 0
        error("An local update rule has to be defined for the declared parameter ", addvar, ".")
    elseif length(newEqs) > 1
        error("Interaction parameter ", addvar, " associted with more than interaction rule.")
    end
    #Check repeated declarations
    varsDeclared=Meta.parse(string(Meta.parse(newEqs[1]).args[1]))
    index = string(Meta.parse(newEqs[1]).args[1])[end]
    if index != '₁' #Check index declared
        error("""Interaction parameter """, varsDeclared, """ has to be declared with underscript "₁".""")
    end
    if addvar != varsDeclared
        error("Interaction parameter ", addvar, " but interaction rule for variable ", varsDeclared, " declared.")
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
            if findfirst(RESERVEDCALLS.==i[2]) == nothing
                error("Probabily distribution assigned to random variable ", i[1], " ", i[2], " does not exist.")
            end
        end
    end
    
    eqs = copy(agentModel.locInter)
    
    #Check vars except RESERVEDVARS
    checkDeclared(agentModel,addvar)

    push!(eqs,Meta.parse([j for j in newEqs if contains(j,string(addvar,"₁"))][1]))

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
    
    newEqs = splitUpdating(addeqs)
    #Check repeated declarations
    varsDeclared = []
    for i in newEqs
        push!(varsDeclared,Meta.parse(string(Meta.parse(i).args[1])[1:end-1]))
        index = string(Meta.parse(i).args[1])[end]
        if index != '₁' #Check index declared
            error("""Interaction parameter """, Meta.parse(string(Meta.parse(i).args[1])), """ has to be declared with underscript "₁".""")
        end
    end
    for i in varsDeclared
        if length(findall(varsDeclared.==i))>1
            error("Interaction parameter ", i, " declared with more than interaction rule.")
        end
    end
    for i in addvar
        if length(findall(addvar.==i))>1
            error("Parameter ", i, " declared with more than one update rule.")
        end
    end
    #Check same declarations for vars and eqs
    if length(varsDeclared) <= length(addvar)
        notDeclared = []
        for i in addvar
            if !(i in varsDeclared)
                push!(notDeclared,i)
            end
        end
        if length(notDeclared) > 0
            error("Declared interaction parameters with no associated interaction rule: $(notDeclared...) ")
        end
    elseif length(varsDeclared) > length(addvar)
        notDeclared = []
        for i in varsDeclared
            if !(i in keys(addvar))
                push!(notDeclared,i)
            end
        end
        error("Interaction parameters with associated interaction rule but not declared: $(notDeclared...)")        
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
    
    eqs = copy(agentModel.locInter)
    
    #Check vars except RESERVEDVARS
    for i in addvar
        checkDeclared(agentModel,i)
    end
    for i in addvar
        push!(eqs,Meta.parse([j for j in newEqs if contains(j,string(i,"₁"))][1]))
    end

    agentModel.locInter = eqs
    append!(agentModel.declaredSymb["locInter"],addvar)
    append!(agentModel.declaredRandSymb["locInterRand"],randVar)
    
    return
end