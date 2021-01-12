"""
    mutable struct Model

Basic structure which contains the model.

# Example
```
m = Model(); #Create empty model

addGlobal!(m,:x); #Add a global variable to the model
# Here there may be many more additions
```
"""
mutable struct Model

    declaredSymb::Dict{String,Array{Symbol}}
    declaredRandSymb::Dict{String,Array{Tuple}}
    declaredIds::Array{Symbol}
    
    equations::Array{Expr}
    inter::Array{Expr}
    locInter::Array{Expr}
    loc::Array{Expr}
    glob::Array{Expr}
    id::Array{Expr}

    neighborhood::Neighbours
    special::Array{Special}

    evolve::Function
    
    function Model()
        new(
            Dict{String,Array{Symbol}}(["var"=>Symbol[],"inter"=>Symbol[],
                                        "loc"=>Symbol[],"locInter"=>Symbol[],"glob"=>Symbol[]]),
            Dict{String,Array{Tuple{Symbol,String}}}(["locRand"=>Tuple{Symbol,String}[],
                    "locInterRand"=>Tuple{Symbol,String}[],"globRand"=>Tuple{Symbol,String}[]]),
            Array(Symbol[]),
            Array(Expr[]),Array(Expr[]),Array(Expr[]),
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