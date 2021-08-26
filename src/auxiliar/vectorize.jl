"""
    function vectorize_(abm::Agent,code::Expr)

Function to subtitute all the declared symbols of the agents in the expression into vector form.
optional arguments base and update add some intermediate names to the vectorized variables and to updated ones.
"""
function vectorize_(abm::Agent,code::Expr,p::Program_)
        
    #Vectorisation changes        
    for (i,v) in enumerate(abm.declaredSymbols["Local"])

        bs = :localV

        code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        v2 = Meta.parse(string(v,"_i"))
        code = postwalk(x->@capture(x, vAux_) && vAux == v2 ? :($bs[ic1_,$i]) : x, code)
        v2 = Meta.parse(string(v,"_j"))
        code = postwalk(x->@capture(x, vAux_) && vAux == v2 ? :($bs[nnic2_,$i]) : x, code)

        if "Local" in keys(p.update)
            if v in keys(p.update["Local"])
                cc = findfirst(abm.declaredSymbols["Local"].==v)
                pos = p.update["Local"][v]
                #Code that may be optimized hopefully
                code = postwalk(x->@capture(x, localV[g_,c_] = v1__) && cc==c ? :(localVCopy[$g,$pos] = $(v1...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] += v1__) && cc==c ? :(localVCopy[$g,$pos] += $(v1...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] -= v1__) && cc==c ? :(localVCopy[$g,$pos] -= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] *= v1__) && cc==c ? :(localVCopy[$g,$pos] *= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] /= v1__) && cc==c ? :(localVCopy[$g,$pos] /= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] \= v1__) && cc==c ? :(localVCopy[$g,$pos] \= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] ÷= v1__) && cc==c ? :(localVCopy[$g,$pos] ÷= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] %= v1__) && cc==c ? :(localVCopy[$g,$pos] %= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] ^= v1__) && cc==c ? :(localVCopy[$g,$pos] ^= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] &= v1__) && cc==c ? :(localVCopy[$g,$pos] &= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] |= v1__) && cc==c ? :(localVCopy[$g,$pos] |= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] ⊻= v1__) && cc==c ? :(localVCopy[$g,$pos] ⊻= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] >>>= v1__) && cc==c ? :(localVCopy[$g,$pos] >>>= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] >>= v1__) && cc==c ? :(localVCopy[$g,$pos] >>= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] <<= v1__) && cc==c ? :(localVCopy[$g,$pos] <<= $(v1...)) : x, code)
            end
        end
    end

    for (i,v) in enumerate(abm.declaredSymbols["Identity"])

        bs = :identityV

        code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($bs[ic1_,$i]) : x, code)
        v2 = Meta.parse(string(v,"_i"))
        code = postwalk(x->@capture(x, vAux_) && vAux == v2 ? :($bs[ic1_,$i]) : x, code)
        v2 = Meta.parse(string(v,"_j"))
        code = postwalk(x->@capture(x, vAux_) && vAux == v2 ? :($bs[nnic2_,$i]) : x, code)

        if "Identity" in keys(p.update)
            if v in keys(p.update["Identity"])
                cc = findfirst(abm.declaredSymbols["Identity"].==v)
                pos = p.update["Identity"][v]
                #Code that may be optimized hopefully
                code = postwalk(x->@capture(x, identityV[g_,c_] = v1__) && cc==c ? :(identityVCopy[$g,$pos] = $(v1...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] += v1__) && cc==c ? :(identityVCopy[$g,$pos] += $(v1...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] -= v1__) && cc==c ? :(identityVCopy[$g,$pos] -= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] *= v1__) && cc==c ? :(identityVCopy[$g,$pos] *= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] /= v1__) && cc==c ? :(identityVCopy[$g,$pos] /= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] \= v1__) && cc==c ? :(identityVCopy[$g,$pos] \= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] ÷= v1__) && cc==c ? :(identityVCopy[$g,$pos] ÷= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] %= v1__) && cc==c ? :(identityVCopy[$g,$pos] %= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] ^= v1__) && cc==c ? :(identityVCopy[$g,$pos] ^= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] &= v1__) && cc==c ? :(identityVCopy[$g,$pos] &= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] |= v1__) && cc==c ? :(identityVCopy[$g,$pos] |= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] ⊻= v1__) && cc==c ? :(identityVCopy[$g,$pos] ⊻= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] >>>= v1__) && cc==c ? :(identityVCopy[$g,$pos] >>>= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] >>= v1__) && cc==c ? :(identityVCopy[$g,$pos] >>= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] <<= v1__) && cc==c ? :(identityVCopy[$g,$pos] <<= $(v1...)) : x, code)
            end
        end
    end
    
    for (i,v) in enumerate(abm.declaredSymbols["Global"])

        bs = :globalV

        code = postwalk(x->@capture(x, $v) ? :($bs[$i]) : x, code)

        if "Global" in keys(p.update)
            if v in keys(p.update["Global"])
                cc = findfirst(abm.declaredSymbols["Global"].==v)
                pos = p.update["Global"][v]
                #Code that may be optimized hopefully
                code = postwalk(x->@capture(x, globalV[c_] = v1__) && cc==c ? :(globalVCopy[$pos] = $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] += v1__) && cc==c ? :(globalVCopy[$pos] += $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] -= v1__) && cc==c ? :(globalVCopy[$pos] -= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] *= v1__) && cc==c ? :(globalVCopy[$pos] *= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] /= v1__) && cc==c ? :(globalVCopy[$pos] /= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] \= v1__) && cc==c ? :(globalVCopy[$pos] \= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] ÷= v1__) && cc==c ? :(globalVCopy[$pos] ÷= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] %= v1__) && cc==c ? :(globalVCopy[$pos] %= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] ^= v1__) && cc==c ? :(globalVCopy[$pos] ^= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] &= v1__) && cc==c ? :(globalVCopy[$pos] &= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] |= v1__) && cc==c ? :(globalVCopy[$pos] |= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] ⊻= v1__) && cc==c ? :(globalVCopy[$pos] ⊻= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] >>>= v1__) && cc==c ? :(globalVCopy[$pos] >>>= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] >>= v1__) && cc==c ? :(globalVCopy[$pos] >>= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] <<= v1__) && cc==c ? :(globalVCopy[$pos] <<= $(v1...)) : x, code)
            end
        end
    end

    for (i,v) in enumerate(abm.declaredSymbols["GlobalArray"])

        if "GlobalArray" in keys(p.update)
            if v in keys(p.update["GlobalArray"])
                name = Meta.parse(string(v,GLOBALARRAYCOPY))
                code = postwalk(x->@capture(x, cc_[c__] = v1__) && cc==v ? :($name[$(c...)] = $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] += v1__) && cc==v ? :($name[$(c...)] += $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] -= v1__) && cc==v ? :($name[$(c...)] -= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] *= v1__) && cc==v ? :($name[$(c...)] *= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] /= v1__) && cc==v ? :($name[$(c...)] /= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] \= v1__) && cc==v ? :($name[$(c...)] \= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] ÷= v1__) && cc==v ? :($name[$(c...)] ÷= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] %= v1__) && cc==v ? :($name[$(c...)] %= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] ^= v1__) && cc==v ? :($name[$(c...)] ^= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] &= v1__) && cc==v ? :($name[$(c...)] &= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] |= v1__) && cc==v ? :($name[$(c...)] |= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] ⊻= v1__) && cc==v ? :($name[$(c...)] ⊻= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] >>>= v1__) && cc==v ? :($name[$(c...)] >>>= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] >>= v1__) && cc==v ? :($name[$(c...)] >>= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] <<= v1__) && cc==v ? :($name[$(c...)] <<= $(v1...)) : x, code)
            end
        end
    end

    for (i,v) in enumerate(abm.declaredSymbols["Medium"])

        bs = :mediumV

        if abm.dims == 1
            code = postwalk(x->@capture(x, $v) ? :($bs[idMediumV[ic1_,1],$i]) : x, code)
        elseif abm.dims == 2
            code = postwalk(x->@capture(x, $v) ? :($bs[idMediumV[ic1_,1],idMediumV[ic1_,2],$i]) : x, code)
        elseif abm.dims == 3
            code = postwalk(x->@capture(x, $v) ? :($bs[idMediumV[ic1_,1],idMediumV[ic1_,2],idMediumV[ic1_,3],$i]) : x, code)
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

        code = postwalk(x->@capture(x, $v) ? :($bs[$i]) : x, code)

        if "Global" in keys(p.update)
            if v in keys(p.update["Global"])
                cc = findfirst(abm.declaredSymbols["Global"].==v)
                pos = p.update["Global"][v]
                #Code that may be optimized hopefully
                code = postwalk(x->@capture(x, globalV[c_] = v1__) && cc==c ? :(globalVCopy[$pos] = $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] += v1__) && cc==c ? :(globalVCopy[$pos] += $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] -= v1__) && cc==c ? :(globalVCopy[$pos] -= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] *= v1__) && cc==c ? :(globalVCopy[$pos] *= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] /= v1__) && cc==c ? :(globalVCopy[$pos] /= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] \= v1__) && cc==c ? :(globalVCopy[$pos] \= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] ÷= v1__) && cc==c ? :(globalVCopy[$pos] ÷= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] %= v1__) && cc==c ? :(globalVCopy[$pos] %= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] ^= v1__) && cc==c ? :(globalVCopy[$pos] ^= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] &= v1__) && cc==c ? :(globalVCopy[$pos] &= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] |= v1__) && cc==c ? :(globalVCopy[$pos] |= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] ⊻= v1__) && cc==c ? :(globalVCopy[$pos] ⊻= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] >>>= v1__) && cc==c ? :(globalVCopy[$pos] >>>= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] >>= v1__) && cc==c ? :(globalVCopy[$pos] >>= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] <<= v1__) && cc==c ? :(globalVCopy[$pos] <<= $(v1...)) : x, code)
            end
        end
    end

    for (i,v) in enumerate(abm.declaredSymbols["GlobalArray"])

        if "GlobalArray" in keys(p.update)
            if v in keys(p.update["GlobalArray"])
                name = Meta.parse(string(v,GLOBALARRAYCOPY))
                code = postwalk(x->@capture(x, cc_[c__] = v1__) && cc==v ? :($name[$(c...)] = $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] += v1__) && cc==v ? :($name[$(c...)] += $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] -= v1__) && cc==v ? :($name[$(c...)] -= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] *= v1__) && cc==v ? :($name[$(c...)] *= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] /= v1__) && cc==v ? :($name[$(c...)] /= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] \= v1__) && cc==v ? :($name[$(c...)] \= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] ÷= v1__) && cc==v ? :($name[$(c...)] ÷= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] %= v1__) && cc==v ? :($name[$(c...)] %= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] ^= v1__) && cc==v ? :($name[$(c...)] ^= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] &= v1__) && cc==v ? :($name[$(c...)] &= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] |= v1__) && cc==v ? :($name[$(c...)] |= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] ⊻= v1__) && cc==v ? :($name[$(c...)] ⊻= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] >>>= v1__) && cc==v ? :($name[$(c...)] >>>= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] >>= v1__) && cc==v ? :($name[$(c...)] >>= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, cc_[c__] <<= v1__) && cc==v ? :($name[$(c...)] <<= $(v1...)) : x, code)
            end
        end
    end

    for (i,v) in enumerate(abm.declaredSymbols["Medium"])

        bs = :mediumV

        if abm.dims == 1
            code = postwalk(x->@capture(x, $v) ? :($bs[ic1_,$i]) : x, code)
        elseif abm.dims == 2
            code = postwalk(x->@capture(x, $v) ? :($bs[ic1_,ic2_,$i]) : x, code)
        elseif abm.dims == 3
            code = postwalk(x->@capture(x, $v) ? :($bs[ic1_,ic2_,ic3_,$i]) : x, code)
        end

        if "Medium" in keys(p.update)
            if v in keys(p.update["Medium"])
                cc = findfirst(abm.declaredSymbols["Medium"].==v)
                pos = p.update["Medium"][v]
                #Code that may be optimized hopefully
                code = postwalk(x->@capture(x, mediumV[g__,c_] = v1__) && cc==c ? :(mediumVCopy[$(g...),$pos] = $(v1...)) : x, code)
                code = postwalk(x->@capture(x, mediumV[g__,c_] += v1__) && cc==c ? :(mediumVCopy[$(g...),$pos] += $(v1...)) : x, code)
                code = postwalk(x->@capture(x, mediumV[g__,c_] -= v1__) && cc==c ? :(mediumVCopy[$(g...),$pos] -= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, mediumV[g__,c_] *= v1__) && cc==c ? :(mediumVCopy[$(g...),$pos] *= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, mediumV[g__,c_] /= v1__) && cc==c ? :(mediumVCopy[$(g...),$pos] /= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, mediumV[g__,c_] \= v1__) && cc==c ? :(mediumVCopy[$(g...),$pos] \= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, mediumV[g__,c_] ÷= v1__) && cc==c ? :(mediumVCopy[$(g...),$pos] ÷= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, mediumV[g__,c_] %= v1__) && cc==c ? :(mediumVCopy[$(g...),$pos] %= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, mediumV[g__,c_] ^= v1__) && cc==c ? :(mediumVCopy[$(g...),$pos] ^= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, mediumV[g__,c_] &= v1__) && cc==c ? :(mediumVCopy[$(g...),$pos] &= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, mediumV[g__,c_] |= v1__) && cc==c ? :(mediumVCopy[$(g...),$pos] |= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, mediumV[g__,c_] ⊻= v1__) && cc==c ? :(mediumVCopy[$(g...),$pos] ⊻= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, mediumV[g__,c_] >>>= v1__) && cc==c ? :(mediumVCopy[$(g...),$pos] >>>= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, mediumV[g__,c_] >>= v1__) && cc==c ? :(mediumVCopy[$(g...),$pos] >>= $(v1...)) : x, code)
                code = postwalk(x->@capture(x, mediumV[g__,c_] <<= v1__) && cc==c ? :(mediumVCopy[$(g...),$pos] <<= $(v1...)) : x, code)
            end
        end
    end

    return code

end
