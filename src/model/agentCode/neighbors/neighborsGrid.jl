###################################################################################################################
#Auxiliar functions
###################################################################################################################

function gridShape(dims::Int,box::Array{<:Real,2},radius::Union{<:Real,Array{<:,1}})
    
    if (dims,2) != size(box)
        error("Box has to be of dimensions of (dims,2), where dims are the dimensions of the model.")
    end

    if size(radius) != ()
        error("Radius has to be or a Real Number or an array with the dimensions of the model.")
    end

    #Compute additional parameters for the structure
    axisSize = [ceil(Int,(i.max-i.box)/radius[j])+2 for (j,i) in enumerate(box2)]
    cum = cumprod(axisSize)
    cumSize = [1;cum[1:end-1]]
    n = cum[end]

    return n
end

function position2gridVectorPosition_(x,boxX,dX,nX)

    pos = min(max(ceil(Int,(x-boxX)/dX+1),1),nX)

    return pos
end

function position2gridVectorPosition_(x,boxX,dX,nX,y,boxY,dY,nY)

    posX = min(max(ceil(Int,(x-boxX)/dX+1),1),nX)
    posY = min(max(ceil(Int,(y-boxY)/dY+1),1),nY)

    return posX + nX * (posY-1)
end

function position2gridVectorPosition_(x,boxX,dX,nX,y,boxY,dY,nY,z,boxZ,dZ,nZ)

    posX = min(max(ceil(Int,(x-boxX)/dX+1),1),nX)
    posY = min(max(ceil(Int,(y-boxY)/dY+1),1),nY)
    posZ = min(max(ceil(Int,(z-boxZ)/dZ+1),1),nZ)

    return posX + nX * (posY-1) + nX * nY * (posZ-1)
end

function gridVectorPositionNeighbour_(p,neighbour,nX,periodicX)
    posX = p+(neighbour-2)

    if periodicX == true
        if posX == 1
            return nX - 1
        elseif posX == nX
            return 2
        else
            return posX
        end
    else
        if posX == 0
            return -1
        elseif posX == nX + 1
            return -1
        else
            return posX
        end
    end
end

function gridVectorPositionNeighbour_(p,neighbour,nX,periodicX,nY,periodicY)

    posY = floor(Int,p/nX-1/nX) 
    p -= nX*posY
    posX = p

    addY = floor(Int,neighbour/3-1/3)
    neighbour -= addY*3
    addX = neighbour - 2

    posY += addY
    posX += addX

    abort = false

    if periodicX == true
        if posX == 1
            posX =  nX - 1
        elseif posX == nX
            posX = 2
        end
    else
        if posX == 0
            abort = true
        elseif posX == nX + 1
            abort = true
        end
    end

    if periodicY == true
        if posY == 1
            posY = nY - 1
        elseif posY == nY
            posY = 2
        end
    else
        if posY == 0
            abort= true
        elseif posY == nY + 1
            abort = true
        end
    end

    #println(posX," ",posY)

    if abort
        return -1
    else
        return posX + nX*(posY-1)
    end
end

function gridVectorPositionNeighbour_(p,neighbour,nX,periodicX,nY,periodicY,nZ,periodicZ)

    nXY = nX*nY
    posZ = floor(Int,p/nXY-1/nXY) 
    p -= nXY*posZ
    posY = floor(Int,p/nX-1/nX) 
    p -= nX*posY
    posX = p

    addZ = floor(Int,neighbour/9-1/9)
    neighbour -= addZ*9
    addY = floor(Int,neighbour/3-1/3)
    neighbour -= addY*3
    addX = neighbour - 2

    posZ += addZ
    posY += addY
    posX += addX

    abort = false

    if periodicX == true
        if posX == 1
            posX =  nX - 1
        elseif posX == nX
            posX = 2
        end
    else
        if posX == 0
            abort = true
        elseif posX == nX + 1
            abort = true
        end
    end

    if periodicY == true
        if posY == 1
            posY = nY - 1
        elseif posY == nY
            posY = 2
        end
    else
        if posY == 0
            abort= true
        elseif posY == nY + 1
            abort = true
        end
    end

    if periodicZ == true
        if posZ == 1
            posZ = nZ - 1
        elseif posZ == nZ
            posZ = 2
        end
    else
        if posZ == 0
            abort= true
        elseif posZ == nZ + 1
            abort = true
        end
    end

    if abort
        return -1
    else
        return posX + nX*(posY-1) + nXY*(posZ-1)
    end
end

#########################################################
#cpu#####################################################
#########################################################
function gridInsertCounts1D_cpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_)

    lockadd_ = Threads.SpinLock()
    Threads.@threads for ic1_ = 1:N

        nnPosIdCell_[ic1_] = AgentBasedModels.position2gridVectorPosition_(localV_[1],box[1,1],r[1],n[1])
        lock(lockadd_)
            nnGridCounts_[nnPosIdCell_[ic1_]]+=1
        unlock(lockadd_)
    
    end

    return nothing

end

function gridInsertCounts2D_cpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_)

    lockadd_ = Threads.SpinLock()
    Threads.@threads for ic1_ = 1:N

        nnPosIdCell_[ic1_] = AgentBasedModels.position2gridVectorPosition_(localV_[1],box[1,1],r[1],n[1],
                                                                            localV_[2],box[2,1],r[2],n[2])
        lock(lockadd_)
            nnGridCounts_[nnPosIdCell_[ic1_]]+=1
        unlock(lockadd_)
    
    end
    
    return nothing

end

function gridInsertCounts3D_cpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_)

    lockadd_ = Threads.SpinLock()
    Threads.@threads for ic1_ = 1:N

        nnPosIdCell_[ic1_] = AgentBasedModels.position2gridVectorPosition_(localV_[1],box[1,1],r[1],n[1],
                                                                            localV_[2],box[2,1],r[2],n[2],
                                                                            localV_[3],box[3,1],r[3],n[3])
        lock(lockadd_)
            nnGridCounts_[nnPosIdCell_[ic1_]]+=1
        unlock(lockadd_)
    
    end

    return nothing

end

function gridCountingSort_cpu(N,nnPosIdCell_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_)

    lockadd_ = Threads.SpinLock()
    Threads.@threads for ic1_ = 1:N
        
        id_ = nnPosIdCell_[ic1_]
        if id_ == 1
            posInit_ = 0
        else
            posInit_ = nnGridCountsCum_[id_-1]
        end
        lock(lockadd_)
            posCell_ = nnGridCountsAux_[id_]
            nnGridCountsAux_[id_]+=1
        unlock(lockadd_)
        nnCellIdPos_[posInit_+posCell_] = ic1_
    
    end

    return nothing

end

function gridComputeNN1D_cpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_)
                    
    nnGridCounts_ .= 0
    nnGridCountsAux_ .= 1
    gridInsertCounts1D_cpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_)
    nnGridCountsCum_ .= cumsum(nnGridCounts_)
    gridCountingSort_cpu(N,nnPosIdCell_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_)

    return nothing
end

function gridComputeNN2D_cpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_)
                    
    nnGridCounts_ .= 0
    nnGridCountsAux_ .= 1
    gridInsertCounts2D_cpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_)
    nnGridCountsCum_ .= cumsum(nnGridCounts_)
    gridCountingSort_cpu(N,nnPosIdCell_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_)

    return nothing
end

function gridComputeNN3D_cpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_)
                    
    nnGridCounts_ .= 0
    nnGridCountsAux_ .= 1
    gridInsertCounts3D_cpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_)
    nnGridCountsCum_ .= cumsum(nnGridCounts_)
    gridCountingSort_cpu(N,nnPosIdCell_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_)

    return nothing
end

#########################################################
#gpu#####################################################
#########################################################
function gridInsertCounts1D_gpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_)

    index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
    stride_ = blockDim().x * gridDim().x

    for ic1_ in index_:stride_:N
        nnPosIdCell_[ic1_] = AgentBasedModels.position2gridVectorPosition_(localV_[1],box[1,1],r[1],n[1])
        CUDA.atomic_add!(CUDA.pointer(nnGridCounts_,nnPosIdCell_[ic1_]),Int32(1))
    end
    
    for ic1_ = 1:stride_:N


    end

    return nothing

end

function gridInsertCounts2D_gpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_)

    index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
    stride_ = blockDim().x * gridDim().x

    for ic1_ in index_:stride_:N
        nnPosIdCell_[ic1_] = AgentBasedModels.position2gridVectorPosition_(localV_[1],box[1,1],r[1],n[1],
                                                                            localV_[2],box[2,1],r[2],n[2])
        CUDA.atomic_add!(CUDA.pointer(nnGridCounts_,nnPosIdCell_[ic1_]),Int32(1))
    end

    return nothing

end

function gridInsertCounts3D_gpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_)

    index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
    stride_ = blockDim().x * gridDim().x

    for ic1_ in index_:stride_:N
        nnPosIdCell_[ic1_] = AgentBasedModels.position2gridVectorPosition_(localV_[1],box[1,1],r[1],n[1],
                                                                            localV_[2],box[2,1],r[2],n[2],
                                                                            localV_[3],box[3,1],r[3],n[3])
        CUDA.atomic_add!(CUDA.pointer(nnGridCounts_,nnPosIdCell_[ic1_]),Int32(1))
    end

    return nothing

end

function gridCountingSort_gpu(N,nnPosIdCell_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_)

    index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
    stride_ = blockDim().x * gridDim().x

    for ic1_ in index_:stride_:N
        id_ = nnPosIdCell_[ic1_]
        if id_ == 1
            posInit_ = 0
        else
            posInit_ = nnGridCountsCum_[id_-1]
        end
        posCell_ = CUDA.atomic_add!(CUDA.pointer(nnGridCountsAux_,id_),Int32(1))
        nnCellIdPos_[posInit_+posCell_] = ic1_
    end

    return nothing

end

function gridComputeNN1_gpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_)
                    
    nnGridCounts_ .= 0
    nnGridCountsAux_ .= 1
    #Insert counts
    kernel_ = @cuda launch = false gridInsertCounts1D_gpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_); 
    prop_ = AgentBasedModels.configurator_(kernel_,N); 
    kernel_(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_;threads=prop_[1],blocks=prop_[2])
    #Cumsum
    nnGridCountsCum_ .= cumsum(nnGridCounts_)
    #Insert counts Sort
    kernel_ = @cuda launch = false gridCountingSort_gpu(N,nnPosIdCell_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_); 
    prop_ = AgentBasedModels.configurator_(kernel_,N); 
    kernel_(N,nnPosIdCell_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_;threads=prop_[1],blocks=prop_[2])

    return nothing
end

function gridComputeNN2_gpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_)
                    
    nnGridCounts_ .= 0
    nnGridCountsAux_ .= 1
    #Insert counts
    kernel_ = @cuda launch = false gridInsertCounts2D_gpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_); 
    prop_ = AgentBasedModels.configurator_(kernel_,N); 
    kernel_(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_;threads=prop_[1],blocks=prop_[2])
    #Cumsum
    nnGridCountsCum_ .= cumsum(nnGridCounts_)
    #Insert counts Sort
    kernel_ = @cuda launch = false gridCountingSort_gpu(N,nnPosIdCell_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_); 
    prop_ = AgentBasedModels.configurator_(kernel_,N); 
    kernel_(N,nnPosIdCell_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_;threads=prop_[1],blocks=prop_[2])

    return nothing
end

function gridComputeNN3_gpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_)
                    
    nnGridCounts_ .= 0
    nnGridCountsAux_ .= 1
    #Insert counts
    kernel_ = @cuda launch = false gridInsertCounts3D_gpu(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_); 
    prop_ = AgentBasedModels.configurator_(kernel_,N); 
    kernel_(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_;threads=prop_[1],blocks=prop_[2])
    #Cumsum
    nnGridCountsCum_ .= cumsum(nnGridCounts_)
    #Insert counts Sort
    kernel_ = @cuda launch = false gridCountingSort_gpu(N,nnPosIdCell_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_); 
    prop_ = AgentBasedModels.configurator_(kernel_,N); 
    kernel_(N,nnPosIdCell_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_;threads=prop_[1],blocks=prop_[2])

    return nothing
end

###################################################################################################################
#Call functions
###################################################################################################################

function argumentsGrid_!(program::Program_, platform::String)
    
    append!(program.declareVar.args, 
    (quote
        n_ = AgentBasedModels.gridShape($(program.agent.dims),box)
        nnPosIdCell_ = zeros(Int,nMax)
        nnGridCounts_ = zeros(Int,n_)
        nnGridCountsAux_ = zeros(Int,n_)
        nnGridCountsCum_ = zeros(Int,n_)
        nnCellIdPos_ = zeros(Int,nMax)
    end).args
    )

    #Create kernels for the algorithm
    if platform != "cpu" && platform != "gpu"
        error("Platform should be or cpu or gpu. ", platform, " was given.")
    end

    append!(program.args, [:nnPosIdCell_,:nnGridCounts_,:nnGridCountsAux_,:nnGridCountsCum_,:nnCellIdPos_])

    aux = Meta.parse(string("gridComputeNN",program.agent.dims,"_",platform,"(N,localV_,box,r,n,nnPosIdCell_,nnGridCounts_,nnGridCountsCum_,nnGridCountsAux_,nnCellIdPos_)"))

    push!(program.execInit.args, :($aux))
    push!(program.execInloop.args, :($aux))
    
    return nothing
end

function loopGrid_(program::Program_, code::Expr, platform::String)

    code = vectorize_(program.agent, code, program)

    #Compute the cell id for each agent in grid and linearized format for any box possible box dimensions.
    if a.dim == 1
        periodicX = typeof(a.box[1,1]) <: Periodic
        loop=:(begin 
            for iAux1_ in 1:3
                pos_ = AgentBasedModels.gridVectorPositionNeighbour_(nnPosIdCell_[ic1_],iAux1_,$(a.axisSize[1]),$periodicX)
                if pos_ != -1
                    max_ = nnGridCountsCum_[pos_]
                    box_ = max_ - nnGridCounts_[pos_] + 1
                    for ic2_ in box_:max_
                        ic2_ = nnCellIdPos_[ic2_]
                        $code
                    end
                end
            end
        end)
    elseif a.dim == 2
        periodicX = typeof(a.box[1,1]) <: Periodic
        periodicY = typeof(a.box[2,1]) <: Periodic
        loop=:(begin 
            for iAux1_ in 1:9
                pos_ = AgentBasedModels.gridVectorPositionNeighbour_(nnPosIdCell_[ic1_],iAux1_,$(a.axisSize[1]),$periodicX,$(a.axisSize[2]),$periodicY)
                if pos_ != -1
                    max_ = nnGridCountsCum_[pos_]
                    box_ = max_ - nnGridCounts_[pos_] + 1
                    for ic2_ in box_:max_
                        ic2_ = nnCellIdPos_[ic2_]
                        $code
                    end
                end
            end
        end)
    elseif a.dim == 3
        periodicX = typeof(a.box[1,1]) <: Periodic
        periodicY = typeof(a.box[2,1]) <: Periodic
        periodicZ = typeof(a.box[3,1]) <: Periodic
        loop=:(begin 
            for iAux1_ in 1:27
                pos_ = AgentBasedModels.gridVectorPositionNeighbour_(nnPosIdCell_[ic1_],iAux1_,$(a.axisSize[1]),$periodicX,$(a.axisSize[2]),$periodicY,$(a.axisSize[3]),$periodicZ)
                if pos_ != -1
                    max_ = nnGridCountsCum_[pos_]
                    box_ = max_ - nnGridCounts_[pos_] + 1
                    for ic2_ in box_:max_
                        ic2_ = nnCellIdPos_[ic2_]
                        $code
                    end
                end
            end
        end)
    end

    loop = subs_(loop,:nnic2_,:(ic2_))
#    loop = postwalk(x->@capture(x,nnic2_) ? :(nnId_[ic2_]) : x, loop)
    loop = simpleFirstLoop_(platform, loop)

    return loop
end

