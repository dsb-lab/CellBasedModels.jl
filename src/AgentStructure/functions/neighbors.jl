"""
    function neighborsFunction(agent)

Assigns the neighbors computation method to the agent.
"""
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
    
    elseif agent.neighbors == :CLVD

        agent.declaredUpdatesFunction[:ComputeNeighbors] = 
                eval(Meta.parse(string("neighborsCLVD$(agent.dims)$(agent.platform)!")))
    
    else
    
        error("Neighbors method is not defined.")
    
    end

end

"""
    function neighborsLoop(code,agent)

For the updateInteraction loop, create the double loop to go over all the agents and neighbors.
"""
function neighborsLoop(code,it,agent)

    if agent.neighbors == :Full

        code = neighborsFullLoop(code,it,agent)

    elseif agent.neighbors == :VerletTime

        code = neighborsVerletLoop(code,it,agent)

    elseif agent.neighbors == :VerletDisplacement

        code = neighborsVerletLoop(code,it,agent)

    elseif agent.neighbors == :CellLinked

        code = neighborsCellLinkedLoop(code,it,agent)

    elseif agent.neighbors == :CLVD

        code = neighborsVerletLoop(code,it,agent)

    else

        error("Neighbors method is not defined.")

    end

    return code

end

"""
    function computeNeighbors!(community)

Function that computes the neighbors of the community according the defined neighbor algorithm in Agent.
"""
function computeNeighbors!(community)

    community.agent.declaredUpdatesFunction[:ComputeNeighbors](community)

end

#Full
"""
    function neighborsFullLoop(code,agent)

Wrapper loop for full neighbors algorithm.
"""
function neighborsFullLoop(code,it,agent)

    return :(for $it in 1:1:N[1]; if i1_ != $it; $code; end; end)

end

"""
    function neighborsFull!(community)

Function that computes the neighbors of the full connected algorithm.
"""
function neighborsFull!(community)

    return nothing

end

#Verlet
"""
    function neighborsVerletLoop(code,agent)

Wrapper loop for verlet neighbors algorithms.
"""
function neighborsVerletLoop(code,it,agent) #Macro to create the second loop in functions
    
    #Go over the list of neighbors
    code = postwalk(x->@capture(x,h_) && h == it ? :(neighborList_[i1_,$it]) : x, code)
    #make loop
    code = :(for $it in 1:1:neighborN_[i1_]; $code; end)
    
    return code

end

"""
    macro verletNeighbors(platform, args...)

Macro to generate the code for the computation of Verlet lists for different platforms and dimensions.

Adds the following functions to the library:

    verletNeighborsCPU!(x)
    verletNeighborsCPU!(x,y)
    verletNeighborsCPU!(x,y,z)
    verletNeighborsGPU!(x)
    verletNeighborsGPU!(x,y)
    verletNeighborsGPU!(x,y,z)
"""
macro verletNeighbors(platform, args...) #Macro to make the verletNeighbor loops

    base = agentArgsNeighbors(args)

    args2 = []
    for i in args
        append!(args2,[:($i[i1_]),:($i[i2_])])
    end

    name = Meta.parse("verletNeighbors$(platform)!")

    code = 0
    if platform == :CPU
        code = :(
            function $name($(base...))
                @inbounds for i1_ in 1:1:N[1] #Lack multithreading because of race
                    # lk = ReentrantLock()
                    for i2_ in (i1_+1):1:N[1]
                        d = euclideanDistance($(args2...))
                        if d < skin[1] 
                            # lock(lk) do
                                neighborN_[i1_] += 1
                                neighborN_[i2_] += 1
                                neighborList_[i1_,neighborN_[i1_]] = i2_
                                neighborList_[i2_,neighborN_[i2_]] = i1_
                            # end
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

"""
    verletNeighborsCPU!(x)
    verletNeighborsCPU!(x,y)
    verletNeighborsCPU!(x,y,z)
    verletNeighborsGPU!(x)
    verletNeighborsGPU!(x,y)
    verletNeighborsGPU!(x,y,z)

Functions generated that compute Verlet lists for CPU/GPU and 1/2/3 dimensions.
"""
@verletNeighbors CPU x
@verletNeighbors CPU x y
@verletNeighbors CPU x y z
@verletNeighbors GPU x
@verletNeighbors GPU x y
@verletNeighbors GPU x y z


    #Verlet Time
"""
    macro neighborsVerletTime(platform, args...)

Macro to generate the code for the computation of Verlet lists updated by Verlet Time algorithm.

Adds the following functions to the library: 

    neighborsVerletTime1CPU!(community)
    neighborsVerletTime2CPU!(community)
    neighborsVerletTime3CPU!(community)
    neighborsVerletTime1GPU!(community)
    neighborsVerletTime2GPU!(community)
    neighborsVerletTime3GPU!(community)
"""
macro neighborsVerletTime(platform, args...)

    base = agentArgsNeighbors(args,sym=:community)
    
    namef = Meta.parse("verletNeighbors$(platform)!")
    name = Meta.parse(string("neighborsVerletTime$(length(args))$(platform)!"))
    if platform == :CPU
        code = :(
            function $name(community)

                if community.neighborTimeLastRecompute_[1] <= community.t[1] || community.flagRecomputeNeighbors_[1] .== 1
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
                if CUDA.@allowscalar community.neighborTimeLastRecompute_[1] <= community.t[1] || CUDA.@allowscalar community.flagRecomputeNeighbors_[1] .== 1
                    CUDA.@sync community.neighborN_ .= 0
                    CUDA.@sync kernel($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                    CUDA.@sync community.neighborTimeLastRecompute_ .= community.t + community.dtNeighborRecompute
                    CUDA.@sync community.flagRecomputeNeighbors_ .= 0
                end
            
                return
            
            end
        )
    end

    return code
end

"""
    neighborsVerletTime1CPU!(community)
    neighborsVerletTime2CPU!(community)
    neighborsVerletTime3CPU!(community)
    neighborsVerletTime1GPU!(community)
    neighborsVerletTime2GPU!(community)
    neighborsVerletTime3GPU!(community)

Functions generated that computes Verlet lists for CPU/GPU and 1/2/3 dimensions when updating according to the Verlet Time Algorithm.
"""
@neighborsVerletTime CPU x
@neighborsVerletTime CPU x y
@neighborsVerletTime CPU x y z
@neighborsVerletTime GPU x
@neighborsVerletTime GPU x y
@neighborsVerletTime GPU x y z

    #Verlet Displacement
"""
    macro verletDisplacement(platform, args...)

Macro to generate the code for the check of Verlet lists recomputation flag according to Verlet Displacement algorithm.

Adds the following functions to the library:

    verletDisplacementCPU!(x)
    verletDisplacementCPU!(x,y)
    verletDisplacementCPU!(x,y,z)
    verletDisplacementGPU!(x)
    verletDisplacementGPU!(x,y)
    verletDisplacementGPU!(x,y,z)
"""
macro verletDisplacement(platform, args...)

    base = agentArgsNeighbors(args)
    
    args3 = []
    for (pos,i) in enumerate(args)
        append!(args3,[:($i[i1_]),:(posOld_[i1_,$pos])])
    end

    name = Meta.parse("verletDisplacement$(platform)!")

    code = 0
    if platform == :CPU
        code = :(
            function $name($(base...))

                @inbounds for i1_ in 1:1:N[1]
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

"""
    verletDisplacementCPU!(x)
    verletDisplacementCPU!(x,y)
    verletDisplacementCPU!(x,y,z)
    verletDisplacementGPU!(x)
    verletDisplacementGPU!(x,y)
    verletDisplacementGPU!(x,y,z)

Functions generated that compute total displacement of agents from last Verlet neighbor computation and flags if recomputation has to be made for CPU/GPU and 1/2/3 dimensions.
"""
@verletDisplacement CPU x
@verletDisplacement CPU x y
@verletDisplacement CPU x y z
@verletDisplacement GPU x
@verletDisplacement GPU x y
@verletDisplacement GPU x y z

"""
    macro verletResetDisplacement(platform, args...)

Macro to generate the code to store the positions of the agents in the last recomputation of Verlet lists for Verlet Displacement algorithm.

Adds the following functions to the library:

    verletResetDisplacementCPU!(x)
    verletResetDisplacementCPU!(x,y)
    verletResetDisplacementCPU!(x,y,z)
    verletResetDisplacementGPU!(x)
    verletResetDisplacementGPU!(x,y)
    verletResetDisplacementGPU!(x,y,z)
"""
macro verletResetDisplacement(platform, args...)

    base = agentArgsNeighbors(args)
    
    up = quote end
    for (pos,i) in enumerate(args)
        push!(up.args,:(posOld_[i1_,$pos]=$i[i1_]))
    end

    name = Meta.parse("verletResetDisplacement$(platform)!")

    code = 0
    if platform == :CPU
        code = :(
            function $name($(base...))

                @inbounds for i1_ in 1:1:N[1]
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

"""
    verletResetDisplacementCPU!(x)
    verletResetDisplacementCPU!(x,y)
    verletResetDisplacementCPU!(x,y,z)
    verletResetDisplacementGPU!(x)
    verletResetDisplacementGPU!(x,y)
    verletResetDisplacementGPU!(x,y,z)

Functions generated that assigns the current positions of the agents at which Verlet neighbor have been recomputed for CPU/GPU and 1/2/3 dimensions.
"""
@verletResetDisplacement CPU x
@verletResetDisplacement CPU x y
@verletResetDisplacement CPU x y z
@verletResetDisplacement GPU x
@verletResetDisplacement GPU x y
@verletResetDisplacement GPU x y z

"""
    macro neighborsVerletDisplacement(platform, args...)

Macro to generate the code for the computation of Verlet lists updated by Verlet Displacement algorithm.
This function puts together the action of:
 - verletDisplacement
 - resetVerletDisplacement
 - verletList

Adds the following functions to the library:

    neighborsVerletDisplacement1CPU!(community)
    neighborsVerletDisplacement2CPU!(community)
    neighborsVerletDisplacement3CPU!(community)
    neighborsVerletDisplacement1GPU!(community)
    neighborsVerletDisplacement2GPU!(community)
    neighborsVerletDisplacement3GPU!(community)
"""
macro neighborsVerletDisplacement(platform, args...)

    base = agentArgsNeighbors(args,sym=:community)
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
                
                CUDA.@sync kernelDisp($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                if CUDA.@allowscalar community.flagRecomputeNeighbors_[1] == 1
                    community.neighborN_ .= 0
                    community.accumulatedDistance_ .= 0.
                    community.flagRecomputeNeighbors_ .= 0
                    CUDA.@sync kernelResDisp($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                    CUDA.@sync kernelNeigh($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                end

                return

            end
        )
    end

    return code
end

"""
    neighborsVerletDisplacement1CPU!(community)
    neighborsVerletDisplacement2CPU!(community)
    neighborsVerletDisplacement3CPU!(community)
    neighborsVerletDisplacement1GPU!(community)
    neighborsVerletDisplacement2GPU!(community)
    neighborsVerletDisplacement3GPU!(community)

Functions generated that computes Verlet lists for CPU/GPU and 1/2/3 dimensions when updating according to the Verlet Time Algorithm.
"""
@neighborsVerletDisplacement CPU x
@neighborsVerletDisplacement CPU x y
@neighborsVerletDisplacement CPU x y z
@neighborsVerletDisplacement GPU x
@neighborsVerletDisplacement GPU x y
@neighborsVerletDisplacement GPU x y z

#Grid
"""
    cellPos(edge,x,xMin,xMax,nX)
    cellPos(edge,x,xMin,xMax,nX,y,yMin,yMax,nY)
    cellPos(edge,x,xMin,xMax,nX,y,yMin,yMax,nY,z,zMin,zMax,nZ)

Function that returns the position of the agent in a cell list given their coordinates and cell grid properties.
"""
cellPos(edge,x,xMin,xMax,nX) = if x > xMax nX elseif x < xMin 1 else Int((x-xMin)÷edge)+2 end
cellPos(edge,x,xMin,xMax,nX,y,yMin,yMax,nY) = cellPos(edge,x,xMin,xMax,nX) + nX*(cellPos(edge,y,yMin,yMax,nY)-1)
cellPos(edge,x,xMin,xMax,nX,y,yMin,yMax,nY,z,zMin,zMax,nZ) = cellPos(edge,x,xMin,xMax,nX) + nX*(cellPos(edge,y,yMin,yMax,nY)-1) + nX*nY*(cellPos(edge,z,zMin,zMax,nZ)-1)

"""
    function cellPosNeigh(pos,i,nX)
    function cellPosNeigh(pos,i,nX,nY)
    function cellPosNeigh(pos,i,nX,nY,nZ)

Returns the position of the neighbors cells to the current cell i (pos in 1D = 1-3, in 2D 1-9...) and gives -1 is the pos is a boundary.

e.g.

grid = 

1  2  3  4
5  6  7  8
9 10 11 12

cellPosNeigh(4,5,4,3) = -1
For i = 5 the outcomes of all the positions will be [-1,1,2,-1,5,6,-1,9,10]
"""
function cellPosNeigh(pos,i,nX)
    px = pos + i - 2
    if px < 1 || px > nX
        return -1
    else
        return px
    end
end

function cellPosNeigh(pos,i,nX,nY)
    pos = pos - 1
    i = i - 1

    py = pos ÷ nX
    px = pos - nX*py

    iy = i ÷ 3
    ix = i - 3*iy

    py = py + iy - 1
    px = px + ix - 1

    if px < 0 || px >= nX || py < 0 || py >= nY
        return -1
    else
        return py*nY+px+1
    end
end

function cellPosNeigh(pos,i,nX,nY,nZ)
    pos = pos - 1
    i = i - 1

    pz = pos ÷ (nX * nY)
    py = (pos - nX*nY*pz) ÷ nX
    px = (pos - nX*nY*pz - nX*py)

    iz = i ÷ 9
    iy = (i - 9*iz) ÷ 3
    ix = (i - 9*iz - 3*iy)

    pz = pz + iz - 1
    py = py + iy - 1
    px = px + ix - 1

    if px < 0 || px >= nX || py < 0 || py >= nY || pz < 0 || pz >= nZ
        return -1
    else
        return pz*nY*nX+py*nX+px+1
    end
end

"""
    function neighborsCellLinkedLoop(code,agent)

Wrapper loop for cell linked neighbors algorithm.
"""
function neighborsCellLinkedLoop(code,it,agent)

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

    return code

end

"""
    macro assignCells(platform, args...)

Macro to generate the code to assign agent to a cell.

Adds the following functions to the library:

    assignCells1CPU!(community)
    assignCells2CPU!(community)
    assignCells3CPU!(community)
    assignCells1GPU!(community)
    assignCells2GPU!(community)
    assignCells3GPU!(community)
"""
macro assignCells(platform, args...)

    base = agentArgsNeighbors(args)

    args2 = Any[:(cellEdge[1])]
    for (i,j) in enumerate(args)
        append!(args2,[:($j[i1_]),:(simBox[$i,1]),:(simBox[$i,2]),:(nCells_[$i])])
    end

    name = Meta.parse(string("assignCells$(length(args))$(platform)!"))

    code = 0
    if platform == :CPU
        code = :(
            function $name($(base...))

                @inbounds for i1_ in 1:1:N[1]
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

"""
    assignCells1CPU!(community)
    assignCells2CPU!(community)
    assignCells3CPU!(community)
    assignCells1GPU!(community)
    assignCells2GPU!(community)
    assignCells3GPU!(community)

Functions generated that assign the current positions of the agents to a cell.
"""
@assignCells CPU x
@assignCells CPU x y
@assignCells CPU x y z
@assignCells GPU x
@assignCells GPU x y
@assignCells GPU x y z

"""
    macro sortAgentsInCells(platform, args...)

Macro to generate the code to sort agents in cells in cell order.

Adds the following functions to the library:

    sortAgentsInCells1CPU!(community)
    sortAgentsInCells2CPU!(community)
    sortAgentsInCells3CPU!(community)
    sortAgentsInCells1GPU!(community)
    sortAgentsInCells2GPU!(community)
    sortAgentsInCells3GPU!(community)
"""
macro sortAgentsInCells(platform, args...)

    base = agentArgsNeighbors(args)

    args2 = Any[:(cellEdge[1])]
    for (i,j) in enumerate(args)
        append!(args2,[:($j[i1_]),:(simBox[$i,1]),:(simBox[$i,2]),:(nCells_[$i])])
    end

    name = Meta.parse(string("sortAgentsInCells$(length(args))$(platform)!"))

    code = 0
    if platform == :CPU
        code = :(
            function $name($(base...))

                @inbounds for i1_ in 1:1:N[1]
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

"""
    sortAgentsInCells1CPU!(community)
    sortAgentsInCells2CPU!(community)
    sortAgentsInCells3CPU!(community)
    sortAgentsInCells1GPU!(community)
    sortAgentsInCells2GPU!(community)
    sortAgentsInCells3GPU!(community)

Functions generated that assign the current positions of the agents to a cell.
"""
@sortAgentsInCells CPU x
@sortAgentsInCells CPU x y
@sortAgentsInCells CPU x y z
@sortAgentsInCells GPU x
@sortAgentsInCells GPU x y
@sortAgentsInCells GPU x y z

"""
    macro neighborsCellLinked(platform, args...)

Macro to generate the code to compute neighbors according to cell linked algorithm.
This function puts together the action of:
    - assignCells
    - sortAgentsInCells

Adds the following functions to the library:

    neighborsCellLinked1CPU!(community)
    neighborsCellLinked2CPU!(community)
    neighborsCellLinked3CPU!(community)
    neighborsCellLinked1GPU!(community)
    neighborsCellLinked2GPU!(community)
    neighborsCellLinked3GPU!(community)
"""
macro neighborsCellLinked(platform, args...)

    base = agentArgsNeighbors(args,sym=:community)

    name = Meta.parse(string("neighborsCellLinked$(length(args))$(platform)!"))
    namef = Meta.parse(string("assignCells$(length(args))$(platform)!"))
    namef2 = Meta.parse(string("sortAgentsInCells$(length(args))$(platform)!"))

    code = 0
    if platform == :CPU
        code = :(
            function $name(community)

                community.cellNumAgents_ .= 0
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
                CUDA.@sync kernel($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                community.cellCumSum_ .= cumsum(community.cellNumAgents_) .- community.cellNumAgents_
                kernel2 = @cuda launch=false $namef2($(base...),)
                CUDA.@sync kernel2($(base...);threads=community.platform.threads,blocks=community.platform.threads)

                return 
            end
        )
    end

    return code
end

"""
    neighborsCellLinked1CPU!(community)
    neighborsCellLinked2CPU!(community)
    neighborsCellLinked3CPU!(community)
    neighborsCellLinked1GPU!(community)
    neighborsCellLinked2GPU!(community)
    neighborsCellLinked3GPU!(community)

Functions generated to compute neighbors according to cell linked algorithm.
"""
@neighborsCellLinked CPU x
@neighborsCellLinked CPU x y
@neighborsCellLinked CPU x y z
@neighborsCellLinked GPU x
@neighborsCellLinked GPU x y
@neighborsCellLinked GPU x y z

#CLVD
"""
    macro verletNeighborsCLVD(platform, args...)

Macro to generate the code for the computation of Verlet lists going over CellLinked lists for different platforms and dimensions .

Adds the following functions to the library:

    verletNeighborsCLVDCPU!(x)
    verletNeighborsCLVDCPU!(x,y)
    verletNeighborsCLVDCPU!(x,y,z)
    verletNeighborsCLVDGPU!(x)
    verletNeighborsCLVDGPU!(x,y)
    verletNeighborsCLVDGPU!(x,y,z)
"""
macro verletNeighborsCLVD(platform, args...) #Macro to make the verletNeighbor loops

    base = agentArgsNeighbors(args)

    args2 = []
    for i in args
        append!(args2,[:($i[i1_]),:($i[i2_])])
    end

    args3 = Any[:(pos_),:(i3_)]
    for i in 1:length(args)
        append!(args3,[:(nCells_[$i])])
    end

    args4 = Any[:(cellEdge[1])]
    for (i,j) in enumerate(POSITIONPARAMETERS[1:length(args)])
        append!(args4,[:($j[i1_]),:(simBox[$i,1]),:(simBox[$i,2]),:(nCells_[$i])])
    end

    name = Meta.parse("verletNeighborsCLVD$(length(args))$(platform)!")

    code = 0
    if platform == :CPU

        code = quote
            if i1_ != i2_
                d = euclideanDistance($(args2...))
                if d < skin[1] 
                    neighborN_[i1_] += 1
                    # neighborN_[i2_] += 1
                    neighborList_[i1_,neighborN_[i1_]] = i2_
                    # neighborList_[i2_,neighborN_[i2_]] = i1_
                end
            end
        end

        code = quote
            pos_ = AgentBasedModels.cellPos($(args4...))
            for i3_ in 1:1:$(3^length(args)) #Go over the posible neighbor cells
                posNeigh_ = AgentBasedModels.cellPosNeigh($(args3...)) #Obtain the position of the neighbor cell
                if posNeigh_ != -1 #Ignore cells outside the boundaries
                    for i4_ in cellCumSum_[posNeigh_]-cellNumAgents_[posNeigh_]+1:1:cellCumSum_[posNeigh_] #Go over the cells of that neighbor cell
                        i2_ = cellAssignedToAgent_[i4_]
                        if i1_ != i2_
                            $code 
                        end
                    end
                end
            end
        end

        code = :(
            function $name($(base...))
                @inbounds for i1_ in 1:1:N[1] #Lack multithreading because of race
                    # lk = ReentrantLock()
                    $code
                end
            end
        )
    elseif platform == :GPU

        code = quote
            if i1_ != i2_
                d = euclideanDistance($(args2...))
                if d < skin[1]
                    pos1 = CUDA.atomic_add!(CUDA.pointer(neighborN_,i1_),Int32(1)) + 1
                    # pos2 = CUDA.atomic_add!(CUDA.pointer(neighborN_,i2_),Int32(1)) + 1
                    neighborList_[i1_,pos1] = i2_
                    # neighborList_[i2_,pos2] = i1_
                 end
            end
        end

        code = quote
            pos_ = AgentBasedModels.cellPos($(args4...))
            for i3_ in 1:1:$(3^length(args)) #Go over the posible neighbor cells
                posNeigh_ = AgentBasedModels.cellPosNeigh($(args3...)) #Obtain the position of the neighbor cell
                if posNeigh_ != -1 #Ignore cells outside the boundaries
                    for i4_ in cellCumSum_[posNeigh_]-cellNumAgents_[posNeigh_]+1:1:cellCumSum_[posNeigh_] #Go over the cells of that neighbor cell
                        i2_ = cellAssignedToAgent_[i4_]
                        if i1_ != i2_
                            $code 
                        end
                    end
                end
            end
        end

        code = :(
            function $name($(base...))
                index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                stride = gridDim().x * blockDim().x
                @inbounds for i1_ in index:stride:N[1]
                    $code
                end

                return
            end
        )
    end

    return code

end

@verletNeighborsCLVD CPU x
@verletNeighborsCLVD CPU x y
@verletNeighborsCLVD CPU x y z
@verletNeighborsCLVD GPU x
@verletNeighborsCLVD GPU x y
@verletNeighborsCLVD GPU x y z

"""
    macro neighborsCLVD(platform, args...)

Macro to generate the code to compute neighbors according to CellLinked-VerletDistance algorithms.

Adds the following functions to the library:

    neighborsCLVD1CPU!(community)
    neighborsCLVD2CPU!(community)
    neighborsCLVD3CPU!(community)
    neighborsCLVD1GPU!(community)
    neighborsCLVD2GPU!(community)
    neighborsCLVD3GPU!(community)
"""
macro neighborsCLVD(platform, args...)

    base = agentArgsNeighbors(args,sym=:community)

    nameDisp = Meta.parse(string("verletDisplacement$(platform)!"))
    nameResDisp = Meta.parse(string("verletResetDisplacement$(platform)!"))

    namef = Meta.parse(string("assignCells$(length(args))$(platform)!"))
    namef2 = Meta.parse(string("sortAgentsInCells$(length(args))$(platform)!"))
    namef3 = Meta.parse(string("verletNeighborsCLVD$(length(args))$(platform)!"))

    name = Meta.parse(string("neighborsCLVD$(length(args))$(platform)!"))

    code = 0
    if platform == :CPU
        code = :(
            function $name(community)

                $nameDisp($(base...),)
                if community.flagRecomputeNeighbors_[1] == 1
                    #Stuff related with CellLink
                    community.cellNumAgents_ .= 0
                    $namef($(base...),)
                    community.cellCumSum_ .= cumsum(community.cellNumAgents_) .- community.cellNumAgents_
                    $namef2($(base...),)
                    #Stuff related with Verlet Displacement
                    @views community.neighborN_[1:community.N[1]] .= 0
                    @views community.accumulatedDistance_[1:community.N[1]] .= 0.
                    @views community.flagRecomputeNeighbors_ .= 0
                    $nameResDisp($(base...))
                    #Assign neighbors
                    $namef3($(base...),)
                end

                return 
            end
        )
    else
        code = :(
            function $name(community)

                kernelDisp = @cuda launch=false $nameDisp($(base...),)
                kernelResDisp = @cuda launch=false $nameResDisp($(base...),)
                
                CUDA.@sync kernelDisp($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                if CUDA.@allowscalar community.flagRecomputeNeighbors_[1] == 1
                    #Stuff relateed with CellLinked
                    community.cellNumAgents_ .= 0
                    kernel = @cuda launch=false $namef($(base...),)
                    CUDA.@sync kernel($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                    community.cellCumSum_ .= cumsum(community.cellNumAgents_) .- community.cellNumAgents_
                    kernel2 = @cuda launch=false $namef2($(base...),)
                    CUDA.@sync kernel2($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                    #Stuff related with Verlet Displacement
                    CUDA.@sync community.neighborN_ .= 0
                    CUDA.@sync community.accumulatedDistance_ .= 0.
                    CUDA.@sync community.flagRecomputeNeighbors_ .= 0
                    CUDA.@sync kernelResDisp($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                    #Assign neighbors
                    kernel3 = @cuda launch=false $namef3($(base...),)
                    CUDA.@sync kernel3($(base...);threads=community.platform.threads,blocks=community.platform.threads)
                end

                return 
            end
        )
    end

    return code
end

@neighborsCLVD CPU x
@neighborsCLVD CPU x y
@neighborsCLVD CPU x y z
@neighborsCLVD GPU x
@neighborsCLVD GPU x y
@neighborsCLVD GPU x y z