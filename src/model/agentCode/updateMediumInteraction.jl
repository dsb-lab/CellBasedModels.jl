"""
    function addUpdateMediumInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with Agent Medium Interaction.
"""
function addUpdateMediumInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if "UpdateMediumInteraction" in keys(p.agent.declaredUpdates)

        if p.agent.dims == 1
            code = quote
                ic2_ = floor(Int,(x-$(p.space.box[1].min))/($(p.space.box[1].max)-$(p.space.box[1].min))*Nx_)+1
            end
        elseif p.agent.dims == 2
            code = quote
                ic2_ = floor(Int,(x-$(p.space.box[1].min))/($(p.space.box[1].max)-$(p.space.box[1].min))*Nx_)+1
                ic3_ = floor(Int,(x-$(p.space.box[2].min))/($(p.space.box[2].max)-$(p.space.box[2].min))*Ny_)+1
            end
        elseif p.agent.dims == 3
            code = quote
                ic2_ = floor(Int,(x-$(p.space.box[1].min))/($(p.space.box[1].max)-$(p.space.box[1].min))*Nx_)+1
                ic3_ = floor(Int,(x-$(p.space.box[2].min))/($(p.space.box[2].max)-$(p.space.box[2].min))*Ny_)+1
                ic4_ = floor(Int,(x-$(p.space.box[3].min))/($(p.space.box[3].max)-$(p.space.box[3].min))*Nz_)+1
            end

        end
        
        push!(code.args, p.agent.declaredUpdates["UpdateMediumInteraction"])

        for (i,j) in enumerate(p.agent.declaredSymbols["Medium"])
            if p.agent.dims == 1
                code = postwalk(x->@capture(x,y_) && y == j ? :(mediumVCopy[ic2_,$i]) : x, code)
            elseif p.agent.dims == 2
                code = postwalk(x->@capture(x,y_) && y == j ? :(mediumVCopy[ic2_,ic3_,$i]) : x, code)
            elseif p.agent.dims == 3
                code = postwalk(x->@capture(x,y_) && y == j ? :(mediumVCopy[ic2_,ic3_,ic4_,$i]) : x, code)
            end
        end

        #Construct functions
        f = simpleFirstLoopWrapInFunction_(platform,:mediumInteractionStep_!,code)
        f = vectorize_(abm,f,p)

        push!(p.declareF.args,
            f)

    end

    return nothing

end