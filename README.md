# CellBasedModels.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://dsb-lab.github.io/CellBasedModels.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://dsb-lab.github.io/CellBasedModels.jl/dev/)

You can find the documentation [**here!**](https://dsb-lab.github.io/CellBasedModels.jl/stable/)

The CellBasedModels.jl package aims to help fast-designing and simulation of agent-based models with possibilities to be run in CPU and NVidia GPUs for the efficient computation of large-scale systems. 

The following methods can be implemented in the model:

 - ODEs
 - SDEs
 - Division
 - Death
 - Coupling to continuum models evolving with PDEs
 - Random events

Check the 
Examples to get an idea of the capabilities of the package.

## Installation

You can install the package from the official repositories as:

```julia
julia> using Pkg
julia> Pkg.add("CellBasedModels")
```

or you can install the developer version from Github as:

```julia
julia> using Pkg
julia> Pkg.add(url="https://github.com/dsb-lab/CellBasedModels.jl")
```

Alternatively, you can install it from the Pkg REPL:

```julia
] add CellBasedModels
```

```julia
] add https://github.com/dsb-lab/CellBasedModels.jl
```

## Docker

There are available docker images that already have everything installed with the packages you may need to execute simulations out-of-the-box.

For more information see [this section](https://github.com/dsb-lab/CellBasedModels.jl/tree/master/docker)

## Examples

||||||
|---|---|---|---|---|
|**Patterning**|**ICM Development**|**Particle Aggregation**|**Bacterial Colony Growth**|**Bacterial Chemotaxis**|
|<img src="./docs/src/assets/patterning.gif" width="300" height="300">|<img src="./docs/src/assets/Development.gif" width="300" height="300">|<img src="./docs/src/assets/aggregation.gif" width="300" height="300">|<img src="./docs/src/assets/colony.gif" width="300" height="300">|<img src="./docs/src/assets/chemotaxis.gif" width="300" height="300">|

## Current Limitations

At the present stage of development, the library is not capable of working on batches of data. That means that the size of the simulated models will be limited by the memory disponibility in RAM or the GPU, depending on the platform in which the simulations are being tested. 

Moreover, we can only use GPUs from NVidia as the GPU implementation is based on CUDA.jl.

## Future work

We intend to extend the current version of the package with additional capabilities. Any help is welcome!

### Short term 

 - Addition of coupling to continuum systems.
 - Additions of inactive agents to make arbitrary shape boundaries.
 - Add more examples
 - Increase the number of implemented models.

### Long term goals

 - Extend GPU capabilities to be used also in other packages.
 - Make optimization methods distributable among different CPU/GPUs.
