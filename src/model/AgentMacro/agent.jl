abstract type Id end
abstract type Local end
abstract type Variable end
abstract type Global end
abstract type GlobalArray end
abstract type Interaction end
abstract type UpdateGlobal end
abstract type UpdateLocal end
abstract type UpdateLocalInteraction end
abstract type UpdateInteraction end
abstract type Equation end

validTypes = [
    :Id,
    :Local,
    :Variable,
    :Global,
    :GlobalArray,
    :Interaction,

    :UpdateGlobal,
    :UpdateLocal,
    :UpdateLocalInteraction,
    :UpdateInteraction,
    :Equation
]

"""
    function agent!(abm::Model, varargs::Expr...) 

Basic Macro to grow an instance of Model. It generates an Agent type with the characteristics specified in its arguments.

Input:
    *abm::Model*: Agent based model.
    *varargs::Expr*: Arguments describing all the parameters, update rules and other properties of the agent. 
                The diferent types can be declared more than once. Valid types are: 
        **:Id**
            Parameter with Int signature that can be used to identify individually each agent in the model, its an agent type...
            It is declared individually for each agent so it can be updated with UpdateLocal types.
            Has to be declared as:
                idName::Id
                [idName1,idName2,idName3,...]::Id
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
            eqName::Equation = 
                begin
                    ... code including the differential equations ...
                end
        **:UpdateGlobal**
            Type for declaring global update rules for the global parameters and global arrays.
            Has to be declared as:
            globalUpdateName::UpdateGlobal = 
                begin
                    ... code including the update rules ...
                end
        **:UpdateLocal**
            Type for declaring local update rules for the local parameters and ids.
            Has to be declared as:
            localUpdateName::UpdateLocal = 
                begin
                    ... code including the update rules ...
                end
        **:UpdateInteraction**
        Type for declaring interaction update rules for the interaction parameters. 
        The variables declared in these updates will be updated during the integration steps.
            Has to be declared as:
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
function agent(m::model, varargs::Expr...) 
    
    #Add all contributions
    for i in varargs
        if typeof(i) != Expr
            error(i, " should be and expression containing at least a name and a type. Example variable::Variable.") 
        end
        
        if i.head == :(=)
            if i.args[1].head == :(::)
                name = i.args[1].args[1]
                type = i.args[1].args[2]
                head = :(=)
            else
                error(i, " should be and expression containing at least a name and a type. Example variable::Variable.") 
            end
        elseif i.head == :(::)
            name = i.args[1].args[1]
            type = i.args[1].args[2]
            head = :(::)
        else
            error(i, " should be and expression containing at least a name and a type. Example variable::Variable.") 
        end

        if !(type in validTypes)
            error(i, " should be and expression containing at least a name and a type. Example variable::Variable.") 
        elseif typeof(name) == Expr
            if !(name.head == :vect)
                error(name, " should be a symbol or an array of symbols. Check how to declare ", type, " types.")
            else
                for j in name.args
                    if typeof(j) != Symbol
                        error(j, " in ", i, " should be a symbol.  Check how to declare ", type, " types.")
                    end
                end
            end
        end

        if type == :Global && head == :(::)
            AgentBasedModels.checkDeclared(m,name)
            push!(m.declaredSymb["global"],name)
        elseif type == :Local && head == :(::)
            AgentBasedModels.checkDeclared(m,name)
            push!(m.declaredSymb["local"],name)
        elseif type == :Interaction && head == :(::)
            AgentBasedModels.checkDeclared(m,name)
            push!(m.declaredSymb["interaction"],name)
        elseif type == :Variable && head == :(::)
            AgentBasedModels.checkDeclared(m,name)
            push!(m.declaredSymb["variable"],name)                    
        elseif type == :Id && head == :(::)
            AgentBasedModels.checkDeclared(m,name)
            push!(m.declaredSymb["identity"],name)
        elseif type == :GlobalArray && head == :(=)
            AgentBasedModels.checkDeclared(m,name)
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
                push!(m.declaredSymb["globalArray"],(name,eval(arg)))
            end
        elseif type == :UpdateGlobal && head == :(=)
            if typeof(i.args[2]) == Expr
                push!(m.declaredUpdate["global"],i.args[2])
            else
                error(i , " should be declared with an expression. Type of ", i.args[2], " is ", typeof(i.args[2]),".") 
            end
        elseif type == :UpdateLocal && head == :(=)
            if typeof(i.args[2]) == Expr
                push!(m.declaredUpdate["local"],i.args[2])
            else
                error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(i.args[2]),".") 
            end
        elseif type == :UpdateInteraction && head == :(=)
            if typeof(i.args[2]) == Expr
                push!(m.declaredUpdate["interaction"],i.args[2])
            else
                error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(i.args[2]),".") 
            end
        elseif type == :UpdateLocalInteraction && head == :(=)
            if typeof(i.args[2]) == Expr
                push!(m.declaredUpdate["localInteraction"],i.args[2])
            else
                error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(i.args[2]),".") 
            end
        elseif type == :Equation && head == :(=)
            if typeof(i.args[2]) == Expr
                push!(m.declaredUpdate["equation"],i.args[2])
            else
                error(i , " should be declared with an expression. Type of ", i.args[2], " is ",typeof(i.args[2]),".") 
            end
        else
           error("Expression ", i, " is not a valid expression. Check how to declare expressions of type ", type) 
        end
    end
        
end

"""
    function agent(name::Symbol, varargs::Expr...) 

It creates an Agent type with the characteristics specified in its arguments by calling @Agent!.

Input:
    **name::Symbol** A Symbol with the name of the agent. e.g. cell::Name
    **varargs::Expr** Properties of the model. Check @Agent! for the valid arguments to pass.
Output:
    Instance of Model with the defined properties.
"""
function agent(name::Symbol, varargs::Expr...)

    m = Model()

    m.name = name

    Agent!(m, varargs...)

    return m
end