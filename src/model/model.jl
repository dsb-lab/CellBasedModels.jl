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
    declaredSymb::Dict{String,Array{Symbol}}
    declaredUpdates::Dict{String,Array{Tuple{Symbol,Expr}}}
    
    evolve::Function
    
    function Model()
        new(
            :UpdateGlobal,
            :UpdateLocal,
            :UpdateLocalInteraction,
            :UpdateInteraction,
            :Equation
        
            :NoName,
            Dict{String,Array{Symbol}}(["Id"=>Symbol[],"Local"=>Symbol[],
                                        "Variable"=>Symbol[],"Global"=>Symbol[],
                                        "GlobalArray"=>Symbol[],"Interaction"=>Symbol[]]),
            Dict{String,Array{Symbol}}(["UpdateGlobal"=>Symbol[],"UpdateLocal"=>Symbol[],
                                        "UpdateLocalInteraction"=>Symbol[],"UpdateInteraction"=>Symbol[],
                                        "Equation"=>Symbol[]]),
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
                print(" ",j,",")
            end
        end
    end
end

"""
    function needCompilation()

Function that ask for compilation before evolve can be used with the current model.
"""
function needCompilation()
    error("Model not yet compiled or modified. Compile it first.")
end