# API

```@meta
CurrentModule = AgentBasedModels
```

## Agent

Methods involved in the construction and modification of the Agent structure.

```@docs
Agent
@agent
add
```

## Simulation Spaces (@id Simulation)

Methods involved in the creation of spaces of simulation.

**Simulation Full**: Simulation space for N-body simulations with all-with-all interactions.
The method implemented so far uses a brute force approach and only parallelizes over the number of agents, 
hence having a minimum cost of computation of ``O(N)`` at best.

**Simulation grid**: Simulation space for N-body simulations with local interactions.
The algorithm implemented uses a fixed radial neighbours search as proposed by 
[Rama C. Hoetzlein](https://on-demand.gputechconf.com/gtc/2014/presentations/S4117-fast-fixed-radius-nearest-neighbor-gpu.pdf)
both for CPU and GPU. For now, the last step of the proposed algorithm, sorting, is ignored but the idea may be to implement for the GPU case soon if it really makes a difference.


### Boundaries

```@docs
Bound
Periodic
```

## Model

```@docs
Model
```

## [Compile](@id APIcompilation)

```@docs
compile
```

## Community

```@docs
Community
CommunityInTime
```
