#List of neighbourhoods available
global NEIGHBOURS = Dict(
    [NeighboursFull=>neighboursFull,
    NeighboursAdjacency=>neighboursByAdjacency,
    NeighboursGrid=>neighboursByGrid
    ])

global NEIGHBORHOODADAPT= Dict(
    [NeighboursFull=>neighboursFullAdapt,
    NeighboursAdjacency=>neighboursByAdjacencyAdapt,
    NeighboursGrid=>neighboursByGridAdapt
    ])

global NEIGHBORHOODLOOP= Dict(
    [
        NeighboursFull=>inloopFull,
        NeighboursAdjacency=>ByAdjacency,
        NeighboursGrid=>inloopByGrid
    ])

function neighborhoodLoop(agentModel::Model)
    return NEIGHBORHOODLOOP[typeof(agentModel.neighborhood)](agentModel)
end