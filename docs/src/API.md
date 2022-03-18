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

## Model

```@docs
Model
```

## [Compile](@id APIcompilation)

```@docs
compile
```

## [Community](@id APICommunity)

```@docs
Community
CommunityInTime
```

### Constructors

Handy functions to construct starting communities with different geometries.

```@docs
initialiseCommunityCompactCubic
initialiseCommunityCompactHexagonal
```

## Optization

Functions to optimize the parameters of the model.

```@docs
Optimization.gridSearch
Optimization.stochasticDescentAlgorithm
Optimization.geneticAlgorithm
Optimization.swarmAlgorithm
Optimization.beeColonyAlgorithm
```

## Models

```@docs
Models.Bacteria2D
Models.Bacteria2DChannel
Models.Bacteria2DGrowth
```