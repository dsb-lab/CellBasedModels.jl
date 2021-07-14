"""
    function addUpdateLocal_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with Global Updates.
"""
function addUpdateGlobal_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if "UpdateGlobal" in keys(abm.declaredUpdates)

        #Check updated
        up = symbols_(abm,abm.declaredUpdates["UpdateGlobal"])
        up = up[Bool.((up[:,"placeDeclaration"].==:Model) .* Bool.((up[:,"assigned"].==true) .+ (up[:,"updated"].==true))),:]

        #Construct functions
        f = simpleFirstLoopWrapInFunction_(platform,:globStep_!,
                        :(begin        
                            if ic1_ == 1
                                $(abm.declaredUpdates["UpdateGlobal"])
                            end
                        end)
                        )
        f = vectorize_(abm,f,p)

        push!(p.declareF.args,
            f)

        push!(p.execInloop.args,
                :(@platformAdapt globStep_!(ARGS_)) 
            )
    end

    return nothing
end