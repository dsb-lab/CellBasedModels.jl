# [**API**](@id API)

```@meta
CurrentModule = AgentBasedModels
```
## Base Parameters

Base parameters are all the parameters that any of the Agent Based Models defined have present as internals. 

|Topic|Symbol|Description|
|---|---|---|
|**Time**|||
||t|Absolute time of evolution of the community.|
||dt|Time increments in each step of the evolution.|
|**Size Community**|||
||N|The number of agents active in the community.|
||NMedium|Size of the grid in which the medium is being computed. This is necessary to be declared if medium parameters are declared by the user.|
||nMax_|Maximum number of agents that can be present in the community.|
|**Id tracking**|||
||id|Unique identifier of the agent.|
||idMax_|Maximum identifier that has been declared in the community.|
|**Simulation space**|||
||simBox|Simulation box in which cells are moving. This is necessary to define a region of space in which a medium will be simulated or for computing neighbors with CellLinked methods.|
|**Agent addition or removal**|||
||NAdd_|Number of agents added in a step.|
||NRemove_|Number of agents removed in a step.|
||NSurvive_|Number of agents survived in a step.|
||flagSurvive_|Flag agents that survived.|
||holeFromRemoveAt_|Keeps position of cells that where removed during a step.|
||repositionAgentInPos_|Keeps position of cells starting from the end that have survived. It helps to reassign cells in the end of the array into the holes.|
|**Neighbors**|||
||skin|Distance below which a cell is considered a neighbor in Verlet neighbor algorithms.|
||dtNeighborRecompute|Time before recomputing neighborhoods in VerletTime algorithm.|
||nMaxNeighbors|Maximum number of neighbors. Necessary for Verlet-like algorithms.|
||cellEdge|Distance of the grid used to compute neighbors.|
||flagRecomputeNeighbors_|Marked as 1 if recomputation of neighbors has to be performed.|
||neighborN_|Number of neighbors for each agent. Used in Verlet-like algorithms.|
||neighborList_|Matrix containing the neighbors of each Agent. Used in Verlet-like algorithms.|
||neighborTimeLastRecompute_|Time storing the information of last neighbor recomputation. Used in Verlet time algorithm.|
||posOld_|Stores the position of each agent in the last VerletDistance neighbor computation.|
||accumulatedDistance_|Stores the accumulated displaced distance of each agent in the last VerletDistance neighbor computation.|
||nCells_|Number of cells in each dimensions of the grid. Used in CellLinked algorithms.|
||cellAssignedToAgent_|Cell assigned to each agent. Used in CellLinked algorithms.|
||cellNumAgents_|Number of agents assigned to each cell. Used in CellLinked algorithms.|
||cellCumSum_|Cumulative number of agents in the cell list. Used in CellLinked algorithms.|
|**Position**|||
||x|Position of the agent in the x axis.|
||y|Position of the agent in the y axis.|
||z|Position of the agent in the z axis.|
||xNew_|Position of the agent in the x axis if updated during a step.|
||yNew_|Position of the agent in the y axis if updated during a step.|
||zNew_|Position of the agent in the z axis if updated during a step.|
|**User declared parameters**|||
||liNM_|Matrix storing user-defined Local Integer parameters that are not modifiable.|
||liM_|Matrix storing user-defined Local Integer parameters that are modifiable.|
||liMNew_|Matrix storing user-defined Local Integer parameters that are modifiable after a step.|
||lii_|Matrix storing user-defined Local Integer parameters that are reset to zero after every step.|
||lfNM_|Matrix storing user-defined Local Float parameters that are not modifiable.|
||lfM_|Matrix storing user-defined Local Float parameters that are not modifiable.|
||lfMNew_|Matrix storing user-defined Local Float parameters that are not modifiable after a step.|
||lfi_|Matrix storing user-defined Local Float parameters that are reset to zero after every step.|
||gfNM_|Matrix storing user-defined Global Integer parameters that are not modifiable.|
||gfM_|Matrix storing user-defined Global Integer parameters that are not modifiable.|
||gfMNew_|Matrix storing user-defined Global Integer parameters that are not modifiable after a step.|
||gfi_|Matrix storing user-defined Global Integer parameters that are reset to zero after every step.|
||giNM_|Matrix storing user-defined Global Integer parameters that are not modifiable.|
||giM_|Matrix storing user-defined Global Integer parameters that are not modifiable.|
||giMNew_|Matrix storing user-defined Global Integer parameters that are not modifiable after a step.|
||gii_|Matrix storing user-defined Global Integer parameters that are reset to zero after every step.|
||mediumNM_|Matrix storing user-defined Medium (Float) parameters that are not modifiable.|
||mediumM_|Matrix storing user-defined Medium (Float) parameters that are not modifiable.|
||mediumMNew_|Matrix storing user-defined Medium (Float) parameters that are not modifiable after a step.|

## Metrics

```@docs
euclideanDistance
manhattanDistance
```

## Agent

Methods involved in the construction and modification of the Agent structure.

```@docs
Agent
```

## Community

```@docs
Community
loadToPlatform!
```

## Evolving

```@docs
update!
```