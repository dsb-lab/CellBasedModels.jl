struct NeighborsGrid <: Neighbors

    box::Array{Tuple{Symbol,<:Real,<:Real,<:Real}}
    dim::Int
    n::Int
    axisSize::Array{Int}
    cumSize::Array{Int}

end
"""
    function NeighboursGrid(agentModel::Model, vars::Array{Symbol}, box::Matrix{<:AbstractFloat}, radius::AbstractFloat)

Function that keeps track of the cells by associating them to a grid position. The neighborhood requires that the variables that define the dimensions of the grid are defined, the size of each dimension and the radius of interaction of each particle.

Example
```
m = Model()

addLocal!([:x,:y])

vars = [:x,:y] #The particles are neighbors depending on the x and y variables.
box = [[-1,-1],[1,1]] #The particles are in a square of size 2 around zero.
radius = 0.5 #The particles interact at most with particles 0.5 far appart from them.
setNeighborhoodGrid!(m,vars,box,radius)
```
"""
function NeighborsGrid(abm::Model, box::Array{<:Tuple{Symbol,<:Real,<:Real,<:Real},1})

    if length(keys(box)) == 0
        error("At least one dimension has to be declared in box.")
    elseif length(keys(box)) > 3
        error("No more than three dimensions are allowed.")
    end
    vars = [i[1] for i in box]
    checkIsDeclared_(abm,vars)
    for i in box
        if i[3] <= i[2]
            error("Superior limit is equal or smaller than inferior limit for ", i, ". The entry should be of the form (symbol,min,max,radius).")
        end
    end

    axisSize = [ceil(Int,(i[3]-i[2])/(2*i[4]))+2 for i in box]
    cum = cumprod(axisSize)
    cumSize = [1;cum[1:end-1]]
    n = cum[end]

    return NeighborsGrid(box,length(vars),n,axisSize,cumSize) 
end

function NeighborsGrid(abm::Model, box::Array{<:Tuple{Symbol,<:Real,<:Real}}, radius::Real)

    box = [(i...,radius) for i in box]

    return NeighborsGrid(abm,box)
end

function arguments_(a::NeighborsGrid,platform::String)
    
    declareVar = 
    [
    :(nnGId_ = zeros(Int,nMax,$(a.dim))),
    :(nnVId_ = zeros(Int,nMax)),
    :(nnGC_ = zeros(Int,$(a.n))),
    :(nnGCAux_ = zeros(Int,$(a.n))),
    :(nnGCCum_ = zeros(Int,$(a.n))),
    :(nnId_ = zeros(Int,nMax))
    ]

    if platform == "cpu"

        positionGrid = quote end
        positionArray = "nnVId_[ic1_] = "
        for (j,i) in enumerate(a.box)

            push!(positionGrid.args,
            :(nnGId_[ic1_,$j] = min(max(ceil(Int,($(i[1])-$(i[2]))/$(2*i[4]))+1,0),$(a.axisSize[j])))
            )

            positionArray = string(positionArray,
            "$(a.cumSize[j])*(nnGId_[ic1_,$j]-1)"
            ,"+")
        end
        positionArray = string(positionArray,"1")

        positionArray = Meta.parse(positionArray)    

        declareF = 
        quote
            function insertCounts_(ARGS_)
                lockadd_ = Threads.SpinLock()
                Threads.@threads for ic1_ = 1:N
                        $positionGrid
                        $positionArray
                        lock(lockadd_)
                            nnGC_[nnVId_[ic1_]]+=1
                        unlock(lockadd_)
                end
                return
            end  

            function countingSort_(ARGS_)
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

                return
            end          

            function computeNN_(ARGS_)
                
                nnGC_ .= 0
                nnGCAux_ .= 1
                insertCounts_(ARGS_)
                nnGCCum_ .= cumsum(nnGC_)
                countingSort_(ARGS_)

                return
            end
        end
    end

    args = [:nnGId_,:nnVId_,:nnGC_,:nnGCAux_,:nnGCCum_,:nnId_]

    argsEval = Nothing

    execInit = Nothing
    execInloop = Nothing

    execAfter = Nothing
    return declareVar, declareF, args, argsEval, execInit, execInloop, execAfter
end

"""
    function neighboursByGrid(agentModel::Model;platform="cpu")
"""
function nnFunction(a::NeighborsGrid, platform::String)
    
    #Make the position assotiation in the grid x
    l= [:(aux = min(max(ceil(Int,($(i[1])-$(i[2]))/$(2*i[4]))+1,0),$(a.axisSize[j]))) for (j,i) in enumerate(a.box)]
    position = :(begin $(l...) end)
        
    if platform == "cpu"
        :(begin
            function insertCounts_(ARGS_)
                lockadd_ = Threads.SpinLock()
                Threads.@threads for ic1_ = 1:N
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
            
            function countingSort_(ARGS_)
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

                return
            end  

            function computeNN_(ARGS_)
                
                nnGC_ .= 0
                insertCounts_(ARGS)
                nnGCCum_ = cumsum(nnGC_)
                countingSort_(ARGS)

                return
            end
        end
        )
    elseif platform == "gpu"
        push!(fDeclare,
            vectParams(agentModel,:( function insertCounts_($(comArgs...),nnVId_,nnGId_,nnGC_,nnGCAux_)
              stride_ = (blockDim()).x*(gridDim()).x
              index_ = (threadIdx()).x + ((blockIdx()).x - 1) * (blockDim()).x
              for ic1_ = index_:stride_:N
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
              for ic1_ = index_:stride_:N
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

    inLoop = loopNeighbourGridCreation(a.dim,a.dim,grid)

    return varDeclare, fDeclare, execute, inLoop, arg
    
end

function loop_(a::NeighborsGrid,code::Expr)

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

    l = [i for i in 1:a.dim][end:-1:1]
    for i in l
        
    end

    loop = subs_(loop,code,:ALGORITHM_)
    loop = subs_(loop,:nnic2_,:(nnId_[ic2_]))

    return loop
end

"""
    function loopNeighbourGridCreation(i,i0,n,x=nothing,pos="")

Auxiliar function for creating nested loops during the grid creation.
"""




function loopNeighbourGridCreation(i,i0,n,x=nothing,pos="")
    iterator = Meta.parse(string("i",i))
    if i == i0
        jump = :($(n.cumSize[i]))
        pos = string(pos,"$jump*(nnGId_[ic1_,$i]+$iterator-1)")
        x = :(for $iterator in -1:1
                if nnGId_[ic1_,$i]+$iterator > 0 && nnGId_[ic1_,$i]+$iterator <= $(n.axisSize[i])
                    posInit = nnGCCum_[POS+1]-nnGC_[POS+1]+1
                    posMax = nnGCCum_[POS+1]
                    for ic2_ in posInit:posMax
                        ALGORITHM_
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
            $x
        end
        )
        x = Meta.parse(replace(string(x),"POS"=>pos))
    end
    
    return x
end