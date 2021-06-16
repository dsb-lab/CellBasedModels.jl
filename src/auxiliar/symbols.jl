"""
    function symbols_(abm,exp,l=Symbol[])

Finds all symbols that have been used in a piece of code and show how they have been employed in the model.
"""
function symbols_(abm::Agent,exp::Expr, 
                symb = DataFrame(Symbol = Symbol[], updated=Bool[], assigned=Bool[], referenced=Bool[], 
                                called=Bool[], placeDeclaration = Symbol[], type = Symbol[]), 
                called = false)

    for (pos,a) in enumerate(exp.args)
        if called
            aux = whereDeclared_(abm,a)
            push!(symb,(a,false,false,false,true,aux[1],aux[2]))
            called = false
        elseif exp.head in [:(+=),:(-=),:(%=),:(/=)] && pos == 1
            if typeof(a) == Symbol
                aux = whereDeclared_(abm,a)
                push!(symb,(a,true,false,false,false,aux[1],aux[2]))
            elseif typeof(a) == Expr && a.head == :ref
                aux = whereDeclared_(abm,a.args[1])
                push!(symb,(a.args[1],true,false,true,false,aux[1],aux[2]))
            end
        elseif exp.head in [:(=)] && pos == 1
            if typeof(a) == Symbol
                aux = whereDeclared_(abm,a)
                push!(symb,(a,false,true,false,false,aux[1],aux[2]))
            elseif typeof(a) == Expr && a.head == :ref
                aux = whereDeclared_(abm,a.args[1])
                push!(symb,(a.args[1],false,true,true,false,aux[1],aux[2]))
            end
        elseif typeof(a) == Expr && a.head == :ref
            aux = whereDeclared_(abm,a.args[1])
            push!(symb,(a.args[1],false,false,true,false,aux[1],aux[2]))
        elseif typeof(a) == Expr && a.head == :call
            symbols_(abm,a,symb,true)
        elseif typeof(a) == Symbol
            aux = whereDeclared_(abm,a)
            push!(symb,(a,false,false,false,false,aux[1],aux[2]))
        elseif typeof(a) == Expr
            symbols_(abm,a,symb)
        end
    end

    return symb
end

# """
#     function vectorize_(abm::Agent,code::Expr)

# Function to subtitute all the declared symbols of the agents in the expression into vector form.
# optional arguments base and update add some intermediate names to the vectorized variables and to updated ones.
# """
# function validSymbolsAgent_(abm::Agent)

#     use =  Symbol[]
#     declaration = Symbol[]
                                            
#     #Vectorisation changes
#     for (i,v) in enumerate(abm.declaredSymbols["Variable"])

#         push!(use["Variable"],v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))
#         push!(declaration["Variable"],v,Meta.parse(string(v,"₁")))
#         push!(allSymbols,v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))

#     end
        
#     for (i,v) in enumerate(abm.declaredSymbols["Local"])

#         push!(use["Local"],v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))
#         push!(declaration["Local"],v,Meta.parse(string(v,"₁")))
#         push!(allSymbols,v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))

#     end
    
#     for (i,v) in enumerate(abm.declaredSymbols["Interaction"])

#         push!(use["Interaction"],v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))
#         push!(declaration["Interaction"],v,Meta.parse(string(v,"₁")))
#         push!(allSymbols,v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))

#     end

#     for (i,v) in enumerate(abm.declaredSymbols["Global"])

#         push!(use["Global"],v)
#         push!(declaration["Global"],v)
#         push!(allSymbols,v)

#     end

#     for (i,v) in enumerate(abm.declaredSymbols["GlobalArray"])

#         push!(use["GlobalArray"],v)
#         push!(declaration["GlobalArray"],v)
#         push!(allSymbols,v)

#     end

#     for (i,v) in enumerate(abm.declaredSymbols["Identity"])

#         push!(use["Identity"],v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))
#         push!(declaration["Identity"],v,Meta.parse(string(v,"₁")))
#         push!(allSymbols,v,Meta.parse(string(v,"₁")),Meta.parse(string(v,"₂")))

#     end

#     return code
# end