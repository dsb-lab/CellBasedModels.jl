"""
    function addUpdateLocal_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with Local Updates.
"""
function addUpdateLocal_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if "UpdateLocal" in keys(abm.declaredUpdates)

        code = abm.declaredUpdates["UpdateLocal"]

        #Construct functions
        f = simpleFirstLoopWrapInFunction_(platform,:locStep_!,code)
        f = vectorize_(abm,f,p)

        push!(p.declareF.args,
            f)

        push!(p.execInloop.args,
                :(@platformAdapt locStep_!(ARGS_)) 
            )

    end

    return nothing
end