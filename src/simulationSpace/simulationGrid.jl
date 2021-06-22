"""
    struct SimulationFree <: SimulationSpace

Simulation space for N-body simulations with local interactions.
The algorithm implemented uses a fixed radial neighbours search as proposed by 
[Rama C. Hoetzlein](https://on-demand.gputechconf.com/gtc/2014/presentations/S4117-fast-fixed-radius-nearest-neighbor-gpu.pdf)
both for CPU and GPU. For now, the last step of the proposed algorithm, sorting, is ignored but the idea may be to implement for the GPU case soon if it really makes a difference.
"""
struct SimulationGrid <: SimulationSpace

    box::Array{<:FlatBoundary}
    radius::Array{<:Real,1}
    dim::Int
    n::Int
    axisSize::Array{Int}
    cumSize::Array{Int}

end

function SimulationGrid(abm::Agent, box::Array{<:Union{<:Tuple{Symbol,<:Real,<:Real},<:FlatBoundary},1}, radius::Union{<:Real,Array{<:Real,1}})

    #Check dimensionality
    if length(keys(box)) == 0
        error("At least one dimension has to be declared in box.")
    elseif length(keys(box)) > 3
        error("No more than three dimensions are allowed.")
    end

    #Make consistent box format adding Open to tuples
    box2 = Array{FlatBoundary,1}()
    for i in 1:length(box)
        if typeof(box[i])<:Tuple{Symbol,<:Real,<:Real}
            push!(box2, Open(box[i]...))
        else
            push!(box2,box[i])
        end
    end

    #Check limits are correct
    vars = [i.s for i in box2]
    checkIsDeclared_(abm,vars)
    for i in box2
        if i.max <= i.min
            error("Superior limit is equal or smaller than inferior limit for ", i.s, ". The entry should be of the form (symbol,min,max,radius).")
        end
    end

    #Check radius has the same dimension as box
    if typeof(radius)<:Real
        radius = [radius for _ in 1:length(box)]
    elseif length(radius) != length(box)
        error("Radius has to be an scalar or the same length than box.")
    end

    #Compute additional parameters for the structure
    axisSize = [ceil(Int,(i.max-i.min)/(2*radius[j]))+2 for (j,i) in enumerate(box2)]
    cum = cumprod(axisSize)
    cumSize = [1;cum[1:end-1]]
    n = cum[end]

    return SimulationGrid(box2,radius,length(vars),n,axisSize,cumSize) 
end

function arguments_!(program::Program_, abm::Agent, a::SimulationGrid, platform::String)
    
    append!(program.declareVar.args, 
    (quote
        nnGId_ = zeros(Int,nMax,$(a.dim))
        nnVId_ = zeros(Int,nMax)
        nnGC_ = zeros(Int,$(a.n))
        nnGCAux_ = zeros(Int,$(a.n))
        nnGCCum_ = zeros(Int,$(a.n))
        nnId_ = zeros(Int,nMax)
    end).args
    )

    #Compute the cell id for each agent in grid and linearized format for any box possible box dimensions.
    positionGrid = quote end
    positionArray = "nnVId_[ic1_] = "
    for (j,i) in enumerate(a.box)

        push!(positionGrid.args,
        :(nnGId_[ic1_,$j] = min(max(ceil(Int,($(i.s)-$(i.min))/$(2*a.radius[j]))+1,0),$(a.axisSize[j])))
        )

        positionArray = string(positionArray,
        "$(a.cumSize[j])*(nnGId_[ic1_,$j]-1)"
        ,"+")
    end
    positionArray = Meta.parse(string(positionArray,"1"))

    positionArray = vectorize_(abm,positionArray,program)
    positionGrid = vectorize_(abm,positionGrid,program)

    #Create kernels for the algorithm
    if platform == "cpu"

        push!(program.declareF.args, 

            wrapInFunction_(:insertCounts_,

                #Assign a cell to each agent and atomic add to the cell agent count
                quote
                    lockadd_ = Threads.SpinLock()
                    Threads.@threads for ic1_ = 1:N

                        $positionGrid
                        $positionArray
                        lock(lockadd_)
                            nnGC_[nnVId_[ic1_]]+=1
                        unlock(lockadd_)
                    
                    end
                end
            ),

            wrapInFunction_(:countingSort_,

                #Sort the agents ids so they can be accessed by cell number
                quote
                    lockadd_ = Threads.SpinLock()
                    Threads.@threads for ic1_ = 1:N
                        
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
                end
            ),

            #Just a function to put all the steps of the algorithm together
            quote                
                function computeNN_(ARGS_)
                    
                    nnGC_ .= 0
                    nnGCAux_ .= 1
                    insertCounts_(ARGS_)
                    nnGCCum_ .= cumsum(nnGC_)
                    countingSort_(ARGS_)

                    println(nnGId_)
                    println(nnVId_)
                    println(nnGC_) 
                    println(nnGCAux_) 
                    println(nnGCCum_)
                    println(nnId_) 

                    return nothing
                end
            end
        )

    elseif platform == "gpu"
        push!(program.declareF.args, 

            simpleFirstLoopWrapInFunction_(platform, :insertCounts_,

                #Assign a cell to each agent and atomic add to the cell agent count
                quote
                    $positionGrid
                    $positionArray
                    CUDA.atomic_add!(CUDA.pointer(nnGC_,nnVId_[ic1_]),Int32(1))
                end

            ),

            :(insertCountsKernel_ = CUDA.@cuda launch = false insertCounts_(ARGS_)),

            simpleFirstLoopWrapInFunction_(platform, :countingSort_,

                #Sort the agents ids so they can be accessed by cell number
                quote
                    id_ = nnVId_[ic1_]
                    if id_ == 1
                        posInit_ = 0
                    else
                        posInit_ = nnGCCum_[id_-1]
                    end
                    posCell_ = CUDA.atomic_add!(CUDA.pointer(nnGCAux_,id_),Int32(1))
                    nnId_[posInit_+posCell_] = ic1_
                end
  
            ),        

            :(countingSortKernel_ = CUDA.@cuda launch = false countingSort_(ARGS_)),

            #Just a function to put all the steps of the algorithm together
            quote
                function computeNN_(ARGS_)
                    
                    nnGC_ .= 0
                    nnGCAux_ .= 1
                    @platformAdapt insertCounts_(ARGS_)
                    nnGCCum_ .= cumsum(nnGC_)
                    @platformAdapt countingSort_(ARGS_)

                    return
                end
            end
        )
    else
        error("Platform should be or cpu or gpu. ", platform, " was given.")
    end

    append!(program.args, [:nnGId_,:nnVId_,:nnGC_,:nnGCAux_,:nnGCCum_,:nnId_])

    #argsEval = Nothing

    #execInit = Nothing
    push!(program.execInit.args, :(computeNN_(ARGS_)))
    push!(program.execInloop.args, :(computeNN_(ARGS_)))

    #execAfter = Nothing
    
    return nothing
end

function loop_(program::Program_, abm::Agent, a::SimulationGrid, code::Expr, platform::String)

    code = vectorize_(abm, code, program)
    #Prototypes of loops to connect cells in the grid as neighbors
    normal = 
    quote
        for AUX1 in -1:1
            if nnGId_[ic1_,AUX2]+AUX1 > 0 && nnGId_[ic1_,AUX2]+AUX1 <= AXISSIZE
                pos_ +=  CUMSIZE*(nnGId_[ic1_,AUX2]+AUX1-1)
                ALGORITHM
            end
        end    
    end

    periodic = 
    quote
        for AUX1 in -1:1
            if nnGId_[ic1_,AUX2]+AUX1 < 0
                pos_ +=  CUMSIZE*(AXISSIZE-1)
                ALGORITHM
            elseif nnGId_[ic1_,AUX2]+AUX1 > AXISSIZE
                pos_ +=  0
                ALGORITHM
            else
                pos_ +=  CUMSIZE*(nnGId_[ic1_,AUX2]+AUX1-1)
                ALGORITHM
            end
        end    
    end

    normal0 = 
    quote
        for AUX1 in -1:1
            if nnGId_[ic1_,AUX2]+AUX1 > 0 && nnGId_[ic1_,AUX2]+AUX1 <= AXISSIZE
                pos_ =  CUMSIZE*(nnGId_[ic1_,AUX2]+AUX1-1)
                ALGORITHM
            end
        end    
    end

    periodic0 = 
    quote
        for AUX1 in -1:1
            if nnGId_[ic1_,AUX2]+AUX1 < 0
                pos_ =  CUMSIZE*(AXISSIZE-1)
                ALGORITHM
            elseif nnGId_[ic1_,AUX2]+AUX1 > AXISSIZE
                pos_ =  0
                ALGORITHM
            else
                pos_ =  CUMSIZE*(nnGId_[ic1_,AUX2]+AUX1-1)
                ALGORITHM
            end
        end    
    end

    #Make nested loops
    loop = quote ALGORITHM end
    for i in a.dim:-1:1
        aux = Meta.parse(string("i",i,"__"))
        if typeof(a.box[i])<:NonPeriodic
            if i != a.dim
                loop = postwalk(x->@capture(x,ALGORITHM) ? normal : x, loop)
            else
                loop = postwalk(x->@capture(x,ALGORITHM) ? normal0 : x, loop)
            end
        elseif typeof(a.box[i])<:Periodic
            if i != a.dim
                loop = postwalk(x->@capture(x,ALGORITHM) ? periodic : x, loop)
            else
                loop = postwalk(x->@capture(x,ALGORITHM) ? periodic0 : x, loop)
            end
        end
        loop = postwalk(x->@capture(x,AUX1) ? aux : x, loop)
        loop = postwalk(x->@capture(x,AUX2) ? i : x, loop)
        loop = postwalk(x->@capture(x,AXISSIZE) ? :($(a.axisSize[i])) : x, loop)
        loop = postwalk(x->@capture(x,CUMSIZE) ? :($(a.cumSize[i])) : x, loop)
    end
    code = :(begin
        for ic2_ in nnGCCum_[pos_]:nnGCCum_[pos_]+nnGCAux_[pos_]
            println(ic2_)
            #$code
        end
    end)
    loop = postwalk(x->@capture(x,ALGORITHM) ? code : x, loop)
    loop = vectorize_(abm, loop, program)
    loop = subs_(loop,:nnic2_,:(nnId_[ic2_]))
#    loop = postwalk(x->@capture(x,nnic2_) ? :(nnId_[ic2_]) : x, loop)
    loop = simpleFirstLoop_(platform, loop)

    return loop
end

function position2gridVectorPosition_(x,minX,dX,nX)

    pos = min(max(ceil(Int,(x-minX)/dX+1),1),nX)

    return pos
end

function position2gridVectorPosition_(x,minX,dX,nX,y,minY,dY,nY)

    posX = min(max(ceil(Int,(x-minX)/dX+1),1),nX)
    posY = min(max(ceil(Int,(y-minY)/dY+1),1),nY)

    return posX + nX * (posY-1)
end

function position2gridVectorPosition_(x,minX,dX,nX,y,minY,dY,nY,z,minZ,dZ,nZ)

    posX = min(max(ceil(Int,(x-minX)/dX+1),1),nX)
    posY = min(max(ceil(Int,(y-minY)/dY+1),1),nY)
    posZ = min(max(ceil(Int,(z-minZ)/dZ+1),1),nZ)

    return posX + nX * (posY-1) + nX * nY * (posZ-1)
end

function gridVectorPositionNeighbour(p,neighbour,nX,periodicX)
    posX = p+(neighbour-2)
    if posX == 0
        if periodicX == true
            return nX
        else
            return -1
        end
    elseif posX == nX + 1
        if periodicX == true
            return 1
        else
            return -1
        end
    else
        return posX
    end
end

function gridVectorPositionNeighbour(p,neighbour,nX,periodicX,nY,periodicY)
    posY = floor(Int,p/nX-.1) + floor(Int,neighbour/3-1/3)

    posX = (p-1)%nX + (neighbour-1)%3

    abort = false

    if posX == 0
        if periodicX == true
            posX = nX
        else
            abort = true
        end
    elseif posX == nX + 1
        if periodicX == true
            posX = 1
        else
            abort = true
        end
    end

    if posY == 0
        if periodicY == true
            posY = nY
        else
            abort = true
        end
    elseif posY == nY + 1
        if periodicY == true
            posY = 1
        else
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

function gridVectorPositionNeighbour(p,neighbour,nX,periodicX,nY,periodicY,nZ,periodicZ)

    auxZ = floor(Int,p/nX/nY-.1)
    posZ = auxZ + floor(Int,neighbour/9-1/9)

    auxY = floor(Int,(p-auxZ*nX*nY)/nX-.1)
    posY = auxY + floor(Int,neighbour/3-1/3)

    posX = ((p-auxY*nX-auxZ*nX*nY)-1)%nX + (neighbour-1)%3

    abort = false

    if posX == 0
        if periodicX == true
            posX == nX
        else
            abort = true
        end
    elseif posX == nX + 1
        if periodicX == true
            posX == 1
        else
            abort = true
        end
    end

    if posY == 0
        if periodicY == true
            posY == nY
        else
            abort = true
        end
    elseif posY == nY + 1
        if periodicY == true
            posY == 1
        else
            abort = true
        end
    end

    if posZ == 0
        if periodicZ == true
            posZ == nZ
        else
            abort = true
        end
    elseif posZ == nZ + 1
        if periodicZ == true
            posZ == 1
        else
            abort = true
        end
    end

    if abort
        return -1
    else
        return posX + nX*(posY-1) + nY*nX*(posZ-1)
    end
end