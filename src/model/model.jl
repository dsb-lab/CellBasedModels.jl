"""
    mutable struct Model

Basic structure which contains the agent based model.

# Examples
```
m = Model(); #Create empty model

addGlobal!(m,:x); #Add a global variable to the model
# Here there may be many more additions
```
"""
mutable struct Model

    declaredSymb::Dict{String,Array{Symbol}}
    declaredSymbArrays::Dict{String,Array{Tuple{Symbol,Array{Int}}}}
    declaredRandSymb::Dict{String,Array{Tuple}}
    declaredRandSymbArrays::Dict{String,Array{Tuple}}
    declaredIds::Array{Symbol}
    
    equations::Expr
    inter::Array{Expr}
    locInter::Array{Expr}
    loc::Array{Expr}
    glob::Array{Expr}
    ids::Array{Expr}

    neighborhood::Neighbours
    special::Array{Special}

    evolve::Function
    
    function Model()
        new(
            Dict{String,Array{Symbol}}(["var"=>Symbol[],"inter"=>Symbol[],
                                        "loc"=>Symbol[],"locInter"=>Symbol[],"glob"=>Symbol[],
                                        "ids"=>Symbol[]]),
            Dict{String,Array{Symbol}}(["glob"=>Symbol[]]),
            Dict{String,Array{Tuple{Symbol,<:Distribution}}}(["loc"=>Tuple{Symbol,<:Distribution}[],
                    "locInter"=>Tuple{Symbol,<:Distribution}[],"glob"=>Tuple{Symbol,<:Distribution}[],
                    "var"=>Tuple{Symbol,<:Distribution}[],"ids"=>Tuple{Symbol,<:Distribution}[]]),
            Dict{String,Array{Tuple{Symbol,<:Distribution}}}(["glob"=>Tuple{Symbol,<:Distribution}[]]),
            Symbol[],
            :(),Array(Expr[]),Array(Expr[]),
            Array(Expr[]),Array(Expr[]),Array(Expr[]),
            NeighboursFull(),Special[],
            needCompilation)
    end
end

"""
    function needCompilation()

Function that ask for compilation before evolve can be used with the current model.
"""
function needCompilation()
    error("Model not yet compiled or modified. Compile it first.")
end