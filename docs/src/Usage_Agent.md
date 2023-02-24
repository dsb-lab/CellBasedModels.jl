```julia
using AgentBasedModels
```

# Defining an Agent model

The `Agent` structure contains all the information of a Agent Based model, their parameters and rules of evolution. There are four elements to take into account when defining agents:

 - **Parameters**. These can be splited in:
    - User-defined parameters: Parameters that are defined for the specific model that is being used.
    - Default parameters: Parameters that are defined for all models by default.
 - **Update rules**. Rules that describe the behavior of the agents during the course of time.
 - **Model inheritance**. More simple models over which we want to build more complex models.

Constructing an agent we use

```julia
Agent(dim,kwArgs...)
```
where `dim` is the only required argument of the model and defined the dimensionality of the agent and can take values 0-3. The `kwArgs` are keyword arguments that define the parameters, rules and base models of the present model and that will be seing in detail in the following.

## Parameters

The agents parameters have several scopes:

 - **Global**: Parameters that affect all the agents.
 - **Local**: Parameters have a different value for each agent.
 - **Medium**: Parameters that belong to the medium in which the model is embedded (if there is a medium defined for this model).

### Parameters - Default Parameters

By default, all agent models have a set of defined set of parameters. A list of the most relevant parameters for a user is:

|**Topic**|**Symbol**|**Scope**|**Description**|
|:---:|:---:|:---:|:---|
|**Time**|||
||t|Global|Absolute time of evolution of the community.|
||dt|Global|Time increments in each step of the evolution.|
|**Size Community**|||
||N|Global|The number of agents active in the community.|
||NMedium|Global|Size of the grid in which the medium is being computed. This is necessary to be declared if medium parameters are declared by the user.|
|**Id tracking**|||
||id|Local|Unique identifier of the agent.|
|**Simulation space**|||
||simBox|Global|Simulation box in which cells are moving. This is necessary to define a region of space in which a medium will be simulated or for computing neighbors with CellLinked methods.|
|**Neighbors**|||
||skin|Global|Distance below which a cell is considered a neighbor in Verlet neighbor algorithms.|
||dtNeighborRecompute|Global|Time before recomputing neighborhoods in VerletTime algorithm.|
||nMaxNeighbors|Global|Maximum number of neighbors. Necessary for Verlet-like algorithms.|
||cellEdge|Global|Distance of the grid used to compute neighbors. Necessary for CellLinked algorithms.|
|**Position**|||
||x|Local|Position of the agent in the x axis.|
||y|Local|Position of the agent in the y axis.|
||z|Local|Position of the agent in the z axis.|

There are more parameters predefined in the model. The other parameters however are used internaly for the package to work properly and should in rare case used directly by the user. A complete list can be seen in the definition of the `Community` structure in `API`. You can identify them because they have a lower underscore in the end of their name.

### Parameters - User defined parmaeters

Apart from the default parameters, the user can define any other parameters necessary for its model of the scopes above mentioned. In addition to the scope, the user has to define:

 - **Data type**. Data type of the parameter to be selected between:
   - **Int**
   - **Float**

 - **Behavior**. Behavior of the parameter that defines if the parameter has to be reset to zero before declaring an interaction. (It will become more clear when seeing the definition of Interaction Updates)
   - **(Default)** 
   - **Interaction**

Which this consideration, in the present implementation, the user can declare parameters of the following types:

| Agent kwArg | Comments |
|:---:|:---|
| `localInt` | |
| `localIntInteraction` | |
| `localFloat` | |
| `localFloatInteraction` | |
| `globalFloat` | |
| `globalInt` | |
| `globalFloatInteraction` | |
| `globalIntInteraction` | |
| `medium` | Implicitely is of dtype Float and (default). As medium models will be continuum models that evolve under PDE. |

User defined parameters will be declared using this keyword arguments and providing a vector of declared symbols.


```julia
agent = Agent(3,
                localFloat = [:a,:b],
                globalInt = [:c],
                globalFloatInteraction = [:gfi]
            )
```


    


    PARAMETERS
    	a (Float Local)
    	b (Float Local)
    	gfi (Float Global)
    	c (Int Global)
    
    
    UPDATE RULES


> **WARNING: User default parameters name convention** 
> 
> The is no rule to declare user-defined parameters but we advise that the names do not end with underscore (e.g. :a_). 
> This nomenclarute is in general used to name hidden parameters that are kept for internal use.

> **INFO Changing data type**
> 
> By default, Float types will be stored as `Float64` and Int types as `Int64` in CPU computations, and `32` format for GPU computations. 
> 
> If you want to change this formats, you can always change them redefining the corresponding entry of `AgentBasedModels.DTYPE`.
>
> ```julia
> >>>AgentBasedModels.DTYPE
> Dict{Symbol, Dict{Symbol, DataType}} with 2 entries:
>   :Float => Dict(:CPU=>Float64, :GPU=>Float32)
>   :Int   => Dict(:CPU=>Int64, :GPU=>Int32)
> ```
> Be aware that most part of GPU only work with 32 precission so changing this value may run into errors at execution time.

## Update Rules

After setting up the parameters of our agent, we can define the rules of evolution of our model and of recomputation.

An overview of the update rules and the special symbols that can be provided to a model are:

|Agent kwArg|Special Symbols|Special functions|Description|
|:---:|:---:|:---:|:---|
|`upateLocal`|`.new`|`addAgent(kwArgs...)`,`removeAgent()`|Define update rules that affect each agent independently.|
|`updateGlobal`|`.new`|`addAgent(kwArgs...)`|Define update rules that affect the global of a model.|
|`updateInteraction`|`.i`,`.j`||Compute interactions between pairs of neighbors.|
|`updateVariable`|`d()`,`dt()`,`dW()`||Define SDE or ODE rules to evolve local parameters of the agents independently.|

### Writting update rules

Update rules in agents is normal julia code that you can write in a simplified level and then, when constructing the `Agent` structure, the code will be vectorized and adapted to be run in the corresponding platform. 
In general any mathematical function from module `Base` and random 1D distributions from `Distributions.jl` will work, as well as any if, for, while and declarations and modification of variables. 
To provide a rule to the `Agent`, you will need to give the code to the `kwArg` in form of 

```julia
quote 
#code of update rule in here...
end
```

Let's see some examples to make it more clear.

## - Local Update

Local rules modify each agent independently. We write the code simply by calling the parameters declared, the contructor is in charge of transforming the code to construct the actual function.

All the basics of Julia code can be used to write in here. In addition, there are a couple of special functions:

 - `addAgent(kwArs...)`: Adds an agent to the `Community`. The `kwArgs` passed to the agent are the new values of the local parameters of the agent that is constructed. The local parmaeters that are not provided will be inherited from the agent that activated the macro.
 - `removeAgent()`: Removes the agent from the `Community`.

In addition you can use the operator `.new` to indicate that you want to use the value in the future of a parameter that has been updated.

**Example** We want to create and agent that, at each step:
 1. Makes a jump to left or right brought from a gaussian. 
 2. If the agent surpasses a certain limit in the left limit, is removed. 
 3. At random, with certain probability, it divides with a new parameter `l`.


```julia
model = Agent(1, #Dimensions of the model
    localFloat = [:l], #Declaration of a local parameter named l
    globalFloat = [
        :σ2,    #Spread of the gaussian
        :pDivision, #Global variable to set the probability at which it will divide
    ],
    updateLocal = quote
        x += Normal(0,σ2) #We can call to distributions from Distributions.jl that are 1D
        #We can make conditionals
        if x.new > simBox[1,2] #We can use the default parameter simBox to define where is the left margin at which cells are removed. 
            removeAgent()
        elseif pDivision < Uniform(0,1) #We can make conditionals
            addAgent(l = sin(Uniform(0,3*π))) #We add an agent that inherits x and initialize it with a new parameter l
        end
    end
)
```


    


    PARAMETERS
    	l (Float Local)
    	σ2 (Float Global)
    	pDivision (Float Global)
    
    
    UPDATE RULES
    UpdateLocal
     begin
        x.new += Normal(0, σ2)
        if x.new > simBox[1, 2]
            removeAgent()
        elseif pDivision < Uniform(0, 1)
            addAgent(l = sin(Uniform(0, 3π)))
        end
    end
    


> **NOTE: Use of the .new symbol** Obverse that, by default, the special symbol `.new` has been added wherever a user-defined parameter is reassigned to specify that this is the value at the future timepoint. 
>
> However, if you do not make explicit that asignement, the condition would look like in `x > simBox[1,2]`, using the old position.

You can see how the code looks like when you declare it in the dictionary field `Agent.declaredUpdates`. We use the function `prettify` to clean up the comment lines of the code and make the code more visible.


```julia
println(AgentBasedModels.prettify(model.declaredUpdates[:UpdateLocal]))
```

    begin
        x.new += Normal(0, σ2)
        if x.new > simBox[1, 2]
            removeAgent()
        elseif pDivision < Uniform(0, 1)
            addAgent(l = sin(Uniform(0, 3π)))
        end
    end


> **NOTE. Internals of Agent** When declaring an update rule, the code is transformed to low level code that can be executed afterwards with the object `Community`. You can see the final function(s) constructed after compilation in `Agent.DeclaredUpdatesCode`.
>> 
>> ```julia
>> println(AgentBasedModels.prettify(model.declaredUpdatesCode[:UpdateLocal_]))
>> ```
>
>> ```
>> (t, dt, N, NMedium, nMax_, id, idMax_, simBox, NAdd_, NRemove_, NSurvive_, flagSurvive_, holeFromRemoveAt_, repositionAgentInPos_, skin, dtNeighborRecompute, nMaxNeighbors, cellEdge, flagRecomputeNeighbors_, flagNeighbors_, neighborN_, neighborList_, neighborTimeLastRecompute_, posOld_, accumulatedDistance_, nCells_, cellAssignedToAgent_, cellNumAgents_, cellCumSum_, x, y, z, xNew_, yNew_, zNew_, varAux_, varAuxΔW_, liNM_, liM_, liMNew_, lii_, lfNM_, lfM_, lfMNew_, lfi_, gfNM_, gfM_, gfMNew_, gfi_, giNM_, giM_, giMNew_, gii_, mediumNM_, mediumM_, mediumMNew_)->@inbounds(Threads.@threads(for i1_ = 1:1:N[1]
>>                 flagSurvive_[i1_] = 1
>>                 xNew_[i1_] += AgentBasedModels.rand(AgentBasedModels.Normal(0, gfM_[1]))
>>                 if xNew_[i1_] > simBox[1, 2]
>>                     idNew_ = Threads.atomic_add!(NRemove_, (Int64)(1)) + 1
>>                     holeFromRemoveAt_[idNew_] = i1_
>>                     flagSurvive_[i1_] = 0
>>                     flagRecomputeNeighbors_[1] = 1
>>                     flagNeighbors_[i1_] = 1
>>                 elseif gfM_[2] < AgentBasedModels.rand(AgentBasedModels.Uniform(0, 1))
>>                     i1New_ = N[1] + Threads.atomic_add!(NAdd_, (Int64)(1)) + 1
>>                     idNew_ = Threads.atomic_add!(idMax_, (Int64)(1)) + 1
>>                     if nMax_[1] >= i1New_
>>                         flagNeighbors_[i1New_] = 1
>>                         id[i1New_] = idNew_
>>                         flagRecomputeNeighbors_[1] = 1
>>                         flagNeighbors_[i1New_] = 1
>>                         lfMNew_[i1New_, 1] = sin(AgentBasedModels.rand(AgentBasedModels.Uniform(0, 3π)))
>>                         xNew_[i1New_] = x[i1_]
>>                     else
>>                         Threads.atomic_add!(NAdd_, (Int64)(-1))
>>                     end
>>                 end
>>             end))
>> ```
>
> If you observe the compiled code carefully you can see how the code has been internally converted to the appropiate objects and steps.
>
>  ```julia
> @inbounds Threads.@threads for i1_ = 1:1:N[1] #Go over all agents in model
>                 flagSurvive_[i1_] = 1
>                 #x += Normal(0,σ2)
>                 xNew_[i1_] += AgentBasedModels.rand(AgentBasedModels.Normal(0, gfM_[1])) # symbol σ2 has been vectorized to the gfM_ (global float Modifiable ) array.
>                 if xNew_[i1_] > simBox[1, 2] # x.new > simBox[1,2]
>                     #removeAgent()
>                     idNew_ = Threads.atomic_add!(NRemove_, (Int64)(1)) + 1
>                     holeFromRemoveAt_[idNew_] = i1_
>                     flagSurvive_[i1_] = 0
>                     flagRecomputeNeighbors_[1] = 1
>                     flagNeighbors_[i1_] = 1
>                 elseif gfM_[2] < AgentBasedModels.rand(AgentBasedModels.Uniform(0, 1))
>                     #addAgent()
>                     i1New_ = N[1] + Threads.atomic_add!(NAdd_, (Int64)(1)) + 1
>                     idNew_ = Threads.atomic_add!(idMax_, (Int64)(1)) + 1
>                     if nMax_[1] >= i1New_
>                         flagNeighbors_[i1New_] = 1
>                         id[i1New_] = idNew_
>                         flagRecomputeNeighbors_[1] = 1
>                         flagNeighbors_[i1New_] = 1
>                         lfMNew_[i1New_, 1] = sin(AgentBasedModels.rand(AgentBasedModels.Uniform(0, 3π)))
>                         xNew_[i1New_] = x[i1_]
>                     else
>                         Threads.atomic_add!(NAdd_, (Int64)(-1))
>                     end
>                 end
>             end
> ```
>

## - Global Update

Global rules are used to modify global parameters of the model. 

There is a special function:

 - `addAgent(kwArs...)`: Adds an agent to the `Community`. The `kwArgs` passed to the agent are the values of the local parameters of the agent that is constructed. Contrary to the `addAgent` defined in `updateLocal`, all local parmaeters of the agent has to be specified.

Similarly to Local, the marker `.new` indicates if you want to use the current parameter or the value in the future.

**Example** Freeze the agents. Imagine that if certain time is met, we want to freeze all the agents that we described in local. One of the ways we can do it is by setting the jump to zero.



```julia
model = Agent(1, #Dimensions of the model
    localFloat = [:l],
    globalFloat = [
        :σ2, 
        :pDivision,
    ],
    globalInt = [:freeze], #Add the constant freeze
    updateLocal = quote
        x += freeze*Normal(0,σ2) 
        if x.new > simBox[1,2]
            removeAgent()
        elseif pDivision < Uniform(0,1)
            addAgent(l = sin(Uniform(0,3*π)))
        end
    end,
    updateGlobal = quote #Set freeze to zero at some point
        if t < 10.
            freeze = 1
        else
            freeze = 0
        end
    end
)
```


    


    PARAMETERS
    	l (Float Local)
    	σ2 (Float Global)
    	pDivision (Float Global)
    	freeze (Int Global)
    
    
    UPDATE RULES
    UpdateGlobal
     if t < 10.0
        freeze.new = 1
    else
        freeze.new = 0
    end
    
    UpdateLocal
     begin
        x.new += freeze * Normal(0, σ2)
        if x.new > simBox[1, 2]
            removeAgent()
        elseif pDivision < Uniform(0, 1)
            addAgent(l = sin(Uniform(0, 3π)))
        end
    end
    


# - Interaction Update

Interaction update are set to compute parameters that need to be computed running through all neighbors of agents (e.g. the force of repulsion between agents). The force will be set as,

$$f_i = \sum_{j\in \mathcal{N}_i} F(x_i,x_j)$$
where $i$ goes over all the agents and $j$ goes over all the neighbors of agent $i$. 

There is three things to have in consideration:

 - Interaction parameters are recomputed each time that we want to compute a new interaction and hence have to be reinitialized. We hence need to define them as `scopeDtyeInteraction`. In this way, the package will know that they have to be set to zero before computing them.
 - Since the interaction go over all agents and all the neighbors of agents, we need to specify in the code declared if we are using a parameter of the agent with an `.i` or a neighbor with a `.j`.
 - There computation goes over the neighbors of the agent. There are different algorithms implemented to keep track of the neighbors and that may matter tot the speed of the simulations. You can choose the neighborhood algorithm with the argument `neighbors`. See a comparative of neighbor algorithms in the examples section.

|Implemented Neighbor algorthms|Description|
|:---:|:---|
|Full|Compute all the interactions among all pairs.|
|VerletTime|Compute a Verlet List and update it at fixed times.|
|VerletDistances|Compute a Verlet List and update it when some cell overpasses certain limit.|
|CellLinked|Assign cells to a matrix and compute neighbors of neighboring cells only.|
|CLVD|Combination of CellLinked and VerletDistances, it uses CellLinked to compute the VerletLists|

**Example** We want to compute mean euclidean distance of an agent to all its neighbors in a specific radius of distance.


```julia
model = Agent(3,
    globalFloat = [:dist], #Maximum distance to compute neighbor distance
    localFloatInteraction = [:mDis], #Interaction variable where to store the mean distance
    localIntInteraction = [:nNeighs], #Number of neighbors that the agent has
    updateInteraction = quote
        d = euclideanMetric(x.i,x.j,y.i,y.j,z.i,z.j) #Using euclidean matric provided in package
        if d < dist
            nNeighs.i += 1 #Add 1 to neighbors
            mDist.i = (mDist.i*(nNeighs.i-1) + d)/nNeighs.i
        end
    end,
    neighbors = :Full, #specifying neighbor algorithm
)
```


    


    PARAMETERS
    	nNeighs (Int Local)
    	mDis (Float Local)
    	dist (Float Global)
    
    
    UPDATE RULES
    UpdateInteraction
     begin
        d = euclideanMetric(x.i, x.j, y.i, y.j, z.i, z.j)
        if d < dist
            nNeighs.i += 1
            mDist.i = (mDist.i * (nNeighs.i - 1) + d) / nNeighs.i
        end
    end
    


## - Variable Update

An alternative to a local update for continuous local parameters is to define differential equations that describe the evolution of the parameter. 

Again, we can write anything we need in normal julia code. When writting an equation, it will be very similar to writting a SDE equation:

$$dx = f(x,t) dt + g(x,t) dW$$

The equations have to be written as:

```julia
d(localParameter) = dt(deterministicContrubution)
d(localParameter) = dW(stochasticContribution)
d(localParameter) = dt(deterministicContrubution) + dW(stochasticContribution)
```

The integration method of the equations can be chosen specifying the `integrator` argument.

|Implemented Integrators|
|:---:|
|Euler|
|Heun|
|RungeKutta4|

**Example** [Ornstein–Uhlenbeck](https://en.wikipedia.org/wiki/Ornstein%E2%80%93Uhlenbeck_process) process.


```julia
model = Agent(2,
    globalFloat = [
        :σ, #Diffussion constant
        :Θ  #Drifft force
    ],
    updateVariable = quote
        d(x) = dt(-θ*x)+dW(σ)
        d(y) = dt(-θ*y)+dW(σ)
    end,
    integrator = :Heun
)
```


    


    PARAMETERS
    	σ (Float Global)
    	Θ (Float Global)
    
    
    UPDATE RULES
    UpdateVariable
     begin
        d(x) = dt(-θ * x) + dW(σ)
        d(y) = dt(-θ * y) + dW(σ)
    end
    


## Model inheritance

The above set of parameters and rules can be used to define all type of agent models. Once we have a developed a model, we can extend the model with additional rules and parameters. This allows to contruct the models in a modular maner.

There are two keyword parameters in the structure `Agent` for doing that:

 1. `baseModelInit`: Models whose rules apply before the rules of the present Agent model.
 2. `baseModelEnd`: Models whose rules apply after the rules of the present Agent model.

The models provided will be concatenated in order of declaration.

**Example** Let's make modular the random walker and boundary conditions of the example provided in **Local** and **Global** updates.


```julia
modelWalker = Agent(1, #Dimensions of the model
    globalFloat = [
        :σ2, 
    ],
    globalInt = [:freeze], #Add the constant freeze
    updateLocal = quote
        x += freeze*Normal(0,σ2) 
    end,
)

modelBoundaries = Agent(1, #Dimensions of the model
    localFloat = [:l],
    globalFloat = [
        :pDivision,
    ],
    updateLocal = quote
        if pDivision < Uniform(0,1)
            addAgent(l = sin(Uniform(0,3*π)))
        elseif x.new > simBox[1,2]
            removeAgent()
        end

    end,
)

modelFreeze = Agent(1, #Dimensions of the model
    updateGlobal = quote #Set freeze to zero at some point
        if t < 10.
            freeze = 1
        else
            freeze = 0
        end
    end
)

modelFull = Agent(1,
    baseModelInit = [
        modelWalker,
        modelBoundaries,
        modelFreeze
        ]
)
```


    


    PARAMETERS
    	σ2 (Float Global)
    	freeze (Int Global)
    	l (Float Local)
    	pDivision (Float Global)
    
    
    UPDATE RULES
    UpdateGlobal
     if t < 10.0
        freeze.new = 1
    else
        freeze.new = 0
    end
    
    UpdateLocal
     begin
        x.new += freeze * Normal(0, σ2)
        if pDivision < Uniform(0, 1)
            addAgent(l = sin(Uniform(0, 3π)))
        elseif x.new > simBox[1, 2]
            removeAgent()
        end
    end
    


As you can see the fumm model is the same as the model that we declared with all the rules together.
