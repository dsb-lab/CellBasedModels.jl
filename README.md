# AgentBasedModels.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://dsb-lab.github.io/AgentBasedModels.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://dsb-lab.github.io/AgentBasedModels.jl/dev/)

The AgentBasedModels.jl package aims to help fast designing and simulation of Agent Based models whith possibilities to be run in CPU and NVidia GPUs for the efficient computation of large scale systems.

The following methods can be implemented in the model:

 - ODEs
 - SDEs
 - Division events
 - Death events
 - Boundary conditions

## Installation

For now, the only way of installing the library is by cloning the project. Hopefully soon we will make an official release in the Julia repository.

```julia
julia> using Pkg
julia> Pkg.add(https://github.com/dsb-lab/AgentBasedModels.jl)
```

or from the Pkg REPL

```julia
(v1.6) pkg> add https://github.com/dsb-lab/AgentBasedModels.jl
```
