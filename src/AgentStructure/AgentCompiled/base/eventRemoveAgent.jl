function removeAgent_cpu!(pos,keepList_,removeList_,remV_)
    keepList_[pos] = 0
    removeList_Pos_ = Threads.atomic_add!(remV_,1) + 1
    removeList_[removeList_Pos_] = pos
end

function removeAgent_gpu!(pos,keepList_,removeList_,remV_)
    keepList_[pos] = 0
    removeList_Pos_ = CUDA.atomic_add!(CUDA.pointer(remV_,Int32(1)),Int32(1)) + 1
    removeList_[removeList_Pos_] = pos
end

function removeDeadAgents_cpu!(remV_,keepList_,removeList_,N,localV,nLocal,identityV,nIdentity,localVCopy,nLocalC,identityVCopy,nIdentityC)

    Threads.@threads for ic1_ in N:-1:N-remV_[]+1
        if keepList_[ic1_] != keepList_[ic1_+1]
            oldPos_ = ic1_
            # println(keepList_[ic1_+1]," ",N," ",N+2-remV_[]-keepList_[ic1_+1])
            newPos_ = removeList_[N+2-remV_[]-keepList_[ic1_+1]]
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
    end

    return
end

function removeDeadAgents_cpu!(remV_,keepList_,removeList_,N,localV,nLocal,identityV,nIdentity,localVCopy,nLocalC)

    Threads.@threads for ic1_ in N:-1:N-remV_[]+1
        if keepList_[ic1_] != keepList_[ic1_+1]
            oldPos_ = ic1_
            # println(keepList_[ic1_+1]," ",N," ",N+2-remV_[]-keepList_[ic1_+1])
            newPos_ = removeList_[N+2-remV_[]-keepList_[ic1_+1]]
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
    end

    return
end

function removeDeadAgents_cpu!(remV_,keepList_,removeList_,N,localV,nLocal,identityV,nIdentity,identityVCopy::Array{<:Int,2},nIdentityC)

    Threads.@threads for ic1_ in N:-1:N-remV_[]+1
        if keepList_[ic1_] != keepList_[ic1_+1]
            oldPos_ = ic1_
            # println(keepList_[ic1_+1]," ",N," ",N+2-remV_[]-keepList_[ic1_+1])
            newPos_ = removeList_[N+2-remV_[]-keepList_[ic1_+1]]
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
    end

    return
end

function removeDeadAgents_cpu!(remV_,keepList_,removeList_,N,localV,nLocal,identityV,nIdentity)

    Threads.@threads for ic1_ in N:-1:N-remV_[]+1
        if keepList_[ic1_] != keepList_[ic1_+1]
            oldPos_ = ic1_
            # println(keepList_[ic1_+1]," ",N," ",N+2-remV_[]-keepList_[ic1_+1])
            newPos_ = removeList_[N+2-remV_[]-keepList_[ic1_+1]]
            if oldPos_ > 0
                for ic2_ in 1:nLocal
                    localV[newPos_, ic2_] = localV[oldPos_, ic2_] 
                end
                for ic2_ in 1:nIdentity
                    identityV[newPos_, ic2_] = identityV[oldPos_, ic2_] 
                end
            end
        end
    end

    return
end

function removeDeadAgents_gpu!(remV_,keepList_,removeList_,N,localV,nLocal,identityV,nIdentity,localVCopy,nLocalC,identityVCopy,nIdentityC)

    index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
    stride_ = blockDim().x * gridDim().x

    for ic1_ in N+1-index_:-stride_:N+1-remV_[1]
        if keepList_[ic1_] != keepList_[ic1_+1]
            oldPos_ = ic1_
            # println(keepList_[ic1_+1]," ",N," ",N+2-remV_[]-keepList_[ic1_+1])
            newPos_ = removeList_[N+2-remV_[1]-keepList_[ic1_+1]]
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
    end

    return nothing
end

function removeDeadAgents_gpu!(remV_,keepList_,removeList_,N,localV,nLocal,identityV,nIdentity,localVCopy::CuDeviceMatrix{<:AbstractFloat, 1},nLocalC)

    index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
    stride_ = blockDim().x * gridDim().x

    for ic1_ in N+1-index_:-stride_:N+1-remV_[1]
        if keepList_[ic1_] != keepList_[ic1_+1]
            oldPos_ = ic1_
            # println(keepList_[ic1_+1]," ",N," ",N+2-remV_[]-keepList_[ic1_+1])
            newPos_ = removeList_[N+2-remV_[1]-keepList_[ic1_+1]]
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
    end

    return
end

function removeDeadAgents_gpu!(remV_,keepList_,removeList_,N,localV,nLocal,identityV,nIdentity,identityVCopy::CuDeviceMatrix{<:Int, 1},nIdentityC)

    index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
    stride_ = blockDim().x * gridDim().x

    for ic1_ in N+1-index_:-stride_:N+1-remV_[1]
        if keepList_[ic1_] != keepList_[ic1_+1]
            oldPos_ = ic1_
            # println(keepList_[ic1_+1]," ",N," ",N+2-remV_[]-keepList_[ic1_+1])
            newPos_ = removeList_[N+2-remV_[1]-keepList_[ic1_+1]]
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
    end

    return
end

function removeDeadAgents_gpu!(remV_,keepList_,removeList_,N,localV,nLocal,identityV,nIdentity)

    index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
    stride_ = blockDim().x * gridDim().x

    for ic1_ in N+1-index_:-stride_:N+1-remV_[1]
        if keepList_[ic1_] != keepList_[ic1_+1]
            oldPos_ = ic1_
            # println(keepList_[ic1_+1]," ",N," ",N+2-remV_[]-keepList_[ic1_+1])
            newPos_ = removeList_[N+2-remV_[1]-keepList_[ic1_+1]]
            if oldPos_ > 0
                for ic2_ in 1:nLocal
                    localV[newPos_, ic2_] = localV[oldPos_, ic2_] 
                end
                for ic2_ in 1:nIdentity
                    identityV[newPos_, ic2_] = identityV[oldPos_, ic2_] 
                end
            end
        end
    end

    return
end

"""
    function addEventRemoveAgent(code::Expr,p::AgentCompiled)

Substitute a declaration of `removeAgent` by the corresponding code.

# Args
 - **code::Expr**:  Code to be changed by agents.
 - **p::AgentCompiled**:  AgentCompiled structure containing all the created code when compiling.

# Returns
 -  `Expr` with the modified code.
"""
function addEventRemoveAgent(code::Expr,p::AgentCompiled)

    #Add remove event if declared
    if inexpr(code,:removeAgent)

        name = Meta.parse(string("removeAgent_",p.platform,"!"))
        code = postwalk(x -> @capture(x,removeAgent()) ? :(AgentBasedModels.$name(ic1_,keepList_,removeList_,remV_)) : x, code)
        
        if inexpr(code,:removeAgent) #Check correct declaration
            error("removeAgent declared with wrong number of parameters. It has to be declared as removeAgent())")
        end     
        
        #Add the keep list initialization at the beginning
        # codeinit = quote keepList_[ic1_] = ic1_ end
        # push!(codeinit.args,code.args...)
        # code = codeinit

        #Add to code the removing algorithm
        a = [:remV_,:keepList_,
                :removeList_,
                :N,
                :localV,length(p.agent.declaredSymbols["Local"]),
                :identityV,length(p.agent.declaredSymbols["Identity"])]
        if !isempty(p.update["Local"])
            push!(a, :localVCopy,length(p.update["Local"]))
        end
        if !isempty(p.update["Identity"])
            push!(a, :identityVCopy, length(p.update["Identity"]))
        end
        if p.platform == "cpu"
            update = quote
                if N - remV_[] > 0
                    keepList_[1:N+1] .= cumsum(keepList_[1:N+1])
                    @platformAdapt AgentBasedModels.removeDeadAgents_cpu!($(a...))
                    N -= remV_[]
                    remV_[] = 0
                    keepList_ .= 1
                elseif N - remV_[] == 0
                    N -= remV_[]
                    remV_[] = 0
                    keepList_ .= 1
                end
            end
        elseif p.platform == "gpu"
            update = quote
                if N - Core.Array(remV_)[1] > 0
                    keepList_[1:N+1] .= CUDA.cumsum(keepList_[1:N+1])
                    @platformAdapt AgentBasedModels.removeDeadAgents_gpu!($(a...))
                    N -= Core.Array(remV_)[1]
                    remV_ .= 0
                    keepList_ .= 1
                elseif N - Core.Array(remV_)[1] == 0
                    N -= Core.Array(remV_)[1]
                    remV_ .= 0
                    keepList_ .= 1
                end
            end        
        end
        push!(p.execInloop.args,update)
        
        # Add to program
        if p.platform == "cpu"
            push!(p.declareVar.args,
                :(begin 
                    remV_ = Threads.Atomic{$INT}()
                    keepList_ = ones($INT,nMax+1)
                    removeList_ = zeros($INT,nMax)
                end)
            )
        elseif p.platform == "gpu"
            push!(p.declareVar.args,
                :(begin 
                    remV_ = CUDA.zeros($INTCUDA,1)
                    keepList_ = ones($INTCUDA,nMax+1)
                    removeList_ = zeros($INTCUDA,nMax)
                end)
            )
        end

        push!(p.args,:remV_,:keepList_,:removeList_)

    end

    return code
end
