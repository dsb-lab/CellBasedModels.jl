function addRemoveProcess!(agentModel::Model, condition::String)
    
    agentModel.remove = (Meta.parse(condition))
    
    return
end

function removeCompile(agentModel::Model, platform::String, varDeclaredAll::Array{Expr})
    
    varD = [i.args[1] for i in varDeclaredAll]
    
    comArgs = commonArguments(agentModel)
    cond = vectParams(agentModel, agentModel.division[1])
    update = vectParams(agentModel, agentModel.division[2])
    
    varDeclare = Expr[]
    fDeclare = Expr[]
    execute = Expr[]
        
    if  platform == "cpu"
        #Declare variables
        varDeclare = [
        platformAdapt(
            :(remList_ = @ARRAY_zeros(Int,nMax,2)),
                platform=platform),
            :(remN_ = 0),
            :(remSubsN_ = 0)
        ]

        #Declare functions
        push!(fDeclare,
            platformAdapt(
            :(
            function remove_($(comArgs...),ic1_,ic2_)
                for i in [$(varD...)]
                    i[ic1_,:] .= i[ic2_,:]
                end

                return
            end
            ), platform=platform)
            ) 

        #Execute
        push!(execute,
            platformAdapt(
            :(begin
            
            lockRem_ = Threads.SpinLock()
            remN_ = 0
            #Check rem cells
            Threads.@threads for ic1_ in 1:N_
                if $cond
                    lock(lockRem_)
                    remN_ += 1
                    remList_[remN_,1] = ic1_
                    unlock(lockRem_)
                end
            end
            remSubsN_ = N_
            for ic1_ in 1:remN_
                for j_ in 1:remN_
                    if remSubsN_ == remList_[j_,1]
                        remSubsN_ -= 1
                        remList_[j_,2] = remList_[j_,1]
                    end
                end
                if remSubsN_ > remList_[ic1_,1]
                    remList_[ic1_,2] = remSubsN_
                    remSubsN_ -= 1
                end
            end
            #Make divisions
            if remN_ > 0
                Threads.@threads for ic1_ in 1:remN_
                    if remList_[ic1_,2] != remList_[ic1_,1]
                        remove_($(comArgs...),remList_[ic1_,1],remList_[ic1_,2])
                    end
                end
                N_ -= remN_
            end
                        
            end
            ), platform=platform)
            )
        
    elseif platform == "gpu"

        #Declare variables
        varDeclare = [
        platformAdapt(
            :(remList_ = @ARRAY_zeros(Int,nMax,2)),
                platform=platform),
        platformAdapt(
            :(nRem_ = @ARRAY_zeros(Int,2)),
                platform=platform),
        ]

        #Declare functions
        push!(fDeclare,
            platformAdapt(
            :(
            function removeList1_($(comArgs...),nRem_,remList_)
                @INFUNCTION_ for ic1_ in index_:stride_:N_
                    if $cond
                        pos = CUDA.atomic_add!(nRem_[1],1)
                        remList_[pos,1] = ic1_
                    end
                end

                return
            end
            ), platform=platform)
            ) 
        push!(fDeclare,
            platformAdapt(
            :(
            function removeList2_($(comArgs...),nRem_,remList_)
                @INFUNCTION_ for ic1_ in index_:stride_:nRem_[1]
                    if remList_[ic1_,1] > (N_ + nRem_[1]) #Avoid updates of the last in the list
                        pos = CUDA.atomic_add!(nRem_[2],1)
                        remList_[pos,2] = remList_[ic1_,1]
                    end
                end

                return
            end
            ), platform=platform)
            ) 
        push!(fDeclare,
            platformAdapt(
            :(
            function removeList3_($(comArgs...),nRem_,remList_)
                @INFUNCTION_ for ic1_ in (N_-index_):(-1*stride_):(N_-nRem_[1])
                    if $cond #Avoid updates of the last in the list
                        pos = CUDA.atomic_add!(nRem_[2],-1)
                        remList_[pos,1] = ic1_
                    end
                end

                return
            end
            ), platform=platform)
            ) 
        push!(fDeclare,
            platformAdapt(
            :(
            function remove_(dt_, t_, N_,nRem_,remList_,$(varD...))
                @INFUNCTION_ for ic1_ in index_:stride_:nRem_[1]
                    if remList_ != 0
                        for i in [$(varD...)]
                            for ic2_ in 1:length(i)
                                i[remList_[ic1_,2],ic2_] .= i[remList_[ic1_,1],ic2_]
                            end
                        end
                    else
                    end
                end

                return
            end
            ), platform=platform)
            ) 

        #Execute
        push!(execute,
            platformAdapt(
            :(begin
                remList_ .= 0
                nRem_ .= 0
                @OUTFUNCTION_ removeList1_($(comArgs...),nRem_,remList_)
                @OUTFUNCTION_ removeList2_($(comArgs...),nRem_,remList_)
                @OUTFUNCTION_ removeList3_($(comArgs...),nRem_,remList_)
                @OUTFUNCTION_ remove_($(comArgs...),nRem_,remList_,$(varD...))
                N_ -= nRem_[1] 
            end
            ), platform=platform)
            )
        
    end
    
    return varDeclare,fDeclare,execute
end