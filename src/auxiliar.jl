#Distance Distances
euclideanDistance(x1,x2) = sqrt((x1-x2)^2)
euclideanDistance(x1,x2,y1,y2) = sqrt((x1-x2)^2+(y1-y2)^2)
euclideanDistance(x1,x2,y1,y2,z1,z2) = sqrt((x1-x2)^2+(y1-y2)^2+(z1-z2)^2)

manhattanDistance(x1,x2) = abs(x1-x2)
manhattanDistance(x1,x2,y1,y2) = abs(x1-x2)+abs(y1-y2)
manhattanDistance(x1,x2,y1,y2,z1,z2) = abs(x1-x2)+abs(y1-y2)+abs(z1-z2)

baseParameterToModifiable(sym) = Meta.parse(string(string(sym)[1:end-3],"M_"))
baseParameterNew(sym) = Meta.parse(string(split(string(sym),"_")[1],"New_"))
agentArgs() = [keys(BASEPARAMETERS)...]
agentArgs(sym) = [:($sym.$i) for i in keys(BASEPARAMETERS)]

function getProperty(dict::OrderedDict,property::Symbol)
    return [getfield(var,property) for (i,var) in pairs(dict)]
end

function getSymbolsThat(dict::OrderedDict,property::Symbol,condition::Array)
    return [i for (i,var) in pairs(dict) if getfield(var,property) in condition]
end

function getSymbolsThat(dict::OrderedDict,property::Symbol,condition)
    return [i for (i,var) in pairs(dict) if getfield(var,property) == condition]
end

function checkFormat(sym,args,prop,dict,agent)

    a = prop.initialize(dict,agent)
    if typeof(args[sym]) != typeof(a)
        error("For parameter $sym we expect a typeof ", typeof(a), " of size ", size(a))
    end

    if typeof(args[sym]) <: Threads.Atomic
        nothing
    elseif size(args[sym]) != size(a)
        error("For parameter $sym we expect a typeof ", size(a))
    end

end

function makeSimpleLoop(code,agent)

    if agent.platform == :CPU

        return :(@inbounds Threads.@threads for i1_ in 1:1:N[1]; $code; end)

    else agent.platform == :GPU

        return :($CUDATHREADS1D; for i1_ in index:stride:N[1]; $code; end)

    end

end

function addCuda(code,agent;oneThread=false)

    if agent.platform == :GPU

        if oneThread

            code = :(@cuda threads=1 blocks=1 $code)
        
        else

            code = :(@cuda threads=community.platform.threads blocks=community.platform.blocks $code)

        end

    end

    return code

end

function cudaAdapt(code,agent)

    if agent.platform == :GPU

        #Adapt atomic
        code = postwalk(x->@capture(x,Threads.atomic_add!(p1_,p2_)) ? :(CUDA.atomic_add!(CUDA.pointer($p1,1),$p2)) : x , code)
        #Call to atomic
        code = postwalk(x->@capture(x,p1_[]) ? :($p1[1]) : x , code)

    end

    return code

end

macro cudaAdapt(code)

    code1 = copy(code)
    #Adapt atomic
    code = postwalk(x->@capture(x,Threads.atomic_add!(p1_,p2_)) ? :(CUDA.atomic_add!(CUDA.pointer($p1,1),$p2)) : x , code)
    #Call to atomic
    code = postwalk(x->@capture(x,p1_[]) ? :($p1[1]) : x , code)
    #Change format declaration
    code = postwalk(x->@capture(x,p1_::Array) ? :($p1::CuArray) : x , code)

    codeFinal = quote
        $code1
        $code
    end

    return codeFinal

end

CUDATHREADS1D = quote
    index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
    stride = gridDim().x * blockDim().x
end