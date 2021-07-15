abstract type Medium end

struct MediumFlat<:Medium

    minBoundaryType::String
    maxBoundaryType::String
    dx::Real

end

