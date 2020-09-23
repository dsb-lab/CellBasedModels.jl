abstract type SpatialDynamics end
abstract type SpatialDynamicsCommunity <: SpatialDynamics end
abstract type SpatialDynamicsCell <: SpatialDynamics end

##################################################
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
end