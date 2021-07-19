function substitution(code::Union{Expr,Symbol},p::Program_;op=nothing,arg=false,pre=nothing,post=nothing,sym=nothing, #Type of symbol between operator, pre/post script and arguments
    nargs = nothing, addArgs = nothing,                       #Args for the functions that depend on arguments
    only=["Local","Global","Identity","GlobalArray","Medium"],           #Subset of parameters to modify
    addName=nothing, expl=nothing,                            #Add something to the vectorized name of fully substitute by something
    ic=[:ic1_,:ic2_,:ic3_], index=nothing, factor=1,          #Change loop symbols and additional indexes
    dims=nothing,                                             #Operators modifying the behaviour of cells
    opF = nothing                                             #Form of the new index
    )

    if dims === nothing
        dims = p.agent.dims
    end

    if op !== nothing

        if nargs === nothing
            code = postwalk(x->@capture(x, opAux_(argAux_)) && opAux == op ? 
                substitution(argAux, p;arg = true, nargs=nargs, only=only, addName=addName, expl=expl, ic=ic, index=index, factor=factor, dims=dims, opF=opF)
            : x, code)
        else
            code = postwalk(x->@capture(x, opAux_(argAux__)) && opAux == op ? 
            if length(argAux) != nargs
                error("Operator ", op, " should be declared with just ", nargs, " arguments. ", length(argAux), " where passed.")
            else
                if opF !== nothing
                    opAux = opF
                end
                if addArgs !== nothing
                    :($opAux($(argAux...),$(addArgs...)))
                else
                    :($opAux($(argAux...)))
                end
            end
            : x, code)
        end

    elseif arg

        add = substitution(code, p, only=only, addName=addName, expl=expl, ic=ic, index=index[1], dims=dims)
        if factor[1] != 1
            add = :($(factor[i])*$add)
        end
        for i in 2:length(index)
            add2 = substitution(code, p, only=only, addName=addName, expl=expl, ic=ic, index=index[i], dims=dims)
            if factor[i] != 1
                add = :($add+$(factor[i])*$add2)
            else
                add = :($add+$add2)
            end
        end

        if opF !== nothing
            code = postwalk(x->@capture(x, vAux_) && vAux == :X ? add : x, opF)
        else
            code = add
        end

    else

        if "Local" in only
            for (i,v) in enumerate(p.agent.declaredSymbols["Local"])

                if pre !== nothing
                    v = Meta.parse(string(pre,v))
                elseif post !== nothing
                    v = Meta.parse(string(v,post))
                end

                if expl !== nothing
                    name = expl
                elseif addName !== nothing
                    name = Meta.parse(string(:localV,addName))
                else
                    name = :localV
                end

                if index !== nothing
                    if index[1] != 0
                        ic_ = :($(ic[1])+$(index[1])) 
                    else
                        ic_ = :($(ic[1]))
                    end
                else
                    ic_ = ic[1]
                end

                if opF !== nothing
                    subs = postwalk(x->@capture(x, vAux_) && vAux == X ? :($name[$ic_,$i]) : x, opF)
                else
                    subs = :($name[$ic_,$i])
                end

                code = postwalk(x->@capture(x, vAux_) && vAux == v ? subs : x, code)

            end
        end

        if "Identity" in only
            for (i,v) in enumerate(p.agent.declaredSymbols["Identity"])

                if pre !== nothing
                    v = Meta.parse(string(pre,v))
                elseif post !== nothing
                    v = Meta.parse(string(v,post))
                end

                if expl !== nothing
                    name = expl
                elseif addName !== nothing
                    name = Meta.parse(string(:identityV,addName))
                else
                    name = :identityV
                end

                if index !== nothing
                    if index[1] != 0
                        ic_ = :($(ic[1])+$(index[1])) 
                    else
                        ic_ = :($(ic[1]))
                    end
                else
                    ic_ = ic[1]
                end

                if opF !== nothing
                    subs = postwalk(x->@capture(x, vAux_) && vAux == X ? :($name[$ic_,$i]) : x, opF)
                else
                    subs = :($name[$ic_,$i])
                end

                code = postwalk(x->@capture(x, vAux_) && vAux == v ? subs : x, code)
            end
        end
        
        if "Global" in only
            for (i,v) in enumerate(p.agent.declaredSymbols["Global"])

                if pre !== nothing
                    v = Meta.parse(string(pre,v))
                elseif post !== nothing
                    v = Meta.parse(string(v,post))
                end

                if expl !== nothing
                    name = expl
                elseif addName !== nothing
                    name = Meta.parse(string(:globalV,addName))
                else
                    name = :globalV
                end

                if opF !== nothing
                    subs = postwalk(x->@capture(x, vAux_) && vAux == X ? :($name[$i]) : x, opF)
                else
                    subs = :($name[$i])
                end

                code = postwalk(x->@capture(x, vAux_) && vAux == v ? subs : x, code)
            end
        end

        if "GlobalArray" in only
            for (i,v) in enumerate(p.agent.declaredSymbols["GlobalArray"])

                if pre !== nothing
                    v2 = Meta.parse(string(pre,v))
                elseif post !== nothing
                    v2 = Meta.parse(string(v,post))
                else
                    v2 = v
                end

                if expl !== nothing
                    name = expl
                elseif addName !== nothing
                    name = Meta.parse(string(v,addName))
                else
                    name = v
                end

                code = postwalk(x->@capture(x, vAux_) && vAux == v2 ? name : x, code)
            end
        end

        if "Medium" in only
            for (i,v) in enumerate(p.agent.declaredSymbols["Medium"])

                if pre !== nothing
                    v = Meta.parse(string(pre,v))
                elseif post !== nothing
                    v = Meta.parse(string(v,post))
                end

                if expl !== nothing
                    name = expl
                elseif addName !== nothing
                    name = Meta.parse(string(:mediumV,addName))
                else
                    name = :mediumV
                end

                if index !== nothing
                    if index[1] != 0
                        ic1_ = :($(ic[1])+$(index[1])) 
                    else
                        ic1_ = :($(ic[1]))
                    end
                    if index[2] != 0
                        ic2_ = :($(ic[2])+$(index[2])) 
                    else
                        ic2_ = :($(ic[2]))
                    end
                    if index[3] != 0
                        ic3_ = :($(ic[3])+$(index[3])) 
                    else
                        ic3_ = :($(ic[3]))
                    end
                else
                    ic1_ = ic[1]
                    ic2_ = ic[2]
                    ic3_ = ic[3]
                end

                if opF !== nothing
                    if dims == 1
                        subs = postwalk(x->@capture(x, vAux_) && vAux == X ? :($name[$ic1_,$i]) : x, opF)
                    elseif dims == 2
                        subs = postwalk(x->@capture(x, vAux_) && vAux == X ? :($name[$ic1_,$ic2_,$i]) : x, opF)
                    elseif dims == 3
                        subs = postwalk(x->@capture(x, vAux_) && vAux == X ? :($name[$ic1_,$ic2_,$ic3_,$i]) : x, opF)
                    end
                else
                    if dims == 1
                        subs = :($name[$ic1_,$i])
                    elseif dims == 2
                        subs = :($name[$ic1_,$ic2_,$i])
                    elseif dims == 3
                        subs = :($name[$ic1_,$ic2_,$ic3_,$i])
                    end
                end

                code = postwalk(x->@capture(x, vAux_)  && vAux == v  ? subs : x, code)

            end
        end

    end

    return code
end
