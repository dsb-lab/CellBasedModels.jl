using CUDA

abstract type SpatialDynamics end

##################################################
#No movement
##################################################

struct noMovement <: SpatialDynamics

    #Global properties
    spatialParametersGlobalNames::Array{String}
    spatialParametersGlobal::Array{Number}
    #Local properties
    spatialDynamicsLocalNames::Array{String}
    spatialDynamicsLocal::Array{Number}

    spatialParametersLocalNames::Array{String}
    spatialParametersLocal::Array{Number}
    
    function noMovement(dim::Integer=3)
        namesParamGlob = []
        namesDynamics = [string("x",i) for i in 1:dim]
        namesParamLoc = []
        new(namesParamGlob,zeros(1,0),namesDynamics,zeros(1,dim),namesParamLoc,zeros(1,0))
    end
    
end
#Pretty printing of the noMovement structure
Base.show(io::IO, z::noMovement) = print(io, "Global spatial parameters\n ",z.spatialParametersGlobalNames,"\n",
                                                 "Local spatial parameters\n ",z.spatialParametersLocalNames,"\n",
                                                 "Local spatial dynamics\n ",z.spatialDynamicsLocalNames,"\n")

struct noMovementCUDA <: SpatialDynamics

    #Global properties
    spatialParametersGlobalNames::Array{String}
    spatialParametersGlobal::CUDA.Array
    
    #Local properties
    spatialDynamicsLocalNames::Array{String}
    spatialDynamicsLocal::CUDA.Array

    spatialParametersLocalNames::Array{String}
    spatialParametersLocal::CUDA.Array
    
    function noMovementCUDA(dim::Integer=3)
        namesParamGlob = []
        namesDynamics = [string("x",i) for i in 1:dim]
        namesParamLoc = []
        new(namesParamGlob,CUDA.zeros(1,0),namesDynamics,CUDA.zeros(1,dim),namesParamLoc,CUDA.zeros(1,0))
    end
    
end
#Pretty printing of the noMovement structure
Base.show(io::IO, z::noMovementCUDA) = print(io, "Global spatial parameters\n ",z.spatialParametersGlobalNames,"\n",
                                                 "Local spatial parameters\n ",z.spatialParametersLocalNames,"\n",
                                                 "Local spatial dynamics\n ",z.spatialDynamicsLocalNames,"\n")

function noMovementFunction(gParam, lParam, dynamics, newDynamics, t)
    
    for i = 1:length(dynamics)
        newDynamics[i] = 0
    end

    return nothing
end

"""##################################################
#Inertial movement
##################################################

struct inertialMovementCommunity <: SpatialDynamicsCommunity
end
#Pretty printing of the inertialMovementCell structure
Base.show(io::IO, z::inertialMovementCommunity) = print(io, "Spatial properties community\n nothing\n")

struct inertialMovementCell <: SpatialDynamicsCell
    mass::Number
    pos::Array{Number}
    vel::Array{Number}
    forces::Array{Number}

    function inertialMovementCell(mass::Number, dim::Integer)
        new(mass, zeros(dim),zeros(dim),zeros(dim))
    end
end
#Pretty printing of the inertialMovementCell structure
Base.show(io::IO, z::inertialMovementCell) = print(io, "Spatial properties cell",
                                                    "\n mass:", z.mass,
                                                    "\n pos:", z.pos,
                                                    "\n velocities:", z.vel,
                                                    "\n forces:", z.forces,"\n")

struct inertialMovement <: SpatialDynamics

    community::inertialMovementCommunity
    cell::inertialMovementCell
    
    function inertialMovement(dim::Integer,mass::Number=1)
        new(inertialMovementCommunity(),inertialMovementCell(mass::Number, dim))
    end
    
end
#Pretty printing of the inertialMovement structure
Base.show(io::IO, z::inertialMovement) = print(io, z.community, z.cell)


function spatialDynamics(community::inertialMovementCommunity, cell::inertialMovementCell, t::Real)
    
    return [cell.vel;cell.forces/cell.mass]
end


##########################################
#Global damped
##########################################

struct globalDampedMovementCommunity <: SpatialDynamicsCommunity
    viscosity::Number
end
#Pretty printing of the globalDampedMovementCommunity structure
Base.show(io::IO, z::globalDampedMovementCommunity) = print(io, "Spatial properties community",
                                                    "\n viscosity:", z.viscosity, "\n")

struct globalDampedMovementCell <: SpatialDynamicsCell
    mass::Number
    pos::Array{Number}
    vel::Array{Number}
    forces::Array{Number}

    function globalDampedMovementCell(mass::Number, dim::Integer)
        new(mass, zeros(dim),zeros(dim),zeros(dim))
    end
end
#Pretty printing of the globalDampedMovementCell structure
Base.show(io::IO, z::globalDampedMovementCell) = print(io, "Spatial properties cell",
                                                    "\n mass:", z.mass,
                                                    "\n pos:", z.pos,
                                                    "\n velocities:", z.vel,
                                                    "\n forces:", z.forces, "\n")

struct globalDampedMovement <: SpatialDynamics

    community::globalDampedMovementCommunity
    cell::globalDampedMovementCell
    
    function globalDampedMovement(dim::Integer,viscosity::Number=1, mass::Number=1)
        new(globalDampedMovementCommunity(viscosity),globalDampedMovementCell(mass,dim))
    end
    
end
#Pretty printing of the globalDampedMovement structure
Base.show(io::IO, z::globalDampedMovement) = print(io, z.community, z.cell)

function spatialDynamics(community::globalDampedMovementCommunity, cell::globalDampedMovementCell, t::Real)
    
    return [cell.vel;cell.forces/cell.mass-community.viscosity*cell.vel/cell.mass]
end"""