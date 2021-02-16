The AgentBasedModels.jl package aims to help fast designing and simulation of Agent Based models.

The following dynamical methods can be implemented in the model:

 - ODEs
 - SDEs

Additionally, the package incorporates special functions as:

 - Division events
 - Death events
 - Randomly selected pairwise interactions

The created models can run the simulations both in CPU and CUDA GPU thanks to the CUDA.jl. The possibility to run in the simulations in GPU makes it possible to run in a resonable time simulations with a huge number of particles.

## Installation

Two options to install de package.

Pkg.add("AgentBasedModels")

or clone it from the repository.

## Requirements and Optional Modules

The current version of AgentModel.jl requires the following packages:

 - Random >= 1.5
 - Distributions >= 1.6

Up to the current state of ourknowledge, it is not possible to include optional packages in Julia. In case that the simulations want to be performed in GPU, the package [CUDA.jl](https://github.com/JuliaGPU/CUDA.jl) should be installed aditionally,

 - CUDA = 1.5