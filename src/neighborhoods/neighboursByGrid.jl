struct NeighboursGrid <: Neighbours

    condition::String

end

function setNeighborhoodGrid!(agentModel::Model, condition::String)
    
    agentModel.neighborhood = NeighboursGrid(condition) 
    
    return
end

function neighboursByGrid(agentModel::Model;platform="cpu")
    
    grid = agentModel.neighbours

    #Add declaring variables
    varDeclare = Expr[]
    push!(varDeclare,:(nnGridBinIdGrid_ = @ARRAY_zeros(Int,nMax_,$(grid.dim))))
    push!(varDeclare,:(nnGridBinId_ = @ARRAY_zeros(Int,nMax_)))
    push!(varDeclare,:(nnGridCounts_ = @ARRAY_zeros(Int,$(grid.N))))
    push!(varDeclare,:(nnGridCountsAlloc_ = @ARRAY_zeros(Int,$(grid.N))))
    push!(varDeclare,:(nnGridCountsCum_ = @ARRAY_zeros(Int,$(grid.N))))
    push!(varDeclare,:(nnId_ = @ARRAY_zeros(Int,nMax_)))
    varDeclare = platformAdapt(varDeclare,platform=platform)
    
    #Make the position assotiation in the grid x
    l= [:(
    begin 
        aux = floor(Int,($(grid.variables[i])-$(grid.boxSize[i][1]))/$(grid.radius*2))+1
        if aux < 1
            position_ += 0
            nnGridBinIdGrid_[ic1_,i] = 1 
        elseif aux > $(grid.NAxis[i])
            position_ += $(grid.NAxis[i])*$(grid.cum[i])
            nnGridBinIdGrid_[ic1_,i] = grid.NAxis[i]
        else
            position_ += (aux-1)*$(cumBins[i])
            nnGridBinIdGrid_[ic1_,i] = aux
        end
                end) for i in 1:length(grid.variables)]
    position = :(begin $(l...) end)
        
    fDeclare = Expr[]
    #Add declaring functions
    comArgs = commonArguments(agentModel)
    if platform == "cpu"
        push!(fDeclare,
            vectParams(agentModel,:( function insertCounts_($(comArgs...),nnGridBinId_,nnGridBinIdGrid_,nnGridCounts_,nnGridCountsAlloc_)
              lockadd_ = Threads.SpinLock()
              Threads.@threads for ic1_ = 1:N_
                    position_ = 1
                    $position
                    nnGridBinId_[ic1_] = position_
                    lock(lockadd_)
                        nnGridCounts_[position_]+=1
                    unlock(lockadd_)
                    nnGridCountsAlloc_[position_] = 1
              end
                return
            end    
            )))
        push!(fDeclare,
            vectParams(agentModel,:( function countingSort_($(comArgs...),nnGridBinId_,nnGridCounts_,nnGridCountsAlloc_,nnGridCountsCum_,nnId_)
                    lockadd_ = Threads.SpinLock()          
                    Threads.@threads for ic1_ = 1:N_
                    id_ = nnGridBinId_[ic1_]
                    if id_ == 1
                        posInit_ = 0
                    else
                        posInit_ = nnGridCountsCum_[id_-1]
                    end
                    lock(lockadd_)
                        posCell_ = nnGridCountsAlloc_[id_]
                        nnGridCountsAlloc_[id_]+=1
                    unlock(lockadd_)
                    nnId_[ic1_] = posInit_+posCell_
              end
                return
            end    
            )))     
    elseif platform == "gpu"
        push!(fDeclare,
            subs(:( function insertCounts_($(comArgs...),nnGridBinId_,nnGridCounts_,nnGridCountsAlloc_)
              stride_ = (blockDim()).x*(gridDim()).x
              index_ = (threadIdx()).x + ((blockIdx()).x - 1) * (blockDim()).x
              for ic1_ = index_:stride_:N_
                    position_ = 1
                    $position
                    nnGridBinId_[ic1_] = position_
                    CUDA.atomic_add!(nnGridCounts_[position_],1)
                    nnGridCountsAlloc_[position_] = 1
              end
                return
            end    
            ))
            )    
        push!(fDeclare,
            subs(:( function countingSort_($(comArgs...),nnGridBinId_,nnGridCounts_,nnGridCountsCum_,nnId_)
              stride_ = (blockDim()).x*(gridDim()).x
              index_ = (threadIdx()).x + ((blockIdx()).x - 1) * (blockDim()).x
              for ic1_ = index_:stride_:N_
                    id_ = nnGridBinId_[ic1_]
                    if id_ == 1
                        posInit_ = 0
                    else
                        posInit_ = nnGridCountsCum_[id_-1]
                    end
                    posCell_ = CUDA.atomic_add!(nnGridCountsAlloc_[id_],1)
                    nnId_[ic1_] = posInit_+posCell_
              end
                return
            end    
            ))
            )
    end
    #Add execution time functions
    execute = Expr[]
    if platform == "cpu"
        push!(execute,
        :(begin
        #Clean counts
        nnGridCounts_ .= 0
        #Insert+Counts
        insertCounts_($(comArgs...),nnGridBinId_,nnGridCounts_,nnGridCountsAlloc_)
        #Prefix sum
        nnGridCountsCum_ = cumsum(nnGridCounts_)
        #Counting sort
        countingSort_($(comArgs...),nnGridBinId_,nnGridCounts_,nnGridCountsAlloc_,nnGridCountsCum_,nnId_)                       
        end
        )
        )
    elseif platform == "gpu"
        push!(execute,
        :(begin
        #Clean counts
        nnGridCounts_ .= 0
        #Insert+Counts
        CUDA.@cuda threads=threads_ blocks=blocks_ insertCounts_($(comArgs...),nnGridBinId_,nnGridCounts_)
        #Prefix sum
        nnGridCountsCum_ = cumsum(nnGridCounts_)
        #Counting sort
        CUDA.@cuda threads=threads_ blocks=blocks_ countingSort_($(comArgs...),nnGridBinId_,nnGridCounts_,nnGridCountsAlloc_,nnGridCountsCum_,nnId_)                        
        end
        )
        )
    end
    
    arg = [:(nnGridBinId_),:(nnGridBinIdGrid_),:(nnGridCounts_),:(nnGridCountsCum_),:(nnId_)]
    for (pos,i) in enumerate(add[2:end-1])
        ll = []
        for j in l
            if i != add[pos]
                for k in [-i,0,i]
                    push!(ll,j+k)
                end
            else
                ll = l
            end
        end
        l = copy(ll)
    end
    ll = []
    for i in l
        push!(ll,:(bin+$i))
    end
    inLoop = subs(:(
    begin
    bin = nnGridBinId_[ic1_]
    for gridPos_ in [$(ll...)]
            if gridPos_ > 0 && gridPos_ <= $(cumprod(nBinsDimension)[end])
            n_ = nnGridCounts_[gridPos_]-1
            start_ = nnGridCountsCum_[gridPos_]
            for ic2_ in start_:(start_+n_)
                ALGORITHMS_
            end
        end
    end    
    end
    ),:nnic2_,:(nnId_[ic2_]))

    return varDeclare, fDeclare, execute
    
end