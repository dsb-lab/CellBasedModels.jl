```julia
using CellBasedModels
```

# Model Fitting

One of the aims of the agent based models is to describe experimental observations. However the models have a complex dependency of the parameters and in general not direct algorithms exist for their optimization.

In the package we provide the submodule `Fitting` that provides of some fitting methods for complex parameter landscapes:

|Methods|
|:---:|
|`gridSearch`|
|`swarmAlgorithm`|
|`beeColonyAlgorithm`|
|`geneticAlgorithm`|

All methods require two basic arguments:

 - An evaluation function. This is a function that has as input a set of parameters of the model in form of `DataFrameRow` and has to return a scalar value that indicates the goodness of the parameters. The usual steps in this function will be:
    - Initialize a community with the provided parameters.
    - Evolution of the community
    - Evaluation of the goodness of fit.
 - A search space. Dictionary specifying the parameters to be fitted and the region of space in which they have to be fitted.

Let's see a very simple example. This example in fact would not need such complex fitting algorithms as we will optimize the parameter of an ODE, but it is sufficiently concise to get the idea.

**Example: Exponential decay**

Imagine that we want to make an optimization of a model such:

$$dx = -\delta x $$

which analytic solution is:

$$x(t) = x_0 e^{-\delta t} $$

and we want to find both $x_0$ and $\delta$. Consider that the data comes from $x_0=10$ and $\delta = 1.$.


```julia
model = ABM(1,
    model = Dict(
        :δ=>Float64
        ),
    agentODE = quote
        dt( x ) = -δ*x
    end,
);
```

Moreover, we make a function of the exact. In other cases, this may be actual data from experiments.


```julia
analyticSolution(t) = 10 .*exp.(-t);
```

## Evaluation function

The evaluation function is a function that accepts a `DataFrameRow` which contains an instance of candidate parameters of the model. 
The function is generic and internally you can declare a model, instantiate a community and evolve it as described in the previous steps.
After the simulation has taken place, you evaluate how good is the fit to your observations. For that you define an error function to be **minimized**. The outcome of the error function is what the evaluation function will return.

For the example above a simulation function will look like:


```julia
com = Community(model,dt=0.1)

function fitting(pars,community=com)
    #Initialize the model
    com = Community(model,
                x=pars.x0,
                δ=pars.δ,
                dt=0.1
            )
    setfield!(com,:abm,community.abm)
    #Evolve the model
    evolve!(com,steps=10)
    #Calulate error
    t = [i.t for i in com.pastTimes]
    d = getParameter(com,[:x])
    loos = sum( [abs( analyticSolution.(tt) .- x[1]) for (tt,x) in zip(t,d[:x])] )
    
    return loos
end;
```

## Search space - gridSearch

The most basic algorithm will be to explore extensively a grid of parameter combinations and get the best one. For simple models with not many parameters, this method can be the fastest one.

For this method we have to provide vectors of potential candidates for each of the explored parameters.


```julia
searchSpace = Dict(
    :x0 => Vector(.0:1:11),
    :δ => Vector(.1:.1:2) 
);
```

Finally, we can explore the space of parameters to fit our model.


```julia
CBMFitting.gridSearch(fitting, searchSpace)
```


<div><div style = "float: left;"><span>DataFrameRow (3 columns)</span></div><div style = "clear: both;"></div></div><div class = "data-frame" style = "overflow-x: scroll;"><table class = "data-frame" style = "margin-bottom: 6px;"><thead><tr class = "header"><th class = "rowLabel" style = "font-weight: bold; text-align: right;">Row</th><th style = "text-align: left;">x0</th><th style = "text-align: left;">δ</th><th style = "text-align: left;">_score_</th></tr><tr class = "subheader headerLastRow"><th class = "rowLabel" style = "font-weight: bold; text-align: right;"></th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th></tr></thead><tbody><tr><td class = "rowLabel" style = "font-weight: bold; text-align: right;">119</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">1.0</td><td style = "text-align: right;">1.48518</td></tr></tbody></table> 
```
</div>


## Search space - Swarm Argorithm and others

For more complex spaces that have many parameters, the grid search algorithm can be computationally impossible as the evaluations require to search all the combinations of all parameters. 
For that, algorithms like the `swarmAlgorthms`, the `geneticAlgorithm` or the `beeAlgorthm` can be far more convenient.

For this algorithms, you can provide search spaces both in the terms of vectors of points for non-coninuous parameters as iin gridSearch or regions of exploration in the shape of tuples. 

In our model, both parameters are continuous so we will define them as continous regions with tupples.


```julia
searchSpace = Dict(
    :x0 => (.0,20),
    :δ => (.0,2) 
);
```


```julia
CBMFitting.swarmAlgorithm(fitting, searchSpace)
```


<div><div style = "float: left;"><span>DataFrameRow (6 columns)</span></div><div style = "clear: both;"></div></div><div class = "data-frame" style = "overflow-x: scroll;"><table class = "data-frame" style = "margin-bottom: 6px;"><thead><tr class = "header"><th class = "rowLabel" style = "font-weight: bold; text-align: right;">Row</th><th style = "text-align: left;">x0</th><th style = "text-align: left;">δ</th><th style = "text-align: left;">x0_velocity_</th><th style = "text-align: left;">δ_velocity_</th><th style = "text-align: left;">_score_</th><th style = "text-align: left;">_generation_</th></tr><tr class = "subheader headerLastRow"><th class = "rowLabel" style = "font-weight: bold; text-align: right;"></th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Int64" style = "text-align: left;">Int64</th></tr></thead><tbody><tr><td class = "rowLabel" style = "font-weight: bold; text-align: right;">967</td><td style = "text-align: right;">10.5734</td><td style = "text-align: right;">1.02219</td><td style = "text-align: right;">-0.109951</td><td style = "text-align: right;">-0.0193163</td><td style = "text-align: right;">1.51499</td><td style = "text-align: right;">10</td></tr></tbody></table> 
```
</div>


## Other packages

Notime that the CellBasedModels can be also fitted using other packages as the really good [Optimization.jl](https://docs.sciml.ai/Optimization/stable/). The functions provided in CellBasedModels for fitting are just an self-contained alternative and most probable the more mature Optimizations.jl package will have better and more robust implementations.
