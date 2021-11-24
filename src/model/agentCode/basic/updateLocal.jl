"""
    function addUpdateLocal_!(p::Program_,platform::String)

Generate the functions related with Local Updates.
"""
function addUpdateLocal_!(p::Program_,platform::String)

    if "UpdateLocal" in keys(p.agent.declaredUpdates)

        code = p.agent.declaredUpdates["UpdateLocal"]

        #Construct functions
        f = simpleFirstLoopWrapInFunction_(platform,:locStep_!,code)
        f = vectorize_(p.agent,f,p)

        push!(p.declareF.args,
            f)

        push!(p.execInloop.args,
                :(@platformAdapt locStep_!(ARGS_)) 
            )

    end

    return nothing
end