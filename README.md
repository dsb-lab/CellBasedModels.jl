# CellBasedModels.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://dsb-lab.github.io/CellBasedModels.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://dsb-lab.github.io/CellBasedModels.jl/dev/)

The CellBasedModels.jl package aims to help fast-designing and simulation of agent-based models whit possibilities to be run in CPU and NVidia GPUs for the efficient computation of large-scale systems. 

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

Hopefully, soon we will make an official release in the Julia repository. For now, you can install the package from Github as:

```julia
julia> using Pkg
julia> Pkg.add(https://github.com/dsb-lab/CellBasedModels.jl)
```

or from the Pkg REPL

```julia
pkg> add https://github.com/dsb-lab/CellBasedModels.jl
```

## Examples

|||||
|---|---|---|---|
|**Patterning**|**ICM Development**|**Particle Aggregation**|**Bacterial Colony Growth**|
|<img src="./docs/src/assets/Patterning.gif" width="300" height="300">|<img src="./docs/src/assets/Development.gif" width="300" height="300">|<img src="./docs/src/assets/Coalescence.gif" width="300" height="300">|<img src="./docs/src/assets/Bacteries.gif" width="300" height="300">|

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
 - 
## Alternatives to CellBasedModels.jl

Many different packages and programs have been developed for constructing agent-based models. 

Non-Julia-based specific software:
 - [NetLogo](https://ccl.northwestern.edu/netlogo/) is mostly focused on discrete dynamics. It is a bit outdated.
 - [Mason](https://cs.gmu.edu/~eclab/projects/mason/) Developed in Java, it is discrete-step-based software.

Non-Julia-based generic software:
 - [ya||a](https://github.com/germannp/yalla) Software developed with CUDA/C++. It is fast as it is fully parallelized but apart from already written models, that are specific for the study of limb morphogenesis, advanced knowledge of CUDA and C++ is required for any customization. 
 - [Mesa](https://github.com/projectmesa/mesa) is developed in Python with a very intuitive framework. It is specialized in discrete dynamics in grid spaces.

Julia-based generic software:
 - [Agents.jl](https://github.com/JuliaDynamics/Agents.jl). To our knowledge, there is only one alternative package written in Julia for the construction and deployment of agent-based models. It is a mature library and is the way to go for agent-based models in Julia for discrete-time dynamics. As another agent-based library, our library and the Agent.jl library overlaps in some of the capabilities and both can construct models in continuous space with similar capabilities. We focus our library on the simulation of continuous spaces with a continuous time that is described in terms of differential equations with the added value of being able to escalate the system to large amounts of agents by simulating in CUDA. 