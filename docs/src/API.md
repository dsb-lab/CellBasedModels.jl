# [**API**](@id API)

```@meta
CurrentModule = AgentBasedModels
```
## Agent

```@docs
Agent
```

**Functions to use in agents code**
```@docs
euclideanDistance
manhattanDistance
```

## Community

```@docs
Community
```

**Packaging Initializations**

```@docs
initializeSpheresCommunity
packagingCompactHexagonal
packagingCubic
```

## Platform loading

```@docs
loadToPlatform!
bringFromPlatform!
```

## Evolution functions

```@docs
evolve!
step!
globalStep!
localStep!
integrationStep!
interactionStep!
computeNeighbors!
update!
```

## IO
```@docs
saveRAM!
saveJLD2
loadJLD2
```

## Fitting
```@docs
Fitting.gridSearch
<!-- Fitting.stochasticDescentAlgorithm -->
Fitting.swarmAlgorithm
Fitting.beeColonyAlgorithm
Fitting.geneticAlgorithm
```