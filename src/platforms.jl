abstract type Platform end


""""
    mutable struct CPU <: Platform

CPU platform structure.
"""
mutable struct CPU <: Platform

end

"""
    function platformSetup!(platform::CPU,com)
    function platformSetup!(platform::GPU,com)

Function to setup the platform parameters.
"""
function platformSetup!(platform::CPU,com)

    return

end

"""
    function platformUpdate!(platform::CPU,com)
    function platformUpdate!(platform::GPU,com)

Function to setup the platform parameters after each step iteration.
"""
function platformUpdate!(platform::CPU,com)

    return

end

""""
    mutable struct GPU <: Platform

CPU platform structure.

# Threads and blocks for each rule method

 - agentThreads
 - agentBlocks
 - modelThreads
 - modelBlocks
 - mediumThreads
 - mediumBlocks

"""
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
    t = copy(ndiv[1:s])
    p = prod(t)
    while p > nMax
        i = argmin(NMedium./t)
        t[i] -= 1
        p = prod(t)
    end

    t = [if i == 0; 1; else i; end for i in t]

    return tuple(t...)

end

# function mediumResources(nMax,s,NMedium)

#     ndiv = copy(NMedium)
#     t = [1,1,1][1:s]
#     p = prod(t)
    # tLast = copy(t)
#     while !(p >= nMax) && !(p >= prod(NMedium))
#         tLast = copy(t)
#         i = argmax(NMedium./t)
#         t[i] += 1
#         p = prod(t)
#     end

#     return tuple(tLast...)

# end