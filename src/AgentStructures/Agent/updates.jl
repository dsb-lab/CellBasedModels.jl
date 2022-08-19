"""
    function addUpdates!(p)

Function that checks the variables in the model that are modified at each step in order to make appropiate copy vectors and add them to `AgentCompiled`.

# Args
 - **p::Agent**: AgentCompiled structure containing all the created code when compiling.

# Returns
 - Nothing
"""
function addUpdates!(p::Agent)

    ##Assign updates of variable types
    for par in eachrow(p.declaredSymbols)

        #Find updates
        for up in keys(p.declaredUpdates)

            code =  postwalk(x->@capture(x, c_.new)  && c == par.name ? :ARGS_ : x , p.declaredUpdates[up]) #remove agent updates
            code =  postwalk(x->@capture(x, c_.g_.new) && c == par.name && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            
            if inexpr(code,:ARGS_) && !(par.name in p.declaredSymbolsUpdated.name)
                push!(p.declaredSymbolsUpdated,[par.name,par.type,:New])
            end

        end

        #Find variables
        for up in keys(p.declaredUpdates)

            code =  postwalk(x->@capture(x, g_(c_) = f_) && c == par.name && g == DIFFSYMBOL ? :ARGS_ : x , p.declaredUpdates[up])
            
            if inexpr(code,:ARGS_) && !(par.name in p.declaredSymbolsUpdated.name) #if not found add
                push!(p.declaredSymbolsUpdated,[par.name,par.type,:Variable])
            elseif  inexpr(code,:ARGS_) && par.name in p.declaredSymbolsUpdated.name #if found as New, change to variable
                p.declaredSymbolsUpdated[p.declaredSymbolsUpdated.name .== par.name,:use] .= :Variable
            end

        end

    end        
    
    return
end