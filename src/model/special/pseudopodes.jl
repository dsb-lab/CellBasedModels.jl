"""
    struct Pseudopode <: Special

Struct containing the conditions for pseudopode like forces.
"""
struct Pseudopode <: Special
    f::Array{Symbol}
    neighbourCondition::Expr
    force::Expr
    updateCondition::Expr
    updateChange::Expr
end

"""
    function addPseudopode!(agentModel::Model, var::Symbol, tVar::Symbol, neighbourCondition::String, force::String, updateChange::String; randVar = Tuple{Symbol,String}[])

Add a pseudopode force.

**Examples**
```
m = Model()
addLocal!([:x,:y])

neighbourCondition = 
"
sqrt((x₁-x₂)^2+(y₁-y₂)^2) < 2.
"
force = 
"
f = sqrt((x₁-x₂)^2+(y₁-y₂)^2)*exp(-sqrt((x₁-x₂)^2+(y₁-y₂)^2))
"
updateChange = 
"
tPseudo = t + σPseudo
"
addPseudopode!(m, :f, :tPseudo, condition, force, updateChange, randVar = [(:σPseudo,"Uniform",1.,2.)])
```
"""
function addPseudopode!(agentModel::Model, fvar::Array{Symbol}, neighbourCondition::String, force::String, updateCondition::String, updateChange::String; randVar = Tuple{Symbol,String}[])
    
    neighbourCondition = Meta.parse(neighbourCondition)
    force = Meta.parse(string("begin ",force, " end"))
    updateCondition = Meta.parse(updateCondition)
    updateChange = Meta.parse(string("begin ",updateChange, " end"))
    
    #Check if a Pseudopode force already exists
    if Pseudopode in [typeof(i) for i in agentModel.special]
        error("A pseudopode force is already present in the model. Only one pseudopode force can exist in the model.")
    end
    #Check var and tVar
    checkDeclared(agentModel, fvar)
    #Add necessary variables
    addIfNot!(agentModel.declaredIds, [:id_,:pseudoId_])
    addIfNot!(agentModel.inter,
    :(if pseudoId_₁ == id_₂ && pseudoId_₂ == id_₁; 
            $force
        end)
    )
    append!(agentModel.declaredSymb["inter"],fvar)
    addIfNot!(agentModel.declaredRandSymb["loc"],randVar)

    push!(agentModel.special, Pseudopode(fvar,neighbourCondition,force,updateCondition,updateChange))

    return
end

"""
    function pseudopodeCompile(pseudopode::Pseudopode,agentModel::Model; platform::String)
"""
function pseudopodeCompile(pseudopode::Pseudopode,agentModel::Model; platform::String)

    comArgs = commonArguments(agentModel)
    
    #Initialize
    varDeclare = Expr[]
    fDeclare = Expr[]
    execute = Expr[]

    #Add variables
    pushAdapt!(varDeclare, agentModel, platform, 
    :(pseudoChoice_ = @ARRAY_zeros(nMax_))
    )
    
    #Add function to declare
    ## Count number of neighbours loop
    algorithm = 
    string(:(
    if $(pseudopode.neighbourCondition)
        nNPseudo += 1
    end 
    ))
    inLoop1, arg = makeInLoop(agentModel,platform,algorithm)
    ## Assign a random neighbour loop
    algorithm = 
    string(:(
    if $(pseudopode.neighbourCondition)
        count -= 1             
        if count < 0
            pseudoId_ = nnic2_
            $(pseudopode.updateChange)
            break
        end
    end
    ))
    inLoop2, arg = makeInLoop(agentModel,platform,algorithm)
    ## Create the function
    pushAdapt!(fDeclare, agentModel, platform,
    :(function pseudoUpdate($(comArgs...),$(arg...),pseudoChoice_)
            @INFUNCTION_ for ic1_ in index_:stride_:N
                if $(pseudopode.updateCondition)
                    nNPseudo = 0
                    $inLoop1
                    count = pseudoChoice_[ic1_]*nNPseudo
                    $inLoop2
                end
            end
        return
    end)
    )
    
    #Add execute functions
    pushAdapt!(execute, agentModel, platform, 
    :(rand!(pseudoChoice_))
    )
    pushAdapt!(execute, agentModel, platform, 
    :(@OUTFUNCTION_ pseudoUpdate($(comArgs...),$(arg...),pseudoChoice_))
    )

    return varDeclare,fDeclare,execute,execute
end