# [**API**](@id API)

```@meta
CurrentModule = AgentBasedModels
```

## Agent

Methods involved in the construction and modification of the Agent structure.

```@docs
Agent
@agent
```

## AgentCompiled

```@docs
AgentCompiled
compile
```

## Community

```@docs
Community
CommunityInTime
```

### [**Constructors**](@id APICommunityConstructors)

Handy functions to construct starting communities with different geometries.

```@docs
initialiseCommunityCompactCubic
initialiseCommunityCompactHexagonal
```

## Optimization

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