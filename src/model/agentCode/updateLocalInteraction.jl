"""
    function addCleanInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with Cleaning Interaction Updates.
"""
function addCleanLocalInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if "UpdateLocalInteraction" in keys(abm.declaredUpdates) || "UpdateInteraction" in keys(abm.declaredUpdates)

        #Construct cleanup function
        s = []
        for i in ["UpdateLocalInteraction"]
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
        fclean = simpleFirstLoopWrapInFunction_(platform,:cleanLocalInteraction_!,up)
        push!(p.declareF.args,fclean)
    end

    return nothing
end

"""
    function addUpdateLocalInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with Local Interaction Updates.
"""
function addUpdateLocalInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if "UpdateLocalInteraction" in keys(abm.declaredUpdates)

        #Construct update computation function
        fcompute = loop_(p,abm,space,abm.declaredUpdates["UpdateLocalInteraction"],platform)
        fcompute = vectorize_(abm,fcompute,p)
        fcompute = wrapInFunction_(:locInterCompute_!,fcompute)
        push!(p.declareF.args,fcompute)

        #Wrap both functions in a clean step function
        f = push!(p.declareF.args,
            :(
                function locInterStep_!(ARGS_)
                    @platformAdapt cleanLocalInteraction_!(ARGS_)
                    @platformAdapt locInterCompute_!(ARGS_)
                    return
                end
            )
            )

        push!(p.execInit.args,
                :(locInterStep_!(ARGS_))
            )
        push!(p.execInloop.args,
            :(locInterStep_!(ARGS_))
        )
        push!(p.execAfter.args,
                :(locInterStep_!(ARGS_))
            )
        
end

    return nothing
end