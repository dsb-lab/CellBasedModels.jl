"""
    mutable struct Agent

Basic structure which contains the high level code specifying the rules of the agents. 
For constructing such agents, it is advised to use the macro function `@agent`.

# Elements

 - **dims::Int**: Dimensions of the model.
 - **declaredSymbols::Dict{String,Array{Symbol,1}}**: Dictionary containing all the parameters of the model.
 - **declaredUpdates::Dict{String,Expr}**: Dictionary containing all the code specifying the rules of the agents.
"""
mutable struct Agent

    dims::Int
    
    declaredSymbols::Dict{String,Array{Symbol,1}}
    declaredUpdates::Dict{String,Expr}
        
    function Agent()
        new(0,
            Dict{String,Array{Symbol}}("Local"=>Symbol[],"Identity"=>Symbol[],"LocalInteraction"=>Symbol[],"IdentityInteraction"=>Symbol[],
                                        "Global"=>Symbol[],"GlobalArray"=>Symbol[],"Medium"=>Symbol[]),
            Dict{String,Expr}()
            )
    end
end

function Base.show(io::IO,abm::Agent)
    print("PARAMETERS\n")
    for i in keys(abm.declaredSymbols)
        if ! isempty(abm.declaredSymbols[i])
            print(i,"\n\t")
            for j in abm.declaredSymbols[i]
                print(" ",j,",")
            end
            print("\n")
        end
    end
    
    print("\n\nUPDATE RULES\n")
    for i in keys(abm.declaredUpdates)
        if [i for i in abm.declaredUpdates[i].args if typeof(i) != LineNumberNode] != []
            print(i,"\n")
            print(" ",clean(copy(abm.declaredUpdates[i])),"\n\n")
        end
    end
end