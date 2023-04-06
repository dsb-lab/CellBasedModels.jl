# API for Developers

```@meta
addEventGlobalAddAgent
CurrentModule = CellBasedModels
```

## Base Structures

```@docs
BaseParameter
UserParameter
BaseSymbol
Platform
Equation
Integrator
```

## Auxiliar - Agent

```@docs
checkDeclared
change
baseParameterToModifiable
baseParameterNew
agentArgs
@agentArgs
getProperty
getSymbolsThat
getEquations!
getEquation
addToList
```

**Global**

```@docs
globalFunction
addEventGlobalAddAgent
addGlobalAgentCode
```

**Local**

```@docs
localFunction
addEventAddAgent
addAgentCode
addEventRemoveAgent
removeAgentCode
```

**Integration**

```@docs
integratorFunction
```

**Interaction**

```@docs
interactionFunction
```

**Neighbors**
```@docs
neighborsFunction
neighborsFull!
@verletNeighbors
@neighborsVerletTime
@verletDisplacement
@verletResetDisplacement
@neighborsVerletDisplacement
cellPos
cellPosNeigh
@assignCells
@sortAgentsInCells
@neighborsCellLinked
@verletNeighborsCLVD
@neighborsCLVD
```

**Update**
```@docs
listSurvivedCPU!
@kernelListSurvivedGPU!
@fillHolesCPU!
@kernelFillHolesGPU!
@updateParameters!
updateCPU!
@updateGPU!
```

## Auxiliar - Metaprogramming

```@docs
makeSimpleLoop
addCuda
cudaAdapt
vectorize
clean
randomAdapt
neighborsLoop
neighborsFullLoop
neighborsVerletLoop
neighborsCellLinkedLoop
```
## Auxiliar - Community

```@docs
checkFormat
checkLoaded
removePositions
```

## CUDA Random distributions

```@docs
NormalCUDA
UniformCUDA
ExponentialCUDA
```