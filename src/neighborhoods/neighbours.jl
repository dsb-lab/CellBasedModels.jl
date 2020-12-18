#Create neighbours supertype
abstract type Neighbours end

NEIGHBORHOODS = Dict(
    ["full"=>neighboursFull,
    "nnAdjacentcy"=>neighboursByAdjacency,
    "nnGrid"=>neighboursByAdjacency
    ])
