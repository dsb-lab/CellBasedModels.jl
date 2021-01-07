"""
    function addLocalInteraction!(agentModel::Model, addvar::Symbol, addeqs::String; randVar = Tuple{Symbol,String}[])

Add a interaction parameters to the model. Differently to the local interactions, this parameters will be updated inside the integration steps of the differential equations.

# Examples
```
m = Model();
eq = "
dxdt = -x+g*ξ #Wiener process with an additional interaction
"
addVariable!(m,:x,eq);


interaction = "
g₁ += 1./sqrt((x₁-x₂)^2+(y₁-y₂)^2) #The difussion will be affected by the presence of other particles around them.
"
addInteraction!(m,:g,interaction);
```
"""
function addInteraction!(agentModel::Model, addvar::Symbol, addeqs::String)
    
    newEqs = splitUpdating(addeqs)
    if length(newEqs) == 0
        error("An equation has to be defined for the declared variable ", addvar, ".")
    elseif length(newEqs) > 1
        error("Interaction parameter ", addvar, " associted with more than interaction rule.")
    end
    #Check repeated declarations
    varsDeclared=Meta.parse(string(Meta.parse(newEqs[1]).args[1])[1:end-1])
    index = string(Meta.parse(newEqs[1]).args[1])[end]
    if index != '₁' #Check index declared
        error("""Interaction parameter """, Meta.parse(string(Meta.parse(newEqs[1]).args[1])), """ has to be declared with underscript "₁".""")
    end
    if addvar != varsDeclared
        error("Interaction parameter ", addvar, " but interaction rule for variable ", varsDeclared, " declared.")
    end
    
    eqs = copy(agentModel.inter)
    
    #Check vars except RESERVEDVARS
    checkDeclared(agentModel,addvar)

    push!(eqs,Meta.parse([j for j in newEqs if contains(j,string(addvar,"₁"))][1]))

    agentModel.inter = eqs
    push!(agentModel.declaredSymb["inter"],addvar)
    
    return
end

"""
    function addLocalInteraction!(agentModel::Model, addvar::Symbol, addeqs::String; randVar = Tuple{Symbol,String}[])

Add a interaction parameters to the model. Differently to the local interactions, this parameters will be updated inside the integration steps of the differential equations.

# Examples
```
m = Model();
eq = "
dxdt = -x+g*ξ+p #Wiener process with an additional interaction
"
addVariable!(m,:x,eq);


interaction = "
g₁ += 1./sqrt((x₁-x₂)^2+(y₁-y₂)^2) #The difussion will be affected by the presence of other particles around them.
p₁ += 1./(abs(x₁-x₂)+abs(y₁-y₂)) #The difussion will be affected by the presence of other particles around them.
"
addInteraction!(m,[:g,:p],interaction);
```
"""
function addInteraction!(agentModel::Model, addvar::Array{Symbol}, addeqs::String)
    
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
        
    eqs = copy(agentModel.inter)
    
    #Check vars except RESERVEDVARS
    for i in addvar
        checkDeclared(agentModel,i)
    end
    for i in addvar
        push!(eqs,Meta.parse([j for j in newEqs if contains(j,string(i,"₁"))][1]))
    end

    agentModel.inter = eqs
    append!(agentModel.declaredSymb["inter"],addvar)
    
    return
end