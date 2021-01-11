struct NeighboursGrid <: Neighbours

    variables::Array{Symbol}
    box::Matrix{AbstractFloat}
    radius::Array{AbstractFloat}

    dim::Int
    n::Int
    axisSize::Array{Int}
    cumSize::Array{Int}

end

function setNeighborhoodGrid!(agentModel::Model, vars::Array{Symbol}, box::Matrix{<:AbstractFloat}, radius::AbstractFloat)

    if length(vars) != size(box)[1]
        error("Declared vars, Box first dimension have to be the same length.")
    end
    if size(box)[2] != 2
        error("Declared box second dimension has to be of length 2 (minimum and maximum).")        
    end

    axisSize = [ceil((box[i,2]-box[i,1])/(2*radius)) for i in 1:size(box)[1]]
    cum = cumprod(axisSize)
    cumSize = [1;cum[1:end-1]]
    n = cum[end]

    agentModel.neighborhood = NeighboursGrid(vars,box,ones(length(vars))*radius,length(vars),n,axisSize,cumSize) 
    
    return
end

function setNeighborhoodGrid!(agentModel::Model, vars::Array{Symbol}, box::Matrix{<:AbstractFloat}, radius::Array{<:AbstractFloat})

    if length(vars) != size(box)[1] || length(vars) != length(radius)
        error("Declared vars, Box first dimension and radius have to be the same length.")
    end
    if size(box)[2] != 2
        error("Declared box second dimension has to be of length 2 (minimum and maximum).")        
    end

    axisSize = [ceil((box[i,2]-box[i,1])/radius[i]) for i in 1:size(box)[1]]
    cum = cumprod(axisSize)
    cumSize = [1;cum[1:end-1]]
    n = cum[end]

    agentModel.neighborhood = NeighboursGrid(vars,box,radius,n,axisSize,cumSize) 
    
    return
end

function loopNeighbourGridCreation(i,i0,n,x=nothing,pos="")
    iterator = Meta.parse(string("i",i))
    if i == i0
        jump = :($(n.cumSize[i]))
        pos = string(pos,"$jump*(nnGId_[ic1_,$i]+$iterator-1)")
        x = :(for $iterator in -1:1
                if nnGId_[ic1_,$i]+$iterator > 0 && nnGId_[ic1_,$i]+$iterator <= $(n.axisSize[i])
                    #print((nnGId_[ic1_,1]+i1,nnGId_[ic1_,2]+i2),"\t")
                    #print(POS+1," ")
                    posInit = nnGCCum_[POS+1]-nnGC_[POS+1]+1
                    posMax = nnGCCum_[POS+1]
                    #print(posMax-posInit,"\n")
                    #print(nnId_[posInit:posMax],"\n")
                    #print(nnVId_[nnId_],"\n")
                    for ic2_ in posInit:posMax
                        ALGORITHMS_
                    end
                end
            end)
        i -= 1 
        x = loopNeighbourGridCreation(i,i0,n,x,pos)
    elseif i > 0
        jump = :($(n.cumSize[i]))
        pos = string(pos,"+$jump*(nnGId_[ic1_,$i]+$iterator-1)")
        x = :(for $iterator in -1:1
                if nnGId_[ic1_,$i]+$iterator > 0 && nnGId_[ic1_,$i]+$iterator <= $(n.axisSize[i])
                    $x
                end
            end)
        i -= 1 
        x=loopNeighbourGridCreation(i,i0,n,x,pos)
    else
        x = :(
        begin
        #println(nnGId_[ic1_,:])
                $x
        #println("\n------")
        end
        )
        x = Meta.parse(replace(string(x),"POS"=>pos))
    end
    
    return x
end

function neighboursByGrid(agentModel::Model;platform="cpu")
    
    grid = deepcopy(agentModel.neighborhood)

    #Add declaring variables
    varDeclare = Expr[]
    push!(varDeclare,:(nnGId_ = @ARRAY_zeros(Int,nMax_,$(grid.dim))))
    push!(varDeclare,:(nnVId_ = @ARRAY_zeros(Int,nMax_)))
    push!(varDeclare,:(nnGC_ = @ARRAY_zeros(Int,$(grid.n))))
    push!(varDeclare,:(nnGCAux_ = @ARRAY_zeros(Int,$(grid.n))))
    push!(varDeclare,:(nnGCCum_ = @ARRAY_zeros(Int,$(grid.n))))
    push!(varDeclare,:(nnId_ = @ARRAY_zeros(Int,nMax_)))
    varDeclare = platformAdapt(varDeclare,platform=platform)
    
    #Make the position assotiation in the grid x
    l= [:(
    begin 
        aux = floor(Int,($(grid.variables[i])-$(grid.box[i][1]))/$(grid.radius[i]*2))+1
        if aux < 1
            position_ += 0
            nnGId_[ic1_,$i] = 1 
        elseif aux > $(grid.axisSize[i])
            position_ += $(grid.axisSize[i]-1)*$(grid.cumSize[i])
            nnGId_[ic1_,$i] = $(grid.axisSize[i])
        else
            position_ += (aux-1)*$(grid.cumSize[i])
            nnGId_[ic1_,$i] = aux
        end
                end) for i in 1:length(grid.variables)]
    position = :(begin $(l...) end)
        
    fDeclare = Expr[]
    #Add declaring functions
    comArgs = commonArguments(agentModel)
    if platform == "cpu"
        push!(fDeclare,
            vectParams(agentModel,:( function insertCounts_($(comArgs...),nnVId_,nnGId_,nnGC_,nnGCAux_)
              lockadd_ = Threads.SpinLock()
              Threads.@threads for ic1_ = 1:N_
                    position_ = 1
                    $position
                    nnVId_[ic1_] = position_
                    lock(lockadd_)
                        nnGC_[position_]+=1
                    unlock(lockadd_)
                    nnGCAux_[position_] = 1
              end
                return
            end    
            )))
        push!(fDeclare,
            vectParams(agentModel,:( function countingSort_($(comArgs...),nnVId_,nnGC_,nnGCAux_,nnGCCum_,nnId_)
                    lockadd_ = Threads.SpinLock()          
                    Threads.@threads for ic1_ = 1:N_
                    id_ = nnVId_[ic1_]
                    if id_ == 1
                        posInit_ = 0
                    else
                        posInit_ = nnGCCum_[id_-1]
                    end
                    lock(lockadd_)
                        posCell_ = nnGCAux_[id_]
                        nnGCAux_[id_]+=1
                    unlock(lockadd_)
                    nnId_[posInit_+posCell_] = ic1_
              end

               # println(nnVId_[nnId_])
                return
            end    
            )))     
    elseif platform == "gpu"
        push!(fDeclare,
            vectParams(agentModel,:( function insertCounts_($(comArgs...),nnVId_,nnGId_,nnGC_,nnGCAux_)
              stride_ = (blockDim()).x*(gridDim()).x
              index_ = (threadIdx()).x + ((blockIdx()).x - 1) * (blockDim()).x
              for ic1_ = index_:stride_:N_
                    position_ = 1
                    $position
                    nnVId_[ic1_] = position_
                    CUDA.atomic_add!(pointer(nnGC_,position_),1)
                    nnGCAux_[position_] = 1
              end
                return
            end    
            ))
            )    
        push!(fDeclare,
            :( function countingSort_($(comArgs...),nnVId_,nnGC_,nnGCAux_,nnGCCum_,nnId_)
              stride_ = (blockDim()).x*(gridDim()).x
              index_ = (threadIdx()).x + ((blockIdx()).x - 1) * (blockDim()).x
              for ic1_ = index_:stride_:N_
                    id_ = nnVId_[ic1_]
                    if id_ == 1
                        posInit_ = 0
                    else
                        posInit_ = nnGCCum_[id_-1]
                    end
                    posCell_ = CUDA.atomic_add!(pointer(nnGCAux_,id_),1)
                    nnId_[posInit_+posCell_] = ic1_
              end
                
                return
            end    
            )
            )
    end
    #Add execution time functions
    execute = Expr[]
    if platform == "cpu"
        push!(execute,
        :(begin
        #Clean counts
        nnGC_ .= 0
        #Insert+Counts
        insertCounts_($(comArgs...),nnVId_,nnGId_,nnGC_,nnGCAux_)
        #Prefix sum
        nnGCCum_ = cumsum(nnGC_)
        #Counting sort
        countingSort_($(comArgs...),nnVId_,nnGC_,nnGCAux_,nnGCCum_,nnId_)                       
        end
        )
        )
    elseif platform == "gpu"
        push!(execute,
        :(begin
        #Clean counts
        nnGC_ .= 0
        #Insert+Counts
        CUDA.@cuda threads=threads_ blocks=nBlocks_ insertCounts_($(comArgs...),nnVId_,nnGId_,nnGC_,nnGCAux_)
        #Prefix sum
        nnGCCum_ = cumsum(nnGC_)
        #Counting sort
        CUDA.@cuda threads=threads_ blocks=nBlocks_ countingSort_($(comArgs...),nnVId_,nnGC_,nnGCAux_,nnGCCum_,nnId_)                        
        end
        )
        )
    end
    
    arg = [:(nnVId_),:(nnGId_),:(nnGC_),:(nnGCCum_),:(nnId_)]

    inLoop = loopNeighbourGridCreation(grid.dim,grid.dim,grid)

    return varDeclare, fDeclare, execute, inLoop, arg
    
end

function neighboursByGridAdapt(entry)

    entry = subs(entry,:nnic2_,:(nnId_[ic2_]))

    return entry

end