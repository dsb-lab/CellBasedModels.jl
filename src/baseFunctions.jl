"""
    function isDimension(unit::Symbol)
    function isDimension(unit::Expr)

Check if the unit is a valid dimension symbol or expression (e.g. L, M, T...). To check valid dimesions se UNITS.

    Parameters
    ----------

| Field | Description |
|:---|:---|
| unit  | The unit symbol or expression to check. |

    Returns
    -------
    bool
        Returns true if the unit is a valid dimension symbol, false otherwise.

    Examples
    --------

```julia
isDimension(:L)  # true
isDimension(:M) # true
isDimension(:a) # false
isDimension(:(L^2)) # true
isDimension(:(L/M)) # true
```
"""
function isDimension(unit::Symbol)
    return haskey(UNITS, unit)
end

function isDimension(expr::Expr)
    is_valid = true
    postwalk(expr) do x
        if x isa Symbol && !(x in DIMENSION_OPERATORS)
            if !isDimension(x)
                is_valid = false
            end
        end
    end
    return is_valid
end

"""
    function isDimensionUnit(unit::Symbol)
    function isDimensionUnit(unit::Expr)

Check if the unit is a valid dimension unit expression (e.g. kg, m, s). To check valid dimension units se UNITS.

    Parameters
    ----------
| Field | Description |
|:---|:---|
| unit | The unit symbol or expression to check. |

    Returns
    -------
    bool
        Returns true if the unit is a valid dimension unit symbol, false otherwise.

    Examples
    --------
```julia
isDimensionUnit(:m)  # true
isDimensionUnit(:s) # true
isDimensionUnit(:(a/k)) # false
isDimensionUnit(:(m/s^2)) # true
isDimensionUnit(:(m/s)) # true
```
"""
function isDimensionUnit(unit::Symbol)
    for i in UNITS
        if haskey(i[2], unit)
            return true
        end
    end
    return false
end

function isDimensionUnit(expr::Expr)
    is_valid = true
    postwalk(expr) do x
        if x isa Symbol && !(x in DIMENSION_OPERATORS)
            if !isDimensionUnit(x)
                is_valid = false
            end
        end
    end
    return is_valid
end

"""
    function dimensionUnits2dimensions(expr::Symbol)
    function dimensionUnits2dimensions(expr::Expr)

Convert a dimension unit expression to a dimension expression.

Parameters
----------

| Field | Description |
|:---|:---|
| expr | The dimension unit expression to convert. |

Returns
-------
Expr
    The converted dimension.

Examples
--------
```julia
dimensionUnits2dimensions(:m) # returns :(L/T)
dimensionUnits2dimensions(:(m/s)) # returns :(L/T)
```
"""
function dimensionUnits2dimensions(expr::Symbol)
    if !isDimensionUnit(expr)
        throw(ArgumentError("The symbol is not a valid dimension unit symbol."))
    end
    
    for (dim, units) in UNITS
        if haskey(units, expr)
            return dim
        end
    end
    
    throw(ArgumentError("The symbol does not correspond to any known dimension unit."))
end

function dimensionUnits2dimensions(expr::Expr)
    if !isDimensionUnit(expr)
        throw(ArgumentError("The expression $expr is not a valid dimension unit expression."))
    end
    
    return postwalk(expr) do x
        if x isa Symbol && !(x in DIMENSION_OPERATORS)
            for (dim, units) in UNITS
                if haskey(units, x)
                    return dim
                end
            end
        end
        return x
    end
end

"""
    function compareDimensionsUnits2dimensions(dimensionsUnits::Union{Symbol, Expr}, dimensions::Union{Symbol, Expr})

Check if a dimension or dimension expression is equivalent to a dimension unit expression.

    Parameters
    ----------

| Field | Description |
|:---|:---|
| dimensionsUnits | The dimension unit expression to compare against. |
| dimensions | The dimension or dimension expression to check. |

    Returns
    -------
    bool
        Returns true if the dimension or dimension expression is equivalent to the dimension unit expression, false otherwise.

    Examples
    --------
```julia
compareDimensionsUnits2dimensions(:m, :L) # true
compareDimensionsUnits2dimensions(:(m/ms), :(L/T)) # true
compareDimensionsUnits2dimensions(:m, :(L^2)) # false
```
"""
function compareDimensionsUnits2dimensions(dimensionsUnits::Union{Symbol, Expr}, dimensions::Union{Symbol, Expr})
        
    return dimensions == dimensionUnits2dimensions(dimensionsUnits)

end