"""
    function addCleanInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with Cleaning Interaction Updates.
"""
function addCleanInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if "UpdateLocalInteraction" in keys(abm.declaredUpdates) || "UpdateInteraction" in keys(abm.declaredUpdates)

        #Construct cleanup function
        s = []
        for i in ["UpdateInteraction"]
            if i in keys(abm.declaredUpdates)
                syms = symbols_(abm,abm.declaredUpdates[i])
                syms = syms[Bool.((syms[:,"placeDeclaration"] .== :Model) .* syms[:,"updated"]),"Symbol"]
                append!(s,syms)
            end
        end
        unique!(s)
        up = quote end
        for i in s
            pos = findfirst(abm.declaredSymbols["Local"] .== i)
            push!(up.args,:(localV[ic1_,$pos]=0))
        end
        fclean = simpleFirstLoopWrapInFunction_(platform,:cleanInteraction_!,up)
        push!(p.declareF.args,fclean)
    end

    return nothing
end