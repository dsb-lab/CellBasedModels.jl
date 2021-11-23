"""
    function agentArguments_(abm::Agent)

Returns the list of vectors arguments to be declared in the model function arguments.
"""
function agentArguments_(abm::Agent)
    l = [:t,:N]

    #Floats
    if length(abm.declaredSymbols["Local"])>0
        push!(l,:loc_)
    end
    if length(abm.declaredSymbols["Identity"])>0
        push!(l,:id_)
    end
    if length(abm.declaredSymbols["Global"])>0
        push!(l,:glob_)
    end
    if length(abm.declaredSymbols["GlobalArray"])>0
        for i in abm.declaredSymbols["GlobalArray"]
            push!(l,i)
        end
    end
    if length(abm.declaredSymbols["Medium"])>0
        push!(l,:mediumN)
    end

    return l
end