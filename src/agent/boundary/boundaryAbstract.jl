abstract type Boundary end
abstract type BoundaryMedium end

abstract type BoundaryFlatSubtypes end

struct PeriodicBoundaryCondition<:BoundaryMedium end

defaultFlatBoundary(x,t) = 0
defaultFlatBoundary(x,y,t) = 0
defaultFlatBoundary(x,y,z,t) = 0

struct DirichletBoundaryCondition<:BoundaryMedium 
    fMin::Function
    fMax::Function
end
function DirichletBoundaryCondition(f::Function)
    return DirichletBoundaryCondition(f,f)
end
function DirichletBoundaryCondition()
    return DirichletBoundaryCondition(defaultFlatBoundary,defaultFlatBoundary)
end
struct DirichletBoundaryCondition_NewmannBoundaryCondition<:BoundaryMedium 
    fMin::Function
    fMax::Function
end
function DirichletBoundaryCondition_NewmannBoundaryCondition()
    return DirichletBoundaryCondition_NewmannBoundaryCondition(defaultFlatBoundary,defaultFlatBoundary)
end

struct NewmannBoundaryCondition<:BoundaryMedium 
    fMin::Function
    fMax::Function
end
function NewmannBoundaryCondition(f::Function)
    return NewmannBoundaryCondition(f,f)
end
function NewmannBoundaryCondition()
    return NewmannBoundaryCondition(defaultFlatBoundary,defaultFlatBoundary)
end
struct NewmannBoundaryCondition_DirichletBoundaryCondition<:BoundaryMedium 
    fMin::Function
    fMax::Function
end
function NewmannBoundaryCondition_DirichletBoundaryCondition()
    return NewmannBoundaryCondition_DirichletBoundaryCondition(defaultFlatBoundary,defaultFlatBoundary)
end

