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