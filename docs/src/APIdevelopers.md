# API for Developers

```@meta
CurrentModule = AgentBasedModels
```

## Program 
```@docs
Program_
```

## Declaration
This is a compendium of handful functions that are used all the time during the adaptation of the rest of the models.
```@docs
agentArguments_
checkDeclared_
checkIsDeclared_
emptyquote_
updatedVariables_
```

## Code modifying
Auxiliar functions that help to write clearer code.

```@docs
simpleFirstLoop_
wrapInFunction_
simpleFirstLoopWrapInFunction_
subs_
subsArguments_
vectorize_
```

## Cuda specific

```@docs
cudaAdapt_
configurator_
```

## Compilation
```@docs
addParameters_!
addUpdateGlobal_!
addUpdateLocal_!
addUpdateLocalInteraction_!
```