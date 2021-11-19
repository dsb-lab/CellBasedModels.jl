"""
Simulation space for N-body simulations with local interactions.
The algorithm implemented uses a fixed radial neighbours search as proposed by 
[Rama C. Hoetzlein](https://on-demand.gputechconf.com/gtc/2014/presentations/S4117-fast-fixed-radius-nearest-neighbor-gpu.pdf)
both for CPU and GPU. For now, the last step of the proposed algorithm, sorting, is ignored but the idea may be to implement for the GPU case soon if it really makes a difference.

# Constructors

    SimulationGrid(abm::Agent; box::Array{<:Any,1}, radius::Union{<:Real,Array{<:Real,1}}, medium::Array{<:Medium,1}=Array{Medium,1}())

### Arguments
 - **abm::Agent** Agent to put in the simulation space.

### Keyword arguments
 - **box::Array{<:Any,1}** Box where to put the agents. It has to be an array with objects FlatBoundary defining the behaviour of each boundary.
 - **radius::Union{<:Real,Array{<:Real,1}}** Radius of interaction of the agents. It can be a real value if isotropic interaction of a vector of the same dimensions as the agent with the radius in each direction.
 - **medium::Array{<:Medium,1}** (Default Array{Medium,1}()) Characteristics of the boundary behaviour of the medium, if it exists.
"""
struct SimulationGrid <: SimulationSpace

    box::Array{<:FlatBoundary}
    radius::Array{<:Real,1}
    dim::Int
    n::Int
    axisSize::Array{Int}
    cumSize::Array{Int}
    medium::Array{Medium,1}

end

function SimulationGrid(abm::Agent; box::Array{<:Any,1}, radius::Union{<:Real,Array{<:Real,1}}, medium::Array{<:Medium,1}=Array{Medium,1}())

    #Check dimensionality
    if length(box) == 0
        error("At least one dimension has to be declared in box.")
    elseif length(box) > 3
        error("No more than three dimensions are allowed.")
    end

    #Check medium has the same dimensions
    if abm.dims != length(medium) && length(abm.declaredSymbols["Medium"]) > 0
        error("Medium has to be specified with the same dimensions as the model. For that, it is necessary to also define a box.")
    end

    #Make consistent box format adding Bound to tuples
    box2 = Array{FlatBoundary,1}()
    for i in 1:length(box)
        if typeof(box[i])<:Tuple{Symbol,<:Real,<:Real}
            push!(box2, Bound(box[i]...))
        elseif typeof(box[i])<:FlatBoundary
            push!(box2,box[i])
        else
            error("Dimension has to be defined as a tupple with (Symbol, Real, Real) or a FlatBoundary Type.")
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

    #Check symbols
    for b in box2
        for i in keys(b.addSymbols)
            for j in b.addSymbols[i]
                checkIsDeclared_(abm,j)
            end
        end
    end

    #Check radius has the same dimension as box
    if typeof(radius)<:Real
        radius = [radius for _ in 1:length(box)]
    elseif length(radius) != length(box)
        error("Radius has to be an scalar or the same length than box.")
    end

    #Compute additional parameters for the structure
    axisSize = [ceil(Int,(i.max-i.min)/radius[j])+2 for (j,i) in enumerate(box2)]
    cum = cumprod(axisSize)
    cumSize = [1;cum[1:end-1]]
    n = cum[end]

    return SimulationGrid(box2,radius,length(vars),n,axisSize,cumSize,medium) 
end

function arguments_!(program::Program_, abm::Agent, a::SimulationGrid, platform::String)
    
    append!(program.declareVar.args, 
    (quote
        nnPosIdCell_ = zeros(Int,nMax)
        nnGridCounts_ = zeros(Int,$(a.n))
        nnGridCountsAux_ = zeros(Int,$(a.n))
        nnGridCountsCum_ = zeros(Int,$(a.n))
        nnCellIdPos_ = zeros(Int,nMax)
    end).args
    )

    #Compute the cell id for each agent in grid and linearized format for any box possible box dimensions.
    if a.dim == 1
        positionGrid=:(begin 
            nnPosIdCell_[ic1_] = AgentBasedModels.position2gridVectorPosition_($(a.box[1].s),$(a.box[1].min),$(a.radius[1]),$(a.axisSize[1]))
        end)
    elseif a.dim == 2
        positionGrid=:(begin 
            nnPosIdCell_[ic1_] = AgentBasedModels.position2gridVectorPosition_($(a.box[1].s),$(a.box[1].min),$(a.radius[1]),$(a.axisSize[1]),
                                                                $(a.box[2].s),$(a.box[2].min),$(a.radius[2]),$(a.axisSize[2]))
        end)
    elseif a.dim == 3
        positionGrid=:(begin 
            nnPosIdCell_[ic1_] = AgentBasedModels.position2gridVectorPosition_($(a.box[1].s),$(a.box[1].min),$(a.radius[1]),$(a.axisSize[1]),
                                                                $(a.box[2].s),$(a.box[2].min),$(a.radius[2]),$(a.axisSize[2]),
                                                                $(a.box[3].s),$(a.box[3].min),$(a.radius[3]),$(a.axisSize[3]))
        end)
    end
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
                        lock(lockadd_)
                            nnGridCounts_[nnPosIdCell_[ic1_]]+=1
                        unlock(lockadd_)
                    
                    end
                end
            ),

            wrapInFunction_(:countingSort_,

                #Sort the agents ids so they can be accessed by cell number
                quote
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
                end
            ),

            #Just a function to put all the steps of the algorithm together
            quote                
                function computeNN_(ARGS_)
                    
                    nnGridCounts_ .= 0
                    nnGridCountsAux_ .= 1
                    insertCounts_(ARGS_)
                    nnGridCountsCum_ .= cumsum(nnGridCounts_)
                    countingSort_(ARGS_)

                    # println(nnGridCounts_)
                    # println(nnGridCountsAux_)
                    # println(nnGridCountsCum_)
                    # println(nnPosIdCell_)
                    # println(nnCellIdPos_)

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
                    CUDA.atomic_add!(CUDA.pointer(nnGridCounts_,nnPosIdCell_[ic1_]),Int32(1))
                end

            ),

            :(insertCountsKernel_ = CUDA.@cuda launch = false insertCounts_(ARGS_)),

            simpleFirstLoopWrapInFunction_(platform, :countingSort_,

                #Sort the agents ids so they can be accessed by cell number
                quote
                    id_ = nnPosIdCell_[ic1_]
                    if id_ == 1
                        posInit_ = 0
                    else
                        posInit_ = nnGridCountsCum_[id_-1]
                    end
                    posCell_ = CUDA.atomic_add!(CUDA.pointer(nnGridCountsAux_,id_),Int32(1))
                    nnCellIdPos_[posInit_+posCell_] = ic1_
                end
  
            ),        

            :(countingSortKernel_ = CUDA.@cuda launch = false countingSort_(ARGS_)),

            #Just a function to put all the steps of the algorithm together
            quote
                function computeNN_(ARGS_)
                    
                    nnGridCounts_ .= 0
                    nnGridCountsAux_ .= 1
                    @platformAdapt insertCounts_(ARGS_)
                    nnGridCountsCum_ .= cumsum(nnGridCounts_)
                    @platformAdapt countingSort_(ARGS_)

                    return
                end
            end
        )
    else
        error("Platform should be or cpu or gpu. ", platform, " was given.")
    end

    append!(program.args, [:nnPosIdCell_,:nnGridCounts_,:nnGridCountsAux_,:nnGridCountsCum_,:nnCellIdPos_])
    #argsEval = Nothing

    #execInit = Nothing
    push!(program.execInit.args, :(computeNN_(ARGS_)))
    push!(program.execInloop.args, :(computeNN_(ARGS_)))

    #execAfter = Nothing
    
    return nothing
end

function loop_(program::Program_, abm::Agent, a::SimulationGrid, code::Expr, platform::String)

    code = vectorize_(abm, code, program)

    #Compute the cell id for each agent in grid and linearized format for any box possible box dimensions.
    if a.dim == 1
        periodicX = typeof(a.box[1]) <: Periodic
        loop=:(begin 
            for iAux1_ in 1:3
                pos_ = AgentBasedModels.gridVectorPositionNeighbour_(nnPosIdCell_[ic1_],iAux1_,$(a.axisSize[1]),$periodicX)
                if pos_ != -1
                    max_ = nnGridCountsCum_[pos_]
                    min_ = max_ - nnGridCounts_[pos_] + 1
                    for ic2_ in min_:max_
                        ic2_ = nnCellIdPos_[ic2_]
                        $code
                    end
                end
            end
        end)
    elseif a.dim == 2
        periodicX = typeof(a.box[1]) <: Periodic
        periodicY = typeof(a.box[2]) <: Periodic
        loop=:(begin 
            for iAux1_ in 1:9
                pos_ = AgentBasedModels.gridVectorPositionNeighbour_(nnPosIdCell_[ic1_],iAux1_,$(a.axisSize[1]),$periodicX,$(a.axisSize[2]),$periodicY)
                if pos_ != -1
                    max_ = nnGridCountsCum_[pos_]
                    min_ = max_ - nnGridCounts_[pos_] + 1
                    for ic2_ in min_:max_
                        ic2_ = nnCellIdPos_[ic2_]
                        $code
                    end
                end
            end
        end)
    elseif a.dim == 3
        periodicX = typeof(a.box[1]) <: Periodic
        periodicY = typeof(a.box[2]) <: Periodic
        periodicZ = typeof(a.box[3]) <: Periodic
        loop=:(begin 
            for iAux1_ in 1:27
                pos_ = AgentBasedModels.gridVectorPositionNeighbour_(nnPosIdCell_[ic1_],iAux1_,$(a.axisSize[1]),$periodicX,$(a.axisSize[2]),$periodicY,$(a.axisSize[3]),$periodicZ)
                if pos_ != -1
                    max_ = nnGridCountsCum_[pos_]
                    min_ = max_ - nnGridCounts_[pos_] + 1
                    for ic2_ in min_:max_
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