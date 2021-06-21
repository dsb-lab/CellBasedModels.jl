"""
Extends the getindex method to access symbolic variables from the Community structure.

# Arguments
 - **a** (Community) Community structure
 - **var** (Symbol) Symbol to be extracted

# Returns
Float if symbol is global parameter
Array{Float} otherwise
"""
function Base.getproperty(a::Community,var::Symbol)
    
    try 
        return getfield(a,var)
    catch
        if var in a.declaredSymbols_["Local"]
            pos = findfirst(a.declaredSymbols_["Local"].==var) 
            return @views a.local_[:,pos]
        elseif var in a.declaredSymbols_["Identity"]
            pos = findfirst(a.declaredSymbols_["Identity"].==var) 
            return @views a.identity_[:,pos]
        elseif var in a.declaredSymbols_["Global"]
            pos = findfirst(a.declaredSymbols_["Global"].==var) 
            return @views a.global_[pos]
        elseif var in a.declaredSymbols_["GlobalArray"]
            pos = findfirst(a.declaredSymbols_["GlobalArray"].==var) 
            return a.globalArray_[pos]
        else
            error("Parameter ", var, " not fount in the community.")
        end
    end
end

"""
Extends the setindex method to assign symbolic variables from the Community structure.

# Arguments
 - **a** (Community) Community structure
 - **v** (Float, Array{Float}) Parameters to be associated with the parameter. If Array, it has to be of the same length as the number of agents in the Community.
 - **var** (Symbol) Symbol to be associated

# Returns
Float if symbol is global parameter
Array{Float} otherwise
"""
function Base.setproperty!(a::Community,var::Symbol,v::Array{<:Number})
    
    if var in a.declaredSymbols_["Local"]
        if size(v) != (a.N,)
            error("Trying to assign array with shape ", shape(v), ". It should be of size (N,)")
        end
        pos = findfirst(a.declaredSymbols_["Local"].==var) 
        vec = a.local_
        vec[:,pos] = v
        setfield!(a,:local_,vec)
    elseif var in a.declaredSymbols_["Identity"]
        if size(v) != (a.N,)
            error("Trying to assign array with shape ", shape(v), ". It should be of size (N,)")
        end
        pos = findfirst(a.declaredSymbols_["Identity"].==var) 
        vec = a.identity_
        vec[:,pos] = v
        setfield!(a,:identity_,vec)
    elseif var in a.declaredSymbols_["GlobalArray"]
        pos = findfirst(a.declaredSymbols_["GlobalArray"].==var) 
        a.globalArray_[pos] = v
    else
        error("Parameter ", var, " not fount in the community.")
    end

end

function Base.setproperty!(a::Community,var::Symbol,v::Number)
    
    if var in a.declaredSymbols_["Local"]
        error("Local parameter ", i, " cannot be assigned with a scalar. Use .= instead.")
    elseif var in a.declaredSymbols_["Identity"]
        error("Identity parameter", i, " cannot be assigned with a scalar. Use .= instead.")
    elseif var in a.declaredSymbols_["Global"]
        pos = findfirst(a.declaredSymbols_["Global"].==var) 
        a.global_[pos] = v
    elseif var in a.declaredSymbols_["GlobalArray"]
        error("GlobalArray ", i, " cannot be assigned with a scalar.")
    elseif var == :N
        a.N = v
    elseif var == :t
        a.t = v
    else
        error("Parameter not fount in the community.")
    end

end

function Base.push!(a::CommunityInTime,c::Community)
    
    push!(a.com,c)
    
    return
end

function Base.length(a::CommunityInTime)
    
    return length(a.com)
end

function Base.getproperty(a::CommunityInTime,var::Symbol)

    try 
        return getfield(a,var)
    catch
        
        if var == :t
            return [i.t for i in a.com]
        elseif var == :N
            return [i.N for i in a.com]
        end

        if var in a.com[1].declaredSymbols_["GlobalArray"]

            out = []
            for i in 1:length(a)
                push!(out,getproperty(a.com[i],var))
            end

            return out

        else
            #Create array
            out = zeros(eltype(getproperty(a.com[1],var)),a[1].N,length(a))
            #Fill array
            for i in 1:length(a)
                out[:,i] .= getproperty(a.com[i],var)
            end
            
            return out

        end

    end

    return
end

function Base.getindex(a::CommunityInTime,var::Int)
    
    return a.com[var]

end

Base.first(a::CommunityInTime) = 1
Base.lastindex(a::CommunityInTime) = length(a)