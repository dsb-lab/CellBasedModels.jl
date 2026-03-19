import ..Unitful
using ..Unitful: Dimensions, Quantity, Units, FreeUnits, NoDims, ustrip, dimension, unit

DATATYPE = Dict(
    Integer => Int,
    AbstractFloat => Float64,
    Bool => Bool,
)

"""
    mutable struct Parameter{D <: DataType}

Represents a **model or simulation parameter** with associated metadata:
type, dimensions, default value, and description.

---

### **Fields**
- `dimensions::Union{Nothing, Symbol, Expr}` — Dimensionality or units of the parameter.
  - `nothing`: dimensionless
  - `Symbol`: single unit or dimension (e.g. `:L`, `:T`)
  - `Expr`: compound unit expression (e.g. `:(L/T^2)`)
- `defaultValue` — Default or initial value.
- `description::String` — Text description of the parameter’s purpose or meaning.
- `_updated::Bool` — Internal flag used to track whether the parameter is modified.
- `_DE::Bool` — Internal flag indicating if the parameter is a variable of a differential equation.
- `_modifiedIn::Union{Symbol, Nothing}` — Internal field indicating the scope of the parameter (e.g. `:agent`, `:edges`). This parameter is just informative and set automatically.

---

### **Constructor**
```julia
Parameter(dataType::DataType;
          dimensions::Union{Nothing, Symbol, Expr}=nothing,
          defaultValue=nothing,
          description::String="")
```

Creates a new `Parameter` object.  

---

### **Examples**
```julia
# Scalar parameter with default value
p1 = Parameter(Float64; defaultValue=1.0, description="Default scalar")

# Parameter with dimensional information
p2 = Parameter(Float64; dimensions=:L, defaultValue=1.0, description="Length parameter")

# Boolean flag
p3 = Parameter(Bool; defaultValue=true, description="Toggle flag")

# Printing
show(p1)
```
"""
mutable struct Parameter{D}
    dimensions::Union{Nothing, Symbol, Expr, Dimensions}
    defaultValue::Any  # Flexible: D, Function, Nothing, Quantity, or compatible array types
    description::String
    _updated::Bool
    _DE::Bool
    _modifiedIn::Vector{Tuple}

    function Parameter(dataType::Union{DataType, UnionAll};
                       dimensions::Union{Nothing, Symbol, Expr, Dimensions}=nothing,
                       defaultValue=nothing,
                       description::String="", _updated::Bool=false, _DE::Bool=false, _modifiedIn::Vector{Tuple}=Vector{Tuple}())

        # Handle Unitful Quantity defaultValue
        if defaultValue isa Quantity
            # Validate dimensions match if both are specified
            if dimensions !== nothing
                value_dims = dimension(defaultValue)
                if dimensions isa Dimensions
                    if value_dims != dimensions
                        error("Parameter defaultValue unit dimension ($(value_dims)) does not match declared dimensions ($dimensions)")
                    end
                else
                    # If dimensions is Symbol/Expr, just warn about using mixed notation
                    @warn "Using Unitful defaultValue with Symbol/Expr dimensions. Consider using Unitful dimensions (e.g., u\"𝐋\") for consistency."
                end
            end
            # Infer dimensions from defaultValue if not specified
            if dimensions === nothing
                dimensions = dimension(defaultValue)
            end
        end

        if dataType <: Integer
            dataType = Integer
        elseif dataType <: AbstractFloat
            dataType = AbstractFloat
        elseif dataType <: Bool
            dataType = Bool
        elseif dataType <: SArray
            dataType = dataType
        elseif dataType <: AbstractArray
            dataType = dataType  # Allow array types (Matrix, Vector, etc.)
        else
            error("Parameter dataType must be a subtype of Real, Bool, or AbstractArray. Found: $dataType")
        end
        # Allow functions as defaultValue (they will be called with the object after initialization)
        # For arrays, check if element types are compatible (e.g., Matrix{Float64} should be valid for Matrix{AbstractFloat})
        function is_compatible_value(val, dtype)
            val === nothing && return true
            val isa Function && return true
            val isa Quantity && return true
            val isa dtype && return true
            # For array types, check if it's an array with compatible element type
            if dtype <: AbstractArray && val isa AbstractArray
                # Check dimensions match
                ndims(val) == ndims(dtype) || return false
                # Check element type compatibility
                return eltype(val) <: eltype(dtype)
            end
            return false
        end
        if !is_compatible_value(defaultValue, dataType)
            error("Parameter defaultValue must be of type $dataType, a Function, Unitful Quantity, or nothing. Found: $(typeof(defaultValue))")
        end

        new{dataType}(dimensions, defaultValue, description, _updated, _DE, _modifiedIn)
    
    end
end

function Base.show(io::IO, x::Parameter{D}) where D
    println("Parameter: ")
    println("\t DataType: ", D)
    println("\n Scope: ", x._modifiedIn)
    println("\t Dimensions: ", x.dimensions)
    if x.defaultValue isa Function
        m = first(methods(x.defaultValue))
        println("\t Default Value: <Function> ", m)
    else
        println("\t Default Value: ", x.defaultValue)
    end
    println("\t ModifiedIn: ", tuple(x._modifiedIn))
    println("\t Description: ", x.description)
end

"""
    ustrip_defaultValue(p::Parameter)

Extract the numeric value from a Parameter's defaultValue, stripping any Unitful units.
Returns the raw numeric value for computation on backends.
"""
function ustrip_defaultValue(p::Parameter)
    if p.defaultValue isa Quantity
        return ustrip(p.defaultValue)
    elseif p.defaultValue isa Function
        return p.defaultValue  # Functions are handled elsewhere
    else
        return p.defaultValue
    end
end

"""
    get_unit(p::Parameter)

Get the Unitful unit from a Parameter's defaultValue, or `Unitful.NoUnits` if dimensionless.
"""
function get_unit(p::Parameter)
    if p.defaultValue isa Quantity
        return unit(p.defaultValue)
    else
        return Unitful.NoUnits
    end
end

"""
    has_units(p::Parameter) -> Bool

Check if a Parameter has Unitful units (either via dimensions or defaultValue).
"""
function has_units(p::Parameter)
    return p.dimensions isa Dimensions || p.defaultValue isa Quantity
end

"""
    apply_units(value, p::Parameter, baseUnits::NamedTuple)

Apply units to a dimensionless value based on the parameter's dimensions and the baseUnits mapping.
This restores Unitful units to values that were stripped for computation.

# Arguments
- `value`: The numeric value to attach units to
- `p::Parameter`: The parameter containing dimension information
- `baseUnits::NamedTuple`: Mapping from dimensions to reference units (e.g., `(𝐋=1u"m", 𝐓=1u"s")`)

# Examples
```julia
baseUnits = (𝐋 = 1u"m", 𝐓 = 1u"s")
p = Parameter(Float64, dimensions=u"𝐋/𝐓")
apply_units(10.0, p, baseUnits)  # Returns 10.0u"m/s"
```
"""
function apply_units(value, p::Parameter, baseUnits::NamedTuple)
    if p.dimensions === nothing || (p.dimensions isa Dimensions && p.dimensions == NoDims)
        return value  # Dimensionless
    end
    
    # If parameter has a Unitful defaultValue, use its unit
    if p.defaultValue isa Quantity
        return value * unit(p.defaultValue)
    end
    
    # For Unitful Dimensions, construct unit from baseUnits
    if p.dimensions isa Dimensions
        # Build the unit from dimension and baseUnits
        # e.g., for dimensions = u"𝐋/𝐓", if baseUnits = (𝐋=1u"m", 𝐓=1u"s")
        # return value * (u"m" / u"s")
        result_unit = 1
        for dim in typeof(p.dimensions).parameters[1]
            if dim isa Symbol
                if haskey(baseUnits, dim)
                    result_unit = result_unit * unit(baseUnits[dim])
                else
                    @warn "Dimension $dim not found in baseUnits. Cannot restore units."
                    return value
                end
            elseif dim isa Expr && dim.head == :call && dim.args[1] == :^
                base_dim = dim.args[2]
                exp_val = dim.args[3]
                if haskey(baseUnits, base_dim)
                    result_unit = result_unit * unit(baseUnits[base_dim])^exp_val
                else
                    @warn "Dimension $base_dim not found in baseUnits. Cannot restore units."
                    return value
                end
            end
        end
        return value * result_unit
    end
    
    # For Symbol/Expr dimensions, we can't automatically reconstruct units
    return value
end

"""
    parameterConvert(parameters::Dict) -> NamedTuple

Convert a dictionary of parameters into a **named tuple of [`Parameter`](@ref) objects**.

Each entry in the input dictionary can be either:
- a `Parameter` object (kept as-is), or
- a `DataType` (automatically wrapped into `Parameter(dataType)`).

Throws an error if any value is not a `Parameter` or `DataType`.

---

### **Arguments**
- `parameters::Dict`: Dictionary with parameter names as keys (symbols or strings) and values as
  either `Parameter` or `DataType` objects.

---

### **Returns**
- `NamedTuple`: A named tuple whose keys match the dictionary keys, and whose values are `Parameter` objects.

---

### **Examples**
```julia
params = Dict(
    :velocity => Parameter(Float64; dimensions=:L, defaultValue=ValueUnits(10.0, :m), description="Velocity magnitude"),
    :temperature => Float64
)

param_tuple = parameterConvert(params)
# NamedTuple with (:velocity, :temperature) => (Parameter(...), Parameter(...))
```
"""
function parameterConvert(parameters; modifiedIn::Vector{Tuple}=Tuple[])
    keys_tuple = Tuple(keys(parameters))
    l = []
    for i in keys_tuple
        if parameters[i] isa Parameter
            push!(l, parameters[i])
            l[end]._modifiedIn = copy(modifiedIn)
        elseif parameters[i] isa DataType
            push!(l, Parameter(parameters[i], _modifiedIn=copy(modifiedIn)))
        else
            error("Parameters must be of type Parameter or DataType. Given: $(parameters[i]) for parameter $i")
        end
    end
    values_tuple = Tuple(l)
    return NamedTuple{keys_tuple}(values_tuple)
end

dtype(parameter::Parameter{D}; isbits=false) where {D} = D in keys(DATATYPE) && isbits ? DATATYPE[D] : D
function abstractDataType(D::DataType)
    for i in keys(DATATYPE)
        if D <: i
            return i
        end
    end
    return D
end
function concreteDataType(D::DataType)
    for i in keys(DATATYPE)
        if D <: i
            return DATATYPE[i]
        end
    end
    return D
end
function standardDataType(D::DataType)
    concreteDataType(abstractDataType(D))
end

function setModifiedIn!(p::Parameter, type, scope; force=false)

    _modifiedNotRule = [i for i in p._modifiedIn if i[1] != :RULE]
    if length(_modifiedNotRule) > 0 && !force && type != :RULE
        error("Parameter is already modified in other scopes: $(p._modifiedIn). Modifying a parameter in multiple scopes can lead to unexpected behavior as the parameter will be updated several times. If you really want to allow multiple modifications, set allowMultipleModifications=true.")
    elseif !(scope in p._modifiedIn)
        push!(p._modifiedIn, (type, scope))
    end

    return

end