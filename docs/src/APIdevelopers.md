# API for Developers

```@meta
addEventGlobalAddAgent
CurrentModule = CellBasedModels
```

## Base Structures

```@docs
BaseParameter
UserParameter
SavingFile
```

## Auxiliar - Agent

```@docs
checkDeclared
change
baseParameterToModifiable
baseParameterNew
agentArgs
agentArgsNeighbors
getProperty
getSymbolsThat
```

**Function generation**
```@docs
functionDE
functionRule
```
## Auxiliar - Metaprogramming

```@docs
makeSimpleLoop
addCuda
cudaAdapt
vectorize
clean
```

## Auxiliar - Community

```@docs
checkFormat
checkLoaded
@kernelListSurvived!
@kernelFillHolesParameters!
@kernelUpdateParameters!
@update!
```

## Neighbors
```@docs
CBMNeighbors.@verletNeighbors
CBMNeighbors.@neighborsVerletTime
CBMNeighbors.@verletDisplacement
CBMNeighbors.@verletResetDisplacement
CBMNeighbors.@neighborsVerletDisplacement
CBMNeighbors.cellPos
CBMNeighbors.cellPosNeigh
CBMNeighbors.@assignCells
CBMNeighbors.@sortAgentsInCells
CBMNeighbors.@neighborsCellLinked
CBMNeighbors.@verletNeighborsCLVD
CBMNeighbors.@neighborsCLVD
```
