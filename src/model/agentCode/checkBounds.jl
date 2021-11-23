"""
    function addCheckBounds_!(p::Program_,platform::String)

Generate the functions related with boundary checking.
"""
function addCheckBounds_!(p::Program_,platform::String)

    if !isempty([i for i in keys(p.update["Local"])])
        ##Add bound code if bound symbols update
        code = returnBound_(space.box,p)

        if !emptyquote_(code)

            #Construct functions
            f = simpleFirstLoopWrapInFunction_(platform,:boundsCheck_!,code)
            f = vectorize_(abm,f,p)

            push!(p.declareF.args,
                f)

            push!(p.execInloop.args,
                    :(@platformAdapt boundsCheck_!(ARGS_)) 
                )

        end

    end

    return nothing
end