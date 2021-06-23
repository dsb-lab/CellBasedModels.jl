"""
    function vectorize_(abm::Agent,code::Expr)

Function to subtitute all the declared symbols of the agents in the expression into vector form.
optional arguments base and update add some intermediate names to the vectorized variables and to updated ones.
"""
function vectorize_(abm::Agent,code::Expr,p::Program_)
        
    #Vectorisation changes        
    for (i,v) in enumerate(abm.declaredSymbols["Local"])

        bs = :localV

        code = postwalk(x->@capture(x, $v) ? :($bs[ic1_,$i]) : x, code)
        v2 = Meta.parse(string(v,"₁"))
        code = postwalk(x->@capture(x, $v2) ? :($bs[ic1_,$i]) : x, code)
        v2 = Meta.parse(string(v,"₂"))
        code = postwalk(x->@capture(x, $v2) ? :($bs[nnic2_,$i]) : x, code)

        if "Local" in keys(p.update)
            if v in keys(p.update["Local"])
                pos = p.update["Local"][v]
                #Code that may be optimized hopefully
                code = postwalk(x->@capture(x, localV[g_,c_] = v__) ? :(localVCopy[$g,$pos] = $(v...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] += v__) ? :(localVCopy[$g,$pos] += $(v...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] -= v__) ? :(localVCopy[$g,$pos] -= $(v...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] *= v__) ? :(localVCopy[$g,$pos] *= $(v...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] /= v__) ? :(localVCopy[$g,$pos] /= $(v...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] \= v__) ? :(localVCopy[$g,$pos] \= $(v...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] ÷= v__) ? :(localVCopy[$g,$pos] ÷= $(v...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] %= v__) ? :(localVCopy[$g,$pos] %= $(v...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] ^= v__) ? :(localVCopy[$g,$pos] ^= $(v...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] &= v__) ? :(localVCopy[$g,$pos] &= $(v...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] |= v__) ? :(localVCopy[$g,$pos] |= $(v...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] ⊻= v__) ? :(localVCopy[$g,$pos] ⊻= $(v...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] >>>= v__) ? :(localVCopy[$g,$pos] >>>= $(v...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] >>= v__) ? :(localVCopy[$g,$pos] >>= $(v...)) : x, code)
                code = postwalk(x->@capture(x, localV[g_,c_] <<= v__) ? :(localVCopy[$g,$pos] <<= $(v...)) : x, code)
            end
        end
    end

    for (i,v) in enumerate(abm.declaredSymbols["Identity"])

        bs = :identityV

        code = postwalk(x->@capture(x, $v) ? :($bs[ic1_,$i]) : x, code)
        v2 = Meta.parse(string(v,"₁"))
        code = postwalk(x->@capture(x, $v2) ? :($bs[ic1_,$i]) : x, code)
        v2 = Meta.parse(string(v,"₂"))
        code = postwalk(x->@capture(x, $v2) ? :($bs[nnic2_,$i]) : x, code)

        if "Identity" in keys(p.update)
            if v in keys(p.update["Identity"])
                pos = p.update["Identity"][v]
                #Code that may be optimized hopefully
                code = postwalk(x->@capture(x, identityV[g_,c_] = v__) ? :(identityVCopy[$g,$pos] = $(v...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] += v__) ? :(identityVCopy[$g,$pos] += $(v...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] -= v__) ? :(identityVCopy[$g,$pos] -= $(v...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] *= v__) ? :(identityVCopy[$g,$pos] *= $(v...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] /= v__) ? :(identityVCopy[$g,$pos] /= $(v...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] \= v__) ? :(identityVCopy[$g,$pos] \= $(v...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] ÷= v__) ? :(identityVCopy[$g,$pos] ÷= $(v...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] %= v__) ? :(identityVCopy[$g,$pos] %= $(v...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] ^= v__) ? :(identityVCopy[$g,$pos] ^= $(v...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] &= v__) ? :(identityVCopy[$g,$pos] &= $(v...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] |= v__) ? :(identityVCopy[$g,$pos] |= $(v...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] ⊻= v__) ? :(identityVCopy[$g,$pos] ⊻= $(v...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] >>>= v__) ? :(identityVCopy[$g,$pos] >>>= $(v...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] >>= v__) ? :(identityVCopy[$g,$pos] >>= $(v...)) : x, code)
                code = postwalk(x->@capture(x, identityV[g_,c_] <<= v__) ? :(identityVCopy[$g,$pos] <<= $(v...)) : x, code)
            end
        end
    end
    
    for (i,v) in enumerate(abm.declaredSymbols["Global"])

        bs = :globalV

        code = postwalk(x->@capture(x, $v) ? :($bs[$i]) : x, code)

        if "Global" in keys(p.update)
            if v in keys(p.update["Global"])
                pos = p.update["Global"][v]
                #Code that may be optimized hopefully
                code = postwalk(x->@capture(x, globalV[c_] = v__) ? :(globalVCopy[$pos] = $(v...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] += v__) ? :(globalVCopy[$pos] += $(v...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] -= v__) ? :(globalVCopy[$pos] -= $(v...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] *= v__) ? :(globalVCopy[$pos] *= $(v...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] /= v__) ? :(globalVCopy[$pos] /= $(v...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] \= v__) ? :(globalVCopy[$pos] \= $(v...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] ÷= v__) ? :(globalVCopy[$pos] ÷= $(v...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] %= v__) ? :(globalVCopy[$pos] %= $(v...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] ^= v__) ? :(globalVCopy[$pos] ^= $(v...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] &= v__) ? :(globalVCopy[$pos] &= $(v...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] |= v__) ? :(globalVCopy[$pos] |= $(v...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] ⊻= v__) ? :(globalVCopy[$pos] ⊻= $(v...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] >>>= v__) ? :(globalVCopy[$pos] >>>= $(v...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] >>= v__) ? :(globalVCopy[$pos] >>= $(v...)) : x, code)
                code = postwalk(x->@capture(x, globalV[c_] <<= v__) ? :(globalVCopy[$pos] <<= $(v...)) : x, code)
            end
        end
    end

    for (i,v) in enumerate(abm.declaredSymbols["GlobalArray"])

        if "GlobalArray" in keys(p.update)
            if v in keys(p.update["GlobalArray"])
                name = Meta.parse(string(v,"Copy"))
                code = postwalk(x->@capture(x, $v[c__] = v__) ? :($name[$(c...)] = $(v...)) : x, code)
                code = postwalk(x->@capture(x, $v[c__] += v__) ? :($name[$(c...)] += $(v...)) : x, code)
                code = postwalk(x->@capture(x, $v[c__] -= v__) ? :($name[$(c...)] -= $(v...)) : x, code)
                code = postwalk(x->@capture(x, $v[c__] *= v__) ? :($name[$(c...)] *= $(v...)) : x, code)
                code = postwalk(x->@capture(x, $v[c__] /= v__) ? :($name[$(c...)] /= $(v...)) : x, code)
                code = postwalk(x->@capture(x, $v[c__] \= v__) ? :($name[$(c...)] \= $(v...)) : x, code)
                code = postwalk(x->@capture(x, $v[c__] ÷= v__) ? :($name[$(c...)] ÷= $(v...)) : x, code)
                code = postwalk(x->@capture(x, $v[c__] %= v__) ? :($name[$(c...)] %= $(v...)) : x, code)
                code = postwalk(x->@capture(x, $v[c__] ^= v__) ? :($name[$(c...)] ^= $(v...)) : x, code)
                code = postwalk(x->@capture(x, $v[c__] &= v__) ? :($name[$(c...)] &= $(v...)) : x, code)
                code = postwalk(x->@capture(x, $v[c__] |= v__) ? :($name[$(c...)] |= $(v...)) : x, code)
                code = postwalk(x->@capture(x, $v[c__] ⊻= v__) ? :($name[$(c...)] ⊻= $(v...)) : x, code)
                code = postwalk(x->@capture(x, $v[c__] >>>= v__) ? :($name[$(c...)] >>>= $(v...)) : x, code)
                code = postwalk(x->@capture(x, $v[c__] >>= v__) ? :($name[$(c...)] >>= $(v...)) : x, code)
                code = postwalk(x->@capture(x, $v[c__] <<= v__) ? :($name[$(c...)] <<= $(v...)) : x, code)
            end
        end
    end

    return code
end