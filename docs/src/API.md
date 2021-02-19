# API

```@meta
CurrentModule = AgentModel
```

## Model

```@docs
Model
```

### Add Parameters
```@docs
addGlobal!
addLocal!
addLocalInteraction!
addVariable!
addInteraction!
```

### Special
```@docs
addDivision!
addPseudopode!
```

### Neighborhoods
```@docs
setNeighborhoodFull!
setNeighborhoodAdjacency!
setNeighborhoodGrid!
```

### Compile

```@docs
compile!
```

## Community

```@docs
Community
CommunityInTime
```

### Initialisation functions

```@docs
latticeCompactHexagonal
latticeCubic
extrude
extrude!
fillVolumeSpheres
```