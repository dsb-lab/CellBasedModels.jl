function vectorize(code,agent)

    for (sym,prop) in pairs(agent.declaredSymbols)

        symNew = Meta.parse(string(sym,"New_"))
        if :Local in prop
            code = postwalk(x->@capture(x,g_.i.new) && g == sym ? :($symNew[i1_]) : x, code)
            code = postwalk(x->@capture(x,g_.j.new) && g == sym ? :($symNew[i2_]) : x, code)
            code = postwalk(x->@capture(x,g_.i) && g == sym ? :($sym[i1_]) : x, code)
            code = postwalk(x->@capture(x,g_.j) && g == sym ? :($sym[i2_]) : x, code)
        elseif :Global in prop
            code = postwalk(x->@capture(x,g_.i) && g == sym ? :($symNew[1]) : x, code)
            code = postwalk(x->@capture(x,g_.j) && g == sym ? :($sym[1]) : x, code)
        elseif :Medium in prop
            args = [:gridPosx_,:gridPosy_,:gridPosz_][1:agent.dims]
            code = postwalk(x->@capture(x,g_.j) && g == sym ? :($sym[$(args...)]) : x, code)
        elseif :SimulationBox in prop
            nothing
        elseif :Dims in prop
            nothing
        elseif :Neighbor in prop
            nothing
        elseif :NeighborLoop in prop
            nothing
        else
            error("Symbol $sym with type $(prop[3]) doesn't has not verctorization implemented.")
        end
    end

    return code
end