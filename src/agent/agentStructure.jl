"""
    mutable struct Agent

Basic structure which contains the agent based Agent.
"""
mutable struct Agent

    dims::Int
    
    declaredSymbols::Dict{String,Dict{Symbol,Union{Real,Nothing}}}
    declaredUpdates::Dict{String,Expr}
        
    function Agent()
        new(0,
            Dict{String,Dict{Symbol,Union{Real,Nothing}}}("Local"=>Dict{Symbol,Union{Real,Nothing}}(),"Identity"=>Dict{Symbol,Union{Real,Nothing}}(),
                                        "LocalInteraction"=>Dict{Symbol,Union{Real,Nothing}}(),"IdentityInteraction"=>Dict{Symbol,Union{Real,Nothing}}(),
                                        "Global"=>Dict{Symbol,Union{Real,Nothing}}(),"GlobalArray"=>Dict{Symbol,Union{Real,Nothing}}(),
                                        "Medium"=>Dict{Symbol,Union{Real,Nothing}}()),
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