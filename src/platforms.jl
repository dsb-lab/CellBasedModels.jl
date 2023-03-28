abstract type Platform end

mutable struct CPU <: Platform

end

function platformUpdate!(platform::CPU,com)

    return

end

mutable struct GPU <: Platform

    agentThreads
    agentBlocks
    mediumThreads
    mediumBlocks

    function GPU()
        return new(1,1,1,1)
    end

end

function platformUpdate!(platform::GPU,com)
    
    platform.agentThreads = 256
    platform.agentBlocks = ceil(Int64,com.N/256)
    platform.mediumThreads = 1
    platform.mediumBlocks = 1
    
    return

end
