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
    elseif var == :t_
        return a.t_
    elseif var == :N_
        return a.N_
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
        a.locInter[:,pos] = v
    elseif var in a.declaredSymb["glob"]
        pos = findfirst(a.declaredSymb["glob"].==var) 
        a.glob[pos] = v
    elseif var == :N_
        a.N_ = v
    elseif var == :t_
        a.t_ = v
    else
        error("Parameter not fount in the community.")
    end

end