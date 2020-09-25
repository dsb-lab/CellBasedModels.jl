abstract type ChemicalDynamics end

##################################################
#No chemical reactions
##################################################

struct noChemical <: ChemicalDynamics

    #Global properties
    chemicalParametersGlobalNames::Array{String}
    #Local properties
    chemicalDynamicsLocalNames::Array{String}

    chemicalParametersLocalNames::Array{String}
    
    function noChemical()
        namesParamGlob = []
        namesDynamics = []
        namesParamLoc = []
        new(namesParamGlob,namesDynamics,namesParamLoc)
    end
    
end
#Pretty printing of the noChemical structure
Base.show(io::IO, z::noChemical) = print(io, "Global chamical parameters\n ",z.chemicalParametersGlobalNames,"\n",
                                                 "Local chemical parameters\n ",z.chemicalDynamicsLocalNames,"\n",
                                                 "Local chemical dynamics\n ",z.chemicalParametersLocalNames,"\n")

function noChemicalFunction(gParam, lParam, dynamics, t, aux, idCell, idaux)
    
    for i = 1:length(dynamics)
        aux[idCell, i] = 0
    end

    return nothing
end