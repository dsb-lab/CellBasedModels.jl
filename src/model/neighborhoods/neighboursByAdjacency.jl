"""
    struct NeighboursAdjacency <: Neighbours
"""
struct NeighboursAdjacency <: Neighbours

    condition::String
    nMax::Int

end

"""
    function setNeighborhoodAdjacency!(agentModel::Model, condition::String, nMax::Int)

Function that creates a track of neighbours based depending on a condition. 
It also requires an estimation of the maximum amount of neighbours that a particle will have, 
the program will crash if during the evolution, the particle finds more than nMax particles fullfilling the condition.

Examples
```
m = Model()

addLocal!([:x,:y])

condition= #Euler distance
"
sqrt((x₁-x₂)^2+(y₁-y₂)^2) < 1.
"
setNeighborhoodAdjacency!(m,condition,nMax=50) #No more than 50 particles will be in the neighborhood at any time
```
"""
function setNeighborhoodAdjacency!(agentModel::Model, condition::String, nMax::Int)

    agentModel.evolve = needCompilation
    
    agentModel.neighborhood = NeighboursAdjacency(condition,nMax) 
    
    return
end

"""
    function neighboursByAdjacency(agentModel::Model;platform="cpu")
"""
function neighboursByAdjacency(agentModel::Model;platform="cpu")

    condition = deepcopy(agentModel.neighborhood.condition)
    neighMax_ = agentModel.neighborhood.nMax

    #Add declaring variables
    varDeclare = Expr[]
    push!(varDeclare,:(nnN_ = @ARRAY_zeros(Int,nMax_)))
    push!(varDeclare,:(nnList_ = @ARRAY_zeros(Int,nMax_,$neighMax_)))
    varDeclare = platformAdapt(varDeclare,platform=platform)

    fDeclare = Expr[]
    #Add declaring functions
    comArgs = commonArguments(agentModel)
    if platform == "cpu"
    push!(fDeclare,
        subs(:( function nnUpdate_($(comArgs...),nnN_,nnList_)
            Threads.@threads for ic1_ in 1:N_
                nnN_[ic1_] = 0
            end
            Threads.@threads for ic1_ in 1:N_
                for ic2_ in ic1_:N_
                    if $(vectParams(agentModel,condition))
                        nnN_[ic1_] += 1
                        nnList_[ic1_,nnN_[ic1_]] = ic2_
                        if ic1_ != ic2_
                            nnN_[ic2_] += 1
                            nnList_[ic2_,nnN_[ic2_]] = ic1_ 
                        end
                    end
                end
            end
                        
            return
        end    
        ),:nnic2_,:ic2_)
        )
    elseif platform == "gpu"
    push!(fDeclare,
        subs(:( function nnUpdate_($(comArgs...),nnN_,nnList_)
        strideX_ = (blockDim()).x*(gridDim()).x
        strideY_ = (blockDim()).y*(gridDim()).y
        indexX_ = (threadIdx()).x + ((blockIdx()).x - 1) * (blockDim()).x
        indexY_ = (threadIdx()).y + ((blockIdx()).y - 1) * (blockDim()).y
        for ic1_ = indexX_:strideX_:N_
            for ic2_ = indexY_+ic1_-1:strideY_:N_
                    if $(vectParams(agentModel,condition))
                        pos = CUDA.atomic_add!(pointer(nnN_,ic1_),1) + 1
                        nnList_[ic1_,pos]=ic2_
                        if ic1_ != ic2_
                            pos = CUDA.atomic_add!(pointer(nnN_,ic2_),1) + 1
                            nnList_[ic2_,pos]=ic1_
                        end
                    end
                end
            end
                        
            return
        end    
        ),:nnic2_,:ic2_)
        )    
    end
    #Add execution time functions
    execute = Expr[]
    if platform == "cpu"
        push!(execute,
        :(
        nnUpdate_($(comArgs...),nnN_,nnList_)
            )
            )
    elseif platform == "gpu"
        push!(execute,
        :(
        nnN_ .= 0
        )
        )
        push!(execute,
        :(
        CUDA.@cuda threads=(16,16) blocks=(100,100) nnUpdate_($(comArgs...),nnN_,nnList_) #Has to be changed
        )
        )
    end

    count = Meta.parse("nnN_[ic1_]")
    arg = Symbol[Meta.parse("nnN_"),Meta.parse("nnList_")]
    inLoop = 
    :(
    for ic2_ in 1:$count
        ALGORITHMS_
    end    
    )

    return varDeclare, fDeclare, execute, inLoop, arg

end

function inloopByAdjacency(agentModel)

    count = Meta.parse("nnN_[ic1_]")
    arg = Symbol[Meta.parse("nnN_"),Meta.parse("nnList_")]
    inLoop = 
    :(
    for ic2_ in 1:$count
        ALGORITHMS_
    end    
    )

    return inLoop, arg
end

"""
    function neighboursByAdjacencyAdapt(entry)
"""
function neighboursByAdjacencyAdapt(entry)

    entry = subs(entry,:nnic2_,:(nnList_[ic1_,ic2_]))

    return entry

end