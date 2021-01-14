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