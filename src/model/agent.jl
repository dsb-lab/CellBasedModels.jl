"""
    macro @agent(name, varargs...) 

Basic Macro to grow an instance of Model. It generates an Agent type with the characteristics specified in its arguments.

Input:
    *name*: Name of agent.
    *varargs::Expr*: Arguments describing all the parameters, update rules and other properties of the agent. 
                The diferent types can be declared more than once. Valid types are: 
        **:Identity**
            Parameter with Int signature that can be used to identify individually each agent in the model, its an agent type...
            It is declared individually for each agent so it can be updated with UpdateLocal types.
            Has to be declared as:
                idName::Identity
                [idName1,idName2,idName3,...]::Identity
        **:Local**
            Local parameter with Float signature. It can represent the individual mass of each agent, its radius...
            It is declared individually for each agent so it can be updated with UpdateLocal types.
            Has to be declared as:
                localParameter::Local
                [localParameter1,localParameter2,localParameter3,...]::Local
        **:Variable**
            Variable with Float signature of the dynamical system.
            It is declared individually for each agent and they are evolved by Equation types.
            Has to be declared as:
                variable::Variable
                [variable1,variable2,variable3,...]::variable
        **:Global**
            Global parameter with Float signature. It can represent the temperature felt by all the agents...
            It is declared globally for all agents and can be updated with UpdateGlobal.
            Has to be declared as:
                globalParameter::Global
                [globalParameter1,globalParameter2,globalParameter3,...]::Global
        **:GlobalArray**
            Global array parameter with Float signature. It can represent the force or interaction matrix between different type of agents...
            It is declared globally for all agents and can be updated with UpdateGlobal.
            Has to be declared as:
                globalArrayParameter::GlobalArray = [dims1,dims2,...]
                [globalArrayParameter1,globalArrayParameter2,...]::GlobalArray = [dims1,dims2,...]
        **:Interaction**
            Parameter with float signature describing pairwise interactions between neighbours.
            It is declared globally for all agents and can be updated with UpdateLocalInteraction or UpdateInteraction.
            Has to be declared as:
            interactionParameter::Interaction
            [interactionParameter,interactionParameter,...]::Interaction
        **:Equation**
            Type for declaring dynamical equations for the variables.
            Has to be declared as:
            ::Equation = 
                begin
                    ... code including the differential equations ...
                end
            eqName::Equation = 
                begin
                    ... code including the differential equations ...
                end
        **:UpdateGlobal**
            Type for declaring global update rules for the global parameters and global arrays.
            Has to be declared as:
            ::UpdateGlobal = 
                begin
                    ... code including the update rules ...
                end
            globalUpdateName::UpdateGlobal = 
                begin
                    ... code including the update rules ...
                end
        **:UpdateLocal**
            Type for declaring local update rules for the local parameters and ids.
            Has to be declared as:
            ::UpdateLocal = 
                begin
                    ... code including the update rules ...
                end
            localUpdateName::UpdateLocal = 
                begin
                    ... code including the update rules ...
                end
        **:UpdateInteraction**
        Type for declaring interaction update rules for the interaction parameters. 
        The variables declared in these updates will be updated during the integration steps.
            Has to be declared as:
            ::UpdateInteraction = 
                begin
                    ... code including the update rules ...
                end
            interactionUpdateName::UpdateInteraction = 
                begin
                    ... code including the update rules ...
                end
        :UpdateLocalInteraction
        Type for declaring interaction update rules for the local parameters and ids. 
        The variables declared in these updates will be updated just once per time step instead of once per integration point. 
        For integrators that evaluate just once as the Euler integrator, UpdateInteraction and UpdateLocalInteraction are equivalent.
        Has to be declared as:
        interactionUpdateName::UpdateLocalInteraction = 
            begin
                ... code including the update rules ...
            end
    Output:
    Nothing
"""
macro agent(name, varargs...) 

    m = Model()

    if typeof(name) == Symbol
        m.name = name
    else
        error("name should be a symbol.")
    end

    #Add all contributions
    for i in varargs
        if typeof(i) != Expr
            error(i, " should be and expression containing at least a name and a type. Example variable::Variable.") 
        end
        
        if i.head == :(=)
            if i.args[1].head == :(::)
                if length(i.args[1].args) == 2
                    name = i.args[1].args[1]
                    type = i.args[1].args[2]
                    head = :(=)
                elseif length(i.args[1].args) == 1
                    name = :_
                    type = i.args[1].args[1]
                    head = :(=)
                end
            else
                error(i, " should be and expression containing at least a name and a type. Example variable::Variable.") 
            end
        elseif i.head == :(::)
            name = i.args[1]
            type = i.args[2]
            head = :(::)
        else
            error(i, " should be and expression containing at least a name and a type. Example variable::Variable.") 
        end

        if !(type in VALID_TYPES)
            error(i, " should be and expression containing at least a name and a type. Example variable::Variable.") 
        elseif typeof(name) == Expr
            if !(name.head == :vect)
                error(name, " should be a symbol or an array of symbols. Check how to declare ", type, " types.")
            else
                names = Symbol[]
                for j in name.args
                    if typeof(j) != Symbol
                        error(j, " in ", i, " should be a symbol.  Check how to declare ", type, " types.")
                    end
                    push!(names,j)
                end
                name = names
            end
        end

        if type == :Global && head == :(::)
            checkDeclared(m,name)
            if typeof(name) == Array{Symbol,1}
                append!(m.declaredSymbols["Global"],name)
            else
                push!(m.declaredSymbols["Global"],name)
            end
        elseif type == :Local && head == :(::)
            checkDeclared(m,name)
            if typeof(name) == Array{Symbol,1}
                append!(m.declaredSymbols["Local"],name)
            else
                push!(m.declaredSymbols["Local"],name)
            end
        elseif type == :Interaction && head == :(::)
            checkDeclared(m,name)
            if typeof(name) == Array{Symbol,1}
                append!(m.declaredSymbols["Interaction"],name)
            else
                push!(m.declaredSymbols["Interaction"],name)
            end
        elseif type == :Variable && head == :(::)
            checkDeclared(m,name)
            if typeof(name) == Array{Symbol,1}
                append!(m.declaredSymbols["Variable"],name)
            else
                push!(m.declaredSymbols["Variable"],name)
            end
        elseif type == :Identity && head == :(::)
            checkDeclared(m,name)
            if typeof(name) == Array{Symbol,1}
                append!(m.declaredSymbols["Identity"],name)
            else
                push!(m.declaredSymbols["Identity"],name)
            end
        elseif type == :GlobalArray && head == :(=)
            checkDeclared(m,name)
            arg = i.args[2]
            if typeof(arg) != Expr
                error(type , " in ", i, " has to be declared with an Array{Int} representing the dimensions.")
            elseif arg.head != :vect
                error(type , " in ", i, " has to be declared with an Array{Int} representing the dimensions.")
            else
                for j in arg.args
                    if !(typeof(j) <: Int)
                        error(type , " in ", i, " has to be declared with an Array{Int} representing the dimensions.")
                    end
                end
                if typeof(name) == Array{Symbol,1}
                    l = [(j,eval(arg)) for j in name]
                    append!(m.declaredSymbols["GlobalArray"],l)
                else
                    push!(m.declaredSymbols["GlobalArray"],(name,eval(arg)))
                end
            end
        elseif type == :UpdateGlobal && head == :(=)
            if typeof(i.args[2]) == Expr
                push!(m.declaredUpdates["Global"],(name,i.args[2]))
            else
                error(i , " should be declared with an expression. Type of ", i.args[2], " is ", typeof(i.args[2]),".") 
            end
        elseif type == :UpdateLocal && head == :(=)
            if typeof(i.args[2]) == Expr
                push!(m.declaredUpdates["Local"],(name,i.args[2]))
            else
                error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(i.args[2]),".") 
            end
        elseif type == :UpdateInteraction && head == :(=)
            if typeof(i.args[2]) == Expr
                push!(m.declaredUpdates["Interaction"],(name,i.args[2]))
            else
                error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(i.args[2]),".") 
            end
        elseif type == :UpdateLocalInteraction && head == :(=)
            if typeof(i.args[2]) == Expr
                push!(m.declaredUpdates["LocalInteraction"],(name,i.args[2]))
            else
                error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(i.args[2]),".") 
            end
        elseif type == :Equation && head == :(=)
            if typeof(i.args[2]) == Expr
                push!(m.declaredUpdates["Equation"],(name,i.args[2]))
            else
                error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(i.args[2]),".") 
            end
        else
           error("Expression ", i, " is not a valid expression. Check how to declare expressions of type ", type) 
        end
    end
        
    return m
end

"""
    macro add(varargs...)

Return a list of varargs as Expr.

Input:
    **varargs...**: Anything
Output:
    Array{Expr}
"""
macro add(varargs...)
    l = Expr[]
    for i in varargs
        push!(l,:($i))
    end

    return l
end

"""
    agent!(m::Model, var::Array{Expr})

Function to add more arguments after declaration to the agent model. Use @add to keep the code clean.

Input:
    **abm::Model**: Model to be extended
    **vararg::Expr**: Arguments to add to the model. See @agent to see valid arguments
Output:
    Nothing

```
m = @agent cell
agent!(m,
@add(
    l::Local,
    g::Global,
    ::UpdateLocal=
    begin
        l += dt
    end
)
)
```
"""
function agent!(m::Model, var::Array{Expr,1})

    #Add all contributions
    for i in var
        if typeof(i) != Expr
            error(i, " should be and expression containing at least a name and a type. Example variable::Variable.") 
        end
        
        if i.head == :(=)
            if i.args[1].head == :(::)
                if length(i.args[1].args) == 2
                    name = i.args[1].args[1]
                    type = i.args[1].args[2]
                    head = :(=)
                elseif length(i.args[1].args) == 1
                    name = :_
                    type = i.args[1].args[1]
                    head = :(=)
                end
            else
                error(i, " should be and expression containing at least a name and a type. Example variable::Variable.") 
            end
        elseif i.head == :(::)
            name = i.args[1]
            type = i.args[2]
            head = :(::)
        else
            error(i, " should be and expression containing at least a name and a type. Example variable::Variable.") 
        end

        if !(type in VALID_TYPES)
            error(i, " should be and expression containing at least a name and a type. Example variable::Variable.") 
        elseif typeof(name) == Expr
            if !(name.head == :vect)
                error(name, " should be a symbol or an array of symbols. Check how to declare ", type, " types.")
            else
                names = Symbol[]
                for j in name.args
                    if typeof(j) != Symbol
                        error(j, " in ", i, " should be a symbol.  Check how to declare ", type, " types.")
                    end
                    push!(names,j)
                end
                name = names
            end
        end

        if type == :Global && head == :(::)
            checkDeclared(m,name)
            push!(m.declaredSymbols["Global"],name)
        elseif type == :Local && head == :(::)
            checkDeclared(m,name)
            push!(m.declaredSymbols["Local"],name)
        elseif type == :Interaction && head == :(::)
            checkDeclared(m,name)
            push!(m.declaredSymbols["Interaction"],name)
        elseif type == :Variable && head == :(::)
            checkDeclared(m,name)
            push!(m.declaredSymbols["Variable"],name)                    
        elseif type == :Identity && head == :(::)
            checkDeclared(m,name)
            push!(m.declaredSymbols["Identity"],name)
        elseif type == :GlobalArray && head == :(=)
            checkDeclared(m,name)
            arg = i.args[2]
            if typeof(arg) != Expr
                error(type , " in ", i, " has to be declared with an Array{Int} representing the dimensions.")
            elseif arg.head != :vect
                error(type , " in ", i, " has to be declared with an Array{Int} representing the dimensions.")
            else
                for j in arg.args
                    if !(typeof(j) <: Int)
                        error(type , " in ", i, " has to be declared with an Array{Int} representing the dimensions.")
                    end
                end
                push!(m.declaredSymbols["GlobalArray"],(name,eval(arg)))
            end
        elseif type == :UpdateGlobal && head == :(=)
            if typeof(i.args[2]) == Expr
                push!(m.declaredUpdates["Global"],(name,i.args[2]))
            else
                error(i , " should be declared with an expression. Type of ", i.args[2], " is ", typeof(i.args[2]),".") 
            end
        elseif type == :UpdateLocal && head == :(=)
            if typeof(i.args[2]) == Expr
                push!(m.declaredUpdates["Local"],(name,i.args[2]))
            else
                error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(i.args[2]),".") 
            end
        elseif type == :UpdateInteraction && head == :(=)
            if typeof(i.args[2]) == Expr
                push!(m.declaredUpdates["Interaction"],(name,i.args[2]))
            else
                error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(i.args[2]),".") 
            end
        elseif type == :UpdateLocalInteraction && head == :(=)
            if typeof(i.args[2]) == Expr
                push!(m.declaredUpdates["LocalInteraction"],(name,i.args[2]))
            else
                error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(i.args[2]),".") 
            end
        elseif type == :Equation && head == :(=)
            if typeof(i.args[2]) == Expr
                push!(m.declaredUpdates["Equation"],(name,i.args[2]))
            else
                error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(i.args[2]),".") 
            end
        else
           error("Expression ", i, " is not a valid expression. Check how to declare expressions of type ", type) 
        end
    end

    return nothing
end