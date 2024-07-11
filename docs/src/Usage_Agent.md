```julia
using CellBasedModels
```

# Defining an ABM model

The `ABM` structure contains all the information of a ABM Based model, their parameters and rules of evolution. There are four elements to take into account when defining agents:

 - **Parameters**. These can be splited in:
    - User-defined parameters: Parameters that are defined for the specific model that is being used.
    - Default parameters: Parameters that are defined for all models by default.
 - **Update rules**. Rules that describe the behavior of the agents during the course of time.
 - **Model inheritance**. More simple models over which we want to build more complex models.

Constructing an agent we use

```julia
ABM(dim,kwArgs...)
```
where `dim` is the only required argument of the model and defined the dimensionality of the agent and can take values 0-3. The `kwArgs` are keyword arguments that define the parameters, rules and base models of the present model and that will be seing in detail in the following.

## Parameters

### Parameters - Default Parameters

By default, all agent models have a set of defined set of parameters. A list of the most relevant parameters for a user is:

|**Topic**|**Symbol**|**dtype**|**Description**|
|:---:|:---:|:---:|:---|
|**Time**|t|Float64|Absolute time of evolution of the community.|
||dt|Float64|Time increments in each step of the evolution.|
|**Size Community**|N|Int64|The number of agents active in the community.|
||NMedium|Vector{Int64}|Size of the grid in which the medium is being computed. This is necessary to be declared if medium parameters are declared by the user.|
|**Id tracking**|id|Int64|Unique identifier of the agent.|
|**Simulation space**|simBox|Matrix{Float64}|Simulation box in which cells are moving. This is necessary to define a region of space in which a medium will be simulated or for computing neighbors with CellLinked methods.|
|**Position**|x|Vector{Float64}|Position of the agent in the x axis.|
||y|Vector{Float64}|Position of the agent in the y axis.|
||z|Vector{Float64}|Position of the agent in the z axis.|
|**Position Medium**|x $_m$|Array{Float64}|Position of the medium gridpoints in the x axis. The shape will depend on the dimensionality o the model. This parameter is only present is a model with medium parameters is declared.|
||y $_m$|Array{Float64}|Position of the medium gridpoints in the y axis. The shape will depend on the dimensionality o the model. This parameter is only present is a model with medium parameters is declared.|
||z $_m$|Array{Float64}|Position of the medium gridpoints in the z axis. The shape will depend on the dimensionality o the model. This parameter is only present is a model with medium parameters is declared.|
|**Grid size Medium**|dx|Float64|Grid separation of the medium in the x axis. This parameter is only present is a model with medium parameters is declared.|
||dy|Float64|Grid separation of the medium in the y axis. This parameter is only present is a model with medium parameters is declared.|
||dz|Float64|Grid separation of the medium in the z axis. This parameter is only present is a model with medium parameters is declared.|
|**Grid position Medium**|i1_|Int64|Index of the medium grid in the x coordinate.|
||i2_|Int64|Index of the medium grid in the x coordinate.|
||i3_|Int64|Index of the medium grid in the x coordinate.|

There are more parameters predefined in the model. The other parameters, however, are used internaly for the package to work properly and should in rare case used directly by the user. A complete list can be seen in the definition of the `Community` structure in `API`. You can identify them because they have a lower underscore in the end of their name.

### Parameters - User defined parmaeters

Apart from the default parameters, the user can define other parameters necessary for its model. 

The user parameters can have three scopes:

 - **model**: Parameters that affect all the agents. These can be scalars or arrays of any shape.
 - **agent**: Parameters have a different value for each agent. These will be stored as length N vectors. These can be scalars.
 - **medium**: Parameters that belong to the medium in which the model is embedded (if there is a medium defined for this model). These can be scalars only.

For declaring the parameters, you will have to pass a dictionary-like object with keys as symbols of the parameters and datatypes as the stored values. Alternatively you can provide a structure and the `ABM` object will take the fields as the parameters.


```julia
agent = ABM(3,                                  #Dimensions of the model
                agent = Dict(                   # Agent parameters
                    :a1=> Float64,
                    :a2=> Int64
                    ),
                model = Dict(                   # Model parameters
                    :g1=> Int64,
                    :g2=> Array{Float64}
                    ),
                medium = Dict(                  # Medium parameters
                    :m=>Float64
                    )
            )
```

    PARAMETERS
    	x (Float64 agent)
    	y (Float64 agent)
    	z (Float64 agent)
    	xₘ (Float64 medium)
    	yₘ (Float64 medium)
    	zₘ (Float64 medium)
    	a2 (Int64 agent)
    	a1 (Float64 agent)
    	g2 (Array{


    


    Float64} model)
    	g1 (Int64 model)
    	m (Float64 medium)
    
    
    UPDATE RULES


> **WARNING: User default parameters name convention** 
> 
> The is no rule to declare user-defined parameters but we advise that the names do not end with underscore (e.g. :a_). 
> This nomenclarute is in general used to name hidden parameters that are kept for internal use.

## Update Rules

After setting up the parameters of our agent, we can define the rules of evolution of our model and of recomputation.

We can evolve all parameters in all the scopes with two methods:

 - Differential Equations: In the most general form we can define up to Stochastic Differential Equations. In these rules we will define the deterministic function $f$ and stochastic functions $g$ separately.

$$d(x) = \underbrace{f(x,t)}_{ODE}dt + \underbrace{g(x,t)}_{SDE}dW$$

 - Rules: Rules that do not have any underlying differential equation to describe their evolution.

### Writting update rules

Update rules in agents is almost normal julia code that you can write in a simplified level and then, when constructing the `ABM` structure, the code will be vectorized and adapted to be run in the corresponding platform.

To provide a rule to the `ABM`, you will need to give the code to the `kwArg` in form of 

```julia
quote 
#code of update rule in here...
end
```

Let's see some examples to make it more clear.

### Rules

**Example** We want to create an agent that, at each step:
 1. Makes a jump to left or right brought from a gaussian. 
 2. If the agent surpasses a certain limit in the left limit, is removed. 
 3. At random, with certain probability, it divides with a new parameter `l`.


```julia
model = ABM(1, #Dimensions of the model
    agent = Dict(
        :l => Float64
    ),
    model = Dict(
        :σ2 => Float64,    #Spread of the gaussian
        :pDivision => Float64 #Global variable to set the probability at which it will divide
    ),
    agentRule = quote
        x += CBMRandom.normal(0.,σ2) #We can call to distributions from Distributions.jl that are 1D
        #We can make conditionals
        if x__ > simBox[1,2] #We can use the default parameter simBox to define where is the left margin at which cells are removed. 
            @removeAgent()
        elseif pDivision < Uniform(0,1) #We can make conditionals
            @addAgent(
                l = sin(CBMRandom.uniform(0,3*π))
                ) #We add an agent that inherits x and initialize it with a new parameter l
        end
    end
)
```


    


    PARAMETERS
    	x (Float64 agent)
    	l (Float64 agent)
    	pDivision (Float64 model)
    	σ2 (Float64 model)
    
    
    UPDATE RULES
    agentRule
     begin
        x__ += CBMRandom.normal(0.0, σ2)
        if x__ > simBox[1, 2]
            @removeAgent
        elseif pDivision < Uniform(0, 1)
            @addAgent l__ = sin(CBMRandom.uniform(0, 3π))
        end
    end
    


Several things to notice: 

 1. Parameters with double lower underline. If you notice, the update rule shows that when the modified parameters `x` and `l`, when reasiged with an updating operator, they where converted into `x__` and `l__`, respectively. The underscore variables are the variables that store the modifications of the parameters before making the final step. This is performed this way to avoid modificating the parameters before all the modifications to all the agents, medium and model parameters are made. When calling the functions `update!` or `evolve!`, the new modifications will take place and will be incorporated into the original parameters. 
 2. Random numbers and GPU. To generate random numbers from distributions we can use the package `Distributions.jl`. This is perfectly fine if your code is going to run only on CPU. However, `Distributions.jl` is not compatible with GPU hence we provide the submodule `CBMRandom` with some random generators from different distributions that may run both in CPU and GPU.
 3. Macros. `CellBasedModels` provide several macros that are handy to perform some special functions of Agent Based Models. You can see the all the provided macros in `API - Macros`. In here we use the macro for adding agents to a model `@addAgent` and the one for removing agents `@removeAgent`.
 4. Use of Base parameters. For checking that the particle has left the simulation space, we use the base parameter `simBox` that defines the boundaries of the simulation.

Let's try now other example but now we want to modify a model parameter. For that, we will define a model rule.

**Example** Freeze the agents. Imagine that if certain time is met, we want to freeze all the agents that we described in local. One of the ways we can do it is by setting the jump to zero.



```julia
model = ABM(1, #Dimensions of the model
    agent = Dict(
        :l => Float64
    ),
    model = Dict(
        :σ2 => Float64,    #Spread of the gaussian
        :pDivision => Float64, #Global variable to set the probability at which it will divide
        :freeze => Bool
    ),
    agentRule = quote
        x += freeze*Normal(0,σ2) 
        if x__ > simBox[1,2]
            @removeAgent()
        elseif pDivision < Uniform(0,1)
            @addAgent(l = sin(Uniform(0,3*π)))
        end
    end,
    modelRule = quote #Set freeze to false
        if t < 10.
            freeze = true
        else
            freeze = false
        end
    end
)
```

    PARAMETERS
    	x (Float64 agent)
    	l (Float64 agent)
    	pDivision (Float64 model)
    	σ2 (Float64 model)
    	freeze (


    


    Bool model)
    
    
    UPDATE RULES
    modelRule
     if t < 10.0
        freeze__ = true
    else
        freeze__ = false
    end
    
    agentRule
     begin
        x__ += freeze * Normal(0, σ2)
        if x__ > simBox[1, 2]
            @removeAgent
        elseif pDivision < Uniform(0, 1)
            @addAgent l__ = sin(Uniform(0, 3π))
        end
    end
    


### Differential Equations

Parameters can be evolved also using Differential Equation. The way of defining the equations is very similar to that of `DifferentialEquations.jl`. `CellBasedModels` is currently compatible with ODE and SDE problems. The most general form of such problems is,

$$d(x) = \underbrace{f(x,t)}_{ODE}dt + \underbrace{g(x,t)}_{SDE}dW$$

Where the functions $f$ and $g$ define the deterministic and stochastic terms, in general. Let's see an example to learn how to define models with these equations.

**Example** The [Ornstein–Uhlenbeck](https://en.wikipedia.org/wiki/Ornstein%E2%80%93Uhlenbeck_process) process is described by a function of the form:

$$d(x) = -xdt + DdW$$

We want a model that:
 1. Evolves under a 2D OU process
 2. Keeps track of the number of neighboring cells in a radius


```julia
model = ABM(2,
    model = Dict(
        :dist => Float64, #Maximum distance to compute neighbor distance
        :D => Float64
        ),
    agent = Dict(
        :nNeighs=> Int64  #Number of neighbors that the agent has
        ),
    agentRule = quote
        nNeighs = 0 #Set it to zero before starting the computation
        @loopOverNeighbors it2 begin
            d = CBMMetrics.euclidean(x,x[it2],y,y[it2]) #Using euclidean matric provided in package
            if d < dist
                nNeighs += 1 #Add 1 to neighbors
            end
        end
    end,
    agentODE = quote #Here we put the deterministic term
        dt(x) = -x
        dt(y) = -y
    end,
    agentSDE = quote #Here we put the stochastic term
        dt(x) = D
        dt(y) = D
    end,

    platform = CPU(),
    neighborsAlg = CBMNeighbors.CellLinked(cellEdge=1)
)
```


    


    PARAMETERS
    	x (Float64 agent)
    	y (Float64 agent)
    	nNeighs (Int64 agent)
    	D (Float64 model)
    	dist (Float64 model)
    
    
    UPDATE RULES
    agentSDE
     begin
        dt__x = D
        dt__y = D
    end
    
    agentRule
     begin
        nNeighs__ = 0
        @loopOverNeighbors it2 begin
                d = CBMMetrics.euclidean(x, x[it2], y, y[it2])
                if d < dist
                    nNeighs__ += 1
                end
            end
    end
    
    agentODE
     begin
        dt__x = -x
        dt__y = -y
    end
    


Several things to notice:

 1. The function `dt` and the parameter decorator `dt__`. Similarly what we do with rules adding a double underscore, we mark differential terms with the function `dt`, this function defines that this parameter is described by a differential equation and a new parameter is added to define that this variable is the differential term.
 2. ODE and SDE. We put the deterministic term un the rule `agentODE` and the stochatic term in the rule `agentSDE`. We may not have a deterministic term or no stochastic term, that is not a problem.
 3. Use of neighbors macros. To go over the neighbors of an agent, we use the `@loopOverNeighbors` macro that requires that you specify an iterator index. Inside neighbors macros, you need to make a difference to which parameters are from the agent and which are the neighbors agent. If you see the line where the euclidean distance is computed you will realise that we specify the parameters of the second agent by providing the corresponding index of the neighboring position to them.

Let's see another example.

**Example** Consider that we want to define a model with a diffusive medium along the x axis and static cells secreting to medium. For now we will limit to have a medium without agents. The equation of diffusion has the form:

$$\frac{\partial p(x,t)}{\partial t} = D\frac{\partial^2 p(x,t)}{\partial x^2}$$

This continuous equation has to be discretized to be able to be integrated. We can use the macros we provide in the code.

For the boundary solutions we can implement Dirichlet conditions:

$$p(x_{max},t) = 0$$

and Newman (reflective):

$$\partial_x p(x,t)|_{x=x_{min}} = 0$$

which in discrete form will correspond to (taking a backward discretization):

$$ \frac{p(x_{min})-p(x_{min}-\Delta x)}{\Delta x} = 0$$

and isolating:

$$ p(x_{min})=p(x_{min}-\Delta x)$$


```julia
model = ABM(2,
    model = Dict(
        :D => Float64
        ),
    agent = Dict(
        :secrete => Float64
    ),
    medium = Dict(
        :p=> Float64  #Number of neighbors that the agent has
        ),
    agentRule = quote
        p += secrete*dt/dx*dy #Add to the medium the secretion content of each neighbor at each time point
    end,
    mediumODE = quote
        if @mediumInside() #Diffusion inside bourders
            dt(p) = @∂2(1,p)      #Second order diffusive term along x axis
        elseif @mediumBorder(1,-1) #Newman (reflective) boundaries on the xmin border
            p = p[2,i2_]    #Reflective at x border, along all y points             
        elseif @mediumBorder(1,1) #Dirichlet (absorvant) boundary on the xmax border
            p = 0                   
        end
    end,
    mediumAlg = DifferentialEquations.AutoTsit5(DifferentialEquations.Rosenbrock23())
)
```


    


    PARAMETERS
    	x (Float64 agent)
    	xₘ (Float64 medium)
    	secrete (Float64 agent)
    	D (Float64 model)
    	p (Float64 medium)
    
    
    UPDATE RULES
    mediumODE
     if @mediumInside()
        dt__p = @∂2(1, p)
    elseif @mediumBorder(1, -1)
        p__ = p[2]
    elseif @mediumBorder(1, 1)
        p__ = 0
    end
    
    agentRule
     p__ += ((secrete * dt) / dx) * dy
    


By now you can already identify all the things that are happening:

 1. In an agent rule we are adding to the medium whatever the agent is secreting.
 2. We used some provided macros to help out the writing of the model.
 3. Updated parameters adquire the underscore and `dt__` decorators.

# Algorithm arguments

Once defined the rules, you can define specific algorithms for the computation of the model. The possible arguments are:

- `platform` argument to define the type of platform in which you want to evolve the model.
- `agentAlg`, `modelAlg` and `mediumAlg` to define the integrator that you want to use. You can use our own integrators provided in the submodule `CBMIntegrators` that may be faster in general but in complex cases with stiff operation or in which you need high precission, you can always use the integrators from `DifferentialEquations.jl` suite. 
- `agentSolveArgs`, `modelSolveArgs` and `mediumSolveArgs` to define additional arguments required by the integrators to work. This arguments are the ones present when definind a problem in `DifferentialEquations.jl`. 
- `neighborsAlg` algorithm. This defines the way of computing neighbors. This step is one of the most cost expensive in ABMs and the correct selection of algorithm can really afect your computational efficientcy. We provide several possible algorithms in the submodule `CBMNeighbors`.

You should have seen some of this arguments declared in the code above.

> **WARNING**  When developing this library, these arguments where declared in the 'Community' object. now that we have a first stable version, they were moved to this object to solve a [World agent problem](https://arxiv.org/abs/2010.07516) when creating Communities inside functions.

## Model inheritance

The above set of parameters and rules can be used to define all type of agent models. Once we have a developed a model, we can extend the model with additional rules and parameters. This allows to contruct the models in a modular maner.

There are two keyword parameters in the structure `ABM` for doing that:

 1. `baseModelInit`: Models whose rules apply before the rules of the present ABM model.
 2. `baseModelEnd`: Models whose rules apply after the rules of the present ABM model.

The models provided will be concatenated in order of declaration.

**Example** Let's make modular the random walker and boundary conditions of the example provided above in **Rules**.


```julia
modelFreeze = ABM(1, #Dimensions of the model
    model = Dict(
        :freeze => Bool
    ),
    modelRule = quote #Set freeze to false
        if t < 10.
            freeze = true
        else
            freeze = false
        end
    end,
)

modelCombined = ABM(1, #Dimensions of the model
    agent = Dict(
        :l => Float64
    ),
    model = Dict(
        :σ2 => Float64,    #Spread of the gaussian
        :pDivision => Float64, #Global variable to set the probability at which it will divide
    ),
    agentRule = quote
        x += freeze*Normal(0,σ2) 
        if x__ > simBox[1,2]
            @removeAgent()
        elseif pDivision < Uniform(0,1)
            @addAgent(l = sin(Uniform(0,3*π)))
        end
    end,

    baseModelInit = [modelFreeze]
)
```


    


    PARAMETERS
    	x (Float64 agent)
    	l (Float64 agent)
    	pDivision (Float64 model)
    	σ2 (Float64 model)
    	freeze (Bool model)
    
    
    UPDATE RULES
    modelRule
     if t < 10.0
        freeze__ = true
    else
        freeze__ = false
    end
    
    agentRule
     begin
        x__ += freeze * Normal(0, σ2)
        if x__ > simBox[1, 2]
            @removeAgent
        elseif pDivision < Uniform(0, 1)
            @addAgent l__ = sin(Uniform(0, 3π))
        end
    end
    


As you can see the combined model is the same as the model that we declared with all the rules together.

Notice that note all models will be inheritable. For example, if we tried to inherit the model the other way around iwe will find that the parameter `freeze` should have been declared in without declaring what it is. 
