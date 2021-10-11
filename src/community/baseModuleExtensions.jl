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
    
    if var in fieldnames(Community)
        return getfield(a,var)
    else
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
        elseif var in a.declaredSymbols_["Medium"]
            pos = findfirst(a.declaredSymbols_["Medium"].==var) 
            if a.dims == 1
                return @views a.medium_[:,pos]
            elseif a.dims == 2
                return @views a.medium_[:,:,pos]
            elseif a.dims == 3
                println(size(a.medium_))
                return @views a.medium_[:,:,:,pos]
            end
        else
            error("Parameter ", var, " not found in the community.")
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
    elseif var in a.declaredSymbols_["Medium"]
        if size(v) != size(a.var)[1:end-1]
            error("Trying to assign array with shape ", shape(v), ". It should be of size ", size(a.var)[1:end-1])
        end
        pos = findfirst(a.declaredSymbols_["Identity"].==var) 
        vec = a.medium_
        if a.dims == 1
            vec[:,pos] = v
        elseif a.dims == 2
            vec[:,:,pos] = v
        elseif a.dims == 3
            vec[:,:,:,pos] = v
        end
        setfield!(a,:medium_,vec)
    else
        error("Parameter ", var, " not fount in the community.")
    end

end

function Base.setproperty!(a::Community,var::Symbol,v::Number)
    
    if var in a.declaredSymbols_["Local"]
        error("Local parameter ", var, " cannot be assigned with a scalar. Use .= instead.")
    elseif var in a.declaredSymbols_["Identity"]
        error("Identity parameter ", var, " cannot be assigned with a scalar. Use .= instead.")
    elseif var in a.declaredSymbols_["Global"]
        pos = findfirst(a.declaredSymbols_["Global"].==var) 
        a.global_[pos] = v
    elseif var in a.declaredSymbols_["GlobalArray"]
        error("GlobalArray ", var, " cannot be assigned with a scalar.")
    elseif var == :N
        setfield!(a,:N,v)
    elseif var == :t
        setfield!(a,:t,v)
    else
        error("Parameter ", var," not fount in the community.")
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

    if var in fieldnames(CommunityInTime)
        return getfield(a,var)
    else
        
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

            nMax = maximum(a.com[end].id)
            #Create array
            out = fill(NaN,length(a),nMax)
            #Fill array
            for i in 1:length(a)
                a.com[i].id
                out[i,a[i].id] .= getproperty(a.com[i],var)
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