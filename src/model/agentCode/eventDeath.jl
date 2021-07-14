"""
function addEventDeath_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions for division events.
"""
function addEventDeath_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

if "EventDeath" in keys(abm.declaredUpdates)

    condition = abm.declaredUpdates["EventDeath"].args[end]

    #Create function to check dead elements
    if platform == "cpu"
        up= :(removeList_Pos_ = Threads.atomic_add!(remV_,1) + 1)
    elseif platform == "gpu"
        up= :(removeList_Pos_ = CUDA.atomic_add!(pointer(remV_,1),Int(1)) + 1)
    end

    code = quote
        if $condition
            keepList_[ic1_] = 0
            $up
            removeList_[removeList_Pos_] = ic1_
        else
            keepList_[ic1_] = ic1_
        end
    end

    code = vectorize_(abm,code,p)

    f1 = simpleFirstLoopWrapInFunction_(platform,:checkDyingAgents_!,code)

    #Create function to put agents in their new position
    code = quote
        oldPos_ = keepList_[ic1_]
        newPos_ = removeList_[ic1_]
    end
    if !isempty(abm.declaredSymbols["Local"])
        push!(code.args,
            :(begin 
                if oldPos_ > 0
                    for ic2_ in 1:$(length(abm.declaredSymbols["Local"]))
                        localV[newPos_, ic2_] = localV[oldPos_, ic2_] 
                    end
                end
            end)
        )
    end
    if !isempty(abm.declaredSymbols["Identity"])
        push!(code.args,
            :(begin 
                if oldPos_ > 0
                    for ic2_ in 1:$(length(abm.declaredSymbols["Identity"]))
                        identityV[newPos_, ic2_] = identityV[oldPos_, ic2_] 
                    end
                end
            end)
        )
    end
    if !isempty(p.update["Local"])
        push!(code.args,
            :(begin 
                if oldPos_ > 0
                    for ic2_ in 1:$(length(p.update["Local"]))
                        localVCopy[newPos_, ic2_] = localVCopy[oldPos_, ic2_] 
                    end
                end
            end)
        )
    end
    if !isempty(p.update["Identity"])
        push!(code.args,
            :(begin 
                if oldPos_ > 0
                    for ic2_ in 1:$(length(p.update["Identity"]))
                        identityVCopy[newPos_, ic2_] = identityVCopy[oldPos_, ic2_] 
                    end
                end
            end)
        )
    end

    f2 = simpleFirstLoopWrapInFunction_(platform,:assignDeadAgentsSpaces_!,code)  
    if platform == "cpu"
        f2 = postwalk(x->@capture(x,N) ? :(remV_[]) : x, f2)      
    elseif platform == "gpu"
        f2 = postwalk(x->@capture(x,N) ? :(remV_[1]) : x, f2)      
    end


    #Make wrap function of the algorithm
    if platform == "cpu"
        code = quote
            remV_[] = 0
            if N > 0
                @platformAdapt checkDyingAgents_!(ARGS_)
                sort!(keepList_,rev=true)
                @platformAdapt assignDeadAgentsSpaces_!(ARGS_)
            end
        end
    elseif platform == "gpu"
        code = quote
            remV_ .= 0
            if N > 0
                @platformAdapt checkDyingAgents_!(ARGS_)
                sort!(keepList_,rev=true)
                @platformAdapt assignDeadAgentsSpaces_!(ARGS_)
            end
        end        
    end
    
    f3 = wrapInFunction_(:removeDeadAgents_!,code)   

    # Add to program
    if platform == "cpu"
        push!(p.declareVar.args,
            :(begin 
                remV_ = Threads.Atomic{Int}()
                keepList_ = zeros(Int,nMax)
                removeList_ = zeros(Int,nMax)
            end)
        )
    elseif platform == "gpu"
        push!(p.declareVar.args,
            :(begin 
                remV_ = CUDA.zeros(Int,1)
                keepList_ = zeros(Int,nMax)
                removeList_ = zeros(Int,nMax)
            end)
        )
    end

    push!(p.args,:remV_,:keepList_,:removeList_)

    push!(p.declareF.args,f1,f2,f3)

    if platform == "cpu"
        push!(p.execInloop.args,:(removeDeadAgents_!(ARGS_); N -= remV_[]))
    else
        push!(p.execInloop.args,:(removeDeadAgents_!(ARGS_); N -= Core.Array(remV_)[1]))
    end
end

return nothing
end
