function substitution(p::Program, code::Expr;op=nothing,pre=nothing,post=nothing,arg=nothing,sym=nothing, #Type of symbol between operator, pre/post script and arguments
    only=nothing,                                       #Subset of parameters to modify
    addName=nothing, expl=nothing,                      #Add something to the vectorized name of fully substitute by something
    ic=[:ic1_,:ic2_,:ic3_],                             #Change loop symbols
    dims=nothing, operator=nothing,                     #Operators modifying the behaviour of cells
    opF = nothing                                       #Form of the new operator
    )

    if dims === nothing
        dims = p.abm.dims
    end

    if pre !== nothing || post !== nothing

        for (i,v) in enumerate(p.abm.declaredSymbols["Local"])

            if pre !== nothing
                v = Meta.parse(string(pre,v))
            else post !== nothing
                v = Meta.parse(string(v,post))
            end

            if expl !== nothing
                name = expl
            elseif addName !== nothing
                name = Meta.parse(string(localV,addName))
            end

            if operator !== nothing
                ic_ = :($(ic[1])+$operator) 
            end

            code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($name[$ic_,$i]) : x, code)

        end

        for (i,v) in enumerate(p.abm.declaredSymbols["Identity"])

            if pre !== nothing
                v = Meta.parse(string(pre,v))
            else post !== nothing
                v = Meta.parse(string(v,post))
            end

            if expl !== nothing
                name = expl
            elseif addName !== nothing
                name = Meta.parse(string(identityV,addName))
            end

            if operator !== nothing
                ic_ = :($(ic[1])+$operator) 
            end

            code = postwalk(x->@capture(x, vAux_) && vAux == v ? :($name[$ic_,$i]) : x, code)
        end
        
        for (i,v) in enumerate(p.abm.declaredSymbols["Global"])

            if pre !== nothing
                v = Meta.parse(string(pre,v))
            else post !== nothing
                v = Meta.parse(string(v,post))
            end

            if expl !== nothing
                name = expl
            elseif addName !== nothing
                name = Meta.parse(string(globalV,addName))
            end

            code = postwalk(x->@capture(x, $vAux_) && vAux == v ? :($name[$i]) : x, code)
        end

        for (i,v) in enumerate(p.abm.declaredSymbols["GlobalArray"])

            if pre !== nothing
                v = Meta.parse(string(pre,v))
            else post !== nothing
                v = Meta.parse(string(v,post))
            end

            if expl !== nothing
                name = expl
            elseif addName !== nothing
                name = Meta.parse(string(v,addName))
            end

            code = postwalk(x->@capture(x, $vAux_) && vAux == v ? name : x, code)
        end

        for (i,v) in enumerate(p.abm.declaredSymbols["Medium"])

            if pre !== nothing
                v = Meta.parse(string(pre,v))
            else post !== nothing
                v = Meta.parse(string(v,post))
            end

            if expl !== nothing
                name = expl
            elseif addName !== nothing
                name = Meta.parse(string(mediumV,addName))
            end

            if operator !== nothing
                ic1_ = :($(ic[1])+$(operator[1])) 
                ic2_ = :($(ic[2])+$(operator[2])) 
                ic3_ = :($(ic[3])+$(operator[3])) 
            end

            if dims == 1
                code = postwalk(x->@capture(x, $vAux_)  && vAux == v  ? :($name[$ic1_,$i]) : x, code)
            elseif dims == 2
                code = postwalk(x->@capture(x, $vAux_) && vAux == v  ? :($name[$ic1_,$ic2_,$i]) : x, code)
            elseif dims == 3
                code = postwalk(x->@capture(x, $vAux_) && vAux == v  ? :($name[$ic1_,$ic2_,$ic3_,$i]) : x, code)
            end
        end

    end

end
