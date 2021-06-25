# Examples

In order to see the capabilities and how to generate and run models, we will consider a real example from the field of life sciences [Saiz 2020](https://elifesciences.org/articles/56079).

## Uploading the package

We start uploading the package.

```@julia
using AgentBasedModels
```

## Creating an empty model

The first step for creating any model is to create and empty Model structure.

```julia
model = Model()
```

In this model we will incorporate all the pieces of the final Agent Based Model. This structure helps to add pieces to the model in a constructive manner helping to constructively create modules.

Schamatically, in the agent based model in the [Saiz 2020](https://elifesciences.org/articles/56079) has three subparts:

 - It has mechanics, leading to movement in the cells.
 - It has a chemical interactions, leading to exchange of concentrations.
 - It has division events representing the growing organism.

 We will go contruct the model in three separated sections.

 ## Adding mechanics

 The dynamics of the cells follow the following equations.

$$m_i\frac{dv_i}{dt} =-bv_i+\sum_j F_{ij}$$
$$\frac{dx_i}{dt} =v_i$$

where the force is

$$F_{ij}=
\begin{cases}
F_0(\frac{r_{ij}}{d}-1)(\frac{\mu r_{ij}}{d}-1)\frac{(x_i-x_j)}{d}\hspace{1cm}\text{if}\;d<\mu r_{ij}\\
0\hspace{4.8cm}\text{otherwise}
\end{cases}$$

If we observe, the model has five different types of terms:

 - **Global parameters** (``b``,``F_0``,``\mu``): These are parameters that will be shared among all the agent in the model.
 - **Local parameters** (``m_i``): These are parameters that vary between cells.
 - Pairwise interactions (``F_{ij}``,``d_{ij}``,``r_{ij}``): This are terms that come from the pairwise interaction between two agents.
 - **Interaction parameters** (``\sum_j F_{ij}``): These are parameters that are computed as a sum of all pairwise interactions from one agent to the rest.
 - **Variables** (``v_i``,``x_i``): These are the variables of the dynamical system.

 Once we have identified all the contributions, we will proceed to declare all the terms in the model.

 First, we introduce the global variables [^1].
 It is possible to intriduce all of them at one:

```julia
 addGlobal!(model,[:b,:F₀,:μ])
```

Then we will define the local parameters.

```julia
 addLocal!(m,[:m,:r])
```

An then the interaction parameters. It is important to notice that we only declare the interacting parameters, that are the sum over all the neighbours of each agent. The pariwise interactions are not usually of interest and having a list of the contributions of each pair would require a lo of memory. Hence, we compute them only to store them in the pariwise interaction terms.

```julia
 interaction = 
 "
 #Define the pairwise distance
 dₐ = sqrt((x₁-x₂)^2+(y₁-y₂)^2+(z₁-z₂)^2)
 #Define the radius sum
 rrₐ = r₁+r₂                              
 #Define the force components under the condition
 if dₐ < μ*rrₐ && dₐ > 0. #Make sure that the force avoids itself or it will diverge 
     Fx₁ += F₀*(rrₐ/dₐ-1)*(μ*rrₐ/dₐ-1)*(x₁-x₂)/dₐ #sum_j F_ij for the x component
     Fy₁ += F₀*(rrₐ/dₐ-1)*(μ*rrₐ/dₐ-1)*(y₁-y₂)/dₐ
     Fz₁ += F₀*(rrₐ/dₐ-1)*(μ*rrₐ/dₐ-1)*(z₁-z₂)/dₐ
 else #This is not really necessary but we include it in the example for shake of completeness
     Fx₁ += 0.
     Fy₁ += 0.
     Fz₁ += 0.
 end
 "
 addInteraction!(m,[:Fx,:Fy,:Fz],interaction)
```

Finally, we will have to include the variables and their dynamical equations.

```julia
eqs = 
#Define the dynamic equations
eqs=
"
dvx = (-b*vx/m+Fx/m)*dt
dvy = (-b*vy/m+Fy/m)*dt
dvz = (-b*vz/m+Fz/m)*dt
dx = vx*dt
dy = vy*dt
dz = vz*dt
"
addVariable!(m,[:vx,:vy,:vz,:x,:y,:z],eqs)
```

And that is it. We have included the dynamical equations to the model.

## Testing the model so far



[^1]: The order in which you declare the different parameters and variables is indiferent.