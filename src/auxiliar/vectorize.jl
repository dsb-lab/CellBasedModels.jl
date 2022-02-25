function errorInteraction(vAux)
    error("In an Interaction module the variable ",vAux," has been declared without specifying to which agent is assigned. Please specify putting .i or .j to the variable.")
end

"""
    function vectorize_(abm::Agent,code::Expr)

Function to subtitute all the declared symbols of the agents in the expression into vector form.
optional arguments base and update add some intermediate names to the vectorized variables and to updated ones.
"""
function vectorize_(abm::Agent,code::Expr,p::Program_;interaction=false)
        
    #Vectorisation changes        
    for (i,v) in enumerate(abm.declaredSymbols["Local"])

        bs = :localV
        bsnew = :localVCopy
        if v in keys(p.update["Local"])
            pos = p.update["Local"][v]
        else
            pos = i
        end

        code = postwalk(x->@capture(x, vAux_.i.new) && vAux == v ? :($bsnew[ic1_,$pos]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j.new) && vAux == v ? :($bsnew[nnic2_,$pos]) : x, code)
        code = postwalk(x->@capture(x, vAux_.i) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j) && vAux == v ? :($bs[nnic2_,$i]) : x, code)
        if interaction
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? errorInteraction(vAux) : x, code)
        else
            code = postwalk(x->@capture(x, vAux_.new) && vAux == v ? :($bsnew[ic1_,$pos]) : x, code)
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        end

    end

    for (i,v) in enumerate(abm.declaredSymbols["LocalInteraction"])

        bs = :localInteractionV

        code = postwalk(x->@capture(x, vAux_.i.new) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j.new) && vAux == v ? :($bs[nnic2_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.i) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j) && vAux == v ? :($bs[nnic2_,$i]) : x, code)
        if interaction
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? errorInteraction(vAux) : x, code)
        else
            code = postwalk(x->@capture(x, vAux_.new) && vAux == v ? :($bs[ic1_,$i]) : x, code)
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        end

    end

    for (i,v) in enumerate(abm.declaredSymbols["Identity"])

        bs = :identityV
        bsnew = :identityVCopy
        if v in keys(p.update["Identity"])
            pos = p.update["Identity"][v]
        else
            pos = i
        end

        code = postwalk(x->@capture(x, vAux_.i.new) && vAux == v ? :($bsnew[ic1_,$pos]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j.new) && vAux == v ? :($bsnew[nnic2_,$pos]) : x, code)
        code = postwalk(x->@capture(x, vAux_.i) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j) && vAux == v ? :($bs[nnic2_,$i]) : x, code)
        if interaction
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? errorInteraction(vAux) : x, code)
        else
            code = postwalk(x->@capture(x, vAux_.new) && vAux == v ? :($bsnew[ic1_,$pos]) : x, code)
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        end

    end

    for (i,v) in enumerate(abm.declaredSymbols["IdentityInteraction"])

        bs = :identityInteractionV

        code = postwalk(x->@capture(x, vAux_.i.new) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j.new) && vAux == v ? :($bs[nnic2_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.i) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        code = postwalk(x->@capture(x, vAux_.j) && vAux == v ? :($bs[nnic2_,$i]) : x, code)
        if interaction
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? errorInteraction(vAux) : x, code)
        else
            code = postwalk(x->@capture(x, vAux_.new) && vAux == v ? :($bs[ic1_,$i]) : x, code)
            code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        end

    end

    for (i,v) in enumerate(abm.declaredSymbols["Global"])

        bs = :globalV
        bsnew = :globalVCopy
        if v in keys(p.update["Global"])
            pos = p.update["Global"][v]
        else
            pos = i
        end

        code = postwalk(x->@capture(x, $v.new) ? :($bsnew[$pos]) : x, code)
        code = postwalk(x->@capture(x, $v) ? :($bs[$i]) : x, code)

    end

    for (i,v) in enumerate(abm.declaredSymbols["GlobalArray"])

        name = Meta.parse(string(v,GLOBALARRAYCOPY))
        code = postwalk(x->@capture(x, cc_[c__].new) && cc==v ? :($name[$(c...)]) : x, code)
        code = postwalk(x->@capture(x, cc_.new) && cc==v ? :($name) : x, code)
    end

    for (i,v) in enumerate(abm.declaredSymbols["Medium"])

        bs = :mediumV
        cp = :mediumVCopy

        if abm.dims == 1
            code = postwalk(x->@capture(x, cc_.new) && cc==v ? :($cp[idMediumX_,$i]) : x, code)
            code = postwalk(x->@capture(x, cc_) && cc==v ? :($bs[idMediumX_,$i]) : x, code)
        elseif abm.dims == 2
            code = postwalk(x->@capture(x, cc_.new) && cc==v ? :($cp[idMediumX_,idMediumY_,$i]) : x, code)
            code = postwalk(x->@capture(x, cc_) && cc==v ? :($bs[idMediumX_,idMediumY_,$i]) : x, code)
        elseif abm.dims == 3
            code = postwalk(x->@capture(x, cc_.new) && cc==v ? :($cp[idMediumX_,idMediumY_,idMediumZ_,$i]) : x, code)
            code = postwalk(x->@capture(x, cc_) && cc==v ? :($bs[idMediumX_,idMediumY_,idMediumZ_,$i]) : x, code)
        end
    end

    return code
end

"""
    function vectorizeMedium_(abm::Agent,code::Expr)

Function to subtitute all the declared symbols of the medium in the expression into vector form.
"""
function vectorizeMedium_(abm::Agent,code::Union{Expr,Symbol,<:Number},p::Program_)

    for (i,v) in enumerate(abm.declaredSymbols["Global"])

        bs = :globalV
        bsnew = :globalVCopy
        if v in keys(p.update["Global"])
            pos = p.update["Global"][v]
        else
            pos = i
        end

        code = postwalk(x->@capture(x, $v.new) ? :($bsnew[$pos]) : x, code)
        code = postwalk(x->@capture(x, $v) ? :($bs[$i]) : x, code)

    end

    for (i,v) in enumerate(abm.declaredSymbols["GlobalArray"])

        name = Meta.parse(string(v,GLOBALARRAYCOPY))
        code = postwalk(x->@capture(x, cc_[c__].new) && cc==v ? :($name[$(c...)]) : x, code)
        code = postwalk(x->@capture(x, cc_.new) && cc==v ? :($name) : x, code)

    end

    for (i,v) in enumerate(abm.declaredSymbols["Medium"])

        bs = :mediumV
        bsnew = :mediumVCopy
        if v in keys(p.update["Medium"])
            pos = p.update["Medium"][v]
        else
            pos = i
        end

        code = postwalk(x->@capture(x, vAux_.new) && vAux == v ? :($bsnew[$(MEDIUMITERATIONSYMBOLS[1:p.agent.dims]...),$pos]) : x, code)
        code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($bs[$(MEDIUMITERATIONSYMBOLS[1:p.agent.dims]...),$i]) : x, code)

    end

    return code

end
