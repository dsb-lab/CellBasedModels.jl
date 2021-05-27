abstract type Name end
abstract type Id end
abstract type Local end
abstract type Variable end
abstract type Global end
abstract type GlobalArray end
abstract type LocalInteraction end
abstract type Interaction end

abstract type UpdateGlobal end
abstract type UpdateLocal end
abstract type UpdateLocalInteraction end
abstract type UpdateInteraction end

validTypes = [
    :Id,
    :Local,
    :Variable,
    :Global,
    :GlobalArray,
    :LocalInteraction,
    :Interaction,
    :Name,
    :UpdateGlobal,
    :UpdateLocal,
    :UpdateLocalInteraction,
    :UpdateInteraction
]

macro Agent(varargs...) 
    
    #Check particle has a name
    m = Nothing
    try name = varargs[1].args[2] == :Name
        if name
            m = Model()
        else
            error("First entry of @Agent has to be an agent name. Example cell::Name.") 
        end
    catch
        error("First entry of @Agent has to be an agent name. Example cell::Name.") 
    end
    
    #Add all contributions
    for i in varargs[2:end]
        if typeof(i) != Expr
            error(i, " should be and expression containing at least a name and a type. Example variable::Variable.") 
        elseif typeof(i.args[1]) == Symbol && typeof(i.args[2]) == Symbol  
            if !(i.args[2] in validTypes)
                error("The type ", i.args[2]," defined in ", i, " is not a valid type.")
            else
                if i.args[2] == :Global
                    AgentBasedModels.checkDeclared(m,i.args[1])
                    push!(m.declaredSymb["glob"],i.args[1])
                elseif i.args[2] == :Local
                    AgentBasedModels.checkDeclared(m,i.args[1])
                    push!(m.declaredSymb["loc"],i.args[1])
                elseif i.args[2] == :Interaction
                    AgentBasedModels.checkDeclared(m,i.args[1])
                    push!(m.declaredSymb["inter"],i.args[1])
                elseif i.args[2] == :LocalInteraction
                    AgentBasedModels.checkDeclared(m,i.args[1])
                    push!(m.declaredSymb["locInter"],i.args[1])
                elseif i.args[2] == :Variable
                    AgentBasedModels.checkDeclared(m,i.args[1])
                    push!(m.declaredSymb["var"],i.args[1])                    
                elseif i.args[2] == :Id
                    AgentBasedModels.checkDeclared(m,i.args[1])
                    push!(m.declaredIds,i.args[1])
                else
                   error("Entry ", i, " is not a valid expression. Check how to define types ", i.args[2],".") 
                end
            end
        elseif typeof(i.args[1].args[1]) == Symbol && typeof(i.args[1].args[2]) == Symbol  
            j = i.args[1]
            if !(j.args[2] in validTypes)
                error("The type ", j.args[2]," defined in ", j, " is not a valid type.")
            else
                if j.args[2] == :GlobalArray
                    AgentBasedModels.checkDeclared(m,j.args[1])
                    dim = eval(i.args[2])
                    if typeof(dim) <: Array{Int}
                        push!(m.declaredSymbArrays["glob"],(j.args[1],dim))
                    else
                       error(i , " should be declared with an Array{Int,1} defining the dimensions. Type of ", dim, " is ",typeof(dim),".") 
                    end
                elseif j.args[2] == :UpdateGlobal
                    if typeof(i.args[2]) == Expr
                        push!(m.loc,i.args[2])
                    else
                       error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(dim),".") 
                    end
                elseif j.args[2] == :UpdateLocal
                    if typeof(i.args[2]) == Expr
                        push!(m.glob,i.args[2])
                    else
                       error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(dim),".") 
                    end
                elseif j.args[2] == :UpdateInteraction
                    if typeof(i.args[2]) == Expr
                        push!(m.inter,i.args[2])
                    else
                       error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(dim),".") 
                    end
                elseif j.args[2] == :UpdateLocalInteraction
                    if typeof(i.args[2]) == Expr
                        push!(m.locInter,i.args[2])
                    else
                       error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(dim),".") 
                    end
                else
                   error("Entry ", i, " is not a valid expression. Check how to define types ", i.args[1].args[2],".") 
                end
            end
        else
           error("Expression ", i, " is not a valid expression.") 
        end
    end
        
    return m
end

function Base.show(io::IO,abm::Model)
    print("PARAMETERS\n")
    print("\tGlobal:\n\t")
    for i in abm.declaredSymb["glob"]
        print(" ",i,",")
    end
    print("\n\tLocal:\n\t")
    for i in abm.declaredSymb["loc"]
        print(" ",i,",")
    end
    print("\n\tVariables:\n\t")
    for i in abm.declaredSymb["var"]
        print(" ",i,",")
    end
    print("\n\tLocal Interaction:\n\t")
    for i in abm.declaredSymb["locInter"]
        print(" ",i,",")
    end
    print("\n\tInteraction:\n\t")
    for i in abm.declaredSymb["inter"]
        print(" ",i,",")
    end
    print("\n\tGlobal Arrays:\n\t")
    for i in abm.declaredSymbArrays["glob"]
        print(" ",i[1],i[2],",")
    end
    print("\n\tIds:\n\t")
    for i in abm.declaredIds
        print(" ",i,",")
    end
    
    print("\n\nEQUATIONS\n\n")
    print(clean(abm.equations),"\n")
    
    print("\nGLOBAl UPDATES\n\n")
    for i in abm.glob
        print(clean(i))
    end

    print("\nLOCAL UPDATES\n\n")
    for i in abm.loc
        print(clean(i))
    end

    print("\nLOCAL INTERACTION UPDATES\n\n")
    for i in abm.locInter
        print(clean(i))
    end

    print("\nINTERACTION UPDATES\n\n")
    for i in abm.inter
        print(clean(i))
    end
    
end