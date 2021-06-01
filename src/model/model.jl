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

    name::Symbol
    declaredSymbols::Dict{String,Array{Any}}
    declaredUpdates::Dict{String,Array{Any}}
    
    evolve::Function
    
    function Model()
        new(
            :NoName,
            Dict{String,Array{Symbol}}(["Identity"=>Symbol[],"Local"=>Symbol[],
                                        "Variable"=>Symbol[],"Global"=>Symbol[],
                                        "GlobalArray"=>Symbol[],"Interaction"=>Symbol[]]),
            Dict{String,Array{Symbol}}(["Global"=>Tuple[],"Local"=>Tuple[],
                                        "LocalInteraction"=>Tuple[],"Interaction"=>Tuple[],
                                        "Equation"=>Tuple[]]),
            needCompilation)
    end
end

function Base.show(io::IO,abm::Model)
    print("PARAMETERS\n")
    for i in keys(abm.declaredSymb)
        if ! isempty(abm.declaredSymb[i])
            print(i,"\n\t")
            for j in abm.declaredSymb[i]
                print(" ",j,",")
            end
        end
    end
    
    print("UPDATE RULES\n")
    for i in keys(abm.declaredUpdate)
        if ! isempty(abm.declaredUpdate[i])
            print(i,"\n\t")
            for j in abm.declaredUpdate[i]
                print(" ",j[2],",")
            end
        end
    end
end

"""
    function needCompilation()

Function that ask for compilation before evolve can be used with the current model.
"""
function needCompilation(args...;kwargs...)
    error("Model not yet compiled or modified. Compile it first.")
end