# AgentBasedModels.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://dsb-lab.github.io/AgentBasedModels.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://dsb-lab.github.io/AgentBasedModels.jl/dev/)

The AgentBasedModels.jl package aims to help fast designing and simulation of Agent Based models.

The following dynamical methods can be implemented in the model:

 - ODEs
 - SDEs

Additionally, the package incorporates special functions as:

 - Division events
 - Death events
 - Randomly selected pairwise interactions

The created models can run the simulations both in CPU and CUDA GPU thanks to the CUDA.jl. The possibility to run in the simulations in GPU makes it possible to run in a resonable time simulations with a huge number of particles in modest computers while allowing to move the simulations to CPU clusters.

## Installation

For now, the only way of installing the library is by cloning the project. Hopefully soon we will make an official release in the Julia framework.

## Requirements

The current version of AgentModel.jl requires the following packages:

 - Random = 1.5
 - Distributions = 1.6
 - CUDA = 1.5

