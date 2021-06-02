#Space class
abstract type SimulationSpace end

#FlatBoundary classes
abstract type FlatBoundary end 
abstract type NonPeriodic<:FlatBoundary end 
#Symmetric boundaries
struct Periodic<:FlatBoundary 
    s::Symbol
    min::Real
    max::Real
end 
struct Open<:NonPeriodic 
    s::Symbol
    min::Real
    max::Real
end
struct Hard<:NonPeriodic 
    s::Symbol
    min::Real
    max::Real
end
struct Reflecting<:NonPeriodic 
    s::Symbol
    min::Real
    max::Real
end
#Asymmetric boundaries
struct OpenReflecting<:NonPeriodic 
    s::Symbol
    min::Real
    max::Real
end
struct ReflectingOpen<:NonPeriodic 
    s::Symbol
    min::Real
    max::Real
end

struct OpenHard<:NonPeriodic 
    s::Symbol
    min::Real
    max::Real
end
struct HardOpen<:NonPeriodic 
    s::Symbol
    min::Real
    max::Real
end

struct HardReflecting<:NonPeriodic 
    s::Symbol
    min::Real
    max::Real
end
struct ReflectingHard<:NonPeriodic 
    s::Symbol
    min::Real
    max::Real
end

