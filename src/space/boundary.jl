abstract type Boundary end

struct Unbound 
    var::Symbol 
    bound::Tuple{T<:Real,t<:Real}
end

struct Periodic 
    var::Symbol
    bound::Tuple{T<:Real,t<:Real}
end

struct Reflecting 
    var::Symbol
    bound::Tuple{T<:Real,t<:Real}
    stop::Array{Symbol}
    reflect::Array{Symbol}
end