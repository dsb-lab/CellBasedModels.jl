# [ICM Development](@id Development)

The model from Saiz et al has three parts in the model

## Definition of the model

### Mechanics

The cells are spheroids that behave under the following equations:

$$m_i\frac{dv_i}{dt} =-bv_i+\sum_j F_{ij}$$

$$\frac{dx_i}{dt} =v_i$$

where the force is

$$F_{ij}=
\begin{cases}
F_0(\frac{r_{ij}}{d_{ij}}-1)(\frac{\mu r_{ij}}{d_{ij}}-1)\frac{(x_i-x_j)}{d_{ij}}\hspace{1cm}if\;d_{ij}<\mu r_{ij}\\
0\hspace{5cm}otherwise
\end{cases}$$

where $d_{ij}$ is the Euclidean distance and $r_{ij}$ is the sum of both radius.

### Biochemical interaction

Each cell has a biochemical component that follows an equation of the form:

$$\frac{dx_i}{dt}=\frac{α(1+x^n_i)^m}{(1+x^n_i)^m+(1+(\langle x\rangle_i)/K)^{2m}}-x_i$$

This is similar to the above case. The only detail required is to note that the average expression can be modeled as the combination of two interacting variables. The biochemical system is activated in the interval $[t_{on},t_{off}]$.

We made explicit that the average operator can be written as two interaction parameters that are the contraction along the second index that runs over the neighbours of each cell as,

$$N_{ij}=
\begin{cases}
1\hspace{1cm}d<f_{range}r_{ij}\\
0\hspace{1cm}otherwise
\end{cases}$$

$$X_{ij}=
\begin{cases}
x_j\hspace{1cm}d<f_{range}r_{ij}\\
0\hspace{1cm}otherwise
\end{cases}$$

$$\langle x\rangle_i=\frac{\sum_j X_{ij}}{\sum_j N_{ij}}=\frac{X_{i}}{N_{i}}$$

### Growth

The cells present division. The rules for the division in this model are. Random election of a division direction over the unit sphere. The daughter cells divide equally in mass and volume and are positioned in oposite directions around the division axis centered at the parent cell. The chemical concentration is divided asymmetrically with each cell taking $1\pm\sigma_x \text{Uniform}(0,1)$ for the parent cell. A new division time is assigned to each aghter cell from a uniform distribution $\text{Uniform}(\tau_{div}(1-\sigma_{div}),\tau_{div}(1+\sigma_{div}))$.

## Creation of the Agent


```julia
#Package
using AgentBasedModels
#Functions for generating random distributions
using Random
using Distributions
#Package for plotting in 3D
using GLMakie
GLMakie.inline!(true)
```

### Define the agent

First, we have to create an instance of an agent with all the propoerties of the agents.First, we have to create an instance of an agent with all the propoerties of the agents.


```julia
model = Agent(3,

    #Inherit model mechanics
    baseModelInit = [Models.softSpheres3D],

    #Global parameters
    globalFloat = [
        #Chemical constants
        :α, :K, :nn, :mm,
        #Physical constants
        :fRange, :mi, :ri, :k0,
        #Division constants
        :fAdh, :τDiv, :σDiv, :c0, :σc, :nCirc, :σNCirc,
        :fMin, :fMax, :fPrE, :fEPI, :τCirc, :στCirc, :rESC,
        :nOn, :cMax
    ],
    #Local float parameters
    localFloat = [
        :c,
        :tDivision #Variable storing the time of division of the cell
    ],
    #Local interactions
    localFloatInteraction = [
        :ci, #Chemical activity of the neighbors
        :ni  #Number of neighbors
    ],
    #Local integer parameters
    localInt = [
        :tOff,    #indicate if the circuit for that cell is on or off (0,1)
        :cellFate #Identity of the cell (1 DP, 2 EPI, 3 PRE)
    ],
    #Chemical dynamics
    updateVariable = quote
        act = 0.
        if tOff == 0 && N > nOn #Activate circuit
            act = 1.
        else
            act = 0.
        end
        d( c ) = dt( act * ( α*(1+c^nn)^mm/((1+c^nn)^mm+(1+(ci/(ni+1))/K)^(2*mm))-c ) )
    end,
    #Interaction computation
    updateInteraction= quote
        dij = euclideanDistance(x.i,x.j,y.i,y.j,z.i,z.j)
        if dij < fRange*rij #Unnecessary to compute dij and rij again, previously computed in UpdateInteraction
            ni.i += 1
            ci.i += c.j
        end 
    end,
    updateLocal=quote
        #Circuit deactivation and comitment
        if c < fPrE*cMax && tOff == 0 && N > nOn
            cellFate = 3
            tOff = 1
        elseif c > fEPI*cMax && tOff == 0 && N > nOn
            cellFate = 2
            tOff = 1
        end

        #Growth
        if t > tDivision
            #Choose random direction in unit sphere
            xₐ = Normal(0,1); yₐ = Normal(0,1); zₐ = Normal(0,1)
            Tₐ = sqrt(xₐ^2+yₐ^2+zₐ^2)
            xₐ /= Tₐ;yₐ /= Tₐ;zₐ /= Tₐ    

            #Chose a random distribution of the material
            dist = Uniform(1-σc,1+σc)

            rsep = r/2
            rnew = r/(2. ^(1. /3))
            
            addAgent( #Add new agent
                x = x+rsep*xₐ,
                y = y+rsep*yₐ,
                z = z+rsep*zₐ,
                vx = 0,
                vy = 0,
                vz = 0,
                r = rnew,
                m = m/2,
                c = c*(dist),
                tDivision = tDivision + Uniform(τDiv*(1-σDiv),τDiv*(1+σDiv))
            )
            addAgent( #Add new agent
                x = x-rsep*xₐ,
                y = y-rsep*yₐ,
                z = z-rsep*zₐ,
                vx = 0,
                vy = 0,
                vz = 0,
                r = rnew,
                m = m/2,
                c = c*(2-dist),
                tDivision = tDivision + Uniform(τDiv*(1-σDiv),τDiv*(1+σDiv))
            )
            removeAgent() # Remove agent that divided
            
        end
    end,

    integrator = :Heun
);
```

## Community construction and initialisation

Once with the model created, we have to construct an initial Community of agents to evolve.

### Parameters

The model from the original version has some parameters defined. We create a dictionary with all the parameters from the model assigned.


```julia
parameters = Dict([
:α => 10,
:K => .9,
:nn => 2,
:mm => 2,
:fRange => 1.2,
:mi => 10E-6,
:ri => 5,
:b => 10E-6,
:k0 => 10E-4,
:fAdh => 1.5,
:μ => 2,
:τDiv => 10,
:σDiv => .5,
:c0 => 3,
:σc => 0.01,
:nCirc => 20,
:σNCirc => .1,
:fMin => .05,
:fMax => .95,
:fPrE => .2,
:fEPI => .8,
:τCirc => 45.,
:στCirc => .02,
:rESC => 2
]);
```

### Initialise the community

The model starts from just one agent. Create the community and assign all the parameters to the Community object.


```julia
function initializeEmbryo(parameters)

    com = Community(model,N=[1])

    #Global parameters
    for (par,val) in pairs(parameters)
        setproperty!(com,par,val)
    end

    com.nOn = rand(Uniform(parameters[:nCirc]-parameters[:σNCirc],parameters[:nCirc]+parameters[:σNCirc]))
    com.cMax = parameters[:α]/(1+1/(2*parameters[:K])^(2*parameters[:mm]))

    #########Local parameters and variables###########
    com.f0 = parameters[:k0]# / parameters[:fAdh]
    #Initialise locals
    com.m = parameters[:mi]
    com.r = parameters[:ri]
    com.cellFate = 1 #Start neutral fate
    com.tOff = 0 #Start with the tOff deactivated
    #Initialise variables
    com.x = 0.
    com.y = 0.
    com.z = 0.
    com.vx = 0.
    com.vy = 0.
    com.vz = 0.
    com.c = com.c0
    com.tDivision = 1#rand(Uniform(com.τDiv-com.σDiv,com.τDiv+com.σDiv))

    return com

end;
```


```julia
com = initializeEmbryo(parameters);
```

## Creating a custom evolve step


```julia
function customEvolve!(com,dt,steps,saveEach)
    com.dt = dt
    loadToPlatform!(com,preallocateAgents = 100)
    for i in 1:steps
        interactionStep!(com)
        integrationStep!(com)
        localStep!(com)
        update!(com)
        computeNeighbors!(com)
        if i % saveEach == 0
            saveRAM!(com)
        end
        #Stop by time
        if all(com.N .> 60)
            break
        end
    end
    bringFromPlatform!(com)
end;
```


```julia
dt = 0.002
steps = round(Int64,50/dt)
saveEach = round(Int64,.5/dt)

com = initializeEmbryo(parameters);
customEvolve!(com,dt,steps,saveEach)
```

### Visualization of results

We check how the agents starts to divide and choose a fate at late stages of the simulation.


```julia
d = getParameter(com,[:x,:y,:z,:r,:cellFate])
colorMap = Dict(1=>:blue,2=>:orange,3=>:green)
for (i,pos) in enumerate(1:length(com))
    color = [colorMap[i] for i in d[:cellFate][pos]]
    fig = Figure(resolution=(2000,2000))
    ax = Axis3(fig[1,1],aspect = :data)
    meshscatter!(ax,d[:x][pos],d[:y][pos],d[:z][pos],markersize=d[:r][pos],color=color)
    xlims!(ax,-7,7)
    ylims!(ax,-7,7)
    zlims!(ax,-7,7)

    ind = "000$i"
    save("video/Development$(ind[end-2:end]).jpeg",fig)
end
```


```julia
fig = Figure(resolution=(2000,500))

d = getParameter(com,[:x,:y,:z,:r,:cellFate])
colorMap = Dict(1=>:blue,2=>:orange,3=>:green)
for (i,pos) in enumerate([1:10:length(com);length(com)])
    ax = Axis3(fig[1,i],aspect = :data)
    color = [colorMap[i] for i in d[:cellFate][pos]]
    meshscatter!(ax,d[:x][pos],d[:y][pos],d[:z][pos],markersize=d[:r][pos],color=color)
    xlims!(ax,-5,5)
    ylims!(ax,-5,5)
    zlims!(ax,-5,5)
end

fig
```


    
![png](Development_files/Development_16_0.png)
    



```julia
function getProportions(com)
    d = getParameter(com,[:cellFate])

    proportions = []
    for fate in [1,2,3]
        fateList = []
        sizeList = []
        for (i,pos) in enumerate(1:length(com))
            push!( sizeList, length(d[:cellFate][pos]) )
            push!( fateList, sum(d[:cellFate][pos].==fate) )
        end
        prop = fateList./sizeList
        push!(proportions,prop)
    end

    return proportions
end;
```


```julia
fig = Figure(resolution=(2000,800))

ax = Axis(fig[1,1])

colorMap = Dict(1=>:blue,2=>:orange,3=>:green)
offset = zeros(length(com))
prop = getProportions(com)
for fate in [1,2,3]
    barplot!(ax,1:length(com),prop[fate],offset=offset,color=colorMap[fate])
    offset .+= prop[fate]
end

fig
```


    
![png](Development_files/Development_18_0.png)
    


### Make statistics of the model

This model contains stochasticity in the division times and the concentration of chemical components that the daughter agents receive. This will make different runs of the simulation to differ. In order to make statistics we run the model several times and collect information of the size and fates of the cells.


```julia
function makeStatisticsTime(dt,steps,saveEach,nRepetitions)

    #Make simulations and add results to list
    propList = Dict( 1=>[], 2=>[], 3=>[] )
    for i in 1:nRepetitions
        #Make the simulations
        com = initializeEmbryo(parameters);
        customEvolve!(com,dt,steps,saveEach)
    
        #Add them to the model
        prop = getProportions(com)
        for fate in 1:3
            for (j,p) in enumerate(prop[fate])
                if j > length(propList[fate])
                    push!(propList[fate],prop[fate][j:j])
                else
                    push!(propList[fate][j],prop[fate][j])
                end
            end
        end
    end

    #Make statistics of the results
    propMean = deepcopy(propList)
    propStd = deepcopy(propList)
    for fate in 1:3
        for j in 1:length(propList[fate])
            propMean[fate][j] = mean(propList[fate][j])
            propStd[fate][j] = std(propList[fate][j])
        end
    end

    return propMean, propStd
end;
```


    makeStatistics (generic function with 1 method)



```julia
dt = 0.0002
steps = round(Int64,50/dt)
saveEach = round(Int64,1/dt)

nRepetitions = 2

propMean, propStd = makeStatistics(dt,steps,saveEach,nRepetitions);
```


    (Dict{Int64, Vector{Any}}(2 => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  0.24, 0.25925925925925924, 0.25925925925925924, 0.25, 0.22972972972972974, 0.2976190476190476, 0.38390243902439025, 0.43863636363636366, 0.4754500818330606, 0.4517945109078114], 3 => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  0.26, 0.24074074074074073, 0.24074074074074073, 0.25, 0.2702702702702703, 0.39285714285714285, 0.47609756097560973, 0.5213636363636364, 0.5053191489361701, 0.513722730471499], 1 => [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0  …  0.5, 0.5, 0.5, 0.5, 0.5, 0.30952380952380953, 0.14, 0.04, 0.019230769230769232, 0.034482758620689655]), Dict{Int64, Vector{Any}}(2 => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  0.33941125496954283, 0.36664796061524685, 0.36664796061524685, 0.3535533905932738, 0.32488689946408944, 0.2862098876231264, 0.14694023843193618, 0.054640069455324125, 0.019674002095206696, 0.053742105818541254], 3 => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  0.36769552621700474, 0.3404588205713006, 0.3404588205713006, 0.3535533905932738, 0.38221988172245813, 0.15152288168283162, 0.051049660300297096, 0.0019284730395996482, 0.007522412565814307, 0.004976120909124207], 1 => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  0.7071067811865476, 0.7071067811865476, 0.7071067811865476, 0.7071067811865476, 0.7071067811865476, 0.437732769305958, 0.19798989873223333, 0.0565685424949238, 0.02719641466102106, 0.04876598490941707]))



```julia
fig = Figure(resolution=(2000,800))

ax = Axis(fig[1,1])
for fate in 1:3
    errorbars!(ax,1:length(propMean[fate]),propMean[fate],propStd[fate],color=:black)
end
for fate in 1:3
    scatter!(ax,1.:length(propMean[fate]),Float64.(propMean[fate]),markersize=30,color=colorMap[fate])
end

fig
```


    
![png](Development_files/Development_22_0.png)
    


## Fitting the model

The parameters above described were chosen to match the experimental observation. This was a qualitative fitting where the parameters where tuned by hand.

In this section we will show how we can use tuning functions to choose optimize certain parameters of the model. In particular, we tune the model to fit parameters related with the chemical circuit to match the correct distributions of cells.

### Upload experimental data

We upload the experimental data that gives raise to this model.


```julia
data = CustomFunction.uploadExperimentalData();
```


```julia
fig = Figure(resolution=(2000,1000))

ax = Axis(fig[1,1],xlabel="N",xlabelsize=30,ylabel="Cell fates",ylabelsize=30)

offset = zeros(size(data)[1])
legend = []
for cellId in ["DP","EPI","PRE"]
    bp = barplot!(ax,data[!,cellId], offset=offset)
    push!(legend,bp)
    offset .+= data[!,cellId]
end

fig
```




    
![png](Development_files/Development_26_0.png)
    



We see that the data corresponds to sets ranging from 5 to 60 cells, being the usual sized between 5 to 30. 


```julia
fig = Figure(resolution=(2000,800))

cluster = 5
CustomFunction.plotData(data,cluster,fig,1,1)

fig
```




    
![png](Development_files/Development_28_0.png)
    



### Prepare experimental data for fitting

To increase the statistical power, we cluster the data into bins of total cell number and compute the mean and variance statistics.


```julia
dataFit = CustomFunction.clusterExperimentalData(data)
```




<div class="data-frame"><p>10 rows × 7 columns</p><table class="data-frame"><thead><tr><th></th><th>NCluster</th><th>PropDPMean</th><th>PropEpiMean</th><th>PropPreMean</th><th>PropDPVar</th><th>PropEpiVar</th><th>PropPreVar</th></tr><tr><th></th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th></tr></thead><tbody><tr><th>1</th><td>7.5</td><td>0.57213</td><td>0.117172</td><td>0.310698</td><td>0.0783641</td><td>0.0129534</td><td>0.0826128</td></tr><tr><th>2</th><td>10.0</td><td>0.666324</td><td>0.185325</td><td>0.148351</td><td>0.106707</td><td>0.0813161</td><td>0.0356754</td></tr><tr><th>3</th><td>12.5</td><td>0.531393</td><td>0.190841</td><td>0.277767</td><td>0.103513</td><td>0.0274729</td><td>0.0444675</td></tr><tr><th>4</th><td>15.0</td><td>0.508135</td><td>0.164428</td><td>0.327437</td><td>0.111539</td><td>0.0209876</td><td>0.0471392</td></tr><tr><th>5</th><td>17.5</td><td>0.381015</td><td>0.226418</td><td>0.392567</td><td>0.102499</td><td>0.0299968</td><td>0.0612153</td></tr><tr><th>6</th><td>20.0</td><td>0.111762</td><td>0.346149</td><td>0.542089</td><td>0.03021</td><td>0.0243066</td><td>0.0308021</td></tr><tr><th>7</th><td>22.5</td><td>0.0591382</td><td>0.411671</td><td>0.529191</td><td>0.0121628</td><td>0.00968479</td><td>0.0125616</td></tr><tr><th>8</th><td>25.0</td><td>0.0421807</td><td>0.409438</td><td>0.548381</td><td>0.00349641</td><td>0.00972507</td><td>0.0162125</td></tr><tr><th>9</th><td>27.5</td><td>0.0</td><td>0.203281</td><td>0.796719</td><td>1.0</td><td>0.0538351</td><td>0.0538351</td></tr><tr><th>10</th><td>30.0</td><td>0.0</td><td>0.236364</td><td>0.763636</td><td>1.0</td><td>1.0</td><td>1.0</td></tr></tbody></table></div>



### Note on simulated data

We cluster the data in the same way so we can compare the experiments and simulations. Notice that the simulations have statistics at all sizes. We will have to limit to the experimental range in order to compare them.


```julia
dataExperimentalFit = CustomFunction.clusterSimulatedData(simulatedData)
```




<div class="data-frame"><p>13 rows × 7 columns</p><table class="data-frame"><thead><tr><th></th><th>NCluster</th><th>PropDPMean</th><th>PropEpiMean</th><th>PropPreMean</th><th>PropDPVar</th><th>PropEpiVar</th><th>PropPreVar</th></tr><tr><th></th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th></tr></thead><tbody><tr><th>1</th><td>2.5</td><td>1.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td></tr><tr><th>2</th><td>5.0</td><td>1.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td></tr><tr><th>3</th><td>7.5</td><td>1.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td></tr><tr><th>4</th><td>10.0</td><td>1.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td><td>0.0</td></tr><tr><th>5</th><td>12.5</td><td>0.958042</td><td>0.0</td><td>0.041958</td><td>0.0154833</td><td>0.0</td><td>0.0154833</td></tr><tr><th>6</th><td>15.0</td><td>0.433957</td><td>0.0399762</td><td>0.526067</td><td>0.125634</td><td>0.0037344</td><td>0.0999143</td></tr><tr><th>7</th><td>17.5</td><td>0.106723</td><td>0.143919</td><td>0.749358</td><td>0.0264177</td><td>0.00596286</td><td>0.0117087</td></tr><tr><th>8</th><td>20.0</td><td>0.00958891</td><td>0.205069</td><td>0.785342</td><td>0.000286084</td><td>0.00118204</td><td>0.000720346</td></tr><tr><th>9</th><td>22.5</td><td>0.00134953</td><td>0.200886</td><td>0.797764</td><td>3.46033e-5</td><td>0.00137099</td><td>0.00141768</td></tr><tr><th>10</th><td>25.0</td><td>0.0</td><td>0.205617</td><td>0.794383</td><td>0.0</td><td>0.000418489</td><td>0.000418489</td></tr><tr><th>11</th><td>27.5</td><td>0.0</td><td>0.211052</td><td>0.788948</td><td>0.0</td><td>0.000260857</td><td>0.000260857</td></tr><tr><th>12</th><td>30.0</td><td>0.0</td><td>0.211785</td><td>0.788215</td><td>0.0</td><td>0.000675022</td><td>0.000675022</td></tr><tr><th>13</th><td>32.5</td><td>0.0</td><td>0.208562</td><td>0.791438</td><td>0.0</td><td>0.000359499</td><td>0.000359499</td></tr></tbody></table></div>



### Set the exploration space

The optimization algorithms require that you specify a set of parameters to optimize. in our case, our parameters correspond to parameters to the agent. However, they does not need to correcpond to parameters of the agent at all. They will be specified for the algorithm to sample from them and give new updates while optimising. 

We have to define them as a dicctionary.


```julia
explore = Dict([
            :α=>(0,20),
            :K=>(0,2),
            :nn=>(0,5),
            :mm=>(0,5)
        ]);
```

### Construct loos function

With the data prepared to be compared, we set the loos function. 

The loos function is a function that has to receive at least one argument, a `RowDataframe` object that contains the information of the parameters that are being fitted and has to return a value indicating how good wwere the simulations.

The function is very general so it can fit a many different routines.

Our function basically contains the following steps:

 - Sets the new parameters
 - Run several simulations for that set of parameters to get robust statistics
 - Cluster the results from the simulations as before to compare it to the experimental data
 - Compare the experimental and simulation results using a Chi Square metric as loos value.
 
The specific form of the function will depend on the optimization algorithm at hand.


```julia
function loosFunction(params,parameters,dataFit,nRepetitions=10)

    #Modify the set of parameters
    parametersModified = copy(parameters)
    parametersModified[:α] = params.α[1]
    parametersModified[:K] = params.K[1]
    parametersModified[:nn] = params.nn[1]
    parametersModified[:mm] = params.mm[1]
    
    #Make a batch of simulations and get relevant information
    simulatedData = CustomFunction.batchSimulations(mCompiled, parametersModified, nRepetitions)

    #Prepare data for fitting
    simulatedFit = CustomFunction.clusterSimulatedData(simulatedData,5)[3:2+size(dataFit)[1],:]
    
    #Xi square loos
    loos = sum((simulatedFit.PropDPMean .- dataFit.PropDPMean).^2 ./dataFit.PropDPVar .+
    (simulatedFit.PropEpiMean .- dataFit.PropEpiMean).^2 ./dataFit.PropEpiVar .+
    (simulatedFit.PropPreMean .- dataFit.PropPreMean).^2 ./dataFit.PropPreVar)
    
    #Return loos
    return loos
    
end
```




    loosFunction (generic function with 2 methods)



### Check stability of loos function

We run the loos function several times to check that the results are consistent between runs. If the loos function returned different results outside the expected fluctuations, the model would not be proporly fitted as the algorithms would not be able to minimize consistently the cost.

The fluctuations for the simulations using 10 repetitions of the simulation for the same parameters show already enough consistency.


```julia
initialisation = DataFrame([:α=>parameters[:α],:K=>parameters[:K],:nn=>parameters[:nn],:mm=>parameters[:mm]])

Threads.@threads for i in 1:6
    println(loosFunction(initialisation,parameters,dataFit,10))
end
```

    37.524702069795865
    35.692004150800024
    39.58578228237162
    38.01336764695495
    36.61591815064281
    38.63926523924343


### Run the optimization algorithm

Once we have set the loos function and the parameter space to be explored, we can run the algorithm.

The algorithm has done a good job finding a fet of parameters that fits the data. Moreover, it fits better the data than the qualitative fitting that seems to want ot match only the final proportions at step 30.

The discrepacy at earlier time comes from the fact that the chemical circuit only starts at a critial size of `N=20`. A further improvement on the optimization would be to change this global parameter i the system or even to add it to the fitting process.

Overall, we showed the capacity of AgentBasedModels to fit models to real data.


```julia
AgentBasedModels.Optimization.swarmAlgorithm(loosFunction,
                                        explore,
                                        population=50,
                                        stopMaxGenerations=10,
                                        saveFileName="OptimizationResults",
                                        args=[parameters,dataFit,10]
                                    )
```

    [32mGeneration 1/10 100%|████████████████████████████████████| Time: 0:04:20[39m
    [32mGeneration 2/10 100%|████████████████████████████████████| Time: 0:04:19[39m
    [32mGeneration 3/10 100%|████████████████████████████████████| Time: 0:04:19[39m
    [32mGeneration 4/10 100%|████████████████████████████████████| Time: 0:04:23[39m
    [32mGeneration 5/10 100%|████████████████████████████████████| Time: 0:04:16[39m
    [32mGeneration 6/10 100%|████████████████████████████████████| Time: 0:04:12[39m
    [32mGeneration 7/10 100%|████████████████████████████████████| Time: 0:04:11[39m
    [32mGeneration 8/10 100%|████████████████████████████████████| Time: 0:04:12[39m
    [32mGeneration 9/10 100%|████████████████████████████████████| Time: 0:04:11[39m
    [32mGeneration 10/10 100%|███████████████████████████████████| Time: 0:04:13[39m





<p>DataFrameRow (10 columns)</p><div class="data-frame"><table class="data-frame"><thead><tr><th></th><th>α</th><th>nn</th><th>K</th><th>mm</th><th>α_velocity_</th><th>nn_velocity_</th><th>K_velocity_</th><th>mm_velocity_</th></tr><tr><th></th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th><th title="Float64">Float64</th></tr></thead><tbody><tr><th>456</th><td>10.0549</td><td>1.92812</td><td>1.16596</td><td>1.85842</td><td>0.447707</td><td>0.053659</td><td>-0.0858023</td><td>0.00522784</td></tr></tbody></table></div>



### Visualize results

Clearly the algorithm tends to converge to better solutions over time.

A plot of the best solution 


```julia
optimization = CSV.read("OptimizationResults.csv",DataFrame);
```

    WARNING: both GLMakie and Distributions export "scale!"; uses of it in module Main must be qualified



```julia
fig = Figure()
ax = Axis(fig[1,1],xticks=1:10,xlabel="Generations",xlabelsize=30,ylabel="Log loos",ylabelsize=30)

scatter!(ax,optimization._generation_.+rand(Uniform(-.2,.2),500),log.(optimization._score_))
#xticks!(ax,[1,2,3],[1,2,3])

fig
```




    
![png](Development_files/Development_43_0.png)
    




```julia
fig = Figure(resolution=(2000,500))

cluster = 5
ax = CustomFunction.plotData(data[1:end,:],cluster,fig,1,1)
ax.title="Real"; ax.titlesize = 30;
ax.xlabel="N"; ax.xlabelsize = 30;
ax.ylabel="Proportions"; ax.ylabelsize = 30;
xlims!(ax,5,32)

cluster = 5
#simulatedData = CustomFunction.batchSimulations(mCompiled, parameters)
ax = CustomFunction.plotProportions(simulatedData,cluster,fig,1,2)
ax.title="Qualitative fitting"; ax.titlesize = 30;
ax.xlabel="N"; ax.xlabelsize = 30;
ax.ylabel="Proportions"; ax.ylabelsize = 30;
xlims!(ax,5,32)

cluster = 5
best = argmin(Array(optimization._score_))
parametersFit = copy(parameters)
parametersFit[:α] = optimization[best,:α]
parametersFit[:K] = optimization[best,:K]
parametersFit[:nn] = optimization[best,:nn]
parametersFit[:mm] = optimization[best,:mm]
#simulatedDataFit = CustomFunction.batchSimulations(mCompiled, parametersFit)
ax = CustomFunction.plotProportions(simulatedDataFit,cluster,fig,1,3)
ax.title="Swarm optimization"; ax.titlesize = 30;
ax.xlabel="N"; ax.xlabelsize = 30;
ax.ylabel="Proportions"; ax.ylabelsize = 30;
xlims!(ax,5,32)

fig
```




    
![png](Development_files/Development_44_0.png)
    




```julia

```
