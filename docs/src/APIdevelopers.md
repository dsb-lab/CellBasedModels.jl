# API for Developers

```@meta
CurrentModule = AgentBasedModels
```

This is a compendium of handful functions that are used all the time during the adaptation of the rest of the models.
```@docs
agentArguments_
checkDeclared_
checkIsDeclared_
clean
subs_
subsArguments_
vectorize_
```

## Wrapping functions
Auxiliar functions that help to write clearer code.

```@docs
simpleFirstLoop_
wrapInFunction_
simpleFirstLoopWrapInFunction_
```

## Cuda specific functions

```@docs
cudaAdapt_
configurator_
```