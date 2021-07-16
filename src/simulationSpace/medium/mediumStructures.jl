abstract type Medium end

struct MediumFlat<:Medium

    minBoundaryType::String
    maxBoundaryType::String
    N::Int

end

function MediumFlat(t::String,N::Int)

    if t == "Periodic" 
        return MediumFlat("Periodic","Periodic",N)
    elseif t == "Newmann"
        return MediumFlat("Newmann","Newmann",N)    
    elseif t == "Dirichlet"
        return MediumFlat("Dirichlet","Dirichlet",N)
    else 
        t = split(t,"-")
        for i in t
            if !(i in ["Periodic","Newmann","Dirichlet"])
                error("N boundary type implemented called ", i, " in ", t, ".")
            end
        end
        if length(t) != 2
            error("Boundary has to be declared as 'nameOfBoundary' or 'nameOfLowerBoundary-nameOfUpperBoundary'")
        end
        if "Periodic" in t && t[1] != t[2]
            error("If boundary is Periodic, upper and lower limits have to be the same.")
        end

        return MediumFlat(t[1],t[2],N)    
    end

end