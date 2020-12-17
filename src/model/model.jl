mutable struct Model

    declaredSymb::Dict{String,Array{Symbol}}
    declaredRandSymb::Dict{String,Array{Tuple}}
    
    equations::Array{Expr}
    inter::Array{Expr}
    locInter::Array{Expr}
    loc::Array{Expr}
    glob::Array{Expr}
    
    division::Tuple{Expr,Array{Expr}}
    remove::Expr

    additionalInteractions::Array{Expr}
    
    function Model()
        new(
            Dict{String,Array{Symbol}}(["var"=>Symbol[],"inter"=>Symbol[],
                                        "loc"=>Symbol[],"locInter"=>Symbol[],"glob"=>Symbol[]]),
            Dict{String,Array{Tuple{Symbol,String}}}(["locRand"=>Tuple{Symbol,String}[],
                    "locInterRand"=>Tuple{Symbol,String}[],"globRand"=>Tuple{Symbol,String}[]]),
            Array(Expr[]),Array(Expr[]),Array(Expr[]),
            Array(Expr[]),Array(Expr[]),
            (:(),Expr[]),:(),
            Array(Expr[]))
    end
end