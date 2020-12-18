mutable struct Model

    declaredSymb::Dict{String,Array{Symbol}}
    declaredRandSymb::Dict{String,Array{Tuple}}
    declaredIds::Array{Symbol}
    
    equations::Array{Expr}
    inter::Array{Expr}
    locInter::Array{Expr}
    loc::Array{Expr}
    glob::Array{Expr}
    
    neighborhood::Neighbours
    special::Array{Special}
    
    function Model()
        new(
            Dict{String,Array{Symbol}}(["var"=>Symbol[],"inter"=>Symbol[],
                                        "loc"=>Symbol[],"locInter"=>Symbol[],"glob"=>Symbol[]]),
            Dict{String,Array{Tuple{Symbol,String}}}(["locRand"=>Tuple{Symbol,String}[],
                    "locInterRand"=>Tuple{Symbol,String}[],"globRand"=>Tuple{Symbol,String}[]]),
            Array(Symbol[]),
            Array(Expr[]),Array(Expr[]),Array(Expr[]),
            Array(Expr[]),Array(Expr[]),
            NeighboursFull(),Special[])
    end
end