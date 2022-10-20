function neighborsFunction(agent)

    args = [:(community.t),:(community.N),:(community.simulationBox)]
    for i in [:x,:y,:z][1:agent.dims]
        push!(args,:(community.$i))
    end
    for i in keys(NEIGHBORSYMBOLS[agent.neighbors])
        push!(args,:(community.$i))
    end

    if agent.neighbors == :Full
        agent.declaredUpdatesFunction[:computeNeighbors] = Main.eval(:((community) -> nothing))
    elseif agent.neighbors == :VerletTime
        agent.declaredUpdatesFunction[:computeNeighbors] = Main.eval(:((community) -> AgentBasedModels.neighborsVerletTime!($(args...))))
    elseif agent.neighbors == :VerletDisplacement
        agent.declaredUpdatesFunction[:computeNeighbors] = Main.eval(:((community) -> AgentBasedModels.neighborsVerletDisplacement!($(args...))))
    elseif agent.neighbors == :CellLinked
        agent.declaredUpdatesFunction[:computeNeighbors] = Main.eval(:((community) -> AgentBasedModels.neighborsCellLinked!($(args...))))
    elseif agent.neighbors == :VerletGrid
        agent.declaredUpdatesFunction[:computeNeighbors] = Main.eval(:((community) -> AgentBasedModels.neighborsGridVerlet!($(args...))))
    else
        error("Neighbors method is not defined.")
    end

end

function computeNeighbors!(agent,community)

    agent.declaredUpdatesFunction[:computeNeighbors](community)

end

#Full
macro neighborsFullLoop(agent,code)

    agent = @eval agent 

    if agent.platform == :CPU
        return :(Threads.@threads for i2_ in 1:1:N[1] $code end)
    else
        return :(for i2_ in 1:1:N[1] $code end)    
    end

end

#Verlet
macro neighborsVerletLoop(agent,code) #Macro to create the second loop in functions

    agent = @eval agent

    code = postwalk(x->@capture(x,:i2_) ? :(neighborsList[i2_]) : x, code)
    
    if agent.platform == :CPU
        return :(Threads.@threads for i2_ in 1:1:neighborsN[i1_] $code end)
    else
        return :(for i2_ in 1:1:neighborsN[i1_] $code end)    
    end

end

euclideanMetric(x1,x2) = sqrt((x1-x2)^2)
euclideanMetric(x1,x2,y1,y2) = sqrt((x1-x2)^2+(y1-y2)^2)
euclideanMetric(x1,x2,y1,y2,z1,z2) = sqrt((x1-x2)^2+(y1-y2)^2+(z1-z2)^2)

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
                    d = euclideanMetric($(args2...))
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
    return :(
        function neighborsVerletTime!(t,N,simulationBox,$(args...),$(keys(NEIGHBORSYMBOLS[:VerletTime])...))

            if neighborTimeLastRecompute_ <= t
                neighborN_ .= 0
                verletNeighbors!(N,$(args...),skin,neighborList_,neighborN_)
                neighborTimeLastRecompute_ .+= dtNeighborRecompute
            end

        end
    )
end

@neighborsVerletTime x
@neighborsVerletTime x y
@neighborsVerletTime x y z

    #Verlet Displacement
macro verletDisplacement(args...)

    args2 = [Meta.parse(string(i,"Old_")) for i in args]

    args3 = []
    for i in args
        append!(args3,[:($i[i1_]),:($(Meta.parse(string(i,"Old_")))[i1_])])
    end

    return :(
        function verletDisplacement!(N,$(args...),$(args2...),skin,accumulatedDistance_,neighborFlagRecompute_)

            for i1_ in 1:1:N[1]
                accumulatedDistance_[i1_] = euclideanMetric($(args3...))
                if accumulatedDistance_[i1_] >= skin[1]/2
                    neighborFlagRecompute_[1] = 1
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

    args2 = [Meta.parse(string(i,"Old_")) for i in args]

    up = [:(i .= j) for (i,j) in zip(args,args2)]

    return :(
        function neighborsVerletDisplacement!(t,N,simulationBox,$(args...),$(keys(NEIGHBORSYMBOLS[:VerletDisplacement])...))

            verletDisplacement!(N,$(args...),$(args2...),skin,accumulatedDistance_,neighborFlagRecompute_)
            if neighborFlagRecompute_[1] == 1
                neighborN_ .= 0
                accumulatedDistance_ .= 0.
                neighborFlagRecompute_ .= 0
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

#Grid
macro neighborsGridLoop(agent,code)

    error("TO DO")

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
macro neighborsVerletGridLoop(agent,code)

    error("TO DO")

end

function neighborsVerletGridLoop(neighborsList,neighborsN,radiusVelvet,N)

    error("TO DO")

end
