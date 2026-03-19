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
    dimensions::Union{Nothing, Symbol, Expr}
    defaultValue::Union{D, Function, Nothing}
    description::String
    _updated::Bool
    _DE::Bool
    _modifiedIn::Vector{Tuple}

    function Parameter(dataType::DataType;
                       dimensions::Union{Nothing, Symbol, Expr}=nothing,
                       defaultValue=nothing,
                       description::String="", _updated::Bool=false, _DE::Bool=false, _modifiedIn::Vector{Tuple}=Vector{Tuple}())

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
        if !(defaultValue === nothing || defaultValue isa Function || defaultValue isa dataType)
            error("Parameter defaultValue must be of type $dataType, a Function, or nothing. Found: $(typeof(defaultValue))")
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