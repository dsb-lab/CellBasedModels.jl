# [**API**](@id API)

```@meta
CurrentModule = CellBasedModels
```

## Indexing

Structures and Functions to convert between positions to methods in positions in grid laticces of different indexing methods.

```@docs
CellBasedModels.IndexingType
CellBasedModels.LinearIndexing
CellBasedMOdels.MortonIndexing
CellBasedModels.positionToCartesian2D
CellBasedModels.positionToCartesian3D
CellBasedModels.cartesianToLinear2D
CellBasedModels.cartesianToLinear3D
CellBasedModels.linearToCartesian2D
CellBasedModels.linearToCartesian3D
CellBasedModels.cartesianToMorton2D
CellBasedModels.cartesianToMorton3D
CellBasedModels.mortonToCartesian2D
CellBasedModels.mortonToCartesian3D
CellBasedModels.cartesianNeighbors2D
CellBasedModels.cartesianNeighbors3D
CellBasedModels.linearNeighbors2D
CellBasedModels.linearNeighbors3D
CellBasedModels.mortonNeighbors2D
CellBasedModels.mortonNeighbors3D
```

## Parameter

Structures and functions to declare parameters.

```@docs
CellBasedModels.Parameter
CellBasedModels.parameterConvert
```

## Agent

```@docs
ABM
```

### Macros
These are macros that can be used in the code.

**AgentRule**
```@docs
@addAgent
@removeAgent
@loopOverNeighbors
```

**Medium**
```@docs
@∂
@∂2
@mediumInside
@mediumBorder
```

## Community

```@docs
Community
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
agentStepRule!
agentStepDE!
modelStepRule!
modelStepDE!
mediumStepRule!
mediumStepDE!
update!
```

## IO
```@docs
saveRAM!
saveJLD2
loadJLD2
```

## Metrics
```@docs
CBMMetrics.euclidean
CBMMetrics.@euclidean
CBMMetrics.manhattan
CBMMetrics.@manhattan
CBMMetrics.cellInMesh
CBMMetrics.intersection2lines
CBMMetrics.point2line
CBMMetrics.pointInsideRod
CBMMetrics.rodIntersection
```

## Random
Random number generators from distributions that are compatible both in CPU and GPU.

```@docs
CBMDistributions.normal
CBMDistributions.uniform
CBMDistributions.exponential
```

## Platform
```@docs
CPU
GPU
```

## Integrators

Integrators can be used the ones from `DifferentialEquations` for ODE or SDE problems or the custom made solvers provided in ths package.

```@docs
CBMIntegrators.Euler
CBMIntegrators.Heun
CBMIntegrators.RungeKutta4
CBMIntegrators.EM
CBMIntegrators.EulerHeun
```

## Neighbor algorithms

```@docs
CBMNeighbors.Full
CBMNeighbors.VerletTime
CBMNeighbors.VerletDisplacement
CBMNeighbors.CellLinked
CBMNeighbors.CLVD
```

## Fitting

```@docs
CBMFitting.gridSearch
CBMFitting.swarmAlgorithm
CBMFitting.beeColonyAlgorithm
CBMFitting.geneticAlgorithm
```

## Plotting

```@docs
CBMPlots.plotRods2D!
```