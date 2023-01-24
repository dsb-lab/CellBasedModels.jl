function neighborsFunction(agent)

    if agent.neighbors == :Full

        agent.declaredUpdatesFunction[:ComputeNeighbors] = neighborsFull!
    
    elseif agent.neighbors == :VerletTime

        if agent.dims == 1
            agent.declaredUpdatesFunction[:ComputeNeighbors] = neighborsVerletTime1!
        elseif agent.dims == 2
            agent.declaredUpdatesFunction[:ComputeNeighbors] = neighborsVerletTime2!
        elseif agent.dims == 3
            agent.declaredUpdatesFunction[:ComputeNeighbors] = neighborsVerletTime3!
        end

    elseif agent.neighbors == :VerletDisplacement
    
        if agent.dims == 1
            agent.declaredUpdatesFunction[:ComputeNeighbors] = neighborsVerletDisplacement1!
        elseif agent.dims == 2
            agent.declaredUpdatesFunction[:ComputeNeighbors] = neighborsVerletDisplacement2!
        elseif agent.dims == 3
            agent.declaredUpdatesFunction[:ComputeNeighbors] = neighborsVerletDisplacement3!
        end
    
    elseif agent.neighbors == :CellLinked
    
        agent.declaredUpdatesFunction[:ComputeNeighbors] = Main.eval(:((community) -> AgentBasedModels.neighborsCellLinked!($(agentArgs(:community)...))))
    
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
function neighborsFull!(community)
    return nothing
end

function neighborsFullLoop(code,agent)

    if agent.platform == :CPU
        return makeSimpleLoop(:(for i2_ in 1:1:N[1]; if i1_ != i2_; $code; end; end), agent)
    else
        error("Make simple loop Gpu not implemented")
    end

end

#Verlet
function neighborsVerletLoop(code,agent) #Macro to create the second loop in functions
    
    if agent.platform == :CPU

        code = makeSimpleLoop(:(for i2_ in 1:1:neighborN_[i1_]; $code; end), agent)
        #Go over the list of neighbors
        code = postwalk(x->@capture(x,g_[h_]) && h == :i2_ ? :($g[neighborList_[i2_]]) : x, code)

        return code

    else

        error("Make simple loop GPU not implemented")

    end

end

macro verletNeighbors(args...) #Macro to make the verletNeighbor loops

    args2 = []
    for i in args
        append!(args2,[:($i[i1_]),:($i[i2_])])
    end

    return :(
        function verletNeighbors!(N,$(args...),skin,neighborList_,neighborN_)
            d = 0.
            lk = ReentrantLock()
            for i1_ in 1:1:N[1]
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

end

@verletNeighbors x
@verletNeighbors x y
@verletNeighbors x y z

    #Verlet Time
macro neighborsVerletTime(args...)

    base = agentArgs(l=length(args))

    return :(
        function neighborsVerletTime!($(base...),)

            if neighborTimeLastRecompute_ <= t
                neighborN_ .= 0
                verletNeighbors!(N,$(args...),skin,neighborList_,neighborN_)
                neighborTimeLastRecompute_ .+= dtNeighborRecompute
            elseif flagRecomputeNeighbors_ .== 1
                neighborN_ .= 0
                verletNeighbors!(N,$(args...),skin,neighborList_,neighborN_)
                neighborTimeLastRecompute_ .= t + dtNeighborRecompute
                flagRecomputeNeighbors_ .= 0
            end

        end
    )
end

@neighborsVerletTime x
@neighborsVerletTime x y
@neighborsVerletTime x y z

macro neighborsVerletTimeCom(args...)

    base = agentArgs(:community,l=length(args))
    name = Meta.parse(string("neighborsVerletTime$(length(args))!"))

    return :(
        function $name(community)

            neighborsVerletTime!($(base...),)

            return

        end
    )
end

@neighborsVerletTimeCom x
@neighborsVerletTimeCom x y
@neighborsVerletTimeCom x y z

    #Verlet Displacement
macro verletDisplacement(args...)

    base = agentArgs(l=length(args))
    
    args3 = []
    for (pos,i) in enumerate(args)
        append!(args3,[:($i[i1_]),:(posOld_[i1_,$pos])])
    end

    return :(
        function verletDisplacement!($(base...))

            for i1_ in 1:1:N[1]
                accumulatedDistance_[i1_] = euclideanDistance($(args3...))
                if accumulatedDistance_[i1_] >= skin[1]/2
                    flagRecomputeNeighbors_[1] = 1
                end
            end

            return 

        end
    )
end

@verletDisplacement x
@verletDisplacement x y
@verletDisplacement x y z

macro neighborsVerletDisplacement(args...)

    base = agentArgs(l=length(args))

    args2 = [Meta.parse(string(i,"Old_")) for i in args]

    up = [:(i .= j) for (i,j) in zip(args,args2)]

    return :(
        function neighborsVerletDisplacement!($(base...))

            verletDisplacement!($(base...))
            if flagRecomputeNeighbors_[1] == 1
                neighborN_ .= 0
                accumulatedDistance_ .= 0.
                flagRecomputeNeighbors_ .= 0
                $up
                verletNeighbors!(N,$(args...),skin,neighborList_,neighborN_)
            end

            return 
        end
    )
end

@neighborsVerletDisplacement x
@neighborsVerletDisplacement x y
@neighborsVerletDisplacement x y z

macro neighborsVerletDisplacementCom(args...)

    base = agentArgs(:community,l=length(args))
    name = Meta.parse(string("neighborsVerletDisplacement$(length(args))!"))

    return :(
        function $name(community)

            neighborsVerletDisplacement!($(base...),)

            return

        end
    )
end

@neighborsVerletDisplacementCom x
@neighborsVerletDisplacementCom x y
@neighborsVerletDisplacementCom x y z

#Grid
function neighborsCellLinkedLoop(code,agent)

    code = postwalk(x->@capture(x,:i2_) ? :(neighborsList[i2_]) : x, code)
    
    if agent.platform == :CPU
        return :(Threads.@threads for i2_ in 1:1:neighborsN[i1_] $code end)
    else
        return :(for i2_ in 1:1:neighborsN[i1_] $code end)    
    end

end

cellPos(edge,x,xMin,xMax,nX) = if x > xMax nX elseif x < xMin 1 else Int((x-xMin)÷edge)+2 end
cellPos(edge,x,xMin,xMax,nX,y,yMin,yMax,nY) = cellPos(edge,x,xMin,xMax,nX) + nX*(cellPos(edge,y,yMin,yMax,nY)-1)
cellPos(edge,x,xMin,xMax,nX,y,yMin,yMax,nY,z,zMin,zMax,nZ) = cellPos(edge,x,xMin,xMax,nX) + nX*(cellPos(edge,y,yMin,yMax,nY)-1) + nX*nY*(cellPos(edge,z,zMin,zMax,nZ)-1)

macro assignCells(args...)

    args2 = Any[:(cellEdge[1])]
    for (i,j) in enumerate(args)
        append!(args2,[:($j[i1_]),:(simulationBox[$i,1]),:(simulationBox[$i,2]),:(nCells_[$i])])
    end

    return :(
        function assignCells!(N,simulationBox,$(args...),$(keys(NEIGHBORSYMBOLS[:CellLinked])...))

            pos = 0
            for i1_ in 1:1:N[1]
                pos = cellPos($(args2...))
                cellAssignedToAgent_[i1_] = pos
                cellNumAgents_[pos] += 1
            end

            return
        end
    )
end

@assignCells x
@assignCells x y
@assignCells x y z

macro neighborsCellLinked(args...)

    return :(
        function neighborsCellLinked!(t,N,simulationBox,$(args...),$(keys(NEIGHBORSYMBOLS[:CellLinked])...))

            @views cellNumAgents_[1:N[1]] .= 0
            assignCells!(N,simulationBox,$(args...),$(keys(NEIGHBORSYMBOLS[:CellLinked])...))
            cellCumSum_ .= cumsum(cellNumAgents_)

            return 
        end
    )
end

@neighborsCellLinked x
@neighborsCellLinked x y
@neighborsCellLinked x y z

#VerletLinkedCell
macro neighborsVerletGridLoop(code,agent)

    error("TO DO")

end

function neighborsVerletGridLoop(neighborsList,neighborsN,radiusVelvet,N)

    error("TO DO")

end