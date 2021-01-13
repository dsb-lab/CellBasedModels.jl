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
sqrt((x₁-x₂)^2+(y₁-y₂)^2)*exp(-sqrt((x₁-x₂)^2+(y₁-y₂)^2))
"
addPseudopode!(m,:f,condition,force)
```
"""
function addPseudopode!(agentModel::Model, var::Symbol, condition::String, force::String; randVar = Tuple{Symbol,String}[])
    
    #Checks
    condition = Meta.parse(condition)
    force = Meta.parse(force)
    #Check if a Pseudopode force already exists
    if Pseudopode in [typeof(i) for i in agentModel.special]
        error("A pseudopode force is already present in the model. Only one pseudopode force can exist in the model.")
    end
    #Check var
    checkDeclared(agentModel, var)
    #Check random variables
    checkRandDeclared(agentModel, randVar)
    #Add necessary variables
    addIfNot!(agentModel.declaredIds, [:id_,:pseudoId_])

    eqs = copy(agentModel.inter)
    
    push!(eqs,
    :(if pseudoId_₁ == id_₂; 
            $(Meta.parse(string(var,"₁"))) += $force
            $(Meta.parse(string(var,"₂"))) += -$(Meta.parse(string(var,"₁")))
        end)
    )

    agentModel.inter = eqs
    push!(agentModel.declaredSymb["inter"],var)

    return
end


"""
    function pseudopodeCompile(pseudopode::Pseudopode,agentModel::Model,inLoop,arg; platform::String)
"""
function pseudopodeCompile(pseudopode::Pseudopode,agentModel::Model,inLoop,arg; platform::String)

    comArgs = commonArguments(agentModel)
    cond = division.condition
    update = division.update
    
    varDeclare = Expr[]
    fDeclare = Expr[]
    execute = Expr[]

    if platform == "cpu"
    
        #Add variables
        push!(varDeclare, :(pseudoChoice_ = zeros(nMax_)))
    
        #Add functions to declare
        inloopCount = copy(inloop)
        algorithm = 
        string(:(
        if $(pseudopode.condition)
            :nNPseudo_₁ += 1
        end
        ))
        inLoop = Meta.parse(replace(string(inLoop),"ALGORITHMS_"=>algorithm))
        inLoop = NEIGHBORHOODADAPT[typeof(agentModel.neighborhood)](inLoop)   
        pushAdapt!(fDeclare, agentModel, platform,
        :(function pseudoCount($(comArgs...))
                @INFUNCTION_ for ic1_ in index_:stride_:N_
                    $(reset...)
                    $inLoop    
                end
            return
        end 
        )
        )
    
    end



    return varDeclare,fDeclare,execute
end