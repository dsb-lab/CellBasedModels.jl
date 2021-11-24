"""
    function addUpdateMediumInteraction_!(p::Program_,platform::String)

Generate the functions related with Agent Medium Interaction.
"""
function addUpdateMediumInteraction_!(p::Program_,platform::String)

    if "UpdateMediumInteraction" in keys(p.agent.declaredUpdates)
        
        code = p.agent.declaredUpdates["UpdateMediumInteraction"]

        for (i,j) in enumerate(p.agent.declaredSymbols["Medium"])
            if p.agent.dims == 1
                code = postwalk(x->@capture(x,y_) && y == j ? :(mediumVCopy[idMediumV[ic1_, 1],$i]) : x, code)
            elseif p.agent.dims == 2
                code = postwalk(x->@capture(x,y_) && y == j ? :(mediumVCopy[idMediumV[ic1_, 1],idMediumV[ic1_, 2],$i]) : x, code)
            elseif p.agent.dims == 3
                code = postwalk(x->@capture(x,y_) && y == j ? :(mediumVCopy[idMediumV[ic1_, 1],idMediumV[ic1_, 2],idMediumV[ic1_, 3],$i]) : x, code)
            end
        end

        #Construct functions
        f = simpleFirstLoopWrapInFunction_(platform,:mediumInteractionStep_!,code)
        f = vectorize_(p.agent,f,p)

        push!(p.declareF.args,
            f)

    end

    return nothing

end