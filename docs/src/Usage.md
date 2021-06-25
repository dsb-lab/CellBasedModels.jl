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

!!! tip "Already declared parameters"
    All the agents already include a few parameters by default that can be used:
     - **t::Global**: Absolute time of the model incremented at each integration step.
     - **dt::Global**: Step of the time integration.
     - **N::Global**: Number of particles in the model at the present time.
     - **idAgent::Identity**: Identification number of each agent.

    Although this variables can be accessed freely by the programer, it is only advised to use them as **read only** parameters and not modify them for the correct evolution of the program. The program will inerently use and modify them when evolving the system.

!!! tip "Parameter Names"
    In principle, except for a handful of restricted parameter names that are used internally, any parameter name can be used. However, AgentBasedModels.jl works with a reasonable amount of metaprograming and, although it has been throughfully tested, it can have some unexpected behaviours depending on how to declare variables. It is advised to follow these not-too-restrictive guidelines for being extremely safe:
     - Define parameters with starting lower-case format (`variable` instead of `Variable`).
     - For compount name variables, avoid underscores and connect with capitals (`compoundName` instead of `compound_Name`).
    It shouldn't be a problem at all and you can be perfectly skiping those recomendations, really, but code is never bullet proof and for sure will avoid unexpected and nasty bugs in that very rare situation when the program crashes for some unpredicted reason.

### Updates rules

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

 - **Equation**: Define the evolution of a local parameter that acts as a continous variable. Equations accept both ODE and SDE systems of equations. Each equation is defined by using the special symbols `d_` in front the the differential variable, `dt` for deterministic component and `dW` for the stochastic term.

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

 - **UpdateInteraction**: Define pairwise 

## Definging a Simulation Space

## Compilation

## Initialising the model

## Debugging Tips

