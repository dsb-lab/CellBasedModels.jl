cellInMesh(edge,x,xMin,xMax,nX) = if x > xMax nX elseif x < xMin 1 else Int((x-xMin)÷edge)+1 end

##############################################################################################################################
# Delta functions
##############################################################################################################################

"""
    functionδ(x,meshSize)

Delta function dicretized.
"""
functionδ(x,meshSize) = Float32(abs(x) < meshSize/2)

##############################################################################################################################
# Agent functions
##############################################################################################################################
function isemptyupdaterule(agent,rule) 
    if rule in keys(agent.declaredUpdates)
        return [i for i in prettify(agent.declaredUpdates[rule]).args if typeof(i) != LineNumberNode] == []
    else
        return true
    end
end
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
    function agentArgs(sym=nothing;params=BASEPARAMETERS) 

Function that returns the arguments obervable for the constructed functions. If symbol is given, it substitutes by the fielnames in form of by *sym.fieldname*.
"""
function agentArgsNeighbors(args,neig;sym=nothing) 

    if sym === nothing
        pars = [:N,:simBox,:flagRecomputeNeighbors_]
        pars = [pars;[i for i in args]]
        pars = [pars;[i for i in fieldnames(neig) if i != :f_]]
        return pars
    else
        pars = [:($sym.N),:($sym.simBox),:($sym.flagRecomputeNeighbors_)]
        pars = [pars;[:($sym.$i) for i in args]]
        pars = [pars;[:($sym.neighbors.$i) for i in fieldnames(neig) if i != :f_]]
        return pars
    end

end

function agentArgs(com;sym=nothing,l=3,params=BASEPARAMETERS) 

    pars = [i for i in keys(params)]
    parsCom = [i for i in fieldnames(typeof(com.neighbors)) if  i != :f_]
    args = [i for i in keys(com.abm.parameters)]
    argsUp = [new(i) for (i,prop) in pairs(com.abm.parameters) if prop.update]
    parsPlat = [i for i in fieldnames(typeof(com.platform))]

    if sym === nothing
        return Any[pars...,
                    parsCom...,
                    args...,
                    argsUp...,
                    parsPlat...
                    ]
    else
        return [
                Any[:($sym.$i) for i in pars];
                Any[:($sym.neighbors.$i) for i in parsCom];
                Any[:($sym.parameters[Symbol($i)]) for i in String.(args)];
                Any[:($sym.parameters[Symbol($i)]) for i in String.(argsUp)];
                Any[:($sym.platform.$i) for i in parsPlat];
                ]
    end

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
    function makeSimpleLoop(code,agent;nloops=nothing)

Wrap code in loop iterating over the Community agents in the correct platform and dimensions (for medium).
"""
function makeSimpleLoop(code,com;nloops=nothing)

    if typeof(com.platform) <: CPU
        
        if nloops === nothing
            return :(@inbounds Threads.@threads for i1_ in 1:1:N[1]; $code; end)
        elseif nloops == 1
            return :(@inbounds Threads.@threads for i1_ in 1:1:NMedium[1]; $code; end)
        elseif nloops == 2
            return :(@inbounds Threads.@threads for i1_ in 1:1:NMedium[1]; for i2_ in 1:1:NMedium[2]; $code; end; end)
        elseif nloops == 3
            return :(@inbounds Threads.@threads for i1_ in 1:1:NMedium[1]; for i2_ in 1:1:NMedium[2];  for i3_ in 1:1:NMedium[3]; $code; end; end; end)
        end

    else typeof(com.platform) <: GPU

        if nloops === nothing
            CUDATHREADS1D = quote
                index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                stride = gridDim().x * blockDim().x
            end            

            return :($CUDATHREADS1D; @inbounds for i1_ in index:stride:N; $code; end)
        elseif nloops == 1
            CUDATHREADS1D = quote
                index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                stride = gridDim().x * blockDim().x
            end            

            return :($CUDATHREADS1D; @inbounds for i1_ in index:stride:NMedium[1]; $code; end)
        elseif nloops == 2
            CUDATHREADS2D = quote
                index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                stride = gridDim().x * blockDim().x
                indexY = (blockIdx().y - 1) * blockDim().y + threadIdx().y
                strideY = gridDim().y * blockDim().y
            end            

            return :($CUDATHREADS2D; @inbounds for i1_ in index:stride:NMedium[1]; for i2_ in indexY:strideY:NMedium[2]; $code; end; end)
        elseif nloops == 3
            CUDATHREADS3D = quote
                index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                stride = gridDim().x * blockDim().x
                indexY = (blockIdx().y - 1) * blockDim().y + threadIdx().y
                strideY = gridDim().y * blockDim().y
                indexZ = (blockIdx().z - 1) * blockDim().z + threadIdx().z
                strideZ = gridDim().z * blockDim().z
            end            

            return :($CUDATHREADS3D; @inbounds for i1_ in index:stride:NMedium[1]; for i2_ in indexY:strideY:NMedium[2]; for i3_ in indexZ:strideZ:NMedium[3]; $code; end; end; end)
        end

    end

end

"""
    function noBorders(code,agent)

Function that limits the computations to the inner set of a grid.
"""
function noBorders(code,agent)

    if agent.dims == 1
        return :(if 1 < i1_ < NMedium[1]; $code; end)
    elseif agent.dims == 2
        return :(if 1 < i1_ < NMedium[1] && 1 < i2_ < NMedium[2]; $code; end)
    elseif agent.dims == 3
        return :(if 1 < i1_ < NMedium[1] && 1 < i2_ < NMedium[2] && 1 < i3_ < NMedium[3]; $code; end)
    end

end

"""
    function addCuda(code,platform::Symbol;oneThread=false)
    function addCuda(code,agent;oneThread=false)

Add cuda macro to execute the kernel with the correspondent number of threads and blocks.
If one thread, launches the kernel just with one thread.
"""
function addCuda(code,scope,platform::Platform;oneThread=false)


    if typeof(platform) <: GPU

        if oneThread

            code = :(AgentBasedModels.CUDA.@sync AgentBasedModels.@cuda threads=1 blocks=1 $code)
        
        else

            code = :(AgentBasedModels.CUDA.@sync AgentBasedModels.@cuda threads=community.platform.$(addSymbol(scope,"Threads")) blocks=community.platform.$(addSymbol(scope,"Blocks")) $code)

        end

    end

    return code

end

function addCuda(code,scope,com;oneThread=false)

    return addCuda(code,scope,com.platform,oneThread=oneThread)

end

"""
    function cudaAdapt(code,platform)

Adapt specific CPU forms of calling parameters (e.g. Atomic) to CUDA valid code (Atomic -> size 1 CuArray).
"""
function cudaAdapt(code,platform)

    if typeof(platform) <: GPU

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

##############################################################################################################################
# Vectorize parameters
##############################################################################################################################
# """
#     function vectorize(code,agent)

# Function that transforms the code provided in Agent to the vectorized form for wrapping around an executable function.
# """
# function vectorize2(code,agent)

#     #For user declared symbols
#     for (sym,prop) in pairs(agent.declaredSymbols)

#         bs = prop.basePar
#         bsn = baseParameterNew(bs)
#         pos = prop.position
#         if :Local == prop.scope
#             code = postwalk(x->@capture(x,g_.p1_.p2_) && g == sym && p1 == BASESYMBOLS[:UpdateSymbol].symbol && p2 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bsn[i1_,$pos]) : x, code)
#             code = postwalk(x->@capture(x,g_.p1_.p2_) && g == sym && p1 == BASESYMBOLS[:UpdateSymbol].symbol && p2 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bsn[i2_,$pos]) : x, code)
#             code = postwalk(x->@capture(x,g_.p1_.p2_) && g == sym && p2 == BASESYMBOLS[:UpdateSymbol].symbol && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bsn[i1_,$pos]) : x, code)
#             code = postwalk(x->@capture(x,g_.p1_.p2_) && g == sym && p2 == BASESYMBOLS[:UpdateSymbol].symbol && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bsn[i2_,$pos]) : x, code)
#             code = postwalk(x->@capture(x,g_.p1_) && g == sym && p1 == BASESYMBOLS[:UpdateSymbol].symbol ? :($bsn[i1_,$pos]) : x, code)
#             code = postwalk(x->@capture(x,g_) && g == sym ? :($bs[i1_,$pos]) : x, code)
#             code = postwalk(x->@capture(x,g_[p1_][p2_]) && g == sym ? :($bs[$p2,$pos]) : x, code) #Undo if it was already vectorized
#             code = postwalk(x->@capture(x,g_.p1_) && g == sym && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bs[i1_,$pos]) : x, code)
#             code = postwalk(x->@capture(x,g_.p1_) && g == sym && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bs[i2_,$pos]) : x, code)
#             code = postwalk(x->@capture(x,g_[h__].p1_) && g == sym && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bs[i1_,$pos]) : x, code)
#             code = postwalk(x->@capture(x,g_[h__].p1_) && g == sym && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bs[i2_,$pos]) : x, code)
#             code = postwalk(x->@capture(x,g_[h__].p1_) && g == bs && p1 == BASESYMBOLS[:AddCell].symbol ? :($bsn[i1New_,$pos]) : x, code)
#         elseif :Global == prop.scope
#             code = postwalk(x->@capture(x,g_.p1_) && g == sym && p1 == BASESYMBOLS[:UpdateSymbol].symbol ? :($bsn[$pos]) : x, code)
#             code = postwalk(x->@capture(x,g_) && g == sym ? :($bs[$pos]) : x, code)
#         elseif :Medium == prop.scope
#             args = [:gridPosx_,:gridPosy_,:gridPosz_][1:agent.dims]
#             code = postwalk(x->@capture(x,g_.j) && g == sym ? :($bs[$(args...)]) : x, code)
#         elseif :Atomic == prop.scope
#             nothing
#         else
#             error("Symbol $bs with type $(prop[2]) doesn't has not vectorization implemented.")
#         end

#     end

#     #For local parameters
#     for bs in [sym for (sym,prop) in pairs(BASEPARAMETERS) if :Local == prop.shape[1]]

#         bsn = baseParameterNew(bs)
#         code = postwalk(x->@capture(x,g_.p1_.p2_) && g == bs && p1 == BASESYMBOLS[:UpdateSymbol].symbol && p2 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bsn[i1_]) : x, code)
#         code = postwalk(x->@capture(x,g_.p1_.p2_) && g == bs && p1 == BASESYMBOLS[:UpdateSymbol].symbol && p2 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bsn[i2_]) : x, code)
#         code = postwalk(x->@capture(x,g_.p1_.p2_) && g == bs && p2 == BASESYMBOLS[:UpdateSymbol].symbol && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bsn[i1_]) : x, code)
#         code = postwalk(x->@capture(x,g_.p1_.p2_) && g == bs && p2 == BASESYMBOLS[:UpdateSymbol].symbol && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bsn[i2_]) : x, code)
#         code = postwalk(x->@capture(x,g_.p1_) && g == bs && p1 == BASESYMBOLS[:UpdateSymbol].symbol ? :($bsn[i1_]) : x, code)
#         code = postwalk(x->@capture(x,g_) && g == bs ? :($bs[i1_]) : x, code)
#         code = postwalk(x->@capture(x,g_[p1_][p2__]) && g == bs ? :($bs[$(p2...)]) : x, code) #Undo if it was already vectorized
#         code = postwalk(x->@capture(x,g_.p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bs[i1_]) : x, code)
#         code = postwalk(x->@capture(x,g_.p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bs[i2_]) : x, code)
#         code = postwalk(x->@capture(x,g_[i1_].p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bs[i1_]) : x, code)
#         code = postwalk(x->@capture(x,g_[i2_].p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bs[i2_]) : x, code)
#         code = postwalk(x->@capture(x,g_[h__].p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex1].symbol ? :($bs[i1_,$(h[2])]) : x, code)
#         code = postwalk(x->@capture(x,g_[h__].p1_) && g == bs && p1 == BASESYMBOLS[:InteractionIndex2].symbol ? :($bs[i2_,$(h[2])]) : x, code)
#         code = postwalk(x->@capture(x,g_[h__].p1_) && g == bs && p1 == BASESYMBOLS[:AddCell].symbol ? :($bsn[i1New_]) : x, code)

#     end

#     #For global parameters
#     for bs in [sym for (sym,prop) in pairs(BASEPARAMETERS) if :Global == prop.shape[1]]

#         code = postwalk(x->@capture(x,g_) && g == bs ? :($bs[1]) : x, code)
#         code = postwalk(x->@capture(x,g_[p1_][p2_]) && g == bs ? :($bs[1]) : x, code) #Undo if it was already vectorized

#     end

#     code = randomAdapt(code, agent)

#     return code

# end

"""
    function vectorize(code,agent)

Function that transforms the code provided in Agent to the vectorized form for wrapping around an executable function.
"""
function vectorize(code,com)

    agent = com.abm
    #For user declared symbols
    code = postwalk(x->@capture(x,id) ? :(id[i1_]) : x, code)
    code = postwalk(x->@capture(x,id[f_][f2_]) ? :(id[$f2]) : x, code) #avoid double indexing
    if typeof(agent) !== Int64 #Avoid empty AGENT
        for (sym,prop) in pairs(agent.parameters)

            if :agent == prop.scope
                code = postwalk(x->@capture(x,g_) && g == sym ? :($g[i1_]) : x, code)
                code = postwalk(x->@capture(x,g_) && g == new(sym) ? :($g[i1_]) : x, code)
                code = postwalk(x->@capture(x,g_) && g == opdt(sym) ? :($g[i1_]) : x, code)
            elseif :model == prop.scope && prop.dtype <: Number
                code = postwalk(x->@capture(x,g_) && g == sym ? :($g[1]) : x, code)
                code = postwalk(x->@capture(x,g_) && g == new(sym) ? :($g[1]) : x, code)
                code = postwalk(x->@capture(x,g_) && g == opdt(sym) ? :($g[1]) : x, code)
            elseif :model == prop.scope && !(prop.dtype <: Number)
                nothing
            elseif :medium == prop.scope
                args = [:i1_,:i2_,:i3_][1:agent.dims]
                code = postwalk(x->@capture(x,g_) && g == sym ? :($g[$(args...)]) : x, code)
                code = postwalk(x->@capture(x,g_) && g == new(sym) ? :($g[$(args...)]) : x, code)
                code = postwalk(x->@capture(x,g_) && g == opdt(sym) ? :($g[$(args...)]) : x, code)
            elseif :Atomic == prop.scope
                nothing
            else
                error("Symbol $bs with type $(prop[2]) doesn't has not vectorization implemented.")
            end
            code = postwalk(x->@capture(x,g_[f_][f2__]) && g == sym ? :($g[$(f2...)]) : x, code) #avoid double indexing
            code = postwalk(x->@capture(x,g_[f_][f2__]) && g == new(sym) ? :($g[$(f2...)]) : x, code) #avoid double indexing
            code = postwalk(x->@capture(x,g_[f_][f2__]) && g == opdt(sym) ? :($g[$(f2...)]) : x, code) #avoid double indexing
        end
    end

    #For global parameters
    for bs in [sym for (sym,prop) in pairs(BASEPARAMETERS) if :Global == prop.shape[1]]

        code = postwalk(x->@capture(x,g_) && g == bs ? :($bs[1]) : x, code)
        code = postwalk(x->@capture(x,g_[p1_][p2_]) && g == bs ? :($bs[1]) : x, code) #Undo if it was already vectorized

    end

    return code

end

function vectorize(code)

    return vectorize(code,COMUNITY)

end

function vectorizeMediumInAgents(code,com)

    for (sym,prop) in pairs(com.abm.parameters)
        if prop.scope == :medium
            code = postwalk(x->@capture(x,m_[g_]) && (m == sym || m == new(sym)) ? :($m[cellInMesh(dx,x[i1_],simBox[1,1],simBox[1,2],NMedium[1])]) : x ,code)
            code = postwalk(x->@capture(x,m_[g_,g2_]) && (m == sym || m == new(sym)) ? :($m[cellInMesh(dx,x[i1_],simBox[1,1],simBox[1,2],NMedium[1]),cellInMesh(dy,y[i1_],simBox[2,1],simBox[2,2],NMedium[2])]) : x ,code)
            code = postwalk(x->@capture(x,m_[g_,g2_,g3_]) && (m == sym || m == new(sym)) ? :($m[cellInMesh(dx,x[i1_],simBox[1,1],simBox[1,2],NMedium[1]),cellInMesh(dy,y[i1_],simBox[2,1],simBox[2,2],NMedium[2]),cellInMesh(dz,z[i1_],simBox[3,1],simBox[3,2],NMedium[3])]) : x ,code)
        end
    end

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

#Random distribution transformations for cuda capabilities
function captureVariables(code)
    function add(a,s)
        push!(a,s)
        unique!(a)
        return addSymbol("dt__",s)
    end
    a = []
    code = postwalk(x->@capture(x,dt(m_)) ? add(a,m) : x, code)
    return a, code
end

function opdt(sym)
    return Meta.parse(string("dt__",sym))
end

function new(sym)
    return Meta.parse(string(sym,"__"))
end

function old(sym)

    if occursin("__",string(sym))
        if string(sym)[end-1:end] == "__"
            return Meta.parse(string(sym)[1:end-2])
        else
            return sym
        end
    else
        return sym
    end
end

function addSymbol(args...)
    return Meta.parse(string(args...))
end