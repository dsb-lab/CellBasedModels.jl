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
    declaredSymbols::Dict{String,Array{Any}}
    declaredUpdates::Dict{String,Array{Any}}
    
    evolve::Function
    
    function Agent()
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

function Base.show(io::IO,abm::Agent)
    print("PARAMETERS\n")
    for i in keys(abm.declaredSymbols)
        if ! isempty(abm.declaredSymbols[i])
            print(i,"\n\t")
            for j in abm.declaredSymbols[i]
                print(" ",j,",")
            end
        end
    end
    
    print("\n\nUPDATE RULES\n")
    for i in keys(abm.declaredUpdates)
        if ! isempty(abm.declaredUpdates[i])
            print(i,"\n\t")
            for j in abm.declaredUpdates[i]
                print(" ",j[2],",")
            end
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