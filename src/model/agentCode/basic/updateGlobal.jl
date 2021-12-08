"""
    function addUpdateLocal_!(p::Program_,platform::String)

Generate the functions related with Global Updates.
"""
function addUpdateGlobal_!(p::Program_,platform::String)

    if "UpdateGlobal" in keys(p.agent.declaredUpdates)

        #Construct functions
        f = simpleFirstLoopWrapInFunction_(platform,:globStep_!,
                        :(begin        
                            if ic1_ == 1
                                $(p.agent.declaredUpdates["UpdateGlobal"])
                            end
                        end)
                        )
        f = vectorize_(p.agent,f,p)

        push!(p.declareF.args,
            f)

        push!(p.execInloop.args,
                :(@platformAdapt globStep_!(ARGS_)) 
            )
    end

    return nothing
end