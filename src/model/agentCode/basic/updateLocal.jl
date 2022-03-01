"""
    function addUpdateLocal_!(p::Program_,platform::String)

Generate the functions related with Local Updates.
"""
function addUpdateLocal_!(p::Program_,platform::String)

    if "UpdateLocal" in keys(p.agent.declaredUpdates)

        push!(p.execInloop.args,
            :(@platformAdapt locStep_!(ARGS_)) 
        )

        code = quote end
        if !(isempty(p.agent.declaredSymbols["Medium"]))
            if p.agent.dims == 1
                code = quote
                    idMediumX_ = round(Int,(x-simulationBox[1,1])/dxₘ_)+1
                end
            elseif p.agent.dims == 2
                code = quote
                    idMediumX_ = round(Int,(x-simulationBox[1,1])/dxₘ_)+1
                    idMediumY_ = round(Int,(y-simulationBox[2,1])/dyₘ_)+1
                end
            elseif p.agent.dims == 3
                code = quote
                    idMediumX_ = round(Int,(x-simulationBox[1,1])/dxₘ_)+1
                    idMediumY_ = round(Int,(y-simulationBox[2,1])/dyₘ_)+1
                    idMediumZ_ = round(Int,(z-simulationBox[3,1])/dzₘ_)+1
                end
            end        
        end

        push!(code.args,p.agent.declaredUpdates["UpdateLocal"])

        #Add events 
        code = addEventAddAgent_(code, p, platform) 
        code = addEventRemoveAgent_(code, p, platform)

        #Construct functions
        f = simpleFirstLoopWrapInFunction_(platform,:locStep_!,code)
        f = vectorize_(p.agent,f,p)

        #Updates to localV
        f = postwalk(x->@capture(x,localVCopy[g__] = localVCopy[g2__]) ? :(localV[$(g...)] = localVCopy[$(g2...)]) : x, f)
        f = postwalk(x->@capture(x,identityVCopy[g__] = identityVCopy[g2__]) ? :(identityV[$(g...)] = identityVCopy[$(g2...)]) : x, f)

        push!(p.declareF.args,
            f)

    end

    return nothing
end