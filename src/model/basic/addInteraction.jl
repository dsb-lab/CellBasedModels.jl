"""
    function addInteraction!(agentModel::Model, addvar::Symbol, addeqs::String)

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

    agentModel.evolve = needCompilation
    
    newEqs = Meta.parse(string("begin \n", addeqs, " \nend"))
    
    eqs = copy(agentModel.inter)
    
    #Check vars except RESERVEDVARS
    checkDeclared(agentModel,addvar)

    push!(eqs,newEqs)

    agentModel.inter = eqs
    push!(agentModel.declaredSymb["inter"],addvar)
    
    return
end

"""
    function addInteraction!(agentModel::Model, addvar::Symbol, addeqs::String)

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

    agentModel.evolve = needCompilation
        
    newEqs = Meta.parse(string("begin ", addeqs, " end"))
        
    eqs = copy(agentModel.inter)
    
    #Check vars except RESERVEDVARS
    for i in addvar
        checkDeclared(agentModel,i)
    end

    push!(eqs,newEqs)

    agentModel.inter = eqs
    append!(agentModel.declaredSymb["inter"],addvar)
    
    return
end