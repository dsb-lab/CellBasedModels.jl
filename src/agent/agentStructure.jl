"""
    mutable struct Agent

Basic structure which contains the agent based Agent.

# Examples
```
m = Agent(); #Create empty Agent

addGlobal!(m,:x); #Add a global variable to the Agent
# Here there may be many more additions
```
"""
mutable struct Agent
    
    name::Symbol
    declaredSymbols::Dict{String,Array{Symbol,1}}
    declaredUpdates::Dict{String,Expr}
    
    evolve::Function
    
    function Agent()
        new(
            :NoName,
            Dict{String,Array{Symbol}}(["Identity"=>Symbol[],"Local"=>Symbol[],
                                        "Variable"=>Symbol[],"Global"=>Symbol[],
                                        "GlobalArray"=>Symbol[],"Interaction"=>Symbol[]]),
            Dict{String,Expr}(["UpdateGlobal"=>quote end,"UpdateLocal"=>quote end,
                                        "UpdateLocalInteraction"=>quote end,"UpdateInteraction"=>quote end,
                                        "Equation"=>quote end]),
            needCompilation)
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

"""
    function needCompilation()

Function that ask for compilation before evolve can be used with the current Agent.
"""
function needCompilation(args...;kwargs...)
    error("Agent not yet compiled or modified. Compile it first.")
end