mutable struct cell
    """
    struct cell: cell object with all the properties for the embryogenesis simulations
        pos::Array{Float64}: array with the position of the cell in the corresponding dimensions
        vel::Array{Float64}: array with the velocity of the cell in the corresponding dimensions
        param::Array{Float64}: array with the physical parameters dependent of each cell 
        stateChem::Array{Float64}: array with the chemical state of the cell 
        paramChem::Array{Float64}: array with the chemical parameters dependent of each cell 
        radius::Float64: radius of the cell
        innerTime::Float64: time since the creation of the cell
    """
    spatialDyn::DynamicsCell
    radius::Float64
    innerTime::Float64

    function cell(spatialDyn::DynamicsCell,radius::Float64=1.,innerTime::Float64=0.)
        new(spatialDyn,1,0)
    end
end

#Pretty printing of the cell structure
Base.show(io::IO, z::cell) = print(io, "cell struct",
                                     "\n spatialDyn:", z.spatialDyn,
                                     "\n radius:", z.radius,
                                     "\n inner cell time:", z.innerTime)
