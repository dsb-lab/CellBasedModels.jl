```julia
using AgentBasedModels
```

# Creating and evolving a Community

The `Community` structure contains the realization of an agent model. This structure will store the parameters of the agent and will be prepared to be evolved by the update rules defined.

Let's use for reference the [Ornstein–Uhlenbeck](https://en.wikipedia.org/wiki/Ornstein%E2%80%93Uhlenbeck_process) process.


```julia
model = Agent(2,
    globalFloat = [
        :σ, #Diffussion constant
        :theta  #Drifft force
    ],
    updateVariable = quote
        d(x) = dt(-theta*x)+dW(σ)
        d(y) = dt(-theta*y)+dW(σ)
    end,
    integrator = :Heun
)
```


    


    PARAMETERS
    	σ (Float Global)
    	theta (Float Global)
    
    
    UPDATE RULES
    UpdateVariable
     begin
        d(x) = dt(-theta * x) + dW(σ)
        d(y) = dt(-theta * y) + dW(σ)
    end
    


To create an initial community we just need to call a Community structure with an `Agent` model. 


```julia
com = Community(model)
```


    


    Community with 1 agents.


## KwArgs of the Community constructor

In addition to the model structure, we can provide the Community structure with keyword arguments corresponding to any of the Default Parameters or User Defined parameters of an Agent (see Constructing Agents - Parameters). 

For example, we can define a community with more agents `N`, a `simulationBox` and random positions (`x`,`y`) in the unit box by constructing the Community as


```julia
N = 10
com = Community(model,
        N=[N],
        simBox=[0 1;0 1.],
        x=Vector(1.:N),
        y=rand(N)
    )
```


    


    Community with 10 agents.


> **NOTE Shape of Scalars**. Notice that even parameters that we expect to be scalars as the number of agents `N` are defined as arrays of size `(1,)`. Although it may look weird in the beggining this is necessary for of how the internals of the package work. Maybe in future versions, it will be possible to declare them without specifying them into brackets.

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
>>    @ AgentBasedModels ~/Documents/AgentBasedModels.jl/src/CommunityStructure/communityStructure.jl:370
>>  [2] top-level scope
>>    @ ~/Documents/AgentBasedModels.jl/examples/Usage_Community.ipynb:1
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


Alternatively, you can get a parameter for all saved points using the function `getParameter`. This function is a lot faster than asking to call any instance of a past time.


```julia
getParameter(com,:x)
```


    1-element Vector{Vector{Float64}}:
     [10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0]



```julia
getParameter(com,[:t,:x])
```


    Dict{Symbol, Vector} with 2 entries:
      :t => [[0.0]]
      :x => [[10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0]]


#### JLD2

We can also save the instances in JLD2 format, a format based in H5MD saving files system that is compatible and readable from many other programming languajes and platforms.

To save in this format we will have to provide the field `Community.fileSaving`.


```julia
com.fileSaving = "test.jld2"
```


    "test.jld2"



```julia
saveJLD2(com)
close(com.fileSaving)
```


    UndefVarError: com not defined


    


    Stacktrace:


     [1] saveJLD2(community::Community; saveLevel::Int64)


       @ AgentBasedModels ~/Documents/AgentBasedModels.jl/src/CommunityStructure/IO.jl:99


     [2] saveJLD2(community::Community)


       @ AgentBasedModels ~/Documents/AgentBasedModels.jl/src/CommunityStructure/IO.jl:74


     [3] top-level scope


       @ ~/Documents/AgentBasedModels.jl/examples/Usage_Community.ipynb:1


And you can always call back the model from a JLD2 file.


```julia
com  = loadJLD2("test.jld2")
```


    ArgumentError: attempted to open file read-only, but file was already open read/write


    


    Stacktrace:


     [1] jldopen(fname::String, wr::Bool, create::Bool, truncate::Bool, iotype::Type{JLD2.MmapIO}; fallback::Type{IOStream}, compress::Bool, mmaparrays::Bool, typemap::Dict{String, Any})


       @ JLD2 ~/.julia/packages/JLD2/r5t7Q/src/JLD2.jl:329


     [2] jldopen(fname::String, wr::Bool, create::Bool, truncate::Bool, iotype::Type{JLD2.MmapIO})


       @ JLD2 ~/.julia/packages/JLD2/r5t7Q/src/JLD2.jl:306


     [3] jldopen(fname::String, mode::String; iotype::Type, kwargs::Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}})


       @ JLD2 ~/.julia/packages/JLD2/r5t7Q/src/JLD2.jl:423


     [4] jldopen(fname::String, mode::String)


       @ JLD2 ~/.julia/packages/JLD2/r5t7Q/src/JLD2.jl:418


     [5] jldopen(::Function, ::String, ::Vararg{String}; kws::Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}})


       @ JLD2 ~/.julia/packages/JLD2/r5t7Q/src/loadsave.jl:2


     [6] jldopen


       @ ~/.julia/packages/JLD2/r5t7Q/src/loadsave.jl:2 [inlined]


     [7] loadJLD2(file::String)


       @ AgentBasedModels ~/Documents/AgentBasedModels.jl/src/CommunityStructure/IO.jl:180


     [8] top-level scope


       @ ~/Documents/AgentBasedModels.jl/examples/Usage_Community.ipynb:1


This file will have all Community instances from the file loaded in `Community.pastTimes` and a copy of the last saved time in the current community itself.

# Evolving the community

Once we have defined a model and constructed an initial community, we can evolve it by the rules of the model.

In the following schema we describe the basic collection of functions provided by the package to evolve the model, where some functions perform automatically all the step that are described on the right.


```@raw html
 <table>
    <thead>
        <th colspan=3> Functions </th>
        <th> Description </th>
    </thead>
    <tbody>
        <tr>
            <td rowspan=9>evolve!</td>
            <td colspan=2>loadToPlatform!</td>
            <td>Function that loads the community information to the appropiate platform (CPU or GPU) for being able to evolve it. In CPU in fact nothing happens.</td>
        </tr>
        <tr>
            <td rowspan=6>step!</td>
            <td>interactionStep!</td>
            <td>Computes the interaction properties between agents as defined in updateInteractions.</td>
        </tr>
        <tr>
            <td>integrationStep!</td>
            <td>Performs the integration step as defined in updateVariable</td>
        </tr>
        <tr>
            <td>localStep!</td>
            <td>Performs the local step as defined in updateLocal.</td>
        </tr>
        <tr>
            <td>globalStep!</td>
            <td>Performs the global step as defined in updateGlobal.</td>
        </tr>
        <tr>
            <td>update!</td>
            <td>Saves all the updated parameters of the community as the present time. Until this function is called all the steps are stored as the future time and the step has not taken place yet!>/td>
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
```


Depending on the control that the user wants to have on the call of the evolution functions, they can decide to use one of the three column schemas proposed above.

So simple evolutions in which we want only to evolve the model after initialization for certain time and save steps at fixed time points, the package already includes the function `evolve!`.


```julia
evolve!(com,steps=100,saveFunction=saveRAM!,saveEach=10)
```

And we can see that our model has now ten more saved points.


```julia
length(com)
```


    11


#### Customizing your evolution function

If you want a more fancy stepping function, you can use more atomic functions to have more control of the stepping process.

**Example** Imagine that we want to save an instance only after some agent `x` has surpassed a a certain limit.


```julia
function evolveCustom!(com,steps)
    loadToPlatform!(com) #Always necessary to load the parameters to the platform
    for i in 1:steps
        integrationStep!(com) #This model only has an SDE that is updated with this function. 
        update!(com) #Always necessary to update the parameters at the end of all the steps.
        if any(getfield(com,:x) .> 5.0)
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
