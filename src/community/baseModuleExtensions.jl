"""
Extends the getindex method to access symbolic variables from the Community structure.

# Arguments
 - **a** (Community) Community structure
 - **var** (Symbol) Symbol to be extracted

# Returns
Float if symbol is global parameter
Array{Float} otherwise
"""
function Base.getindex(a::Community,var::Symbol)
    
    if var in a.declaredSymb["var"]
        pos = findfirst(a.declaredSymb["var"].==var)
        return a.var[:,pos]
    elseif var in a.declaredSymb["inter"]
        pos = findfirst(a.declaredSymb["inter"].==var) 
        return a.inter[:,pos]
    elseif var in a.declaredSymb["loc"]
        pos = findfirst(a.declaredSymb["loc"].==var) 
        return a.loc[:,pos]
    elseif var in a.declaredSymb["locInter"]
        pos = findfirst(a.declaredSymb["locInter"].==var) 
        return a.locInter[:,pos]
    elseif var in a.declaredSymb["glob"]
        pos = findfirst(a.declaredSymb["glob"].==var) 
        return a.glob[pos]
    elseif var in a.declaredSymb["ids"]
        pos = findfirst(a.declaredSymb["ids"].==var) 
        return a.ids[:,pos]
    elseif var == :t
        return a.t
    elseif var == :N
        return a.N
    else
        error("Parameter not fount in the community.")
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
function Base.setindex!(a::Community,v::Array{<:AbstractFloat},var::Symbol)
    
    if var in a.declaredSymb["var"]
        pos = findfirst(a.declaredSymb["var"].==var) 
        a.var[:,pos] = v
    elseif var in a.declaredSymb["inter"]
        pos = findfirst(a.declaredSymb["inter"].==var) 
        a.inter[:,pos] = v
    elseif var in a.declaredSymb["loc"]
        pos = findfirst(a.declaredSymb["loc"].==var) 
        a.loc[:,pos] = v
    elseif var in a.declaredSymb["locInter"]
        pos = findfirst(a.declaredSymb["locInter"].==var) 
        a.locInter[:,pos] = v
    elseif var in a.declaredSymb["ids"]
        pos = findfirst(a.declaredSymb["ids"].==var) 
        a.ids[:,pos] = v
    else
        error("Parameter not fount in the community.")
    end

end

function Base.setindex!(a::Community,v::Number,var::Symbol)
    
    if var in a.declaredSymb["var"]
        pos = findfirst(a.declaredSymb["var"].==var) 
        a.var[:,pos] .= v
    elseif var in a.declaredSymb["inter"]
        pos = findfirst(a.declaredSymb["inter"].==var) 
        a.inter[:,pos] .= v
    elseif var in a.declaredSymb["loc"]
        pos = findfirst(a.declaredSymb["loc"].==var) 
        a.loc[:,pos] .= v
    elseif var in a.declaredSymb["locInter"]
        pos = findfirst(a.declaredSymb["locInter"].==var) 
        a.locInter[:,pos] .= v
    elseif var in a.declaredSymb["glob"]
        pos = findfirst(a.declaredSymb["glob"].==var) 
        a.glob[pos] = v
    elseif var in a.declaredSymb["ids"]
        pos = findfirst(a.declaredSymb["ids"].==var) 
        a.ids[:,pos] .= v
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

function Base.getindex(a::CommunityInTime,var::Symbol)
    
    if var == :t
        return [i.t for i in a.com]
    elseif var == :N
        return [i.N for i in a.com]
    end

    if :id_ in a.com[1].declaredSymb["ids"]

        #Find number of ids
        posId = findfirst(a.com[1].declaredSymb["ids"].==:id_)
        l = []
        for i in a.com
            append!(l, i.ids[:,posId])
        end
        idMax = maximum(l)
        #Create NaN array
        out = zeros(eltype(a.com[1][var]),length(a),idMax)
        out .= NaN
        #Fill array
        for i in 1:length(a)
            out[i,a.com[i][:id_]] .= a.com[i][var]
        end

        return out

    else

        #Create array
        out = zeros(eltype(a.com[1][var]),length(a),a[1].N)
        #Fill array
        for i in 1:length(a)
            out[i,:] .= a.com[i][var]
        end
        
        return out

    end

    return
end

function Base.getindex(a::CommunityInTime,var::Int)
    
    return a.com[var]

end

Base.first(a::CommunityInTime) = 1
Base.lastindex(a::CommunityInTime) = length(a)