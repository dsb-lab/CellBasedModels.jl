"""
    struct Pseudopode <: Special

Struct containing the conditions for pseudopode like forces.
"""
struct Pseudopode <: Special
    condition::Expr
    force::Expr
end

"""
    function addPseudopode!(agentModel::Model, symbol::Symbol, condition::String, force::String; randVar = Tuple{Symbol,String}[])

Add a pseudopode force.

Examples
```
m = Model()
addLocal!([:x,:y])

condition = 
"
sqrt((x₁-x₂)^2+(y₁-y₂)^2) < 2.
"
force = 
"
f = sqrt((x₁-x₂)^2+(y₁-y₂)^2)*exp(-sqrt((x₁-x₂)^2+(y₁-y₂)^2))
"
addPseudopode!(m,:f,condition,force)
```
"""
function addPseudopode!(agentModel::Model, symbol::Symbol, condition::String, force::String; randVar = Tuple{Symbol,String}[])
    
    #Check if a Pseudopode force already exists
    if Pseudopode in [typeof(i) for i in agentModel.special]
        error("A pseudopode force is already present in the model. Only one pseudopode force can exist in the model.")
    end

    #Check integrity of the inputs
    condition = splitUpdating(condition)
    if length(condition) != 1
        error("Error in the pseudopode condition definition.")
    end 
    force = splitUpdating(force)
    if length(force) != 1
        error("Error in the pseudopode force definition.")
    end 

    #Add necessary variables
    addIfNot!(agentModel.declaredIds, [:id_,:nNPseudo_,:pseudoId_])

    #Check random variables
    checkRandDeclared(agentModel, randVar)


    
end