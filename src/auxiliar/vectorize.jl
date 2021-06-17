"""
    function vectorize_(abm::Agent,code::Expr)

Function to subtitute all the declared symbols of the agents in the expression into vector form.
optional arguments base and update add some intermediate names to the vectorized variables and to updated ones.
"""
function vectorize_(abm::Agent,code::Expr;base="",update="")
        
    #Vectorisation changes        
    for (i,v) in enumerate(abm.declaredSymbols["Local"])

        bs = Meta.parse(string("loc",base,"_"))
        up = Meta.parse(string("loc",update,"_"))

        code = subs_(code,v,:($up[ic1_,$i]),update=true)
        v2 = Meta.parse(string(v,"₁"))
        code = subs_(code,v2,:($up[ic1_,$i]),update=true)
        v2 = Meta.parse(string(v,"₂"))
        code = subs_(code,v2,:($up[nnic2_,$i]),update=true)

        code = subs_(code,v,:($bs[ic1_,$i]))
        v2 = Meta.parse(string(v,"₁"))
        code = subs_(code,v2,:($bs[ic1_,$i]))
        v2 = Meta.parse(string(v,"₂"))
        code = subs_(code,v2,:($bs[nnic2_,$i]))
    end

    for (i,v) in enumerate(abm.declaredSymbols["Identity"])

        bs = Meta.parse(string("id",base,"_"))
        up = Meta.parse(string("id",update,"_"))

        code = subs_(code,v,:($up[ic1_,$i]),update=true)
        v2 = Meta.parse(string(v,"₁"))
        code = subs_(code,v2,:($up[ic1_,$i]),update=true)
        v2 = Meta.parse(string(v,"₂"))
        code = subs_(code,v2,:($up[nnic2_,$i]),update=true)

        code = subs_(code,v,:($bs[ic1_,$i]))
        v2 = Meta.parse(string(v,"₁"))
        code = subs_(code,v2,:($bs[ic1_,$i]))
        v2 = Meta.parse(string(v,"₂"))
        code = subs_(code,v2,:($bs[nnic2_,$i]))
    end
    
    for (i,v) in enumerate(abm.declaredSymbols["Global"])

        bs = Meta.parse(string("glob",base,"_"))
        up = Meta.parse(string("glob",update,"_"))

        code = subs_(code,v,:($up[$i]),update=true)

        code = subs_(code,v,:($bs[$i]))
    end

    return code
end