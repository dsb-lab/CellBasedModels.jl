function neighborsFunction(agent)

    args = [:(community.t),:(community.N)]
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
    elseif agent.neighbors == :Grid
        agent.declaredUpdatesFunction[:computeNeighbors] = Main.eval(:((community) -> AgentBasedModels.neighborsGrid!($(args...))))
    elseif agent.neighbors == :VerletGrid
        agent.declaredUpdatesFunction[:computeNeighbors] = Main.eval(:((community) -> AgentBasedModels.neighborsGridVerlet!($(args...))))
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
        function neighborsVerletTime!(t,N,$(args...),$(keys(NEIGHBORSYMBOLS[:VerletTime])...))

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
macro neighborsVerletDisplacement(args...)

    error("TO DO")

end

#Grid
macro neighborsGridLoop(agent,code)

    error("TO DO")

end

function neighborsGridLoop(neighborsList,neighborsN,radiusVelvet,N)

    error("TO DO")

end

#VerletGrid
macro neighborsVerletGridLoop(agent,code)

    error("TO DO")

end

function neighborsVerletGridLoop(neighborsList,neighborsN,radiusVelvet,N)

    error("TO DO")

end
