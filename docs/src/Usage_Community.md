```julia
using CellBasedModels
```

# Creating and evolving a Community

The `Community` structure contains the realization of an agent model. This structure will store the parameters of the agent and will be prepared to be evolved by the update rules defined.

Let's use for reference the [Ornstein–Uhlenbeck](https://en.wikipedia.org/wiki/Ornstein%E2%80%93Uhlenbeck_process) process.


```julia
model = ABM(2,
    model = Dict(
        :σ => Float64, #Diffussion constant
        :theta => Float64  #Drifft force
    ),
    agentODE = quote
        dt(x) = -theta*x
        dt(y) = -theta*y
    end,
    agentSDE = quote
        dt(x) = σ
        dt(y) = σ
    end,
    agentAlg = DifferentialEquations.EM(), #Let's use an algorithm from DifferentialEquations suite
)
```

    PARAMETERS
    	x (Float64 agent)
    	y (Float64 agent)
    	σ (Float64 model)
    	theta (Float64 model)
    
    
    UPDATE RULES
    agentSDE
     begin


    


    
        dt__x = σ
        dt__y = σ
    end
    
    agentODE
     begin
        dt__x = -theta * x
        dt__y = -theta * y
    end
    


To create an initial community we just need to call a Community structure with an `ABM` model. 


```julia
com = Community(model,
                dt=0.1,
                )
```


    


    Community with 1 agents.


## KwArgs of the Community constructor

In addition to the model structure, we can provide the Community structure with keyword arguments. You can see all pf them in the API - Community documentation. Among them you will find:

 - Base parameters like the time `dt` or the simulation box `simBox`.
 - User parameters.

For example, we can define a community with more agents `N`, a `simulationBox` and random positions (`x`,`y`) in the unit box by constructing the Community as


```julia
N = 10
com = Community(model,
        N=N,
        simBox=[0 1;0 1.],
        dt = 0.1,
        x=Vector(1.:N),
        y=rand(N)
    )
```


    


    Community with 10 agents.


## Accessing and manipulating a Community

You can access a community in two ways:

 - Property: `com.parameter`
 - Index: `com[:parameter]`


```julia
println(com.x)
```

    [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]



```julia
println(com[:x])
```

    [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]


You can manipulate certain parameters in a community and assigning new values using the `=` operator.

It works both for assigning a new array.


```julia
com.x = Vector(2:11.)
println(com.x)
```

    [2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0]


and broad casting:


```julia
com.x = 10
println(com.x)
```

    [10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0]


> **NOTE Protected parameters** You will not be able and modify later some of the parameters of the model such as `N`. This behavior is intended to not break the functionality of the program. For example:
> 
>> ```julia
>> com.N = 10
>> ```
> 
>> ```julia
>> Parameter of community N is protected. If you really need to change it declare a new Community or use setfield! method (can be unstable).
>> 
>> Stacktrace:
>>  [1] setproperty!(com::Community, var::Symbol, v::Int64)
>>    @ CellBasedModels ~/Documents/CellBasedModels.jl/src/CommunityStructure/communityStructure.jl:370
>>  [2] top-level scope
>>    @ ~/Documents/CellBasedModels.jl/examples/Usage_Community.ipynb:1
>> ```
> 
> If you really need to change you can always use the function `setfield!` at your own risk of breacking the code.

> **WARNING Avoid broadcasting** As you can see the assign operator has been defined in such a way that works both for assigning new arrays to the parameters and broadcasting. I do not advice to use the broadcasted operator `.=` as it may change the behavior of protedted parameters which may modify in unexpected ways the results of the simulations,

## IO

When evolving the system, you will want to save instances of the community. Currently there are two ways of saving them:

#### RAM

For saving a function in RAM we can invoke the function `saveRam!`. This will save an instance of the current state in `Community.pastTimes`.


```julia
com.x = 10
saveRAM!(com)
com.x = 0.5
println("Current state of x: ", com.x)
```

    Current state of x: [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]


You can check how many instances have been saved using the function `length` on the community.


```julia
length(com)
```


    1


And you can access any past community instance calling by index of the position.


```julia
println("Past community x: ", com[1].x)
println("Current community x: ", com.x)
```

    Past community x: [10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0]
    Current community x: [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]


#### JLD2

We can also save the instances in JLD2 format, a format based in H5MD saving files system that is compatible and readable from many other programming languages and platforms.


```julia
saveJLD2("test.jld2",com)
```

And you can always call back the model from a JLD2 file.


```julia
com  = loadJLD2("test.jld2")
com.loaded
```


    false


This file will have all Community instances from the file loaded in `Community.pastTimes` and a copy of the last saved time in the current community itself.

# Evolving the community

Once we have defined a model and constructed an initial community, we can evolve it by the rules of the model.

In the following schema we describe the basic collection of functions provided by the package to evolve the model, where some functions perform automatically all the step that are described on the right.

<table>
    <thead>
        <th colspan=3> Functions </th>
        <th> Description </th>
    </thead>
    <tbody>
        <tr>
            <td rowspan=12>evolve!</td>
            <td colspan=2>loadToPlatform!</td>
            <td>Function that loads the community information to the appropiate platform (CPU or GPU) for being able to evolve it. In CPU in fact nothing happens.</td>
        </tr>
        <tr>
            <td rowspan=9>step!</td>
        </tr>
        <tr>
            <td>agentStepDE!</td>
            <td>Performs the agent DE step.</td>
        </tr>
        <tr>
            <td>agentStepRule!</td>
            <td>Performs the agent rule step.</td>
        </tr>
        <tr>
            <td>mediumStepDE!</td>
            <td>Performs the medium DE step.</td>
        </tr>
        <tr>
            <td>mediumStepRule!</td>
            <td>Performs the medium rule step.</td>
        </tr>
        <tr>
            <td>modelStepDE!</td>
            <td>Performs the model DE step.</td>
        </tr>
        <tr>
            <td>modelStepRule!</td>
            <td>Performs the model rule step.</td>
        </tr>
        <tr>
            <td>update!</td>
            <td>Saves all the updated parameters of the community as the present time. Until this function is called all the steps are stored as the future time and the step has not taken place yet!</td>
        </tr>
        <tr>
            <td>computeNeighbors!</td>
            <td>Uptdates de neighborhoods of the agents if necessary.</td>
        </tr>
        <tr>
            <td colspan=2>saveRAM!/saveJLD2!</td>
            <td>Save the current instance of the community.</td>
        </tr>
        <tr>
            <td colspan=2>bringFromPlatform!</td>
            <td>Brings back the community to RAM again.</td>
        </tr>
    </tbody>
</table>

Depending on the control that the user wants to have on the call of the evolution functions, they can decide to use one of the three column schemas proposed above.

So simple evolutions in which we want only to evolve the model after initialization for certain time and save steps at fixed time points, the package already includes the function `evolve!`.


```julia
evolve!(com,steps=100,saveEach=10)
```

And we can see that our model has now ten more saved points.


```julia
length(com)
```


    10


#### Customizing your evolution function

If you want a more fancy stepping function, you can use more atomic functions to have more control of the stepping process.

**Example** Imagine that we want to save an instance only after some agent `x` has surpassed a a certain limit.


```julia
function evolveCustom!(com,steps)
    loadToPlatform!(com) #Always necessary to load the parameters to the platform
    for i in 1:steps
        agentStepDE!(com) #This model only has an SDE that is updated with this function. 
        update!(com) #Always necessary to update the parameters at the end of all the steps.
        if any(com.x .> 5.0)
            saveRAM!(com)
        end
    end
    bringFromPlatform!(com) #Always necessary to bring the data back to RAM after evolution lo unlock the agent.
end;
```


```julia
com = com[1] #Get initial instance of the agent above defined

evolveCustom!(com,10)
```
