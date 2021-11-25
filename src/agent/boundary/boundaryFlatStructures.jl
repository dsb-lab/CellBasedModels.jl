export BoundaryFlat, Periodic, Bounded, Free

"""
Boundary defining a line, rectangle or box.

# Constructors

    function BoundaryFlat(boundX::BoundaryFlatSubtypes=Free(),
        boundY::BoundaryFlatSubtypes=Free(),
        boundZ::BoundaryFlatSubtypes=Free())

### Arguments
 - **boundX::BoundaryFlatSubtypes** Bound type of the first dimension. (Default Free())
 - **boundY::BoundaryFlatSubtypes** Bound type of the second dimension. (Default Free())
 - **boundZ::BoundaryFlatSubtypes** Bound type of the third dimension. (Default Free())
"""
struct BoundaryFlat<:Boundary

    dims::Int
    boundaries::Array{BoundaryFlatSubtypes,1}
    addSymbols::Array{Symbol}

end

function BoundaryFlat(n::Int=0,boundX::BoundaryFlatSubtypes=Free(),
                        boundY::BoundaryFlatSubtypes=Free(),
                        boundZ::BoundaryFlatSubtypes=Free())

    bound = Array{BoundaryFlatSubtypes,1}([])
    symbols = Array{Symbol,1}([])
    for i in [boundX,boundY,boundZ][1:n]
        push!(bound,i)
        for j in keys(i.addSymbols)
            append!(symbols,i.addSymbols[j])
        end
    end

    return BoundaryFlat(n,bound,symbols)
end

"""
Boundary defining periodic boundary conditions.

# Constructors

    function Free(;medium::BoundaryMedium=Dirichlet())

### Keyword arguments
- **additional::Array{Symbol,1}** (Default Array{Symbol,1}()) Additional symbols to be updated when the symbol `s` crosses the boundary. (Empty)
- **medium::BoundaryMedium** Boundary method of the medium. (Default Dirichlet()) 

# Example: A free particle moving in the hole space.

```
bound = Free()
```
"""
struct Free<:BoundaryFlatSubtypes
    addSymbols::Dict{String,Array{Symbol,1}}
    medium::BoundaryMedium
end

function Free(;medium::BoundaryMedium=Dirichlet())
    return Free(Dict{String,Array{Symbol,1}}(),medium)
end

"""
Boundary defining periodic boundary conditions.

# Constructors

    function Periodic(;additional::Array{Symbol,1}=Array{Symbol,1}(),medium=MediumPeriodic())

### Keyword arguments
 - **additional::Array{Symbol,1}** (Default Array{Symbol,1}()) Additional symbols to be updated when the symbol `s` crosses the boundary.
 - **medium::BoundaryMedium** Boundary method of the medium. (Default Dirichlet()) 

# Example: An elongated particle with two degrees of freedom `x` and `x1` moving in periodic conditions.

```
bound = Periodic(:x,0,10,additional=[:x1])
```
"""
struct Periodic<:BoundaryFlatSubtypes 
    addSymbols::Dict{String,Array{Symbol,1}}
    medium::BoundaryMedium
end 

function Periodic(;additional::Array{Symbol,1}=Array{Symbol,1}(),medium::BoundaryMedium=PeriodicMedium())
    return Periodic(Dict("add"=>additional),medium)
end

"""
Default boundary defining a non-periodic, bounded space. The parameters specified in keyword arguments can have three behaviours:

 - **stop**: If the symbol `s` crosses the boundary, the specified parameter will be set to zero.
 - **bounce**: If the symbol `s` crosses the boundary, the specified parameter will be set to the position with respect to the boundary as it have bounced back.
 - **reflect**: If the symbol `s` crosses the boundary, the specified parameter will change sign.

All the behaviours can be specified for the minimum, the maximum or both boundaries.

# Constructors

    function Bounded(;
        stop::Array{Symbol,1}=Array{Symbol,1}(),
        stopMin::Array{Symbol,1}=Array{Symbol,1}(),
        stopMax::Array{Symbol,1}=Array{Symbol,1}(),
        bounce::Array{Symbol,1}=Array{Symbol,1}(),
        bounceMin::Array{Symbol,1}=Array{Symbol,1}(),
        bounceMax::Array{Symbol,1}=Array{Symbol,1}(),
        reflect::Array{Symbol,1}=Array{Symbol,1}(),
        reflectMin::Array{Symbol,1}=Array{Symbol,1}(),
        reflectMax::Array{Symbol,1}=Array{Symbol,1}(),
        medium::BoundaryMedium=Dirichlet()
        )

### Keyword arguments
 - **stop::Array{Symbol,1}** (Default Array{Symbol,1}())) 
 - **stopMin::Array{Symbol,1}** (Default Array{Symbol,1}())
 - **stopMax::Array{Symbol,1}** (Default Array{Symbol,1}())
 - **bounce::Array{Symbol,1}** (Default Array{Symbol,1}())
 - **bounceMin::Array{Symbol,1}** (Default Array{Symbol,1}())
 - **bounceMax::Array{Symbol,1}** (Default Array{Symbol,1}())
 - **reflect::Array{Symbol,1}** (Default Array{Symbol,1}())
 - **reflectMin::Array{Symbol,1}** (Default Array{Symbol,1}())
 - **reflectMax::Array{Symbol,1}** (Default Array{Symbol,1}())
 - **medium::BoundaryMedium** Boundary method of the medium. (Default Dirichlet()) 

Example: A particle with some velocity that bounces when touches a border and changes direction.

```
boundX = Bounded(:x,0,10,
            bounce=[:x],
            reflect=[:vx])
boundY = Bounded(:y,0,10,
            bounce=[:y],
            reflect=[:vy])
```
"""
struct Bounded<:BoundaryFlatSubtypes 
    addSymbols::Dict{String,Array{Symbol,1}}
    medium::BoundaryMedium
end

function Bounded(;
                stop::Array{Symbol,1}=Array{Symbol,1}(),
                stopMin::Array{Symbol,1}=Array{Symbol,1}(),
                stopMax::Array{Symbol,1}=Array{Symbol,1}(),
                bounce::Array{Symbol,1}=Array{Symbol,1}(),
                bounceMin::Array{Symbol,1}=Array{Symbol,1}(),
                bounceMax::Array{Symbol,1}=Array{Symbol,1}(),
                reflect::Array{Symbol,1}=Array{Symbol,1}(),
                reflectMin::Array{Symbol,1}=Array{Symbol,1}(),
                reflectMax::Array{Symbol,1}=Array{Symbol,1}(),
                medium::BoundaryMedium=Dirichlet())

        d = Dict{String,Array{Symbol,1}}()

        d["stop"]=stop
        d["stopMin"]=stopMin
        d["stopMax"]=stopMax
        d["bounce"]=bounce
        d["bounceMin"]=bounceMin
        d["bounceMax"]=bounceMax
        d["reflect"]=reflect
        d["reflectMin"]=reflectMin
        d["reflectMax"]=reflectMax

    return Bounded(d,medium)
end