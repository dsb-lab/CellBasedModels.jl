# Usage


```julia
using AgentBasedModels
```

## Constructing an AgentBasedModel

The most basic structure will be to define an agent and its properties.

### Default parameters

The Agent model has already defined some parameters that can be used by the user. These are:

 - `t`: The time of evolution.
 - `dt`: The step time between updates.
 - `N`: The number of agents.
 - `id`: The id numer of an agent.
 - `simulationBox`: The line, square or cube of simulation.
 - [`x`,`y`,`z`]: The position variables of the agent. Since we declared a model with 3 dimensions, we have all three.


```julia
agent = Agent(3)
```




    



    PARAMETERS
    	t	dt	N	id	simulationBox	x	y	z
    
    UPDATE RULES


### User defined parameters

Apart from the default parameters, the user can define any other parameters necessary for its model.

In the present, the user can declare parameters of the following types:

 - `localInt`
 - `localIntInteraction`
 - `localFloat`
 - `localFloatInteraction`
 - `globalFloat`
 - `globalInt`
 - `globalFloatInteraction`
 - `globalIntInteraction`
 - `medium`

This types are:

 - `local`, `global` or `medium` depending if the parameter is a property the agent, the whole community or the medium.
 - `Int` or `Float` if the parameter should be an integer or a float.
 - `Interaction` if the parameter has to be reset to zero before each step (we will see in more detail this property when explaining interaction rules).

 As you will see, the parameter `medium` does not incorporate any specification of the type. This is because AgentBasedModels only allow mediums based on partial derivatives and thus, only Float mediums are allowed.


```julia
agent = Agent(3,
                localFloat = [:a,:b],
                globalInt = [:c],
                globalFloatInteraction = [:gfi]
            )
```




    



    PARAMETERS
    	t (Global Float)
    	dt (Global Float)
    	N (Global Int)
    	id (Local Int)
    	simulationBox (SimulationBox Float)
    	x (Local Float)
    	y (Local Float)
    	z (Local Float)
    	a (Local Float)
    	b (Local Float)
    	gfi (Global Float)
    	c (Global Int)
    
    
    UPDATE RULES


### Changing data type

By default, Float types will be stored as `Float64` and Int types as `Int64` in CPU computations, and `32` format for GPU computations. 

If you would need to change this formats, you can always change them redefining the constants:


```julia
AgentBasedModels.FLOAT
```




    Dict{Symbol, DataType} with 2 entries:
      :CPU => Float64
      :GPU => Float64




```julia
AgentBasedModels.INT
```




    Dict{Symbol, DataType} with 2 entries:
      :CPU => Int64
      :GPU => Int32




```julia
### Local Updates
```

## Constructing a Community

Once we have set up the parameters and rules of our agents, we need to create an initial community of agents.

### Creating a Community

We construct a set of agents calling the structure `Community`.


```julia
community = Community(agent,N=10)
```




    



    Community with 10 agents.


### Accessing and setting community parameters

We can easily access any of the parameters of the agent as a property of the created Community object.

To retrieve a property:


```julia
community.x
```




    10-element Vector{Float64}:
     0.0
     0.0
     0.0
     0.0
     0.0
     0.0
     0.0
     0.0
     0.0
     0.0



Take into account that global variables are stored as vectors of dimension 1 and will be returned the same way.


```julia
community.N
```




    1-element Vector{Int64}:
     10



And to set a property:


```julia
community.x = rand(10) 
community.x
```




    10-element Vector{Float64}:
     0.14895388170521273
     0.5288329863151697
     0.09828923662495748
     0.16229456278643783
     0.4317789778074792
     0.4351312496814155
     0.46845523272652123
     0.8666695756502663
     0.6871995041321248
     0.7844502348448836




```julia
community.c = 2
community.c
```




    1-element Vector{Int64}:
     2



## Preparing a community to be evolved

The last step before being able to evolve a community is to load the community to the corresponding computational platform.

For doing that we only need to call the function `loadToPlatform!`.


```julia
loadToPlatform!(community,addAgents=10)
```

## Evolve a community
