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

function arguments_!(abm::Agent, a::SimulationGrid, data::Program_, platform::String)
    
    append!(data.declareVar.args, 
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

    #Create kernels for the algorithm
    if platform == "cpu"

        push!(data.declareF.args, 

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

                    return nothing
                end
            end
        )

    elseif platform == "gpu"
        push!(data.declareF.args, 

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
                    (threads_,blocks_) = configurator_(insertCountsKernel_,N)
                    CUDA.@cuda threads = threads_ blocks = blocks_ insertCounts_(ARGS_)
                    nnGCCum_ .= cumsum(nnGC_)
                    (threads_,blocks_) = configurator_(countingSortKernel_,N)
                    CUDA.@cuda  threads = threads_ blocks = blocks_ countingSort_(ARGS_)

                    return
                end
            end
        )
    else
        error("Platform should be or cpu or gpu. ", platform, " was given.")
    end

    append!(data.args, [:nnGId_,:nnVId_,:nnGC_,:nnGCAux_,:nnGCCum_,:nnId_])

    #argsEval = Nothing

    #execInit = Nothing
    #execInloop = Nothing

    #execAfter = Nothing
    
    return nothing
end

function loop_(a::SimulationGrid, abm::Agent, code::Expr, platform::String)

    code = vectorize_(abm, code)
    #Prototypes of loops to connect cells in the grid as neighbors
    normal = 
    quote
        for AUX1_ in -1:1
            if nnGId_[ic1_,AUX2_]+AUX1_ > 0 && nnGId_[ic1_,AUX2_]+AUX1_ <= $(n.axisSize[AUX2_])
                pos_ +=  $(n.cumSize[AUX2_])*(nnGId_[ic1_,AUX2_]+AUX1_-1)
                ALGORITHM_
            end
        end    
    end

    periodic = 
    quote
        for AUX1_ in -1:1
            if nnGId_[ic1_,AUX2_]+AUX1_ < 0
                pos_ +=  $(n.cumSize[AUX2_])*($(n.axisSize[AUX2_])-1)
                ALGORITHM_
            elseif nnGId_[ic1_,AUX2_]+AUX1_ > $(n.axisSize[AUX2_])
                pos_ +=  0
                ALGORITHM_
            else
                pos_ +=  $(n.cumSize[AUX2_])*(nnGId_[ic1_,AUX2_]+AUX1_-1)
                ALGORITHM_
            end
        end    
    end

    #Make nested loops
    loop = :(ALGORITHM_)
    for i in a.dim:-1:1
        aux = Meta.parse(string("i",i,"__"))
        if typeof(a.boundaries[i])<:NonPeriodic
            loop = subs_(loop,:ALGORITHM_,normal)
        elseif typeof(a.boundaries[i])<:Periodic
            loop = subs_(loop,:ALGORITHM_,periodic)
        end
        loop = subs_(loop,:AUX1_,aux)                        
        loop = subs_(loop,:AUX2_,i)
    end
    loop = subs_(loop,:ALGORITHM_,code)
    loop = vectorize_(abm, loop)
    loop = subs_(loop,:nnic2_,:(nnId_[ic2_]))
    loop = simpleFirstLoop_(platform, loop)

    return loop
end