function removeAgent_cpu!(pos,keepList_,removeList_,remV_)
    keepList_[pos] = 0
    removeList_Pos_ = Threads.atomic_add!(remV_,1) + 1
    removeList_[removeList_Pos_] = pos
end

function removeAgent_gpu!(pos,keepList_,removeList_,remV_)
    keepList_[pos] = 0
    removeList_Pos_ = CUDA.atomic_add!(pointer(remV_,1),Int(1)) + 1
    removeList_[removeList_Pos_] = pos
end

function removeDeadAgents_cpu!(remV_,keepList_,removeList_,localV,nLocal,identityV,nIdentity,localVCopy,nLocalC,identityVCopy,nIdentityC)

    for ic1_ in 1:remV_[]
        oldPos_ = keepList_[ic1_]
        newPos_ = removeList_[ic1_]
        if oldPos_ > 0
            for ic2_ in 1:nLocal
                localV[newPos_, ic2_] = localV[oldPos_, ic2_] 
            end
            for ic2_ in 1:nIdentity
                identityV[newPos_, ic2_] = identityV[oldPos_, ic2_] 
            end
            for ic2_ in 1:nLocalC
                localVCopy[newPos_, ic2_] = localVCopy[oldPos_, ic2_] 
            end
            for ic2_ in 1:nIdentityC
                identityVCopy[newPos_, ic2_] = identityVCopy[oldPos_, ic2_] 
            end
        end
    end

    return
end

function removeDeadAgents_cpu!(remV_,keepList_,removeList_,localV,nLocal,identityV,nIdentity,localVCopy,nLocalC)

    for ic1_ in 1:remV_[]
        oldPos_ = keepList_[ic1_]
        newPos_ = removeList_[ic1_]
        if oldPos_ > 0
            for ic2_ in 1:nLocal
                localV[newPos_, ic2_] = localV[oldPos_, ic2_] 
            end
            for ic2_ in 1:nIdentity
                identityV[newPos_, ic2_] = identityV[oldPos_, ic2_] 
            end
            for ic2_ in 1:nLocalC
                localVCopy[newPos_, ic2_] = localVCopy[oldPos_, ic2_] 
            end
        end
    end

    return
end

function removeDeadAgents_cpu!(remV_,keepList_,removeList_,localV,nLocal,identityV,nIdentity,identityVCopy::Array{<:Int,2},nIdentityC)

    for ic1_ in 1:remV_[]
        oldPos_ = keepList_[ic1_]
        newPos_ = removeList_[ic1_]
        if oldPos_ > 0
            for ic2_ in 1:nLocal
                localV[newPos_, ic2_] = localV[oldPos_, ic2_] 
            end
            for ic2_ in 1:nIdentity
                identityV[newPos_, ic2_] = identityV[oldPos_, ic2_] 
            end
            for ic2_ in 1:nIdentityC
                identityVCopy[newPos_, ic2_] = identityVCopy[oldPos_, ic2_] 
            end
        end
    end

    return
end

function removeDeadAgents_cpu!(remV_,keepList_,removeList_,localV,nLocal,identityV,nIdentity)

    for ic1_ in 1:remV_[]
        oldPos_ = keepList_[ic1_]
        newPos_ = removeList_[ic1_]
        if oldPos_ > 0
            for ic2_ in 1:nLocal
                localV[newPos_, ic2_] = localV[oldPos_, ic2_] 
            end
            for ic2_ in 1:nIdentity
                identityV[newPos_, ic2_] = identityV[oldPos_, ic2_] 
            end
        end
    end

    return
end

function removeDeadAgents_gpu!(remV_,keepList_,removeList_,localV,nLocal,identityV,nIdentity,localVCopy,nLocalC,identityVCopy,nIdentityC)

    for ic1_ in 1:remV_[0]
        oldPos_ = keepList_[ic1_]
        newPos_ = removeList_[ic1_]
        if oldPos_ > 0
            for ic2_ in 1:nLocal
                localV[newPos_, ic2_] = localV[oldPos_, ic2_] 
            end
            for ic2_ in 1:nIdentity
                identityV[newPos_, ic2_] = identityV[oldPos_, ic2_] 
            end
            for ic2_ in 1:nLocalC
                localVCopy[newPos_, ic2_] = localVCopy[oldPos_, ic2_] 
            end
            for ic2_ in 1:nIdentityC
                identityVCopy[newPos_, ic2_] = identityVCopy[oldPos_, ic2_] 
            end
        end
    end

    return
end

function removeDeadAgents_gpu!(remV_,keepList_,removeList_,localV,nLocal,identityV,nIdentity,localVCopy,nLocalC)

    for ic1_ in 1:remV_[0]
        oldPos_ = keepList_[ic1_]
        newPos_ = removeList_[ic1_]
        if oldPos_ > 0
            for ic2_ in 1:nLocal
                localV[newPos_, ic2_] = localV[oldPos_, ic2_] 
            end
            for ic2_ in 1:nIdentity
                identityV[newPos_, ic2_] = identityV[oldPos_, ic2_] 
            end
            for ic2_ in 1:nLocalC
                localVCopy[newPos_, ic2_] = localVCopy[oldPos_, ic2_] 
            end
        end
    end

    return
end

function removeDeadAgents_gpu!(remV_,keepList_,removeList_,localV,nLocal,identityV,nIdentity,identityVCopy::Array{<:Int,2},nIdentityC)

    for ic1_ in 1:remV_[0]
        oldPos_ = keepList_[ic1_]
        newPos_ = removeList_[ic1_]
        if oldPos_ > 0
            for ic2_ in 1:nLocal
                localV[newPos_, ic2_] = localV[oldPos_, ic2_] 
            end
            for ic2_ in 1:nIdentity
                identityV[newPos_, ic2_] = identityV[oldPos_, ic2_] 
            end
            for ic2_ in 1:nIdentityC
                identityVCopy[newPos_, ic2_] = identityVCopy[oldPos_, ic2_] 
            end
        end
    end

    return
end

function removeDeadAgents_gpu!(remV_,keepList_,removeList_,localV,nLocal,identityV,nIdentity)

    for ic1_ in 1:remV_[0]
        oldPos_ = keepList_[ic1_]
        newPos_ = removeList_[ic1_]
        if oldPos_ > 0
            for ic2_ in 1:nLocal
                localV[newPos_, ic2_] = localV[oldPos_, ic2_] 
            end
            for ic2_ in 1:nIdentity
                identityV[newPos_, ic2_] = identityV[oldPos_, ic2_] 
            end
        end
    end

    return
end

"""
function addEventDeath_(code::Expr,p::Program_,platform::String)

Generate the functions for division events.
"""
function addEventRemoveAgent_(code::Expr,p::Program_,platform::String)

    #Add remove event if declared
    if inexpr(code,:removeAgent)

        name = Meta.parse(string("removeAgent_",platform,"!"))
        code = postwalk(x -> @capture(x,removeAgent()) ? :(AgentBasedModels.$name(ic1_,keepList_,removeList_,remV_)) : x, code)
        
        if inexpr(code,:removeAgent) #Check correct declaration
            error("removeAgent declared with wrong number of parameters. It has to be declared as removeAgent())")
        end     
        
        #Add the keep list initialization at the beginning
        codeinit = quote keepList_[ic1_] = ic1_ end
        push!(codeinit.args,code.args...)
        code = codeinit

    end    

    #Add to code the removing algorithm
    a = [:remV_,:keepList_,
            :removeList_,
            :localV,length(p.agent.declaredSymbols["Local"]),
            :identityV,length(p.agent.declaredSymbols["Identity"])]
    if !isempty(p.update["Local"])
        push!(a, :localVCopy,length(p.update["Local"]))
    end
    if !isempty(p.update["Identity"])
        push!(a, :identityVCopy, length(p.update["Identity"]))
    end
    if platform == "cpu"
        update = quote
            if N > 0
                sort!(keepList_,rev=true)
                @platformAdapt AgentBasedModels.removeDeadAgents_cpu!($(a...))
                N -= remV_[]
                remV_[] = 0
                keepList_ .= 0
            end
        end
    elseif platform == "gpu"
        update = quote
            if N > 0
                sort!(keepList_,rev=true)
                @platformAdapt AgentBasedModels.removeDeadAgents_gpu!($(a...))
                N -= Core.Array(remV_)[1]
                remV_ .= 0
                keepList_ .= 0
            end
        end        
    end
    push!(p.execInloop.args,update)
    
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

    return code
end
