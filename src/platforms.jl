abstract type Platform end

mutable struct CPU <: Platform

end

function platformSetup!(platform::CPU,com)

    return

end

function platformUpdate!(platform::CPU,com)

    return

end

mutable struct GPU <: Platform

    agentThreads
    agentBlocks
    modelThreads
    modelBlocks
    mediumThreads
    mediumBlocks

    function GPU()
        return new(1,1,1,1,1,1)
    end

end

function platformSetup!(platform::GPU,com)
    
    platform.agentThreads = MAXTHREADS
    platform.agentBlocks = min(ceil(Int64,com.N/MAXTHREADS),MAXBLOCKS)
    platform.modelThreads = 1
    platform.modelBlocks = 1
    platform.mediumThreads = mediumResources(MAXTHREADS,com.abm.dims,Array(com.NMedium))
    platform.mediumBlocks = mediumResources(min(ceil(Int64,prod(com.NMedium)/prod(platform.mediumThreads)),MAXBLOCKS),
                                                com.abm.dims,Array(com.NMedium))
    
    return

end

function platformUpdate!(platform::GPU,com)
    
    platform.agentThreads = MAXTHREADS
    platform.agentBlocks = min(ceil(Int64,com.N/MAXTHREADS),MAXBLOCKS)
    
    return

end

function mediumResources(nMax,s,NMedium)

    ndiv = copy(NMedium)
    t = [1,1,1][1:s]
    p = prod(t)
    while !(p >= nMax) && !(p >= prod(NMedium))
        i = argmax(NMedium./t)
        t[i] += 1
        p = prod(t)
    end

    return tuple(t...)

end