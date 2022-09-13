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
    
    declaredSymbols::DataFrame
    declaredSymbolsUpdated::DataFrame
    additionalSymbols::DataFrame
    declaredUpdates::Dict{Symbol,Expr}
    neighbors::Neighbors
    integrator::Integrator
    platform::Symbol
    saving::Symbol
        
    function Agent()
        new(0,
            DataFrame(name=Symbol[],type=Symbol[],use=Symbol[]),
            DataFrame(name=Symbol[],type=Symbol[],use=Symbol[]),
            DataFrame(name=Symbol[],type=Symbol[],use=Symbol[]),
            Dict{Symbol,Expr}(),
            NeighborsFull,
            Euler,
            :CPU,
            :RAM
            )
    end

end

function Base.show(io::IO,abm::Agent)
    print("PARAMETERS\n")
    for i in unique(abm.declaredSymbols.type)
        print("\t",i)
        println("\t", abm.declaredSymbols[abm.declaredSymbols.type .== i, :].name)
    end

    print("\n\nUPDATED PARAMETERS\n")
    for i in unique(abm.declaredSymbolsUpdated.type)
        print("\t",i)
        println("\t", abm.declaredSymbolsUpdated[abm.declaredSymbolsUpdated.type .== i, :].name)
    end

    print("\n\nADDITIONAL PARAMETERS\n")
    for i in unique(abm.additionalSymbols.type)
        print("\t",i)
        println("\t", abm.additionalSymbols[abm.additionalSymbols.type .== i, :].name)
    end

    print("\n\nUPDATE RULES\n")
    for i in keys(abm.declaredUpdates)
        if [i for i in abm.declaredUpdates[i].args if typeof(i) != LineNumberNode] != []
            print(i,"\n")
            print(" ",prettify(copy(abm.declaredUpdates[i])),"\n\n")
        end
    end
end