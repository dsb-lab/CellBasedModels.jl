# Usage

In the steps we will go over the steps for constructing and evolving an agent based model.

## Defining Agent Properties

The creation of models is based on the macro `@agent`.

The unique parameter compoulsory required by the agent model is a name of the agent.

```julia
m = @agent(agentName)
```

In addition to the name, there are three types of pieces of code that can be included in the model:

### Parameter declaration

With this special characters, we define all the parameters that a model may have.

 - **Local**: These are continuous parameters that are assigned independently to each agent.
 - **Identity**: These parameters are discrete parameters that are assigned to a each agent.
 - **Global**: Parameters that are shared by all the agents.
 - **GlobalArray**: Parameters in terms of array formats that are shared by all agents.

The parameters can be declared individually of collect them in an array declaration.

```julia
m = @agent(agentName,
    local1::Local,
    local2::Local,

    id1::Identity,
    id2::Identity,

    glob1::Global,
    glob2::Global,

    array1::GlobalArray,
    array2::GlobalArray
)
```
or equivalently,

```julia
m = @agent(agentName,
    [local1,local2]::Local,

    [id1,id2]::Identity,

    [glob1,glob2]::Global,

    [array1,array2]::GlobalArray
)
```

!!! warning "Already Declared Parameters"
    All the agents already include a few parameters by default that can be used:
     - **t::Global**: Absolute time of the model incremented at each integration step.
     - **dt::Global**: Step of the time integration.
     - **dW::Local**: Step of the Stochastic Term.
     - **N::Global**: Number of particles in the model at the present time.
     - **idAgent::Identity**: Identification number of each agent.

    Although this variables can be accessed freely by the programer, it is only advised to use them as **read only** parameters and not modify them for the correct evolution of the program. The program will inerently use and modify them when evolving the system.

!!! tip "Parameter Names"
    In principle, except for a handful of restricted parameter names that are used internally, any parameter name can be used. However, AgentBasedModels.jl works with a reasonable amount of metaprograming and, although it has been throughfully tested, it can have some unexpected behaviours depending on how to declare variables. It is advised to follow these not-too-restrictive guidelines for being extremely safe:
     - Define parameters with starting lower-case format (`variable` instead of `Variable`). As in the Julia guidelines these variables are by convention for Modules and Structures.
     - Avoid finishing the variable name with an underscore (`variable` instead of `variable_`). As in the Julia guidelines these variables are by convention private variables.
    It shouldn't be a problem at all and you can be perfectly skiping those recomendations, really, but code is never bullet proof and for sure will avoid unexpected and nasty bugs in that very rare situation when the program crashes for some unpredicted reason.

### Updating rules

All the declared parameters of the model and of each agent may change in time. For that, we use Update rules. All update rules are defined as:

```julia
m = @agent(agentName,

    Update_type = SOMERULE

)
```
if is a very simple rule that can be put in a line, or

```julia
m = @agent(agentName,

    Update_type = begin
        SOMERULES
    end
)
```

 - **UpdateLocal**: Includes updates that will be performed at every time step on each agent independently.

Example.
```julia
m = @agent(agentName,
    local1::Local,

    UpdateLocal = begin
        if local1 > t #At each step, check if local1 is over the time and if so, increase the step.
            local1 += Uniform(1,2)
        end
    end
)
```

 - **UpdateGlobal**: Includes updates that will be performed at every time step on each agent independently.

 Example.
```julia
m = @agent(agentName,
    glob1::Global,
    globA1::GlobalArray,

    UpdateGlobal = begin
        glob1 += dt
        globA1[1,1] += 3 
    end
)
```

 - **Equation**: Pecific local update rule for the definition of ODE ans SDE systems of equations governing the dynamics of the agents. Equations accept both ODE and SDE systems of equations. Each equation is defined by using the special symbols `d_` in front the the differential variable, `dt` for deterministic component and `dW` for the stochastic term.

 Example: Consider a 2D [Ornstein–Uhlenbeck process](https://en.wikipedia.org/wiki/Ornstein%E2%80%93Uhlenbeck_process) with asymmetric difussivity. The system of equations would look like:

$$dx = -xdt + \sqrt{D_x}dW$$
$$dy = -ydt + \sqrt{D_y}dW$$

```julia
m = @agent(agentName,
    [x,y]::Local,
    [Dx,Dy]::Global,

    Equation = begin
        d_x = -x*dt + sqrt(Dx)*dW
        d_y = -y*dt + sqrt(Dy)*dW
    end
)
```

 - **UpdateLocalInteraction**: Define the rules for interacting agents one in each integration step. In these rules, local and identity parameters of two agents will be used. To differentiate the parameters of which agent we are using, we use the notation `_i` to indicate the agent we are updating the rules and `_j` for the other agents interacting with the agent being updated. This notation resembles the notation of a contracting index $x_i=\sum_jx_{ij}$.

 Example, consider that an agent flips between an stressed or an unstressed state depending on the number of neighbours that it has around. We will define such a rule as,

```julia
m = @agent(agentName,
    x::Local,
    n::Identity, #Keep the number of neighbours
    stressed::Identity #0 not stressed, 1 stressed 

    UpdateLocalInteraction = begin
        if abs(x_i - x_j) < 3. #If agent j is in some neighbourhood of i
            n += 1
            if n > 5
                stressed = 1
            else
                stressed = 0
            end
        end
    end
)
```

!!! warning "Interaction Parameter Erasing Behaviour"
    By default, all local and identity **parameters that are modified using an [updating operator](https://docs.julialang.org/en/v1/manual/mathematical-operations/#Updating-operators) are set to zero** before the UpdateLocalInteraction and the UpdateInteraction rules happen.** This is intended as, in most part of the cases, want an continuous increase of the operator. In the example above, for example, we want to count every step how many neighbours we have with the parameter `n`, not that this increases every time.

    In case that we would like to not erase the parameter before the update rule, use instead the expanded version of the update operator** : `n = n + 1`. This will prevent the program to detect it as an interacting operator and will not erase it before the computation.


 - **UpdateInteraction**: Define the rules of interacting terms and other rules of interaction between agents. The difference with the UpdateLocalInteraction rules is that these interactions will be computed for every intermediate step of the integrtion rule (Euler integration a one step integrator, Heun's method uses two evaluations before computing the final step). The same notation as for the UpdateLocalInteraction applies here.

 Consider the example of a dynamical system consisting of interacting particles of the form:

$$\dot{x}_i = g + l_i + \sum_jf(x_i,x_j)$$
where $x$ is a variable, $g$ a global parameter, $l$ is a local parameter, and $sum_j f(x_i,x_j)$ is a sum over the pairwise forces between particles. The sum contracts the index $j$, so the contribution of interactions are effectively defined by a local parameter $int_i=\sum_jf(x_i,x_j)$. The update of the local parameter $int_i$ will be defined as an interaction term.

```julia
m = @agent(agentName,
    [x,l,int]::Local,
    [g]::Global,

    Equation = begin
        d_x = g*dt + l*dt + int*dt
    end

    UpdateInteraction = begin
        int_i += f(x_i,x_j)
    end
)
```

### Events

Events are sets of rules that change the total number of agents in a simulation.

## Definging a Simulation Space

## Compilation

## Initialising the model

## Debugging Tips

