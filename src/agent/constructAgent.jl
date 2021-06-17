"""
    macro @agent(name, varargs...) 

Basic Macro to create an instance of Agent. It generates an Agent type with the characteristics specified in its arguments.

The only compulsory input is the name of the agent.
 - **name**: Name of agent.    
 
Then you can add an arbitrary set of additional parameters and rules for the agent. 
    
# Parameter Types

 - **:Local**
Local parameter with Float signature. It can represent the individual mass of each agent, its radius...
It is declared individually for each agent so it can be updated with UpdateLocal types.
Has to be declared as:

    localParameter::Local
    [localParameter1,localParameter2,localParameter3,...]::Local

 - **:Identity**
Parameter with Int signature that can be used to identify individually each agent in the model, its an agent type...
It is declared individually for each agent so it can be updated with UpdateLocal types.
Has to be declared as:

    idName::Identity
    [idName1,idName2,idName3,...]::Identity

 - **:Global**
Global parameter with Float signature. It can represent the temperature felt by all the agents...
It is declared globally for all agents and can be updated with UpdateGlobal.
Has to be declared as:

    globalParameter::Global
    [globalParameter1,globalParameter2,globalParameter3,...]::Global

 - **:GlobalArray**
Global array parameter with Float signature. It can represent the force or interaction matrix between different type of agents...
It is declared globally for all agents and can be updated with UpdateGlobal.
Has to be declared as:

    globalArrayParameter::GlobalArray = [dims1,dims2,...]
    [globalArrayParameter1,globalArrayParameter2,...]::GlobalArray = [dims1,dims2,...]

# Update rules

 - **:Interaction**
Parameter with float signature describing pairwise interactions between neighbours.
It is declared globally for all agents and can be updated with UpdateLocalInteraction or UpdateInteraction.
Has to be declared as:

    interactionParameter::Interaction
    [interactionParameter,interactionParameter,...]::Interaction

 - **Equation**
Type for declaring dynamical equations for the variables.
Has to be declared as:

    Equation = 
        quote
            ... code including the differential equations ...
        end

 - **UpdateGlobal**
Type for declaring global update rules for the global parameters and global arrays.
Has to be declared as:

    UpdateGlobal = 
        quote
            ... code including the update rules ...
        end

 - **UpdateLocal**
Type for declaring local update rules for the local parameters and ids.
Has to be declared as:

    UpdateLocal = 
        quote
            ... code including the update rules ...
        end

 - **UpdateInteraction**
Type for declaring interaction update rules for the interaction parameters. 
The variables declared in these updates will be updated during the integration steps.
Has to be declared as:
    
    UpdateInteraction = 
        quote
            ... code including the update rules ...
        end

 - **UpdateLocalInteraction**
Type for declaring interaction update rules for the local parameters and ids. 
The variables declared in these updates will be updated just once per time step instead of once per integration point. 
For integrators that evaluate just once as the Euler integrator, UpdateInteraction and UpdateLocalInteraction are equivalent.
Has to be declared as:
        
    UpdateLocalInteraction = 
        quote
            ... code including the update rules ...
        end

# Custom made blocks of code

Any function which returns a piece of code with the structue as the above declared is valid for declaration. This allows repetitive algorithms to be reused and allow a fluent customization.

```
function localWithIncrements(variable,step)
    return quote
        \$variable::Local

        UpdateLocal = \$variable += \$step
    end
end

@agent(
    Agent, #Name of the agent

    l1::Local,

    localWithIncrement(:b)
)

```
"""
macro agent(name, varargs...) 

    m = Agent()

    if typeof(name) == Symbol
        m.name = name
    else
        error("name of agent should be a symbol, not an expression. ", name, " was given.")
    end

    #Add all contributions
    for ii in varargs
        if typeof(ii) != Expr
            error(ii, " should be and expression containing at least a name and a type. Example variable::Variable.") 
        end

        if ii.head == :call
            t = eval(ii)
            if typeof(t) != Expr
                error("Function ", ii, " should return a piece of code to be added to the agent.")
            elseif t.head != :block
                t = quote $t end
            end

            t = t.args
        else 
            t = [ii]
        end

        for i in t
            if typeof(i) == LineNumberNode
                nothing
            elseif i.head == :(::)
                name = i.args[1]
                type = i.args[2]

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

                checkDeclared_(m,name)
                if typeof(name) == Array{Symbol,1}
                    append!(m.declaredSymbols[string(type)],name)
                else
                    push!(m.declaredSymbols[string(type)],name)
                end

            elseif i.head == :(=)
                if i.args[1] in VALID_UPDATES
                    if i.args[2].head == :block
                        append!(m.declaredUpdates[string(i.args[1])].args,i.args[2].args)
                    else
                        push!(m.declaredUpdates[string(i.args[1])].args,i.args[2])
                    end
                else
                    error(i.args[1], " is not a valid type.")
                end
            else
                error(i, " is not an understood rule or variable declaration. Error in ", ii)
            end 
        end
    end
        
    return m
end

"""
    function add(name,varags...)

Function that takes the arguments of the different agents and add them in a single agent if no overlapping between parameters exist. 
Useful when combining different blocks of code or models that are tested separately.

Example
```
    local = @agent(
        mechanics,

        l1::Local,

        UpdateLocal = l1 += 1
    )

    global = @agent(
        mechanics,

        g1::Global,

        Global = g1 += 1
    )

    jointModel = add(:JointModelName,local,global)

```
"""
function add(name::Symbol,varags::Agent...)
    main = @agent name

    if length(varags) == 1
        nothing
    else
        for i in varags
            for j in keys(i.declaredSymbols)
                checkDeclared_(main,i.declaredSymbols[j])
                append!(main.declaredSymbols[j],i.declaredSymbols[j])
            end
            for j in keys(i.declaredUpdates)
                append!(main.declaredUpdates[j].args,i.declaredUpdates[j].args)
            end
        end
    end

    return main
end