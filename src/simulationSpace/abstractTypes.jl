#Boundary types

"""
Boundary defining periodic boundary conditions.

# Constructors

    function Periodic(s::Symbol,min::Real,max::Real;additional::Array{Symbol,1}=Array{Symbol,1}())

### Arguments
 - **s::Symbol** Symbol of the variable to be used for the periodic variable.
 - **min::Real** Minimum of the boundary.
 - **max::Real** Maximum of the boundary.

### Keyword arguments
 - **additional::Array{Symbol,1}** (Default Array{Symbol,1}()) Additional symbols to be updated when the symbol `s` crosses the boundary.
"""
struct Periodic<:FlatBoundary 
    s::Symbol
    min::Real
    max::Real
    addSymbols::Dict{String,Array{Symbol,1}}
end 

function Periodic(s::Symbol,min::Real,max::Real;additional::Array{Symbol,1}=Array{Symbol,1}())
    return Periodic(s,min,max,Dict("add"=>additional))
end

function returnBound_(b::Periodic,p::Program_)

    posm = p.update["Local"][b.s]

    up = quote localVCopy[ic1_,$posm] += $(b.max-b.min) end
    for i in b.addSymbols["add"]
        pos = p.update["Local"][i]
        push!(up.args,:(localVCopy[ic1_,$pos] += $(b.max-b.min)))
    end


    down = quote localVCopy[ic1_,$posm] -= $(b.max-b.min) end
    for i in b.addSymbols["add"]
        pos = p.update["Local"][i]
        push!(down.args,:(localVCopy[ic1_,$pos] -= $(b.max-b.min)))
    end


    code = quote
                if localVCopy[ic1_,$posm] < $(b.min)
                    $up
                elseif localVCopy[ic1_,$posm] >= $(b.max)
                    $down
                end
           end

    return code
end

"""
Default boundary defining a non-periodic, bounded space. The parameters specified in keyword arguments can have three behaviours:

 - **stop**: If the symbol `s` crosses the boundary, the specified parameter will be set to zero.
 - **bounce**: If the symbol `s` crosses the boundary, the specified parameter will be set to the position with respect to the boundary as it have bounced back.
 - **reflect**: If the symbol `s` crosses the boundary, the specified parameter will change sign.

All the behaviours can be specified for the minimum, the maximum or both boundaries.

# Constructors

    function Bound(s::Symbol,min::Real,max::Real;
        stop::Array{Symbol,1}=Array{Symbol,1}(),
        stopMin::Array{Symbol,1}=Array{Symbol,1}(),
        stopMax::Array{Symbol,1}=Array{Symbol,1}(),
        bounce::Array{Symbol,1}=Array{Symbol,1}(),
        bounceMin::Array{Symbol,1}=Array{Symbol,1}(),
        bounceMax::Array{Symbol,1}=Array{Symbol,1}(),
        reflect::Array{Symbol,1}=Array{Symbol,1}(),
        reflectMin::Array{Symbol,1}=Array{Symbol,1}(),
        reflectMax::Array{Symbol,1}=Array{Symbol,1}()
        )

### Arguments
 - **s::Symbol** Symbol of the variable to be used for the periodic variable.
 - **min::Real** Minimum of the boundary.
 - **max::Real** Maximum of the boundary.

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
"""
struct Bound<:NonPeriodicFlat 
    s::Symbol
    min::Real
    max::Real
    addSymbols::Dict{String,Array{Symbol,1}}
end

function Bound(s::Symbol,min::Real,max::Real;
                stop::Array{Symbol,1}=Array{Symbol,1}(),
                stopMin::Array{Symbol,1}=Array{Symbol,1}(),
                stopMax::Array{Symbol,1}=Array{Symbol,1}(),
                bounce::Array{Symbol,1}=Array{Symbol,1}(),
                bounceMin::Array{Symbol,1}=Array{Symbol,1}(),
                bounceMax::Array{Symbol,1}=Array{Symbol,1}(),
                reflect::Array{Symbol,1}=Array{Symbol,1}(),
                reflectMin::Array{Symbol,1}=Array{Symbol,1}(),
                reflectMax::Array{Symbol,1}=Array{Symbol,1}()
                )

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

    return Bound(s,min,max,d)
end

function returnBound_(b::Bound,p::Program_)

    min = quote end
    for i in b.addSymbols["stop"]
        pos = p.update["Local"][i]
        push!(min.args,:(localVCopy[ic1_,$pos] = boundStopMin(localVCopy[ic1_,$pos],$(b.min))))
    end
    for i in b.addSymbols["stopMin"]
        pos = p.update["Local"][i]
        push!(min.args,:(localVCopy[ic1_,$pos] = boundStopMin(localVCopy[ic1_,$pos],$(b.min))))
    end
    for i in b.addSymbols["bounce"]
        pos = p.update["Local"][i]
        push!(min.args,:(localVCopy[ic1_,$pos] = boundBounceMin(localVCopy[ic1_,$pos],$(b.min))))
    end
    for i in b.addSymbols["bounceMin"]
        pos = p.update["Local"][i]
        push!(min.args,:(localVCopy[ic1_,$pos] = boundBounceMin(localVCopy[ic1_,$pos],$(b.min))))
    end
    for i in b.addSymbols["reflect"]
        pos = p.update["Local"][i]
        push!(min.args,:(localVCopy[ic1_,$pos] = boundReflect(localVCopy[ic1_,$pos])))
    end
    for i in b.addSymbols["reflectMin"]
        pos = p.update["Local"][i]
        push!(min.args,:(localVCopy[ic1_,$pos] = boundReflect(localVCopy[ic1_,$pos])))
    end


    max = quote end
    for i in b.addSymbols["stop"]
        pos = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$pos] = boundStopMax(localVCopy[ic1_,$pos],$(b.max))))
    end
    for i in b.addSymbols["stopMax"]
        pos = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$pos] = boundStopMax(localVCopy[ic1_,$pos],$(b.max))))
    end
    for i in b.addSymbols["bounce"]
        pos = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$pos] = boundBounceMax(localVCopy[ic1_,$pos],$(b.max))))
    end
    for i in b.addSymbols["bounceMax"]
        pos = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$pos] = boundBounceMax(localVCopy[ic1_,$pos],$(b.max))))
    end
    for i in b.addSymbols["reflect"]
        pos = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$pos] = boundReflect(localVCopy[ic1_,$pos])))
    end
    for i in b.addSymbols["reflectMax"]
        pos = p.update["Local"][i]
        push!(max.args,:(localVCopy[ic1_,$pos] = boundReflect(localVCopy[ic1_,$pos])))
    end

    pos = p.update["Local"][b.s]

    if !emptyquote_(min) && !emptyquote_(max)

        code = quote 
            if localVCopy[ic1_,$pos] < $(b.min) 
                $min
            elseif localVCopy[ic1_,$pos] >= $(b.max) 
                $max
            end
       end        
       
       return code
    elseif !emptyquote_(min)
        code = quote 
            if localVCopy[ic1_,$pos] < $(b.min) 
                $min
            end
       end        
       
        return code
    elseif !emptyquote_(max)
        code = quote 
            if localVCopy[ic1_,$pos] >= $(b.max) 
                $max
            end
       end        
       
        return code
    else

        return quote end
    end

end

export boundStopMin, boundStopMax, boundBounceMin, boundBounceMax, boundReflect

boundStopMin(x,min) = max(x,min)
boundStopMax(x,max) = min(x,max)

boundBounceMin(x,min) = min + (min-x)
boundBounceMax(x,max) = max - (x-max)

boundReflect(x) = -x

function returnBound_(b::Array{<:FlatBoundary,1},p::Program_)

    code = quote end
    for i in b
        if i.s in keys(p.update["Local"])
            codeb = returnBound_(i,p)

            if !emptyquote_(codeb)
                push!(code.args,codeb)
            end
        end
    end
    
    return code

end
