##############################################################################################################################
# Agent functions
##############################################################################################################################
"""
    function isemptyupdaterule(agent,rule) 

Function that checks if a ABM rule is empty (agentRule, mediumODE...)
"""
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
        pars = [pars;[:($sym.abm.neighbors.$i) for i in fieldnames(neig) if i != :f_]]
        return pars
    end

end

"""
    function agentArgs(abm;sym=nothing,l=3,params=BASEPARAMETERS) 

Function that returns the arguments to be provided to a kernel function. If `sym` is provided, it will return them as `sym.argument`.
"""
function agentArgs(abm;sym=nothing,l=3,params=BASEPARAMETERS) 

    pars = [i for i in keys(params)]
    parsCom = [i for i in fieldnames(typeof(abm.neighbors)) if  i != :f_]
    args = [i for i in keys(abm.parameters)]
    argsUp = [new(i) for (i,prop) in pairs(abm.parameters) if prop.update]

    if sym === nothing
        return Any[pars...,
                    parsCom...,
                    args...,
                    argsUp...,
                    :platform
                    ]
    else
        return [
                Any[:($sym.$i) for i in pars];
                Any[:($sym.abm.neighbors.$i) for i in parsCom];
                Any[:($sym.parameters[Symbol($i)]) for i in String.(args)];
                Any[:($sym.parameters[Symbol($i)]) for i in String.(argsUp)];
                Any[:($sym.abm.platform)];
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
    function makeSimpleLoop(code,abm;nloops=nothing)

Wrap code in loop iterating over the Community agents in the correct platform and dimensions (for medium).
"""
function makeSimpleLoop(code,abm;nloops=nothing)

    if typeof(abm.platform) <: CPU
        
        if nloops === nothing
            return :(@inbounds Threads.@threads for i1_ in 1:1:N[1]; $code; end)
        elseif nloops == 1
            return :(@inbounds Threads.@threads for i1_ in 1:1:NMedium[1]; $code; end)
        elseif nloops == 2
            return :(@inbounds Threads.@threads for i1_ in 1:1:NMedium[1]; for i2_ in 1:1:NMedium[2]; $code; end; end)
        elseif nloops == 3
            return :(@inbounds Threads.@threads for i1_ in 1:1:NMedium[1]; for i2_ in 1:1:NMedium[2];  for i3_ in 1:1:NMedium[3]; $code; end; end; end)
        end

    else typeof(abm.platform) <: GPU

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

            code = :(CellBasedModels.CUDA.@sync CellBasedModels.@cuda threads=1 blocks=1 $code)
        
        else

            code = :(CUDA.@cuda threads=community.abm.platform.$(addSymbol(scope,"Threads")) blocks=community.abm.platform.$(addSymbol(scope,"Blocks")) $code)

        end

    end

    return code

end

function addCuda(code,scope,abm;oneThread=false)

    return addCuda(code,scope,abm.platform,oneThread=oneThread)

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

##############################################################################################################################
# Vectorize parameters
##############################################################################################################################
"""
    function vectorize(code,agent)

Function that transforms the code provided in Agent to the vectorized form for wrapping around an executable function.
"""
function vectorize(code,agent)

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
            code = postwalk(x->@capture(x,g_[f__][f2__]) && g == sym ? :($g[$(f2...)]) : x, code) #avoid double indexing
            code = postwalk(x->@capture(x,g_[f__][f2__]) && g == new(sym) ? :($g[$(f2...)]) : x, code) #avoid double indexing
            code = postwalk(x->@capture(x,g_[f__][f2__]) && g == opdt(sym) ? :($g[$(f2...)]) : x, code) #avoid double indexing
        end
    end

    #For global parameters
    for bs in [sym for (sym,prop) in pairs(BASEPARAMETERS) if :Global == prop.shape[1]]

        code = postwalk(x->@capture(x,g_) && g == bs ? :($bs[1]) : x, code)
        code = postwalk(x->@capture(x,g_[p1_][p2_]) && g == bs ? :($bs[1]) : x, code) #Undo if it was already vectorized

    end

    return code

end

# function vectorize(code)

#     return vectorize(code,COMUNITY)

# end

"""
    function vectorizeMediumInAgents(code,abm)

Function that vectorize medium parameters at the position of the agent center.
"""
function vectorizeMediumInAgents(code,abm)

    for (sym,prop) in pairs(abm.parameters)
        if prop.scope == :medium
            code = postwalk(x->@capture(x,m_[g_]) && (m == sym || m == new(sym)) ? :($m[CBMMetrics.cellInMesh(dx,x[i1_],simBox[1,1],simBox[1,2],NMedium[1])]) : x ,code)
            code = postwalk(x->@capture(x,m_[g_,g2_]) && (m == sym || m == new(sym)) ? :($m[CBMMetrics.cellInMesh(dx,x[i1_],simBox[1,1],simBox[1,2],NMedium[1]),CBMMetrics.cellInMesh(dy,y[i1_],simBox[2,1],simBox[2,2],NMedium[2])]) : x ,code)
            code = postwalk(x->@capture(x,m_[g_,g2_,g3_]) && (m == sym || m == new(sym)) ? :($m[CBMMetrics.cellInMesh(dx,x[i1_],simBox[1,1],simBox[1,2],NMedium[1]),CBMMetrics.cellInMesh(dy,y[i1_],simBox[2,1],simBox[2,2],NMedium[2]),CBMMetrics.cellInMesh(dz,z[i1_],simBox[3,1],simBox[3,2],NMedium[3])]) : x ,code)
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

#################################################################################################################
# Manipulating symbols and other decorators
#################################################################################################################
"""
    function captureVariables(code)

Function that transforms the dt(par) nomenclature in the variable dt__par for being used in Differential Equations kernels.
"""
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

"""
    function opdt(sym)

Function that returns the symbol dt__sym
"""
function opdt(sym)
    return Meta.parse(string("dt__",sym))
end

"""
    function new(sym)

Function that returns the symbol sym__
"""
function new(sym)
    return Meta.parse(string(sym,"__"))
end

"""
    function old(sym)

Function that returns the parametric symbol sym is it is new.
"""
function old(sym)

    if occursin("__",string(sym))
        if string(sym)[end-1:end] == "__"
            return Meta.parse(string(sym)[1:length(string(sym))-2])
        else
            return sym
        end
    else
        return sym
    end
end

"""
    function addSymbol(args...)

Function to make a new symbol putting together all the arguments.
"""
function addSymbol(args...)
    return Meta.parse(string(args...))
end