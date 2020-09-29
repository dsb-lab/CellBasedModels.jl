# Writting models

The main feature of this package is to have te hability to develop cellular models at high level from different modules with the power of being able to use such models both in CPUs of GPUs. For accomplishing this purposes, we write text files where we specify the structure and characteristics of our model. The purpose of writting the code as text files if two folded: avoid the complications of writting specific kernels and the ability to write models at human level code that will be easier to understand and correct.

The text file is structured in headers which determine the properties of the following code.

## Parameter headers

In order to define relevant parameters for our systems we may use different headers.

### GlobalParams:

In this header should include all the parameters of the model that are shared by all the cells of the model. For example, if our model depends on the temperature and the magnetic field, which we consider that are uniform for all the cells in the system, we will include it as:

```julia
text = 
"
GlobalParams:
T, H #Temperature and Magnetic field of the model
"
```

Notice that we can add comments after a #. 

### LocalParams:

Under this header we should include all the parameters that may variate between cells but that are not described by a differential set of equations. Imagine for example that the cells of our system have have flutuating promotor strengths. In such situation, we include the parameters as local parameters.

```julia
text = 
"
LocalParams:
K #Promotor strenght of the model
"
```

### Variables:

The dynamics of the model are described by variables. All the terms in the model that are described by differential equations appear in such header. Consider for example that in our model we have cells with a chemical component and statial dynamics in the three dimensions.

```julia
text = 
"
Variables:
x1,x2,x3 #Spatial variables
c        #Chemical component
"
```
The differential equations describing the evolution of the variables have to be described later under the Equations: header.

### RandomVariables:

Finally, our models may depend on random variables. Such random variables may take affect the dynamics, transforming the system in stochastic differential equations, or may be used to choose the random axis if division during cellular mitosis.

```julia
text = 
"
RandomVariables:
\epsilon        #Stochastic variable affecting the chemical dynamcs
r1,r2,r3        #Random variables choosing the axis of division durin mitosis
"
```

## Equations

All the variables must have a differential equation which describes them. These equations must depend on declared parameters of the system and simple functions that can be accessed from the code. We will always declare them by ``dVARIABLE/dt = ...`` Following the previous example, imagine that the cells in our model follow a uniform movement and the chemical systems in self damped.

```julia
text = 
"
Equations:
dx1/dt = H        #Movement that depends on the magnetic field felt by the particles
dx2/dt = H        #Movement that depends on the magnetic field felt by the particles
dx3/dt = H        #Movement that depends on the magnetic field felt by the particles
dc/dt = -c+T*\epsilon        #Self damping with a random variable
"
```

The equations allow the definition of simple functions. By simple we refer to functions that do not require heavy memory allocations (e.g. arrays) for its computation. This is a requirement for allowing the models to works seamlesly both in CPUs and GPUs.

```julia
#Custom defined function that does not depend on arrays nor heavy memory allocations
function f(x,y)
    g = y*y #This allocates some memory during the run. It is allowed as long as the allocation is static.
    return x - g

text = 
"
Equations:
dx1/dt = sin(H)   #The equation depend in a build in method from the julia package. This is a valid definition
dx2/dt = f(x2,H)  #The equation depend on a custom made function defined by the user outside the text. This is a valid definition.
dx3/dt = H        #Movement that depends on the magnetic field felt by the particles
dc/dt = -c+T*\epsilon        #Self damping with a random variable
"
```
The definition of external functions outside the model are usefull for simple functions. The requirement that these functions are "simple" may seem a drawback of the program. However, the aim of the this package is to be able to define arbitrary complex models in a high level framework. Any arbitrary function could be defined in terms of parameters and variables defined inside the systems, by declaring them.

## Rules

During the time evolution, discrete processes may happen as exchange of chemicals, computation of forces or cell division. These processes are defined through algorithms. In order to specify where and when these alorithms are computed, we define rules.

### NeighboursRules:

For computing the cell-cell interactions, we can perform an extensive computation between all the interactive terms. Such computations may be very expensive. However, in many cases, it is only necessary the to compute interactions over a local neighbourhood (e.g. forces exerted between local neighbours or local exchange of chemical components). We can define algorithms that are only computed between neighbours so we reduce computational time. In this header we define the set of conditions that are necessary in order to consider two cells to be neighbours. Since the conditions depend on pairwise interactions, it is necessary to specify to which cell belong the parameters (``cell1`` or ``cell2``).

```julia
text = 
"
NeighboursRules:
sqrt(cell1.x1-cell2.x1)^2+(cell1.x2-cell2.x2)^2+(cell1.x3-cell2.x3)^2) < 0.1 #The neighbours are only those cells whose euclidean distance is under
"
```
If more than one rule is set, they are consider all necessary to be considered a neighbour.

### DivisionRules:

These rules determine when the cells have to split in two cells.

```julia
text = 
"
NeighboursRules:
c < 0.1 #The cell will split every time that the concentration of c is below certain threshold.
"
```

## Algorithms

In the algorithms, we specify all the processes that are not campture by single cell dynamics as the forces between cells, the exchange of chemicals. We also specify here the division algorithm, which is a non-continuous process of the model.

### CellCellGlobalAlgorithms:

We include in this header all the processes which require the interaction between all the cells in the system. Since these are cell-cell interacting algorithms, we need to specify the cell receiving (``cell1``) and the cell giving the interaction (``cell2``).

```julia
text = 
"
CellCellGlobalAlgorithms:
cell1.c <- cell2.c/gaussian(d) #The cell1 will receive concentration from cell2 inversely proportional to the distance to it.
"
```
Two details to notice. Instead of an equality ``=``, we have assign the values by the ``<-`` as ``cell1`` will receive a sum over all the other cells in the model. Second, since ``d`` is a cell-cell interacting parameter which is symmetric, we do not need to specify the components. by default the fist component will be choosed to be ``cell1`` and the second component to be ``cell2``. If an inverse wants to be performed, in case of asymmetric components, we should specify ``d[cell2,cell1]`` instead.

### CellCellLocalAlgorithms:

These algorithms will be computed only thorugh the neighbours of each cells. For sparse neighbourhood, this may greatly simplify the computational cost.

```julia
text = 
"
CellCellLocalAlgorithms:
cell1.c <- cell2.c/cell2.Nnn #The cell1 will receive concentration from cell2 inversely proportional to the number of nearest neighbours of this cell.
"
```

### DivisionAlgorithms:

The last header that can be included is the division header. This header specifies the procedure to divide the cells. In this header, we specify what parameters change after the division. We specify the parent cell as ``parent`` and the two daughter cells as ``daughter1`` and ``daughter2``.

```julia
text = 
"
CellCellLocalAlgorithms:
daughter1.x1 = parent.x1+r1 #The daugter will be move according to a r1 variable.
daughter2.x1 = parent.x1+-r1 #The daugter will be move inversely according to a r1 variable.
daughter1.x2 = parent.x1+r2 #The daugter will be move according to a r2 variable.
daughter2.x2 = parent.x1+-r2 #The daugter will be move inversely according to a r2 variable.
daughter1.x3 = parent.x1+r3 #The daugter will be move according to a r3 variable.
daughter2.x3 = parent.x1+-r3 #The daugter will be move inversely according to a r3 variable.
"
```
The rest of the unespecified parameters will be exact copies of the original parent.

## Mixing headers and Models

All the parameters above 