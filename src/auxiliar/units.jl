"""
    UNITS::Dict{Symbol,Dict{Symbol,Float64}}

Dictionary of **SI base dimensions** and their **unit conversion factors**  
relative to the corresponding **SI base unit** (all values in `Float64`).

Each top-level key represents one of the seven SI base quantities:
- `:L` — Length  
- `:T` — Time  
- `:M` — Mass  
- `:Θ` — Thermodynamic temperature  
- `:I` — Luminous intensity  
- `:N` — Amount of substance  
- `:J` — Electric current  

Each nested dictionary maps a **unit symbol** to its **multiplier relative
to the base unit** (e.g. `UNITS[:L][:km] == 1000.0` → 1 km = 1000 m).

---

### **Length (:L)** — base unit: **meter (m)**
| Unit | Symbol | Multiplier (m) |
|:------|:--------|---------------:|
| kilometer | `:km` | 1_000.0 |
| meter | `:m` | 1.0 |
| centimeter | `:cm` | 0.01 |
| millimeter | `:mm` | 0.001 |
| micrometer | `:μm` | 1e-6 |
| nanometer | `:nm` | 1e-9 |
| picometer | `:pm` | 1e-12 |
| femtometer | `:fm` | 1e-15 |

---

### **Time (:T)** — base unit: **second (s)**
| Unit | Symbol | Multiplier (s) |
|:------|:--------|---------------:|
| year (365.25 d) | `:year` | 31_557_600.0 |
| month (30 d) | `:month` | 2_592_000.0 |
| day | `:day` | 86_400.0 |
| hour | `:h` | 3_600.0 |
| minute | `:min` | 60.0 |
| second | `:s` | 1.0 |
| millisecond | `:ms` | 1e-3 |
| microsecond | `:μs` | 1e-6 |
| nanosecond | `:ns` | 1e-9 |
| picosecond | `:ps` | 1e-12 |
| femtosecond | `:fs` | 1e-15 |

---

### **Mass (:M)** — base unit: **gram (g)**
| Unit | Symbol | Multiplier (g) |
|:------|:--------|---------------:|
| kilogram | `:kg` | 1_000.0 |
| gram | `:g` | 1.0 |
| milligram | `:mg` | 1e-3 |
| microgram | `:μg` | 1e-6 |
| nanogram | `:ng` | 1e-9 |
| picogram | `:pg` | 1e-12 |
| femtogram | `:fg` | 1e-15 |

---

### **Thermodynamic Temperature (:Θ)** — base unit: **kelvin (K)**
| Unit | Symbol | Multiplier (K) |
|:------|:--------|---------------:|
| kelvin | `:K` | 1.0 |

---

### **Luminous Intensity (:I)** — base unit: **candela (cd)**
| Unit | Symbol | Multiplier (cd) |
|:------|:--------|---------------:|
| kilocandela | `:kcd` | 1_000.0 |
| candela | `:cd` | 1.0 |
| millicandela | `:mcd` | 1e-3 |
| microcandela | `:μcd` | 1e-6 |
| nanocandela | `:ncd` | 1e-9 |
| picocandela | `:pcd` | 1e-12 |
| femtocandela | `:fcd` | 1e-15 |

---

### **Amount of Substance (:N)** — base unit: **mole (mol)**
| Unit | Symbol | Multiplier (mol) |
|:------|:--------|---------------:|
| mole | `:mol` | 1.0 |
| millimole | `:mmol` | 1e-3 |
| micromole | `:μmol` | 1e-6 |
| nanomole | `:nmol` | 1e-9 |
| picomole | `:pmol` | 1e-12 |
| femtomole | `:fmol` | 1e-15 |

---

### **Electric Current (:J)** — base unit: **ampere (A)**
| Unit | Symbol | Multiplier (A) |
|:------|:--------|---------------:|
| ampere | `:A` | 1.0 |
| milliampere | `:mA` | 1e-3 |
| microampere | `:μA` | 1e-6 |
| nanoampere | `:nA` | 1e-9 |
| picoampere | `:pA` | 1e-12 |
| femtoampere | `:fA` | 1e-15 |

---

"""
const UNITS = Dict(
    :L => Dict(
        :km => 1000.0,
        :m => 1.0,
        :cm => 0.01,
        :mm => 0.001,
        :μm => 1e-6,
        :nm => 1e-9,
        :pm => 1e-12,
        :fm => 1e-15,        
    ),
    :T => Dict(
        :year => 31557600.0,  # 365.25 days
        :month => 2592000.0,  # 30 days
        :day => 86400.0,
        :h => 3600.0,
        :min => 60.0,
        :s => 1.0,
        :ms => 0.001,
        :μs => 1e-6,
        :ns => 1e-9,
        :ps => 1e-12,
        :fs => 1e-15,
    ),
    :M => Dict(
        :kg => 1000.0,
        :g => 1.0,
        :mg => 0.001,
        :μg => 1e-6,
        :ng => 1e-9,
        :pg => 1e-12,
        :fg => 1e-15,
    ),
    :Θ => Dict(
        :K => 1.0,  # Kelvin is the base unit        
    ),
    :I => Dict(
        :kcd => 1000.0,  # Kilocandela
        :cd => 1.0,  # Candela is the base unit
        :mcd => 0.001,  # Millicandela
        :μcd => 1e-6,  # Microcandela
        :ncd => 1e-9,  # Nanocandela
        :pcd => 1e-12,  # Picocandela
        :fcd => 1e-15,  # Femtocandela
    ),
    :N => Dict(
        :mol => 1.0,  # Mole is the base unit
        :mmol => 0.001,  # Millimole
        :μmol => 1e-6,  # Micromole
        :nmol => 1e-9,  # Nanomole
        :pmol => 1e-12,  # Picomole
        :fmol => 1e-15,  # Femtomole
    ),
    :J => Dict(
        :A => 1.0,  # Ampere is the base unit
        :mA => 0.001,
        :μA => 1e-6,
        :nA => 1e-9,
        :pA => 1e-12,
        :fA => 1e-15,
    ),
)

const UNIT_SYMBOLS = Set{Symbol}()

const UNITS_INVERSE = Dict{Symbol,Symbol}()

function set_units_globals!(units_dict::Dict{Symbol,Dict{Symbol,Float64}}=UNITS)

    UNITS = units_dict

    for (dim, udict) in UNITS
        for (u, _) in udict
            push!(UNIT_SYMBOLS, u)
            UNITS_INVERSE[u] = dim
        end
    end

    return

end

"""
    canonicalize_units(units::Union{Nothing,Symbol,Expr}) -> Union{Nothing,Symbol,Expr}

Return a **deterministic, canonical** unit expression by:
1. Flattening `*`, `/`, `^` and combining like symbols (integer exponents only).
2. Sorting terms first by **dimension** (via `UNITS_INVERSE`), then by symbol name.
3. Emitting a minimal expression with numerator/denominator separated.

Examples:
```julia
canonicalize_units(:(m*kg/s^2))      # :(kg*m/s^2)
canonicalize_units(:(s^-1*m/s))      # :(m/s^2)
canonicalize_units(:(μm*nA/(kg*m)))  # :(μm*nA/(kg*m))
canonicalize_units(:m)               # :m
canonicalize_units(nothing)          # nothing
"""
function canonicalize_units(units::Union{Nothing,Symbol,Expr})
    units === nothing && return nothing
    units isa Symbol && return units

    exps = Dict{Symbol,Int}()

    function accum(x, k::Int)
        if x isa Symbol
            exps[x] = get(exps, x, 0) + k

        elseif x isa Expr
            if x.head === :call
                f = x.args[1]

                if f === :*
                    accum(x.args[2], k)
                    accum(x.args[3], k)

                elseif f === :/
                    accum(x.args[2], k)
                    accum(x.args[3], -k)

                elseif f === :^
                    base = x.args[2]
                    pow  = x.args[3]
                    if pow isa Integer
                        accum(base, k * Int(pow))
                    elseif pow isa Real && isfinite(pow) && isinteger(pow)
                        accum(base, k * Int(round(pow)))
                    else
                        throw(ArgumentError("Unit exponents must be integers; got $pow"))
                    end

                else
                    for i in 2:length(x.args)
                        accum(x.args[i], k)
                    end
                end
            else
                for a in x.args
                    accum(a, k)
                end
            end
        else
            throw(ArgumentError("Unsupported unit node: $(typeof(x))"))
        end
    end

    accum(units, 1)

    for (s, e) in collect(exps)
        e == 0 && delete!(exps, s)
    end
    isempty(exps) && return :(1)

    num = Dict{Symbol,Int}()
    den = Dict{Symbol,Int}()

    for (s, e) in exps
        if e > 0
            num[s] = e
        else
            den[s] = -e
        end
    end

    dim_of = s -> get(UNITS_INVERSE, s, :_unknown)
    sortkey = s -> (String(dim_of(s)), String(s))

    mkterm = (s::Symbol, e::Int) -> (e == 1 ? s : Expr(:call, :^, s, e))

    num_syms = sort!(collect(keys(num)), by = sortkey)
    num_expr =
        if isempty(num_syms)
            1
        elseif length(num_syms) == 1
            mkterm(num_syms[1], num[num_syms[1]])
        else
            reduce((a, b) -> Expr(:call, :*, a, b),
                   Any[mkterm(s, num[s]) for s in num_syms])
        end

    den_syms = sort!(collect(keys(den)), by = sortkey)
    if isempty(den_syms)
        return num_expr isa Int ? :(1) : num_expr
    else
        den_expr =
            if length(den_syms) == 1
                mkterm(den_syms[1], den[den_syms[1]])
            else
                reduce((a, b) -> Expr(:call, :*, a, b),
                       Any[mkterm(s, den[s]) for s in den_syms])
            end
        return Expr(:call, :/, num_expr, den_expr)
    end
end

# Internal: collect all Symbols that appear inside a unit Expr
# (operators like :*, :/, :^ will be filtered later)
function _collect_unit_symbols(x, out::Vector{Symbol}=Symbol[])
    if x isa Symbol
        push!(out, x)
    elseif x isa Expr
        for a in x.args
            _collect_unit_symbols(a, out)
        end
    end
    return out
end

# Internal: validate that every symbol in `units` is a known unit
function _validate_units(units::Union{Nothing,Symbol,Expr})

    unit_symbols = Set{Symbol}()
    for (_, udict) in UNITS
        for (u, _) in udict
            push!(unit_symbols, u)
        end
    end

    units === nothing && return

    # Operators to ignore when walking expressions
    OPS = Set([:*, :/, :^])

    if units isa Symbol
        if !(units in unit_symbols)
            throw(ArgumentError("Unknown unit symbol: $units. Allowed: $(collect(unit_symbols))"))
        end
        return
    elseif units isa Expr
        syms = _collect_unit_symbols(units)
        for s in syms
            if s in OPS
                continue
            elseif !(s in unit_symbols)
                throw(ArgumentError("Unknown unit symbol in expression: $s. Allowed: $(collect(unit_symbols))"))
            end
        end
        return
    else
        throw(ArgumentError("`units` must be Nothing, Symbol, or Expr; got $(typeof(units))"))
    end
end

"""
    Unit(value::AbstractArray{<:Real}, units::Union{Nothing,Symbol,Expr}=nothing)

Represents a **numerical quantity with associated physical units**.

`Unit` wraps an array of real values and optionally an associated **unit symbol**  
or **compound unit expression**, such as `:m`, `:(m/s)`, or `:(kg*m/s^2)`.

---

### **Fields**
- `value::AbstractArray{<:Real}` — numerical array (scalars, vectors, tensors, etc.)  
- `units::Union{Nothing,Symbol,Expr}` — physical unit of the values:
  - `nothing`: dimensionless quantity
  - `Symbol`: single base or prefixed unit (e.g. `:m`, `:kg`, `:μs`)
  - `Expr`: compound unit expression using `*`, `/`, and `^`
    (e.g. `:(m/s)`, `:(kg*m/s^2)`)

---

### **Examples**
```julia
# Scalar in meters
u1 = Unit([1.0], :m)

# Array in milliseconds
u2 = Unit(rand(10), :ms)

# Compound unit expression (Newton = kg*m/s^2)
u3 = Unit([9.81], :(kg*m/s^2))

# Dimensionless quantity
u4 = Unit([42.0])

# Invalid unit name triggers ArgumentError
Unit([1.0], :parsec)    # ERROR: Unknown unit symbol :parsec
"""
struct UnitScalar{T<:Real} <: Number
    value::T
    units::Union{Nothing,Symbol,Expr}
end

# Minimal Number interface (add more as you need)
Base.promote_rule(::Type{UnitScalar{T}}, ::Type{S}) where {T<:Real,S<:Real} = UnitScalar{promote_type(T,S)}
Base.convert(::Type{UnitScalar{T}}, x::Real) where {T} = UnitScalar{T}(convert(T,x), nothing)
Base.show(io::IO, u::UnitScalar) = print(io, "Unit(", u.value, ", ", u.units, ")")

# Arithmetic operations (result keeps left operand's units)
for op in (:+, :-, :*, :/, :\, :^, :div, :fld, :cld, :rem, :mod, :mod1, :inv)
    eval(quote Base.$op(a::UnitScalar, b::Real) = UnitScalar($op(a.value, b), a.units) end)
    eval(quote Base.$op(a::Real, b::UnitScalar) = UnitScalar($op(a, b.value), b.units) end)
end
for op in (:^,)
    eval(quote 
            function Base.$op(a::UnitScalar, b::Int)
                newUnits = :()
                for i in 1:b 
                    newUnits *= a.units 
                end
                
                return UnitScalar($op(a.value, b.value), canonicalize_units(newUnits))
            end
        end)
end
for op in (:+, :-, :\, :div, :fld, :cld, :rem, :mod, :mod1, :inv)
    eval(quote 
            function Base.$op(a::UnitScalar, b::UnitScalar)
                if a.units == b.units
                    return UnitScalar($op(a.value, b.value), a.units) 
                else
                    throw(ArgumentError("Cannot $op quantities with different units: $(a.units) and $(b.units)"))
                end
            end
        end)
end
for op in (:*, :/)
    eval(quote 
            function Base.$op(a::UnitScalar, b::UnitScalar) 
                newunits = :($a.units $op $b.units)
                return UnitScalar($op(a.value, b.value), canonicalize_units(newunits)) 
            end
        end)
end
for op in (:^,)
    eval(quote 
            function Base.$op(a::UnitScalar, b::UnitScalar) 
                if b.units != nothing
                    throw(ArgumentError("Cannot raise units to a power that has units"))
                else
                    return a^b.value
                end
            end
        end)
end

# Number properties
for op in (:abs, :real, :imag, :complex, :conj, :ceil, :floor, :trunc, :round, :modf, :frexp, :ldexp)
    eval(quote Base.$op(a::UnitScalar) = UnitScalar($op(a.value), a.units) end)
end
function Base.abs2(a::UnitScalar) 
    newUnits = :()
    for i in 1:2
        newUnits *= a.units
    end
    UnitScalar(abs2(a.value), canonicalize_units(newUnits))
end
for op in (:sign, :signbit, :copysign, :isfinite, :isinf, :isnan, :iszero, :isone)
    eval(quote Base.$op(a::UnitScalar) = $op(a.value) end)
end

# Power functions
for op in (:sqrt,)
    eval(quote Base.$op(a::UnitScalar) = throw(ArgumentError("TO BE IMPLEMENTED")) end)
end
for op in (:cbrt, :hypot, :exp, :exp2, :exp10, :expm1, :log, :log2, :log10, :log1p)
    eval(quote 
            function Base.$op(a::UnitScalar)
                if a.units != nothing
                    throw(ArgumentError("Cannot apply $op to a quantity with units"))
                else 
                    UnitScalar($op(a.value), nothing)
                end
            end
        end)
end

# Trigonometric and special functions
for op in (:sin, :cos, :tan, :cot, :sec, :csc, :asin, :acos, :atan, :acot, :asec, :acsc, :sinc, :cosc, :sinh, :cosh, :tanh, :coth, :sech, :csch, :asinh, :acosh, :atanh, :acoth, :asech, :acsch)
    eval(quote 
            function Base.$op(a::UnitScalar)
                if a.units != nothing
                    throw(ArgumentError("Cannot apply $op to a quantity with units"))
                else 
                    UnitScalar($op(a.value), nothing)
                end
            end
        end)
end

Base.clamp(a::UnitScalar, b::Real, c::Real) = UnitScalar(clamp(a.value, b.value, c.value), a.units)
Base.clamp(a::UnitScalar, b::UnitScalar, c::UnitScalar) = if a.units == b.units == c.units; UnitScalar(clamp(a.value, b.value, c.value), a.units); else error("Incompatible units"); end

struct UnitArray{T,N,A<:AbstractArray{T,N}} <: AbstractArray{T,N}
    value::A
    units::Union{Nothing,Symbol,Expr}
end
Base.size(u::UnitArray) = size(u.value)
Base.axes(u::UnitArray) = axes(u.value)
Base.IndexStyle(::Type{U}) where {T,N,A<:AbstractArray{T,N},U<:UnitArray{T,N,A}} = IndexStyle(A)
Base.getindex(u::UnitArray, I...) = u.value[I...]
Base.setindex!(u::UnitArray, v, I...) = (u.value[I...] = v)
Base.similar(u::UnitArray, ::Type{S}, dims::Vararg{Int}) where {S} = UnitArray(similar(u.value, S, dims...), u.units)
Base.show(io::IO, u::UnitArray) = print(io, "Unit(", u.value, ", ", u.units, ")")

function Unit(value::Union{AbstractArray{<:Real}, <:Real}, units::Union{Nothing, Symbol, Expr}=nothing)
    _validate_units(units)
    units = canonicalize_units(units)
    if typeof(value) <: Real
        return UnitScalar{typeof(value)}(value, units)
    else
        return UnitArray{typeof(value[1]), ndims(value), typeof(value)}(value, units)
    end
end