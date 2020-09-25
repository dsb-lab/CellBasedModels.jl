abstract type GrowDynamics end

##################################################
#No chemical reactions
##################################################

struct sphericalNoGrowNoDivision <: GrowDynamics

    #Local properties
    shapeParametersLocalNames::Array{String}
    
    function sphericalNoGrowNoDivision(dim::Integer=3)
        namesParamLoc = ["radius","innerTime"]
        new(namesParamLoc)
    end
    
end
#Pretty printing of the noMovement structure
Base.show(io::IO, z::sphericalNoGrowNoDivision) = print(io, "Local shape parameters\n ",z.shapeParametersLocalNames,"\n")

function sphericalNoGrowFunction(gParam, lParam, dynamics, aux, t, idCell, idaux)
    
    for i = 1:length(dynamics)
        aux[idCell, i] = 0
    end

    return nothing
end