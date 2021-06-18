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
        if var in a.declaredSymbols["Local"]
            pos = findfirst(a.declaredSymbols["Local"].==var) 
            return a.local_[:,pos]
        elseif var in a.declaredSymbols["Identity"]
            pos = findfirst(a.declaredSymbols["Identity"].==var) 
            return a.identity_[:,pos]
        elseif var in a.declaredSymbols["Global"]
            pos = findfirst(a.declaredSymbols["Global"].==var) 
            return a.global_[pos]
        elseif var in a.declaredSymbols["GlobalArray"]
            pos = findfirst(a.declaredSymbols["GlobalArray"].==var) 
            return a.globalArray_[pos]
        elseif var == :t
            return a.t
        elseif var == :N
            return a.N
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
    
    if var in a.declaredSymbols["Local"]
        pos = findfirst(a.declaredSymbols["Local"].==var) 
        vec = a.local_
        vec[:,pos] = v
        setfield!(a,:local_,vec)
    elseif var in a.declaredSymbols["Identity"]
        pos = findfirst(a.declaredSymbols["Identity"].==var) 
        vec = a.identity_
        vec[:,pos] = v
        setfield!(a,:identity_,vec)
    elseif var in a.declaredSymbols["GlobalArray"]
        pos = findfirst(a.declaredSymbols["GlobalArray"].==var) 
        a.GlobalArray[pos] = v
    else
        error("Parameter ", var, " not fount in the community.")
    end

end

function Base.setproperty!(a::Community,var::Symbol,v::Number)
    
    if var in a.declaredSymbols["Local"]
        pos = findfirst(a.declaredSymbols["Local"].==var) 
        a.local_[:,pos] .= v
    elseif var in a.declaredSymbols["Identity"]
        pos = findfirst(a.declaredSymbols["Identity"].==var) 
        a.identity_[:,pos] .= v
    elseif var in a.declaredSymbols["Global"]
        pos = findfirst(a.declaredSymbols["Global"].==var) 
        a.global_[pos] = v
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

# function Base.getindex(a::CommunityInTime,var::Symbol)
    
#     if var == :t
#         return [i.t for i in a.com]
#     elseif var == :N
#         return [i.N for i in a.com]
#     end

#     if var in a.com[1].declaredSymbols["globArray"]

#         out = []
#         for i in 1:length(a)
#             push!(out,a.com[i][var])
#         end

#         return out

#     elseif :id_ in a.com[1].declaredSymbols["ids"]

#         #Find number of ids
#         posId = findfirst(a.com[1].declaredSymbols["ids"].==:id_)
#         l = []
#         for i in a.com
#             append!(l, i.Identity[:,posId])
#         end
#         idMax = maximumIdentity
#         #Create NaN array
#         out = zeros(eltype(a.com[1][var]),length(a),idMax)
#         out .= NaN
#         #Fill array
#         for i in 1:length(a)
#             out[i,a.com[i][:id_]] .= a.com[i][var]
#         end

#         return out

#     else
#         #Create array
#         out = zeros(eltype(a.com[1][var]),length(a),a[1].N)
#         #Fill array
#         for i in 1:length(a)
#             out[i,:] .= a.com[i][var]
#         end
        
#         return out

#     end

#     return
# end

# function Base.getindex(a::CommunityInTime,var::Int)
    
#     return a.com[var]

# end

# Base.first(a::CommunityInTime) = 1
# Base.lastindex(a::CommunityInTime) = length(a)