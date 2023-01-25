function vectorize(code,agent)

    #For user declared symbols
    for (sym,prop) in pairs(agent.declaredSymbols)

        bs = prop.basePar
        bsn = baseParameterNew(bs)
        pos = prop.position
        if :Local == prop.scope
            code = postwalk(x->@capture(x,g_.p1_.p2_) && g == sym && p1 == BASESYMBOLS[:UpdateSymbol].symbol && p2 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bsn[i1_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_.p1_.p2_) && g == sym && p1 == BASESYMBOLS[:UpdateSymbol].symbol && p2 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bsn[i2_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_.p1_.p2_) && g == sym && p2 == BASESYMBOLS[:UpdateSymbol].symbol && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bsn[i1_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_.p1_.p2_) && g == sym && p2 == BASESYMBOLS[:UpdateSymbol].symbol && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bsn[i2_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_.p1_) && g == sym && p1 == BASESYMBOLS[:UpdateSymbol].symbol ? :($bsn[i1_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_) && g == sym ? :($bs[i1_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_[p1_][p2_]) && g == sym ? :($bs[$p2,$pos]) : x, code) #Undo if it was already vectorized
            code = postwalk(x->@capture(x,g_.p1_) && g == sym && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bs[i1_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_.p1_) && g == sym && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bs[i2_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_[h__].p1_) && g == sym && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bs[i1_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_[h__].p1_) && g == sym && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bs[i2_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_[h__].p1_) && g == bs && p1 == BASESYMBOLS[:AddCell].symbol ? :($bsn[i1New_,$pos]) : x, code)
        elseif :Global == prop.scope
            code = postwalk(x->@capture(x,g_.p1_) && g == sym && p1 == BASESYMBOLS[:UpdateSymbol].symbol ? :($bsn[$pos]) : x, code)
            code = postwalk(x->@capture(x,g_) && g == sym ? :($bs[$pos]) : x, code)
        elseif :Medium == prop.scope
            args = [:gridPosx_,:gridPosy_,:gridPosz_][1:agent.dims]
            code = postwalk(x->@capture(x,g_.j) && g == sym ? :($bs[$(args...)]) : x, code)
        elseif :Atomic == prop.scope
            nothing
        else
            error("Symbol $bs with type $(prop[2]) doesn't has not vectorization implemented.")
        end

    end

    #For local parameters
    for bs in [sym for (sym,prop) in pairs(BASEPARAMETERS) if :Local == prop.shape[1]]

        bsn = baseParameterNew(bs)
        code = postwalk(x->@capture(x,g_.p1_.p2_) && g == bs && p1 == BASESYMBOLS[:UpdateSymbol].symbol && p2 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bsn[i1_]) : x, code)
        code = postwalk(x->@capture(x,g_.p1_.p2_) && g == bs && p1 == BASESYMBOLS[:UpdateSymbol].symbol && p2 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bsn[i2_]) : x, code)
        code = postwalk(x->@capture(x,g_.p1_.p2_) && g == bs && p2 == BASESYMBOLS[:UpdateSymbol].symbol && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bsn[i1_]) : x, code)
        code = postwalk(x->@capture(x,g_.p1_.p2_) && g == bs && p2 == BASESYMBOLS[:UpdateSymbol].symbol && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bsn[i2_]) : x, code)
        code = postwalk(x->@capture(x,g_.p1_) && g == bs && p1 == BASESYMBOLS[:UpdateSymbol].symbol ? :($bsn[i1_]) : x, code)
        code = postwalk(x->@capture(x,g_) && g == bs ? :($bs[i1_]) : x, code)
        code = postwalk(x->@capture(x,g_[p1_][p2__]) && g == bs ? :($bs[$(p2...)]) : x, code) #Undo if it was already vectorized
        code = postwalk(x->@capture(x,g_.p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bs[i1_]) : x, code)
        code = postwalk(x->@capture(x,g_.p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bs[i2_]) : x, code)
        code = postwalk(x->@capture(x,g_[h__].p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bs[i1_,$(h[2])]) : x, code)
        code = postwalk(x->@capture(x,g_[h__].p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bs[i2_,$(h[2])]) : x, code)
        code = postwalk(x->@capture(x,g_[h__].p1_) && g == bs && p1 == BASESYMBOLS[:AddCell].symbol ? :($bsn[i1New_]) : x, code)

    end

    #For global parameters
    for bs in [sym for (sym,prop) in pairs(BASEPARAMETERS) if :Global == prop.shape[1]]

        code = postwalk(x->@capture(x,g_) && g == bs ? :($bs[1]) : x, code)
        code = postwalk(x->@capture(x,g_[p1_][p2_]) && g == bs ? :($bs[1]) : x, code) #Undo if it was already vectorized

    end

    return code

end