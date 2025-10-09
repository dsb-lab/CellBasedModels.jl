abstract type AbstractIntegrator end

struct Rule <: AbstractIntegrator
    rules::NTuple{N, Expr} where N

    function Rule(f...)
        for (i, code) in enumerate(f)
            if typeof(code) !== Expr
                error("Argument $i must be of type Expr, but got $(typeof(code)).")
            end
        end
        new(f)
    end

    function Rule(;f::Union{Expr, NTuple{N, Expr}}) where N
        if typeof(f) === Expr
            f = (f,)
        end
        new(f)
    end
end

struct ODE <: AbstractIntegrator
    f::NTuple{N, Expr} where N

    function ODE(f...)
        for (i, code) in enumerate(f)
            if typeof(code) !== Expr
                error("Argument $i must be of type Expr, but got $(typeof(code)).")
            end
        end
        new(f)
    end

    function ODE(;f::Union{Expr, NTuple})
        if typeof(f) === Expr
            f = (f,)
        end
        new(f)
    end

end

struct DynamicalODE <: AbstractIntegrator
    f1::NTuple{N, Expr} where N
    f2::NTuple{N, Expr} where N

    function DynamicalODE(;f1::Union{Expr, NTuple{N1, Expr}}, f2::Union{Expr, NTuple{N2, Expr}}) where {N1, N2}
        if typeof(f1) === Expr
            f1 = (f1,)
        end
        if typeof(f2) === Expr
            f2 = (f2,)
        end
        new(f1,f2)
    end
end

struct SplitODE <: AbstractIntegrator
    f1::NTuple{N, Expr} where N
    f2::NTuple{N, Expr} where N

    function SplitODE(;f1::Union{Expr, NTuple{N1, Expr}}, f2::Union{Expr, NTuple{N2, Expr}}) where {N1, N2}
        if typeof(f1) === Expr
            f1 = (f1,)
        end
        if typeof(f2) === Expr
            f2 = (f2,)
        end
        new(f1,f2)
    end
end

struct SDE <: AbstractIntegrator
    f1::NTuple{N, Expr} where N
    f2::NTuple{N, Expr} where N

    function SDE(;f::Union{Expr, NTuple{N1, Expr}}, g::Union{Expr, NTuple{N2, Expr}}) where {N1, N2}
        if typeof(f) === Expr
            f = (f,)
        end
        if typeof(g) === Expr
            g = (g,)
        end
        new(f,g)
    end
end

struct RODE <: AbstractIntegrator
    f::NTuple{N, Expr} where N

    function RODE(f...)
        for (i, code) in enumerate(f)
            if typeof(code) !== Expr
                error("Argument $i must be of type Expr, but got $(typeof(code)).")
            end
        end
        new(f)
    end

    function RODE(;f::Union{Expr, NTuple})
        if typeof(f) === Expr
            f = (f,)
        end
        new(f)
    end
end


struct ADIODE{D,R} <: AbstractIntegrator where {D, R}
    f1::NTuple{N, Expr} where N
    f2::Union{Nothing, NTuple{P, Expr}} where P
    f3::Union{Nothing, NTuple{Q, Expr}} where Q
    g::Union{Nothing, NTuple{M, Expr}} where M

    function ADIODE(;f1::Union{Expr, NTuple}, f2::Union{Nothing, Expr, NTuple}=nothing, f3::Union{Nothing, Expr, NTuple}=nothing, g::Union{Nothing, Expr, NTuple}=nothing)
        if typeof(f1) === Expr
            f1 = (f1,)
        end
        if typeof(f2) === Expr
            f2 = (f2,)
        end
        if typeof(f3) === Expr
            f3 = (f3,)
        end
        if typeof(g) === Expr
            g = (g,)
        end
        R = true
        if g === nothing
            R = false
        end
        
        if f2 === nothing && f3 === nothing
            new{1,R}(f1, f2, f3, g)
        elseif f3 === nothing
            new{2,R}(f1, f2, f3, g)
        else
            new{3,R}(f1, f2, f3, g)
        end
    end
end