"""
    function vectorize_(abm::Agent,code::Expr)

Function to subtitute all the declared symbols of the agents in the expression into vector form.
"""
function vectorize_(abm::Agent,code::Expr)
        
    #Vectorisation changes
    for (i,v) in enumerate(abm.declaredSymbols["Variable"])
        code = subs_(code,v,:(var_[ic1_,$i]))
        v2 = Meta.parse(string(v,"₁"))
        code = subs_(code,v2,:(var_[ic1_,$i]))
        v2 = Meta.parse(string(v,"₂"))
        code = subs_(code,v2,:(var_[nnic2_,$i]))
    end
        
    for (i,v) in enumerate(abm.declaredSymbols["Local"])
        code = subs_(code,v,:(loc_[ic1_,$i]))
        v2 = Meta.parse(string(v,"₁"))
        code = subs_(code,v2,:(loc_[ic1_,$i]))
        v2 = Meta.parse(string(v,"₂"))
        code = subs_(code,v2,:(loc_[nnic2_,$i]))
    end
    
    for (i,v) in enumerate(abm.declaredSymbols["Interaction"])
        code = subs_(code,v,:(inter_[ic1_,$i]))
        v2 = Meta.parse(string(v,"₁"))
        code = subs_(code,v2,:(inter_[ic1_,$i]))
        v2 = Meta.parse(string(v,"₂"))
        code = subs_(code,v2,:(inter_[nnic2_,$i]))
    end

    for (i,v) in enumerate(abm.declaredSymbols["Global"])
        code = subs_(code,v,:(glob_[$i]))
    end

    for (i,v) in enumerate(abm.declaredSymbols["Identity"])
        code = subs_(code,v,:(id_[ic1_,$i]))
        v2 = Meta.parse(string(v,"₁"))
        code = subs_(code,v2,:(id_[ic1_,$i]))
        v2 = Meta.parse(string(v,"₂"))
        code = subs_(code,v2,:(id_[nnic2_,$i]))
    end

    return code
end