"""
    function addCheckBounds_!(p::Program_,platform::String)

Generate the functions related with boundary checking.
"""
function addCheckBounds_!(p::Program_,platform::String)

    if any([typeof(i) in [Periodic,Bounded] for i in p.agent.boundary.boundaries])
        push!(p.declareVar.args, #Checking that the particles are initially inside the simulation box
        Meta.parse(string("AgentBasedModels.checkInitiallyInBound",
                        typeof(p.agent.boundary),
                        "(Core.Array(simulationBox),Core.Array(localV),",
                        [typeof(i) for i in p.agent.boundary.boundaries],
                        ")"
                    )

                )
        )
    end

    if !isempty([i for i in keys(p.update["Local"])])
        ##Add bound code if bound symbols update
        code = returnBound_(p.agent.boundary,p) #This is defined in the boundary definitions

        if !emptyquote_(code)

            #Construct functions
            f = simpleFirstLoopWrapInFunction_(platform,:boundsCheck_!,code)
            f = vectorize_(p.agent,f,p)

            push!(p.declareF.args,
                f)

            push!(p.execInloop.args,
                    :(@platformAdapt boundsCheck_!(ARGS_)) 
                )
        end

    end

    return nothing
end