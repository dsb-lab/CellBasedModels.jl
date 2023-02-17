##############################################################################################################################
# Distance metrics
##############################################################################################################################
"""
    euclideanDistance(x1,x2)
    euclideanDistance(x1,x2,y1,y2)
    euclideanDistance(x1,x2,y1,y2,z1,z2)

Euclidean distance metric between two positions.

d = (x₁-x₂)²
"""
euclideanDistance(x1,x2) = sqrt((x1-x2)^2)
euclideanDistance(x1,x2,y1,y2) = sqrt((x1-x2)^2+(y1-y2)^2)
euclideanDistance(x1,x2,y1,y2,z1,z2) = sqrt((x1-x2)^2+(y1-y2)^2+(z1-z2)^2)

"""
    manhattanDistance(x1,x2)
    manhattanDistance(x1,x2,y1,y2)
    manhattanDistance(x1,x2,y1,y2,z1,z2)

Manhattan distance metric between two positions.

d = |x₁-x₂|
"""
manhattanDistance(x1,x2) = abs(x1-x2)
manhattanDistance(x1,x2,y1,y2) = abs(x1-x2)+abs(y1-y2)
manhattanDistance(x1,x2,y1,y2,z1,z2) = abs(x1-x2)+abs(y1-y2)+abs(z1-z2)

##############################################################################################################################
# Agent functions
##############################################################################################################################
"""
    function baseParameterToModifiable(sym)

Return sym coming from UserParameter.basePar changed to modifiable. (e.g. liNM_ -> liM_)
"""
function baseParameterToModifiable(sym) 
    
    m = split(string(sym),"NM_")
    
    if length(m) == 1
        return Meta.parse(m[1])
    else
        return Meta.parse(string(m[1],"M_"))
    end

end
"""
    baseParameterNew(sym)

Return sym coming from UserParameter.basePar to new. (e.g. liM_ -> liMNew_)
"""
baseParameterNew(sym) = Meta.parse(string(split(string(sym),"_")[1],"New_"))

"""
    function agentArgs(sym=nothing;l=3,params=BASEPARAMETERS,posparams=POSITIONPARAMETERS) 

Function that returns the arguments obervable for the constructed functions. If symbol is given, it substitutes by the fielnames in form of by *sym.fieldname*.
"""
function agentArgs(sym=nothing;l=3,params=BASEPARAMETERS,posparams=POSITIONPARAMETERS) 

    pars = [i for i in keys(params)]

    for i in posparams[3:-1:1+l]
        popat!(pars,findfirst(pars.==i))
    end

    if sym === nothing
        return Any[pars...]
    else
        return Any[:($sym.$i) for i in pars]
    end

end

"""
    macro agentArgs(code)
    macro agentArgs(name,code)

Macro that substitutes the symbol :ARGS in **code** by the fieldnames of the structure Community. If **name** is given, it substitutes by the fielnames in form of by *name.fieldname*.
"""
macro agentArgs(code)

    code = postwalk(x->@capture(x,ARGS) ? :($(agentArgs())...) : x, code)

    return code

end

macro agentArgs(name,code)

    code = postwalk(x->@capture(x,ARGS) ? :($(agentArgs(name))...) : x, code)

    return code
    
end

"""
    function getProperty(dict::OrderedDict,property::Symbol)

For a Ordered dictionary of {Symbols, Structure} like BASEPARAMETERS, get a specific field of the structure.
"""
function getProperty(dict::OrderedDict,property::Symbol)
    return [getfield(var,property) for (i,var) in pairs(dict)]
end

"""
    function getSymbolsThat(dict::OrderedDict,property::Symbol,condition)
    function getSymbolsThat(dict::OrderedDict,property::Symbol,condition::Array)

For a Ordered dictionary of {Symbols, Structure} like BASEPARAMETERS, and a specific field (property) of the structure.
If the property has as value of the condition, returns that symbol.
"""
function getSymbolsThat(dict::OrderedDict,property::Symbol,condition::Array)
    return [i for (i,var) in pairs(dict) if getfield(var,property) in condition]
end

function getSymbolsThat(dict::OrderedDict,property::Symbol,condition)
    l = []
    for (i,var) in pairs(dict) 
        f = getfield(var,property) 
        if f == condition 
            push!(l,i)
        elseif typeof(f) <: Tuple
            if condition in f
                push!(l,i)
            end
        end
    end
    return l
end

##############################################################################################################################
# Check if appropiate format
##############################################################################################################################
"""
    function checkFormat(sym,args,prop,dict,agent)

Function that checks that the args provided to Community are from the same type that the ones provided by automatic initialization property in BASEPARAMETERS. 
If they are not, it gives an error.
"""
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

##############################################################################################################################
# Constuct custom functions
##############################################################################################################################
"""
    function makeSimpleLoop(code,agent)

Wrap code in loop iterating over the Community agents in the correct platform.
"""
function makeSimpleLoop(code,agent)

    if agent.platform == :CPU

        return :(@inbounds Threads.@threads for i1_ in 1:1:N[1]; $code; end)

    else agent.platform == :GPU

        return :($CUDATHREADS1D; @inbounds for i1_ in index:stride:N[1]; $code; end)

    end

end

"""
    function addCuda(code,platform::Symbol;oneThread=false)
    function addCuda(code,agent;oneThread=false)

Add cuda macro to execute the kernel with the correspondent number of threads and blocks.
If one thread, launches the kernel just with one thread.
"""
function addCuda(code,platform::Symbol;oneThread=false)

    if platform == :GPU

        if oneThread

            code = :(@cuda threads=1 blocks=1 $code)
        
        else

            code = :(@cuda threads=community.platform.threads blocks=community.platform.blocks $code)
            # code = :(@cuda threads=5 blocks=5 $code)

        end

    end

    return code

end

function addCuda(code,agent;oneThread=false)

    return addCuda(code,agent.platform,oneThread=oneThread)

end

"""
    function cudaAdapt(code,agent)

Adapt specific CPU forms of calling parameters (e.g. Atomic) to CUDA valid code (Atomic -> size 1 CuArray).
"""
function cudaAdapt(code,agent)

    if agent.platform == :GPU

        #Adapt atomic
        code = postwalk(x->@capture(x,Threads.atomic_add!(p1_,p2_)) ? :(CUDA.atomic_add!(CUDA.pointer($p1,1),$p2)) : x , code)
        #Call to atomic
        code = postwalk(x->@capture(x,p1_[]) ? :($p1[1]) : x , code)

    end

    return code

end

############ I think this code can be removed
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

############ I think this code can be removed
CUDATHREADS1D = quote
    index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
    stride = gridDim().x * blockDim().x
end

##############################################################################################################################
# Vectorize parameters
##############################################################################################################################
"""
    function vectorize(code,agent)

Function that transforms the code provided in Agent to the vectorized form for wrapping around an executable function.
"""
function vectorize(code,agent)

    #For user declared symbols
    for (sym,prop) in pairs(agent.declaredSymbols)

        bs = prop.basePar
        bsn = baseParameterNew(bs)
        pos = prop.position
        if :Local == prop.scope
            code = postwalk(x->@capture(x,g_.p1_.p2_) && g == sym && p1 == BASESYMBOLS[:UpdateSymbol].symbol && p2 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bsn[i1_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_.p1_.p2_) && g == sym && p1 == BASESYMBOLS[:UpdateSymbol].symbol && p2 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bsn[i2_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_.p1_.p2_) && g == sym && p2 == BASESYMBOLS[:UpdateSymbol].symbol && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bsn[i1_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_.p1_.p2_) && g == sym && p2 == BASESYMBOLS[:UpdateSymbol].symbol && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bsn[i2_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_.p1_) && g == sym && p1 == BASESYMBOLS[:UpdateSymbol].symbol ? :($bsn[i1_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_) && g == sym ? :($bs[i1_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_[p1_][p2_]) && g == sym ? :($bs[$p2,$pos]) : x, code) #Undo if it was already vectorized
            code = postwalk(x->@capture(x,g_.p1_) && g == sym && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bs[i1_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_.p1_) && g == sym && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bs[i2_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_[h__].p1_) && g == sym && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bs[i1_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_[h__].p1_) && g == sym && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bs[i2_,$pos]) : x, code)
            code = postwalk(x->@capture(x,g_[h__].p1_) && g == bs && p1 == BASESYMBOLS[:AddCell].symbol ? :($bsn[i1New_,$pos]) : x, code)
        elseif :Global == prop.scope
            code = postwalk(x->@capture(x,g_.p1_) && g == sym && p1 == BASESYMBOLS[:UpdateSymbol].symbol ? :($bsn[$pos]) : x, code)
            code = postwalk(x->@capture(x,g_) && g == sym ? :($bs[$pos]) : x, code)
        elseif :Medium == prop.scope
            args = [:gridPosx_,:gridPosy_,:gridPosz_][1:agent.dims]
            code = postwalk(x->@capture(x,g_.j) && g == sym ? :($bs[$(args...)]) : x, code)
        elseif :Atomic == prop.scope
            nothing
        else
            error("Symbol $bs with type $(prop[2]) doesn't has not vectorization implemented.")
        end

    end

    #For local parameters
    for bs in [sym for (sym,prop) in pairs(BASEPARAMETERS) if :Local == prop.shape[1]]

        bsn = baseParameterNew(bs)
        code = postwalk(x->@capture(x,g_.p1_.p2_) && g == bs && p1 == BASESYMBOLS[:UpdateSymbol].symbol && p2 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bsn[i1_]) : x, code)
        code = postwalk(x->@capture(x,g_.p1_.p2_) && g == bs && p1 == BASESYMBOLS[:UpdateSymbol].symbol && p2 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bsn[i2_]) : x, code)
        code = postwalk(x->@capture(x,g_.p1_.p2_) && g == bs && p2 == BASESYMBOLS[:UpdateSymbol].symbol && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bsn[i1_]) : x, code)
        code = postwalk(x->@capture(x,g_.p1_.p2_) && g == bs && p2 == BASESYMBOLS[:UpdateSymbol].symbol && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bsn[i2_]) : x, code)
        code = postwalk(x->@capture(x,g_.p1_) && g == bs && p1 == BASESYMBOLS[:UpdateSymbol].symbol ? :($bsn[i1_]) : x, code)
        code = postwalk(x->@capture(x,g_) && g == bs ? :($bs[i1_]) : x, code)
        code = postwalk(x->@capture(x,g_[p1_][p2__]) && g == bs ? :($bs[$(p2...)]) : x, code) #Undo if it was already vectorized
        code = postwalk(x->@capture(x,g_.p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bs[i1_]) : x, code)
        code = postwalk(x->@capture(x,g_.p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bs[i2_]) : x, code)
        code = postwalk(x->@capture(x,g_[i1_].p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bs[i1_]) : x, code)
        code = postwalk(x->@capture(x,g_[i2_].p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bs[i2_]) : x, code)
        code = postwalk(x->@capture(x,g_[h__].p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bs[i1_,$(h[2])]) : x, code)
        code = postwalk(x->@capture(x,g_[h__].p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bs[i2_,$(h[2])]) : x, code)
        code = postwalk(x->@capture(x,g_[h__].p1_) && g == bs && p1 == BASESYMBOLS[:AddCell].symbol ? :($bsn[i1New_]) : x, code)

    end

    #For global parameters
    for bs in [sym for (sym,prop) in pairs(BASEPARAMETERS) if :Global == prop.shape[1]]

        code = postwalk(x->@capture(x,g_) && g == bs ? :($bs[1]) : x, code)
        code = postwalk(x->@capture(x,g_[p1_][p2_]) && g == bs ? :($bs[1]) : x, code) #Undo if it was already vectorized

    end

    code = randomAdapt(code, agent)

    return code

end

"""
    function clean(code,it=5)

Simplify code by removing multiplications by 1 or 0 and additions of 0 that appear sometimes when generating the integration code.
"""
function clean(code,it=5)

    for i in 1:it
        code = postwalk(x->@capture(x,varVarΔW_[g_,0,y_]) ? 0 : x, code)
        code = postwalk(x->@capture(x,1*g_) ? g : x, code)
        code = postwalk(x->@capture(x,0*g_) ? 0 : x, code)
        code = postwalk(x->@capture(x,0+g_) ? g : x, code)
        code = postwalk(x->@capture(x,g_*1) ? g : x, code)
        code = postwalk(x->@capture(x,g_*0) ? 0 : x, code)
        code = postwalk(x->@capture(x,g_+0) ? g : x, code)
        code = postwalk(x->@capture(x,f_+0+g_) ? :($f+$g) : x, code)
        code = postwalk(x->@capture(x,f_+g_+0) ? :($f+$g) : x, code)
        code = postwalk(x->@capture(x,0*f_*g_) ? 0 : x, code)
    end

    return code
end

##############################################################################################################################
# Random functions
##############################################################################################################################
VALIDDISTRIBUTIONS = [i for i in names(Distributions) if uppercasefirst(string(i)) == string(i)]
VALIDDISTRIBUTIONSCUDA = [:Normal,:Uniform,:Exponential]

#Random distribution transformations for cuda capabilities
"""
    NormalCUDA(x,μ,σ)

Normal distribution adapted to CUDA.
"""
NormalCUDA(x,μ,σ) = σ*CUDA.sqrt(2.)*SpecialFunctions.erfinv(2*(x-.5))+μ
"""
    UniformCUDA(x,l0,l1)

Uniform distribution adapted to CUDA.
"""
UniformCUDA(x,l0,l1) = (l1-l0)*x+l0
"""
    ExponentialCUDA(x,θ)

Exponential distribution adapted to CUDA.
"""
ExponentialCUDA(x,θ) = -CUDA.log(1-x)*θ

"""
    function randomAdapt(code, p)

Adapt the random function invocations of the code to be executable in the different platforms.
"""
function randomAdapt(code, p)

    if p.platform == :CPU
        for i in VALIDDISTRIBUTIONS
            code = postwalk(x -> @capture(x,$i(v__)) ? :(AgentBasedModels.rand(AgentBasedModels.$i($(v...)))) : x, code)
        end
    elseif p.platform == :GPU
        for i in VALIDDISTRIBUTIONS

            if inexpr(code,i) && !(i in VALIDDISTRIBUTIONSCUDA)
                error(i," random distribution valid for cpu but still not implemented in gpu. Valid distributions are $(VALIDDISTRIBUTIONSCUDA)")
            else
                s = Meta.parse(string("AgentBasedModels.",i,"CUDA"))
                code = postwalk(x -> @capture(x,$i(v__)) ? :($s(AgentBasedModels.rand(),$(v...))) : x, code)

            end

        end
    end    
    
    return code
    
end