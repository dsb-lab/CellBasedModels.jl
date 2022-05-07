# API for Developers

```@meta
CurrentModule = AgentBasedModels
```

## Auxiliar functions for Agent creation
All the auxiliar functions used by `@agent` to create the `Agent` structure.

```@docs
checkDeclared_
```
## Functions for Model creation
All the auxiliar functions used inside `compile` to create the compiled object `AgentCompiled` from the `Agent` into a compiled model.

### Auxiliar structures
```@docs
Program_
```
### Auxiliar functions
```@docs
addMediumCode
cudaAdapt_
updates_!
vectorize_
simpleFirstLoop_
simpleGridLoop_
wrapInFunction_
simpleFirstLoopWrapInFunction_
simpleGridLoopWrapInFunction_
randomAdapt_
```
### Basic code
```@docs
addParameters_!
addUpdate_!
addUpdateGlobal_!
addUpdateInteraction_!
addUpdateLocal_!
addEventAddAgent_
addEventRemoveAgent_
addUpdateMediumInteraction_!
boundariesFunctionDefinition
```
### Integrators
Functions used to implement the different integration methods for `UpdateVariable`.

```@docs
addIntegratorEuler_!
addIntegratorHeun_!
addIntegratorRungeKutta4_!
addIntegratorVerletVelocity_!
```
### Integrators Medium
Functions used to implement the different integration methods for `UpdateMedium`.

```@docs
addIntegratorMediumFTCS_!
addIntegratorMediumLax_!
```
### Neighbors
Functions used to adapt the code to run over the different neighborhood search algorithms that are used when computing interactions in `UpdateInteraction`.

```@docs
argumentsFull_!
loopFull_
argumentsGrid_!
loopGrid_
```

### Saving
Functions used to adapt the code to be saved in specified formats and memory locations.

```@docs
addSavingRAM_!
addSavingJLD_!
addSavingCSV_!
```



