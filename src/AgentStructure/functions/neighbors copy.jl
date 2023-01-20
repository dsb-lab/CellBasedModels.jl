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
function neighborsVerletTime(args...)

    arg = agentArgs(l=length(args))

    code = :(
        function ($(arg...),)
        
            if neighborTimeLastRecompute_ <= t
                neighborN_ .= 0
                AgentBasedModels.verletNeighbors!(N,$(args...),skin,neighborList_,neighborN_)
                neighborTimeLastRecompute_ .+= dtNeighborRecompute
            elseif flagRecomputeNeighbors_ .== 1
                neighborN_ .= 0
                AgentBasedModels.verletNeighbors!(N,$(args...),skin,neighborList_,neighborN_)
                neighborTimeLastRecompute_ .= t + dtNeighborRecompute
                flagRecomputeNeighbors_ .= 0
            end
        
        end
    )

    return Main.eval(code)

end

    #Verlet Displacement
macro verletDisplacement(args...)

    args2 = [Meta.parse(string(i,"Old_")) for i in args]

    args3 = []
    for i in args
        append!(args3,[:($i[i1_]),:($(Meta.parse(string(i,"Old_")))[i1_])])
    end

    return :(
        function verletDisplacement_!($(keys(BASESYMBOLS)...),$(args...),$(args2...),skin,accumulatedDistance_)

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

    args2 = [Meta.parse(string(i,"Old_")) for i in args]

    up = [:(i .= j) for (i,j) in zip(args,args2)]

    return :(
        function neighborsVerletDisplacement!($(keys(BASESYMBOLS)...),$(args...),$(keys(NEIGHBORSYMBOLS[:VerletDisplacement])...))

            verletDisplacement!($(keys(BASESYMBOLS)...),$(args...),$(args2...),skin,accumulatedDistance_)
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

function neighborsFunction(agent)

    if agent.neighbors == :Full

        agent.declaredUpdatesFunction[:ComputeNeighbors] = neighborsFull!
    
    elseif agent.neighbors == :VerletTime

        arg = agentArgs(:community,l=length(agent.dims))

        agent.declaredUpdatesFunction[:ComputeNeighbors_] = neighborsVerletTime(POSITIONPARAMETERS[1:agent.dims]...)
        agent.declaredUpdatesFunction[:ComputeNeighbors] = Main.eval(:((community,) -> community.agent.declaredUpdatesFunction[:ComputeNeighbors_]($(arg...),)))

    elseif agent.neighbors == :VerletDisplacement
    
        arg = agentArgs(:community,l=length(agent.dims))
        
        agent.declaredUpdatesFunction[:ComputeNeighbors_] = neighborsVerletDisplacement(POSITIONPARAMETERS[1:agent.dims]...)
        agent.declaredUpdatesFunction[:ComputeNeighbors] = Main.eval(:((community,) -> community.agent.declaredUpdatesFunction[:ComputeNeighbors_]($(arg...),)))
    
    elseif agent.neighbors == :CellLinked
    
        agent.declaredUpdatesFunction[:ComputeNeighbors] = Main.eval(:((community) -> AgentBasedModels.neighborsCellLinked!($(agentArgs(:community)...))))
    
    elseif agent.neighbors == :VerletGrid
    
        agent.declaredUpdatesFunction[:ComputeNeighbors] = Main.eval(:((community) -> AgentBasedModels.neighborsGridVerlet!($(agentArgs(:community)...))))
    
    else
    
        error("Neighbors method is not defined.")
    
    end

end