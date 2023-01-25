function neighborsFunction(agent)

    if agent.neighbors == :Full

        agent.declaredUpdatesFunction[:ComputeNeighbors] = neighborsFull!
    
    elseif agent.neighbors == :VerletTime

        agent.declaredUpdatesFunction[:ComputeNeighbors] = 
                eval(Meta.parse(string("neighborsVerletTime$(agent.dims)$(agent.platform)!")))

    elseif agent.neighbors == :VerletDisplacement
    
        agent.declaredUpdatesFunction[:ComputeNeighbors] = 
                eval(Meta.parse(string("neighborsVerletDisplacement$(agent.dims)$(agent.platform)!")))
    
    elseif agent.neighbors == :CellLinked
    
        agent.declaredUpdatesFunction[:ComputeNeighbors] = 
                eval(Meta.parse(string("neighborsCellLinked$(agent.dims)$(agent.platform)!")))
    
    elseif agent.neighbors == :VerletGrid
    
        agent.declaredUpdatesFunction[:ComputeNeighbors] = Main.eval(:((community) -> AgentBasedModels.neighborsGridVerlet!($(agentArgs(:community)...))))
    
    else
    
        error("Neighbors method is not defined.")
    
    end

end

function neighborsLoop(code,agent)

    if agent.neighbors == :Full

        code = neighborsFullLoop(code,agent)

    elseif agent.neighbors == :VerletTime

        code = neighborsVerletLoop(code,agent)

    elseif agent.neighbors == :VerletDisplacement

        code = neighborsVerletLoop(code,agent)

    elseif agent.neighbors == :CellLinked

        code = neighborsCellLinkedLoop(code,agent)

    elseif agent.neighbors == :VerletGrid

        error("Not done yet.")

    else

        error("Neighbors method is not defined.")

    end

    return code

end

function computeNeighbors!(community)

    community.agent.declaredUpdatesFunction[:ComputeNeighbors](community)

end

#Full
function neighborsFullLoop(code,agent)

    return makeSimpleLoop(:(for i2_ in 1:1:N[1]; if i1_ != i2_; $code; end; end), agent)

end

function neighborsFull!(community)

    return nothing

end


#Verlet
function neighborsVerletLoop(code,agent) #Macro to create the second loop in functions
    
    #Go over the list of neighbors
    code = postwalk(x->@capture(x,h_) && h == :i2_ ? :(neighborList_[i1_,i2_]) : x, code)
    #make loop
    code = makeSimpleLoop(:(for i2_ in 1:1:neighborN_[i1_]; $code; end), agent)
    
    return code


end

macro verletNeighbors(platform, args...) #Macro to make the verletNeighbor loops

    base = agentArgs(l=length(args))

    args2 = []
    for i in args
        append!(args2,[:($i[i1_]),:($i[i2_])])
    end

    name = Meta.parse("verletNeighbors$(platform)!")

    code = 0
    if platform == :CPU
        code = :(
            function $name($(base...))
                @inbounds Threads.@threads for i1_ in 1:1:N[1]
                    lk = ReentrantLock()
                    for i2_ in (i1_+1):1:N[1]
                        d = euclideanDistance($(args2...))
                        if d < skin[1]
                            lock(lk) do
                                neighborN_[i1_] += 1
                                neighborList_[i1_,neighborN_[i1_]] = i2_
                                neighborN_[i2_] += 1
                                neighborList_[i2_,neighborN_[i2_]] = i1_
                            end
                        end
                    end
                end
            end
        )
    elseif platform == :GPU
        code = :(
            function $name($(base...))
                index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                stride = gridDim().x * blockDim().x
                @inbounds for i1_ in index:stride:N[1]
                    for i2_ in (i1_+1):1:N[1]
                        d = euclideanDistance($(args2...))
                        if d < skin[1]
                            pos1 = CUDA.atomic_add!(CUDA.pointer(neighborN_,i1_),Int32(1)) + 1
                            pos2 = CUDA.atomic_add!(CUDA.pointer(neighborN_,i2_),Int32(1)) + 1
                            neighborList_[i1_,pos1] = i2_
                            neighborList_[i2_,pos2] = i1_
                        end
                    end
                end

                return
            end
        )
    end

    return code

end

@verletNeighbors CPU x
@verletNeighbors CPU x y
@verletNeighbors CPU x y z
@verletNeighbors GPU x
@verletNeighbors GPU x y
@verletNeighbors GPU x y z


    #Verlet Time
macro neighborsVerletTime(platform, args...)

    base = agentArgs(:community,l=length(args))
    
    namef = Meta.parse("verletNeighbors$(platform)!")
    name = Meta.parse(string("neighborsVerletTime$(length(args))$(platform)!"))
    if platform == :CPU
        code = :(
            function $name(community)

                if CUDA.@allowscalar community.neighborTimeLastRecompute_[1] <= community.t[1]
                    community.neighborN_ .= 0
                    $namef($(base...),)
                    community.neighborTimeLastRecompute_ .+= community.dtNeighborRecompute
                elseif CUDA.@allowscalar community.flagRecomputeNeighbors_[1] .== 1
                    community.neighborN_ .= 0
                    $namef($(base...),)
                    community.neighborTimeLastRecompute_ .= community.t + community.dtNeighborRecompute
                    community.flagRecomputeNeighbors_ .= 0
                end

                return

            end
        )
    else
        code = :(
            function $name(community)
            
                kernel = @cuda launch=false $namef($(base...),)
                if CUDA.@allowscalar community.neighborTimeLastRecompute_[1] <= community.t[1]
                    community.neighborN_ .= 0
                    kernel($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                    community.neighborTimeLastRecompute_ .+= community.dtNeighborRecompute
                elseif CUDA.@allowscalar community.flagRecomputeNeighbors_[1] .== 1
                    community.neighborN_ .= 0
                    kernel($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                    community.neighborTimeLastRecompute_ .= community.t + community.dtNeighborRecompute
                    community.flagRecomputeNeighbors_ .= 0
                end
            
                return
            
            end
        )
    end

    return code
end

@neighborsVerletTime CPU x
@neighborsVerletTime CPU x y
@neighborsVerletTime CPU x y z
@neighborsVerletTime GPU x
@neighborsVerletTime GPU x y
@neighborsVerletTime GPU x y z

    #Verlet Displacement
macro verletDisplacement(platform, args...)

    base = agentArgs(l=length(args))
    
    args3 = []
    for (pos,i) in enumerate(args)
        append!(args3,[:($i[i1_]),:(posOld_[i1_,$pos])])
    end

    name = Meta.parse("verletDisplacement$(platform)!")

    code = 0
    if platform == :CPU
        code = :(
            function $name($(base...))

                @inbounds Threads.@threads for i1_ in 1:1:N[1]
                    accumulatedDistance_[i1_] = euclideanDistance($(args3...))
                    if accumulatedDistance_[i1_] >= skin[1]/2
                        flagRecomputeNeighbors_[1] = 1
                    end
                end

                return 

            end
        )
    else
        code = :(
            function $name($(base...))

                index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                stride = gridDim().x * blockDim().x

                @inbounds for i1_ in index:stride:N[1]
                    accumulatedDistance_[i1_] = euclideanDistance($(args3...))
                    if accumulatedDistance_[i1_] >= skin[1]/2
                        flagRecomputeNeighbors_[1] = 1
                    end
                end

                return 

            end
        )
    end

    return code
end

@verletDisplacement CPU x
@verletDisplacement CPU x y
@verletDisplacement CPU x y z
@verletDisplacement GPU x
@verletDisplacement GPU x y
@verletDisplacement GPU x y z

macro verletResetDisplacement(platform, args...)

    base = agentArgs(l=length(args))
    
    up = quote end
    for (pos,i) in enumerate(args)
        push!(up.args,:(posOld_[i1_,$pos]=$i[i1_]))
    end

    name = Meta.parse("verletResetDisplacement$(platform)!")

    code = 0
    if platform == :CPU
        code = :(
            function $name($(base...))

                @inbounds Threads.@threads for i1_ in 1:1:N[1]
                    $up
                end

                return 

            end
        )
    else
        code = :(
            function $name($(base...))

                index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                stride = gridDim().x * blockDim().x

                @inbounds for i1_ in index:stride:N[1]
                    $up
                end

                return 

            end
        )
    end

    return code
end

@verletResetDisplacement CPU x
@verletResetDisplacement CPU x y
@verletResetDisplacement CPU x y z
@verletResetDisplacement GPU x
@verletResetDisplacement GPU x y
@verletResetDisplacement GPU x y z

macro neighborsVerletDisplacement(platform, args...)

    base = agentArgs(:community,l=length(args))
    name = Meta.parse(string("neighborsVerletDisplacement$(length(args))$(platform)!"))

    nameNeigh = Meta.parse(string("verletNeighbors$(platform)!"))
    nameDisp = Meta.parse(string("verletDisplacement$(platform)!"))
    nameResDisp = Meta.parse(string("verletResetDisplacement$(platform)!"))

    code = 0
    if platform == :CPU
        code = :(
            function $name(community)


                $nameDisp($(base...),)
                if community.flagRecomputeNeighbors_[1] == 1
                    community.neighborN_ .= 0
                    community.accumulatedDistance_ .= 0.
                    community.flagRecomputeNeighbors_ .= 0
                    $nameResDisp($(base...))
                    $nameNeigh($(base...),)
                end

                return

            end
        )
    else
        code = :(
            function $name(community)

                kernelDisp = @cuda launch=false $nameDisp($(base...),)
                kernelResDisp = @cuda launch=false $nameResDisp($(base...),)
                kernelNeigh = @cuda launch=false $nameNeigh($(base...),)
                
                kernelDisp($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                if CUDA.@allowscalar community.flagRecomputeNeighbors_[1] == 1
                    community.neighborN_ .= 0
                    community.accumulatedDistance_ .= 0.
                    community.flagRecomputeNeighbors_ .= 0
                    kernelResDisp($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                    kernelNeigh($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                end

                return

            end
        )
    end

    return code
end

@neighborsVerletDisplacement CPU x
@neighborsVerletDisplacement CPU x y
@neighborsVerletDisplacement CPU x y z
@neighborsVerletDisplacement GPU x
@neighborsVerletDisplacement GPU x y
@neighborsVerletDisplacement GPU x y z

#Grid
cellPos(edge,x,xMin,xMax,nX) = if x > xMax nX elseif x < xMin 1 else Int((x-xMin)÷edge)+2 end
cellPos(edge,x,xMin,xMax,nX,y,yMin,yMax,nY) = cellPos(edge,x,xMin,xMax,nX) + nX*(cellPos(edge,y,yMin,yMax,nY)-1)
cellPos(edge,x,xMin,xMax,nX,y,yMin,yMax,nY,z,zMin,zMax,nZ) = cellPos(edge,x,xMin,xMax,nX) + nX*(cellPos(edge,y,yMin,yMax,nY)-1) + nX*nY*(cellPos(edge,z,zMin,zMax,nZ)-1)

function cellPosNeigh(pos,i,nX)
    p = pos + (i - 2)
    if p < 1 || p > nX
        return -1
    else
        return p
    end
end

function cellPosNeigh(pos,i,nX,nY)
    p = pos + 3*((i ÷ 3) - 1) + ((i % 3) - 1)
    posy = p ÷ nX
    posx = p - nX * posy
    px = posx +i - 2
    py = posy +i - 2
    if px < 0 || px > nX || py < 0 || py > nY
        return -1
    else
        return p
    end
end

function neighborsCellLinkedLoop(code,agent)

    args = Any[:(pos_),:(i3_)]
    for i in 1:agent.dims
        append!(args,[:(nCells_[$i])])
    end

    args2 = Any[:(cellEdge[1])]
    for (i,j) in enumerate(POSITIONPARAMETERS[1:agent.dims])
        append!(args2,[:($j[i1_]),:(simBox[$i,1]),:(simBox[$i,2]),:(nCells_[$i])])
    end

    code = quote 
                pos_ = AgentBasedModels.cellPos($(args2...))
                for i3_ in 1:1:$(3^agent.dims) #Go over the posible neighbor cells
                    posNeigh_ = AgentBasedModels.cellPosNeigh($(args...)) #Obtain the position of the neighbor cell
                    # println(i1_," ",i3_," ",posNeigh_)
                    if posNeigh_ != -1 #Ignore cells outside the boundaries
                        for i4_ in cellCumSum_[posNeigh_]-cellNumAgents_[posNeigh_]+1:1:cellCumSum_[posNeigh_] #Go over the cells of that neighbor cell
                            i2_ = cellAssignedToAgent_[i4_]
                            # println("\t"," ",i4_," ",i2_)
                            if i1_ != i2_
                                $code 
                            end
                        end
                    end
                    # println()
                end
            end 

    code = makeSimpleLoop(code, agent)

    return code

end

macro assignCells(platform, args...)

    base = agentArgs(l=length(args))

    args2 = Any[:(cellEdge[1])]
    for (i,j) in enumerate(args)
        append!(args2,[:($j[i1_]),:(simBox[$i,1]),:(simBox[$i,2]),:(nCells_[$i])])
    end

    name = Meta.parse(string("assignCells$(length(args))$(platform)!"))

    code = 0
    if platform == :CPU
        code = :(
            function $name($(base...))

                @inbounds Threads.@threads for i1_ in 1:1:N[1]
                    pos = cellPos($(args2...))
                    lk = ReentrantLock()
                    lock(lk) do
                        cellNumAgents_[pos] += 1
                    end
                end

                return
            end
        )
    else
        code = :(
            function $name($(base...))

                index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                stride = gridDim().x * blockDim().x
                @inbounds for i1_ in index:stride:N[1]
                    pos = cellPos($(args2...))
                    CUDA.atomic_add!(CUDA.pointer(cellNumAgents_,pos),Int32(1))
                end

                return
            end
        )
    end

    return code
end

@assignCells CPU x
@assignCells CPU x y
@assignCells CPU x y z
@assignCells GPU x
@assignCells GPU x y
@assignCells GPU x y z

macro sortAgentsInCells(platform, args...)

    base = agentArgs(l=length(args))

    args2 = Any[:(cellEdge[1])]
    for (i,j) in enumerate(args)
        append!(args2,[:($j[i1_]),:(simBox[$i,1]),:(simBox[$i,2]),:(nCells_[$i])])
    end

    name = Meta.parse(string("sortAgentsInCells$(length(args))$(platform)!"))

    code = 0
    if platform == :CPU
        code = :(
            function $name($(base...))

                @inbounds Threads.@threads for i1_ in 1:1:N[1]
                    pos = cellPos($(args2...))
                    lk = ReentrantLock()
                    lock(lk) do
                        cellCumSum_[pos] += 1
                        pos = cellCumSum_[pos]
                        cellAssignedToAgent_[pos] = i1_
                    end
                end

                return
            end
        )
    else
        code = :(
            function $name($(base...))

                index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                stride = gridDim().x * blockDim().x
                @inbounds for i1_ in index:stride:N[1]
                    pos = cellPos($(args2...))
                    pos = CUDA.atomic_add!(CUDA.pointer(cellCumSum_,pos),Int32(1)) + 1
                    cellAssignedToAgent_[pos] = i1_
                end

                return
            end
        )
    end

    return code
end

@sortAgentsInCells CPU x
@sortAgentsInCells CPU x y
@sortAgentsInCells CPU x y z
@sortAgentsInCells GPU x
@sortAgentsInCells GPU x y
@sortAgentsInCells GPU x y z

macro neighborsCellLinked(platform, args...)

    base = agentArgs(:community,l=length(args))

    name = Meta.parse(string("neighborsCellLinked$(length(args))$(platform)!"))
    namef = Meta.parse(string("assignCells$(length(args))$(platform)!"))
    namef2 = Meta.parse(string("sortAgentsInCells$(length(args))$(platform)!"))

    code = 0
    if platform == :CPU
        code = :(
            function $name(community)

                @views community.cellNumAgents_[1:community.N[1]] .= 0
                $namef($(base...),)
                community.cellCumSum_ .= cumsum(community.cellNumAgents_) .- community.cellNumAgents_
                $namef2($(base...),)

                return 
            end
        )
    else
        code = :(
            function $name(community)

                community.cellNumAgents_ .= 0
                kernel = @cuda launch=false $namef($(base...),)
                kernel($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                community.cellCumSum_ .= cumsum(community.cellNumAgents_) .- community.cellNumAgents_
                kernel2 = @cuda launch=false $namef2($(base...),)
                kernel2($(base...);threads=community.platform.threads,blocks=community.platform.threads)

                return 
            end
        )
    end

    return code
end

@neighborsCellLinked CPU x
@neighborsCellLinked CPU x y
@neighborsCellLinked CPU x y z
@neighborsCellLinked GPU x
@neighborsCellLinked GPU x y
@neighborsCellLinked GPU x y z

#VerletLinkedCell
macro neighborsVerletGridLoop(code,agent)

    error("TO DO")

end

function neighborsVerletGridLoop(neighborsList,neighborsN,radiusVelvet,N)

    error("TO DO")

end