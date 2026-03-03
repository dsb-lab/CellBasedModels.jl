abstract type CustomIntegrator end

# struct Rule <: AbstractIntegrator
#     c::Symbol
#     dt::Symbol
#     rules::NTuple{N, Expr} where N

#     function Rule(c::Symbol, n::Symbol, f...)
#         for (i, code) in enumerate(f)
#             if typeof(code) !== Expr
#                 error("Argument $i must be of type Expr, but got $(typeof(code)).")
#             end
#         end
#         new(c, n, f)
#     end

#     function Rule(c::Symbol, n::Symbol; f::Union{Expr, NTuple{N, Expr}}) where N
#         if typeof(f) === Expr
#             f = (f,)
#         end
#         new(c, n, f)
#     end
# end

# listCode(integrator::Rule) = integrator.rules

# struct ODE <: AbstractIntegrator
#     c::Symbol
#     dt::Symbol
#     f::NTuple{N, Expr} where N

#     function ODE(c::Symbol, dt::Symbol, f...)
#         for (i, code) in enumerate(f)
#             if typeof(code) !== Expr
#                 error("Argument $i must be of type Expr, but got $(typeof(code)).")
#             end
#         end
#         new(c, dt, f)
#     end

#     function ODE(c::Symbol, dt::Symbol; f::Union{Expr, NTuple})
#         if typeof(f) === Expr
#             f = (f,)
#         end
#         new(c, dt, f)
#     end

# end

# listCode(integrator::ODE) = integrator.f

# struct DynamicalODE <: AbstractIntegrator
#     c::Symbol
#     dt::Symbol
#     f1::NTuple{N, Expr} where N
#     f2::NTuple{N, Expr} where N

#     function DynamicalODE(c::Symbol, dt::Symbol; f1::Union{Expr, NTuple{N1, Expr}}, f2::Union{Expr, NTuple{N2, Expr}}) where {N1, N2}
#         if typeof(f1) === Expr
#             f1 = (f1,)
#         end
#         if typeof(f2) === Expr
#             f2 = (f2,)
#         end
#         new(c, dt, f1, f2)
#     end
# end

# listCode(integrator::DynamicalODE) = (integrator.f1..., integrator.f2...)

# struct SplitODE <: AbstractIntegrator
#     c::Symbol
#     dt::Symbol
#     f1::NTuple{N, Expr} where N
#     f2::NTuple{N, Expr} where N

#     function SplitODE(c::Symbol, dt::Symbol; f1::Union{Expr, NTuple{N1, Expr}}, f2::Union{Expr, NTuple{N2, Expr}}) where {N1, N2}
#         if typeof(f1) === Expr
#             f1 = (f1,)
#         end
#         if typeof(f2) === Expr
#             f2 = (f2,)
#         end
#         new(c, dt, f1, f2)
#     end
# end

# listCode(integrator::SplitODE) = (integrator.f1..., integrator.f2...)

# struct SDE <: AbstractIntegrator
#     c::Symbol
#     dt::Symbol
#     f1::NTuple{N, Expr} where N
#     f2::NTuple{N, Expr} where N

#     function SDE(c::Symbol, dt::Symbol; f::Union{Expr, NTuple{N1, Expr}}, g::Union{Expr, NTuple{N2, Expr}}) where {N1, N2}
#         if typeof(f) === Expr
#             f = (f,)
#         end
#         if typeof(g) === Expr
#             g = (g,)
#         end
#         new(c, dt, f, g)
#     end
# end

# listCode(integrator::SDE) = (integrator.f1..., integrator.f2...)

# struct RODE <: AbstractIntegrator
#     c::Symbol
#     dt::Symbol
#     f::NTuple{N, Expr} where N

#     function RODE(c::Symbol, dt::Symbol, f...)
#         for (i, code) in enumerate(f)
#             if typeof(code) !== Expr
#                 error("Argument $i must be of type Expr, but got $(typeof(code)).")
#             end
#         end
#         new(c, dt, f)
#     end

#     function RODE(c::Symbol, dt::Symbol; f::Union{Expr, NTuple})
#         if typeof(f) === Expr
#             f = (f,)
#         end
#         new(c, dt, f)
#     end
# end

# listCode(integrator::RODE) = integrator.f

# struct ADIODE{D,R} <: AbstractIntegrator where {D, R}
#     c::Symbol
#     dt::Symbol
#     f1::NTuple{N, Expr} where N
#     f2::Union{Nothing, NTuple{P, Expr}} where P
#     f3::Union{Nothing, NTuple{Q, Expr}} where Q
#     g::Union{Nothing, NTuple{M, Expr}} where M

#     function ADIODE(c::Symbol, dt::Symbol; f1::Union{Expr, NTuple}, f2::Union{Nothing, Expr, NTuple}=nothing, f3::Union{Nothing, Expr, NTuple}=nothing, g::Union{Nothing, Expr, NTuple}=nothing)
#         if typeof(f1) === Expr
#             f1 = (f1,)
#         end
#         if typeof(f2) === Expr
#             f2 = (f2,)
#         end
#         if typeof(f3) === Expr
#             f3 = (f3,)
#         end
#         if typeof(g) === Expr
#             g = (g,)
#         end
#         R = true
#         if g === nothing
#             R = false
#         end
        
#         if f2 === nothing && f3 === nothing
#             new{1,R}(c, dt, f1, f2, f3, g)
#         elseif f3 === nothing
#             new{2,R}(c, dt, f1, f2, f3, g)
#         else
#             new{3,R}(c, dt, f1, f2, f3, g)
#         end
#     end
# end

# listCode(integrator::ADIODE{1,false}) = integrator.f1
# listCode(integrator::ADIODE{2,false}) = (integrator.f1..., integrator.f2...)
# listCode(integrator::ADIODE{3,false}) = (integrator.f1..., integrator.f2..., integrator.f3...)
# listCode(integrator::ADIODE{1,true}) = (integrator.f1..., integrator.g...)
# listCode(integrator::ADIODE{2,true}) = (integrator.f1..., integrator.f2..., integrator.g...)
# listCode(integrator::ADIODE{3,true}) = (integrator.f1..., integrator.f2..., integrator.f3..., integrator.g...)
