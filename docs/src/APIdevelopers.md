# API for Developers

```@meta
CurrentModule = AgentBasedModels
```

## Auxiliar functions
This is a compendium of handful functions that are used all the time during the adaptation of the rest of the models.
```@docs
platformAdapt
vectParams
adapt
pushAdapt!
addIfNot!
checkDeclared
clean
commonArguments
findSymbol
splits
splitEqs
subs
parameterAdapt
```

## Precompilation
```@docs
precompile!
```

## Set neighbourhood
All the neighborhood types X share the same structure. They contain always four elements:
  1. A NeighborhoodX structure that keeps all the required elements in order to define the neighborhood. This structured is created when calling the setNeighborhoodX! and added to the model.
  2. The setNeighborhoodX! function that is the high level function for seting a neighborhood. The details are present in the API.
  3. A neighboursX function that is runned during compilation time and creates the functions that computed to make the neighborhoods.
  4. A neighboursXAdapt that assigns the inner loop iterator `:nnic2_` into the appropiate term depending on the neighborhood type.

Functions defined in 2 and 4 have always the same inputs and outputs.

### Full connected
```@docs
NeighboursFull
neighboursFull
neighboursFullAdapt
```

### By Adjacecy
```@docs
NeighboursAdjacency
neighboursByAdjacency
neighboursByAdjacencyAdapt
```

### By Grid
```@docs
NeighboursGrid
neighboursByGrid
neighboursByGridAdapt
loopNeighbourGridCreation
```

## Integrators
```@docs
integratorEuler
integratorHeun
```
