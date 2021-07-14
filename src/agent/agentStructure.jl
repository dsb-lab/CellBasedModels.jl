"""
    mutable struct Agent

Basic structure which contains the agent based Agent.
"""
mutable struct Agent

    dims::Int
    
    declaredSymbols::Dict{String,Array{Symbol,1}}
    declaredUpdates::Dict{String,Expr}
    
    evolve::Function
    
    function Agent()
        new(0,
            Dict{String,Array{Symbol}}("Local"=>Symbol[],"Identity"=>Symbol[:agentId],
                                        "Global"=>Symbol[],"GlobalArray"=>Symbol[],"Medium"=>Symbol[]),
            Dict{String,Expr}(),
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