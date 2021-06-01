struct NeighborsGrid <: Neighbors

    variables::Array{Symbol}
    box::Matrix{AbstractFloat}
    radius::Array{AbstractFloat}

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
function NeighboursGrid(vars::Array{Symbol}, box::Matrix{<:AbstractFloat}, radius::AbstractFloat)

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

    return NeighborsGrid(vars,box,ones(length(vars))*radius,length(vars),n,axisSize,cumSize) 
end

function arguments(algorithm::NeighborsFull)
    return [
    :(nnGId_ = @ARRAY_zeros(Int,nMax,$(algorithm.dim))),
    :(nnVId_ = @ARRAY_zeros(Int,nMax)),
    :(nnGC_ = @ARRAY_zeros(Int,$(algorithm.n))),
    :(nnGCAux_ = @ARRAY_zeros(Int,$(algorithm.n))),
    :(nnGCCum_ = @ARRAY_zeros(Int,$(algorithm.n))),
    :(nnId_ = @ARRAY_zeros(Int,nMax))]
end

function loop(algorithm::NeighborsFull,code:Expr)

    loop = loopNeighbourGridCreation(algorithm.dim,algorithm.dim,algorithm)

    subs!(loop,code,:ALGORITHMS_)
    subs!(loop,:nnic2_,:(nnId_[ic2_]))

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
            $x
        end
        )
        x = Meta.parse(replace(string(x),"POS"=>pos))
    end
    
    return x
end

"""
    function neighboursByGrid(agentModel::Model;platform="cpu")
"""
function nnFunction(algorithm::NeighborsFull, platform::String)
    
    #Make the position assotiation in the grid x
    l= [:(
    begin 
        aux = floor(Int,($(algorithm.variables[i])-$(algorithm.box[i][1]))/$(algorithm.radius[i]*2))+1
        if aux < 1
            position_ += 0
            nnGId_[ic1_,$i] = 1 
        elseif aux > $(algorithm.axisSize[i])
            position_ += $(algorithm.axisSize[i]-1)*$(algorithm.cumSize[i])
            nnGId_[ic1_,$i] = $(algorithm.axisSize[i])
        else
            position_ += (aux-1)*$(algorithm.cumSize[i])
            nnGId_[ic1_,$i] = aux
        end
    end) for i in 1:length(algorithm.variables)]
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
        push!(fDeclare,
            vectParams(agentModel,:( function countingSort_($(comArgs...),nnVId_,nnGC_,nnGCAux_,nnGCCum_,nnId_)
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

               # println(nnVId_[nnId_])
                return
            end    
            )))     
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

    inLoop = loopNeighbourGridCreation(algorithm.dim,algorithm.dim,grid)

    return varDeclare, fDeclare, execute, inLoop, arg
    
end