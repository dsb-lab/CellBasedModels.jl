
"""
    struct Parameter

Represents a **model or simulation parameter** with associated metadata:
type, dimensions, default value, and description.

---

### **Fields**
- `dataType::DataType` — The Julia data type of the parameter (e.g. `Float64`, `Int`, `Bool`).
- `dimensions::Union{Nothing, Symbol, Expr}` — Dimensionality or units of the parameter.
  - `nothing`: dimensionless
  - `Symbol`: single unit or dimension (e.g. `:L`, `:T`)
  - `Expr`: compound unit expression (e.g. `:(L/T^2)`)
- `defaultValue` — Default or initial value, automatically wrapped in a [`ValueUnits`](@ref) object.
- `description::String` — Text description of the parameter’s purpose or meaning.
- `_updated::Bool` — Internal flag used to track whether the parameter is modified.

---

### **Constructor**
```julia
Parameter(dataType::DataType;
          dimensions::Union{Nothing, Symbol, Expr}=nothing,
          defaultValue::Union{<:Real, Bool, Nothing}=nothing,
          description::String="")
```

Creates a new `Parameter` object.  
If `defaultValue` is not already a `ValueUnits` object, it is automatically wrapped as `ValueUnits(defaultValue)`.

---

### **Examples**
```julia
# Scalar parameter with default value
p1 = Parameter(Float64; defaultValue=1.0, description="Default scalar")

# Parameter with dimensional information
p2 = Parameter(Float64; dimensions=:L, defaultValue=ValueUnits(1.0, :m), description="Length parameter")

# Boolean flag
p3 = Parameter(Bool; defaultValue=true, description="Toggle flag")

# Printing
show(p1)
```
"""
struct Parameter
    dataType::DataType
    dimensions::Union{Nothing, Symbol, Expr}
    defaultValue
    description::String
    _updated::Bool

    function Parameter(dataType::DataType;
                       dimensions::Union{Nothing, Symbol, Expr}=nothing,
                       defaultValue::Union{<:Real, Bool, Nothing}=nothing,
                       description::String="")
        new(dataType, dimensions, defaultValue, description, false)
    end
end

"""
    Base.show(io::IO, x::Parameter)

Custom display for [`Parameter`](@ref) objects, printing all key fields
in a readable format.

---

### **Example**
```julia
p = Parameter(Float64; defaultValue=1.0, description="Example")
show(p)
```

Output:
```
Parameter:
    DataType: Float64
    Dimensions: nothing
    Default Value: ValueUnits(1.0)
    Description: Example
```
"""
function Base.show(io::IO, x::Parameter)
    println("Parameter: ")
    println("\t DataType: ", x.dataType)
    println("\t Dimensions: ", x.dimensions)
    println("\t Default Value: ", x.defaultValue)
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
function parameterConvert(parameters)
    keys_tuple = Tuple(keys(parameters))
    l = []
    for i in keys_tuple
        if parameters[i] isa Parameter
            push!(l, parameters[i])
        elseif parameters[i] isa DataType
            push!(l, Parameter(parameters[i]))
        else
            error("Parameters must be of type Parameter or DataType. Given: $(typeof(parameters[i])) for parameter $i")
        end
    end
    values_tuple = Tuple(l)
    return NamedTuple{keys_tuple}(values_tuple)
end
