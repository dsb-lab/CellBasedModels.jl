#Distance Distances
euclideanDistance(x1,x2) = sqrt((x1-x2)^2)
euclideanDistance(x1,x2,y1,y2) = sqrt((x1-x2)^2+(y1-y2)^2)
euclideanDistance(x1,x2,y1,y2,z1,z2) = sqrt((x1-x2)^2+(y1-y2)^2+(z1-z2)^2)

manhattanDistance(x1,x2) = abs(x1-x2)
manhattanDistance(x1,x2,y1,y2) = abs(x1-x2)+abs(y1-y2)
manhattanDistance(x1,x2,y1,y2,z1,z2) = abs(x1-x2)+abs(y1-y2)+abs(z1-z2)

function makeSimpleLoop(code,agent)

    if agent.platform == :CPU

        return :(Threads.@threads for i1_ in 1:1:N[1]; $code; end)

    else agent.platform == :GPU

        return :($CUDATHREADS1D; for i1_ in index:stride:N[1]; $code; end)

    end
end

CUDATHREADS1D = quote
    index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
    stride = gridDim().x * blockDim().x
end