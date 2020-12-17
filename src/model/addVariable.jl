function addVariables!(agentModel::Model, addvar::Symbol, addeqs::String)
    
    newEqs = splitLines(addeqs,"=")
    if length(newEqs) == 0
        error("An equation has to be defined for the declared variable ", addvar, ".")
    elseif length(newEqs) > 1
        error("Variable ", addvar, " associted with more than one equation.")
    end
    #Check repeated declarations
    varsDeclared=Meta.parse(string(Meta.parse(newEqs[1]).args[1])[2:end-2])
    if addvar != varsDeclared
        error("Variable ", addvar, " but equation for variable ", varsDeclared, " declared.")
    end
    
    eqs = copy(agentModel.equations)
    
    #Check vars except RESERVEDVARS
    checkDeclared(agentModel,addvar,eqs=true)

    push!(eqs,Meta.parse([j for j in newEqs if contains(j,string("d",addvar,"dt"))][1]))

    agentModel.equations = eqs
    push!(agentModel.declaredSymb["var"],addvar)
    
    return
end

function addVariables!(agentModel::Model, addvar::Array{Symbol}, addeqs::String)
    
    newEqs = splitLines(addeqs,"=")
    #Check repeated declarations
    varsDeclared = []
    for i in newEqs
        push!(varsDeclared,Meta.parse(string(Meta.parse(i).args[1])[2:end-2]))
    end
    for i in varsDeclared
        if length(findall(varsDeclared.==i))>1
            error("Variable ", i, " declared with more than one equation.")
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
            error("Declared variables with no associated equation: $(notDeclared...) ")
        end
    elseif length(varsDeclared) > length(addvar)
        notDeclared = []
        for i in varsDeclared
            if !(i in keys(addvar))
                push!(notDeclared,i)
            end
        end
        error("Variables with associated equation but not declared: $(notDeclared...)")        
    end
        
    eqs = copy(agentModel.equations)
    
    #Check vars except RESERVEDVARS
    for i in addvar
        checkDeclared(agentModel,i,eqs=true)
    end
    for i in addvar
        push!(eqs,Meta.parse([j for j in newEqs if contains(j,string("d",i,"dt"))][1]))
    end

    agentModel.equations = eqs
    append!(agentModel.declaredSymb["var"],addvar)
    
    return
end