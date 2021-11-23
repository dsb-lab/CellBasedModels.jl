"""
    function addCleanInteraction_!(p::Program_,platform::String)

Generate the functions related with Cleaning Interaction Updates.
"""
function addCleanInteraction_!(p::Program_,platform::String)

    if "UpdateLocalInteraction" in keys(p.agent.declaredUpdates) || "UpdateInteraction" in keys(p.agent.declaredUpdates)

        #Construct cleanup function
        s = []
        for i in ["UpdateInteraction"]
            if i in keys(p.agent.declaredUpdates)
                syms = symbols_(p.agent,p.agent.declaredUpdates[i])
                syms = syms[Bool.((syms[:,"placeDeclaration"] .== :Model) .* syms[:,"updated"]),"Symbol"]
                append!(s,syms)
            end
        end
        unique!(s)
        up = quote end
        for i in s
            pos = findfirst(p.agent.declaredSymbols["Local"] .== i)
            push!(up.args,:(localV[ic1_,$pos]=0))
        end
        fclean = simpleFirstLoopWrapInFunction_(platform,:cleanInteraction_!,up)
        push!(p.declareF.args,fclean)
    end

    return nothing
end