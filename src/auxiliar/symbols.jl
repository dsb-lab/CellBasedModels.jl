"""
    function symbols_(exp::Expr,l=Symbol[])

Finds all parameters that has been used in a piece of code.
"""
function symbols_(exp::Expr,updated=Symbol[],assigned=Symbol[],ref=Symbol[],symbol =Symbol[])
    for (pos,a) in enumerate(exp.args)
        if exp.head in [:(+=),:(-=),:(%=),:(/=)] && pos == 1
            if typeof(a) == Symbol
                push!(updated,a)
                push!(symbol,a)
            elseif typeof(a) == Expr && a.head == :ref
                push!(updated,a.args[1])
                push!(ref,a.args[1])
                push!(symbol,a.args[1])
            end
        elseif exp.head in [:(=)] && pos == 1
            if typeof(a) == Symbol
                push!(assigned,a)
                push!(symbol,a)
            elseif typeof(a) == Expr && a.head == :ref
                push!(assigned,a.args[1])
                push!(ref,a.args[1])
                push!(symbol,a.args[1])
            end
        elseif typeof(a) == Expr && a.head == :ref
            push!(ref,a.args[1])
            push!(symbol,a.args[1])
        elseif typeof(a) == Symbol
            push!(symbol,a.args[1])
        elseif typeof(a) == Expr
            updatedParameters_(a,updated,assigned,ref,symbol)
        end
    end

    return updated,assigned,ref,symbol
end

"""
    function vectorize_(abm::Agent,code::Expr)

Function to subtitute all the declared symbols of the agents in the expression into vector form.
optional arguments base and update add some intermediate names to the vectorized variables and to updated ones.
"""
function validSymbolsAgent_(abm::Agent)

    use =  Symbol[]
    declaration = Symbol[]
                                            
    #Vectorisation changes
    for (i,v) in enumerate(abm.declaredSymbols["Variable"])

        push!(use["Variable"],v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))
        push!(declaration["Variable"],v,Meta.parse(string(v,"₁")))
        push!(allSymbols,v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))

    end
        
    for (i,v) in enumerate(abm.declaredSymbols["Local"])

        push!(use["Local"],v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))
        push!(declaration["Local"],v,Meta.parse(string(v,"₁")))
        push!(allSymbols,v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))

    end
    
    for (i,v) in enumerate(abm.declaredSymbols["Interaction"])

        push!(use["Interaction"],v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))
        push!(declaration["Interaction"],v,Meta.parse(string(v,"₁")))
        push!(allSymbols,v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))

    end

    for (i,v) in enumerate(abm.declaredSymbols["Global"])

        push!(use["Global"],v)
        push!(declaration["Global"],v)
        push!(allSymbols,v)

    end

    for (i,v) in enumerate(abm.declaredSymbols["GlobalArray"])

        push!(use["GlobalArray"],v)
        push!(declaration["GlobalArray"],v)
        push!(allSymbols,v)

    end

    for (i,v) in enumerate(abm.declaredSymbols["Identity"])

        push!(use["Identity"],v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))
        push!(declaration["Identity"],v,Meta.parse(string(v,"₁")))
        push!(allSymbols,v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))

    end

    return code
end