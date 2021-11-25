abstract type Boundary end
abstract type BoundaryMedium end

abstract type BoundaryFlatSubtypes end

struct PeriodicMedium<:BoundaryMedium end

struct Dirichlet<:BoundaryMedium end
struct Dirichlet_Dirichlet<:BoundaryMedium end
struct Dirichlet_Newmann<:BoundaryMedium end

struct Newmann<:BoundaryMedium end
struct Newmann_Newmann<:BoundaryMedium end
struct Newmann_Dirichlet<:BoundaryMedium end
