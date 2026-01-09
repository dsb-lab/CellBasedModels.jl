import RecursiveArrayTools
import LinearAlgebra
import KernelAbstractions

# Add ForwardDiff support for automatic differentiation
using ForwardDiff: ForwardDiff

# Import OrdinaryDiffEqDifferentiation for jacobian! method
try
    using OrdinaryDiffEqDifferentiation
catch
    # Fallback if package not available
end

######################################################################################################
# Base Properties
######################################################################################################
abstract type AbstractUnstructuredMeshProperty end

struct Node{N, P} <: AbstractUnstructuredMeshProperty
    p::NamedTuple{N, P}    # Dictionary to hold agent properties
end

function Node(p::NamedTuple=(;)) 
    p_ = parameterConvert(p)
    Node{typeof(p_).parameters[1], typeof(p_).parameters[2]}(
        p_
    )
end

struct Edge{N, P} <: AbstractUnstructuredMeshProperty
    c::Tuple{Symbol, Symbol}
    p::NamedTuple{N, P}    # Dictionary to hold agent properties
end

function Edge(c::Tuple{Symbol, Symbol}, p::NamedTuple=(;))
    p_ = parameterConvert(p)
    Edge{typeof(p_).parameters[1], typeof(p_).parameters[2]}(
        c,
        p_
    )
end
struct Face{N, P} <: AbstractUnstructuredMeshProperty
    c::Symbol
    p::NamedTuple{N, P}    # Dictionary to hold agent properties
end

function Face(c::Symbol, p::NamedTuple=(;))
    p_ = parameterConvert(p)
    Face{typeof(p_).parameters[1], typeof(p_).parameters[2]}(
        c,
        p_
    )
end

struct Volume{N, P} <: AbstractUnstructuredMeshProperty
    c::Symbol
    p::NamedTuple    # Dictionary to hold agent properties
end

function Volume(c::Symbol, p::NamedTuple=(;))
    p_ = parameterConvert(p)
    Volume{typeof(p_).parameters[1], typeof(p_).parameters[2]}(
        c,
        p_
    )
end

struct Agent{N, P} <: AbstractUnstructuredMeshProperty
    p::NamedTuple{N, P}    # Dictionary to hold agent properties
end

function Agent(p::NamedTuple=(;))
    p_ = parameterConvert(p)
    Agent{typeof(p_).parameters[1], typeof(p_).parameters[2]}(
        p_
    )
end

######################################################################################################
# AGENT STRUCTURE
######################################################################################################
struct UnstructuredMesh{D, S, P} <: AbstractMesh

    _p::NamedTuple    # Dictionary to hold agent properties
    _functions::Dict{Symbol, Any}    # Dictionary to hold functions associated with the mesh

end

function _posMerge(properties, defaultParameters)
    for (k, v) in pairs(properties)
        if haskey(defaultParameters, k)
            error("Parameter $k is already defined and cannot be used as agent property.")
        elseif startswith(string(k), "_")
            error("Parameter $k is protected and cannot be used as agent property.")
        end
    end
    return merge(defaultParameters, properties)
end

function UnstructuredMesh(
    dims::Int;
    specialization::DataType=Nothing,
    kwargs...
)

    if dims < 0 || dims > 3
        error("dims must be between 0 and 3. Found $dims")
    end
    defaultParameters = (
        x = dims >= 1 ? Parameter(AbstractFloat, description="Position in x (protected parameter)", dimensions=:L) : nothing,
        y = dims >= 2 ? Parameter(AbstractFloat, description="Position in y (protected parameter)", dimensions=:L) : nothing,
        z = dims >= 3 ? Parameter(AbstractFloat, description="Position in z (protected parameter)", dimensions=:L) : nothing,
    )
    defaultParameters = NamedTuple{Tuple(k for (k,v) in pairs(defaultParameters) if v !== nothing)}(
        (v for (k,v) in pairs(defaultParameters) if v !== nothing)
    )

    for (k, v) in pairs(kwargs)
        if !(typeof(v) <: AbstractUnstructuredMeshProperty)
            error("Property $k must be a subtype of AbstractUnstructuredMeshProperty. Found: $(typeof(v))")
        end
    end

    if !any(k -> k isa Node, values(kwargs))
        error("UnstructuredMesh must have at least a Node property defined.")
    end

    agents = [k for (k, v) in pairs(kwargs) if v isa Agent]

    if length(agents) > 1
        error("UnstructuredMesh can have at most one Agent property defined. Found $(length(agents)) Agent properties.")
    end

    nodes = [k for (k, v) in pairs(kwargs) if v isa Node]

    propertiesAdapted = Dict()
    for (n,i) in kwargs
        if i isa Edge
            if !(i.c[1] in nodes) || !(i.c[2] in nodes)
                error("Edge properties must reference existing Node properties. Found Edge referencing $(i.c[1]) and $(i.c[2]), but existing Node properties are: $nodes")
            end
        elseif i isa Face || i isa Volume
            if !(i.c in nodes)
                error("Face and Volume properties must reference existing Node properties. Found referencing $(i.c), but existing Node properties are: $nodes")
            end
        end

        if i isa Node
            propertiesAdapted[n] = Node(_posMerge(i.p, defaultParameters))
        elseif i isa Edge
            propertiesAdapted[n] = Edge(i.c, i.p)
        elseif i isa Face
            propertiesAdapted[n] = Face(i.c, i.p)
        elseif i isa Volume
            propertiesAdapted[n] = Volume(i.c, i.p)
        elseif i isa Agent
            propertiesAdapted[n] = Agent(i.p)
        else
            error("Unknown property type: $(typeof(i))")
        end
    end

    propertiesTuple = NamedTuple{Tuple(k for (k,v) in pairs(propertiesAdapted))}(
        (v for (k,v) in pairs(propertiesAdapted))
    )

    return UnstructuredMesh{dims, specialization, typeof(propertiesTuple)}(
        propertiesTuple,
        Dict{Symbol, Any}()
    )
end

spatialDims(::UnstructuredMesh{D}) where {D} = D
specialization(::UnstructuredMesh{D, S}) where {D, S} = S

function Base.show(io::IO, x::UnstructuredMesh)

    if specialization(x) === Nothing
        println(io, "UnstructuredMesh with dimensions $(spatialDims(x)): \n")
    else
        println(io, "$(specialization(x)) with dimensions $(spatialDims(x)): \n")
    end
    for (name, props) in pairs(x._p)
        println(io, "(", typeof(props).name.name, ") mesh.",string(name),".")
        println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-60s %-s", "Name", "DataType", "Dimensions", "Default_Value", "ModifiedIn", "Description"))
        println(io, "\t" * repeat("-", 145))
        for (n, par) in pairs(props.p)
            println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-60s %-s", 
                n, 
                dtype(par), 
                par.dimensions === nothing ? "" : string(par.dimensions),
                par.defaultValue === nothing ? "" : string(par.defaultValue), 
                length(par._modifiedIn) === 0 ? "" : string(tuple([i[2] for i in par._modifiedIn]...)),
                par.description))
        end
        println(io)
    end
    println(io, "Functions")
    for (scope, (type, funcs)) in pairs(x._functions)
        print(io, "\t", scope, " (", type, "):")
        for (i,f) in enumerate(funcs)
            # print(io, "\t\t Subfunctions ", i, ":")
            print(io, " ", f)
        end
        println(io)
    end
end

function Base.show(io::IO, ::Type{UnstructuredMesh{D, S, P}}) where {D, S, P}
    if S === Nothing
        print(io, "UnstructuredMesh{dims=", D, ",")
    else
        print(io, string(S), "{dims=", D, ",")
    end
    for (name, prop) in zip(P.parameters[1], P.parameters[2].parameters[1].parameters)
        print(io, string(name), "=(")
        for i in prop[1:end-1]
            print(io, i, ",")
        end
        print(io, prop[end], ")")
        # for p in prop.parameters[2].parameters[1]
        #     print(io, string(p), "::", t.parameters[1])
        # end
    end
    print(io, "}")
end

function addFunction!(mesh::UnstructuredMesh, type, scope, params, functions)

    for param in params
        if !(length(param) in (2,3))
            error("Each parameter modification must be a tuple of (field, parameter_name). Found: $param. Most probably you assigned incorrectly a parameter in a function (e.g. mesh.field_name.parameter_name). Valid parameters are: \n $mesh")
        elseif length(param) == 3 && param[2] != :_p
            error("When specifying three elements in parameter modification tuple, the second element must be :_p to indicate accessing the properties. Found: $param. Most probably you assigned incorrectly a parameter in a function (e.g. mesh.field_name.parameter_name). Valid parameters are: \n $mesh")
        end

        field_name = nothing
        parameter_name = nothing
        if length(param) == 2
            field_name, parameter_name = param
        else
            field_name, _, parameter_name = param
        end

        field = nothing
        if field_name in keys(mesh._p)
            field = getfield(mesh._p, field_name)
        else
            error("Mesh does not have field $field_name. Available fields are: $(fieldnames(typeof(mesh))). Most probably you assigned incorrectly a parameter in a function (e.g. mesh.$field_name.$parameter_name). Valid parameters are: \n $mesh")
        end  

        if parameter_name in keys(field.p)
            par = field.p[parameter_name]
            CellBasedModels.setModifiedIn!(par, type, scope)
        else
            error("Parameter $parameter_name does not exist in field $field_name. Most probably you assigned incorrectly a parameter in a function (e.g. mesh.$field_name.$parameter_name). Valid parameters are: \n $mesh")
        end
    end

    if scope in keys(mesh._functions)
        error("Function scope $scope is already defined for the mesh. Multiple definitions are not allowed.")
    else
        mesh._functions[scope] = (type, functions)
    end

    return
end

function modifiedInScope(mesh::UnstructuredMesh, scope::Symbol)

    modified = []

    for field in keys(mesh._p)
        props = getfield(mesh._p, field)
        for (name, par) in pairs(props.p)
            for (t, s) in par._modifiedIn
                if s == scope
                    push!(modified, (field, name))
                end
            end
        end
    end

    return modified
end

function modifiedInScope(mesh::UnstructuredMesh)

    modified = []

    for field in keys(mesh._p)
        props = getfield(mesh, field)
        if props !== nothing
            for (name, par) in pairs(props.p)
                for (t, s) in par._modifiedIn
                    push!(modified, (field, name))
                end
            end
        end
    end

    return modified
end

######################################################################################################
# UnstructuredMeshField
######################################################################################################
struct UnstructuredMeshField{
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,    
            VI1, VI2, VI3, VI4,
            AI, VB, SI, VVNT, AB            
        }
    _p::PR
    _NP::Int
    _pReference::PRC

    _id::IDVI
    _idMax::IDAI

    _nodes1::VI1
    _nodes2::VI2
    _nodes3::VI3
    _nodes4::VI4

    _N::AI
    _NCache::AI
    _FlagsSurvived::VB
    _NRemoved::AI
    _NRemovedThread::SI
    _NAdded::AI
    _NAddedThread::SI    
    _AddedAgents::VVNT
    _NOverflow::AB
end
Adapt.@adapt_structure UnstructuredMeshField

const UnstructuredMeshNode{
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,    
            AI, VB, SI, VVNT, AB            
        } = UnstructuredMeshField{
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,    
            Nothing, Nothing, Nothing, Nothing,
            AI, VB, SI, VVNT, AB            
        }

const UnstructuredMeshEdge{
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,    
            VI1, VI2,
            AI, VB, SI, VVNT, AB            
        } = UnstructuredMeshField{
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,    
            VI1, VI2, Nothing, Nothing,
            AI, VB, SI, VVNT, AB            
        }

const UnstructuredMeshFace{
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,    
            VI1, VI2, VI3,
            AI, VB, SI, VVNT, AB            
        } = UnstructuredMeshField{
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,    
            VI1, VI2, VI3, Nothing,
            AI, VB, SI, VVNT, AB            
        }

const UnstructuredMeshVolume{
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,    
            VI1, VI2, VI3, VI4,
            AI, VB, SI, VVNT, AB            
        } = UnstructuredMeshField{
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,    
            VI1, VI2, VI3, VI4,
            AI, VB, SI, VVNT, AB            
        }

function UnstructuredMeshField(
        meshProperties::AbstractUnstructuredMeshProperty;
        N::Int=0,
        NCache::Int=0,
        id=true
)

    if meshProperties === nothing
        return nothing
    end

    if id
        _id = Vector{Int}(zeros(Int, NCache))
        _id[1:N] = 1:N
        _idMax = SizedVector{1}(N)
    else
        _id = nothing
        _idMax = nothing
    end

    # Initialize node connectivity based on mesh property type
    if meshProperties isa Node || meshProperties isa Agent
        _nodes1 = nothing
        _nodes2 = nothing
        _nodes3 = nothing
        _nodes4 = nothing
    elseif meshProperties isa Edge
        _nodes1 = zeros(Int, NCache)
        _nodes2 = zeros(Int, NCache)
        _nodes3 = nothing
        _nodes4 = nothing
    elseif meshProperties isa Face
        _nodes1 = zeros(Int, NCache)
        _nodes2 = zeros(Int, NCache)
        _nodes3 = zeros(Int, NCache)
        _nodes4 = nothing
    elseif meshProperties isa Volume
        _nodes1 = zeros(Int, NCache)
        _nodes2 = zeros(Int, NCache)
        _nodes3 = zeros(Int, NCache)
        _nodes4 = zeros(Int, NCache)
    end

    _N = SizedVector{1}(N)
    _NCache = SizedVector{1}(NCache)
    _FlagsSurvived = ones(Bool, NCache)
    _NRemoved = SizedVector{1}(0)
    _NRemovedThread = SizedVector{Threads.nthreads(), Int}(zeros(Int, Threads.nthreads()))
    _NAdded = SizedVector{1}(0)
    _NAddedThread = SizedVector{Threads.nthreads(), Int}(zeros(Int, Threads.nthreads()))
    P = keys(meshProperties.p)
    T = Tuple{(dtype(i, isbits=true) for i in values(meshProperties.p))...}
    _AddedAgents = [Vector{NamedTuple{P, T}}() for _ in 1:Threads.nthreads()]
    _NOverflow = SizedVector{1}(0)

    _p = NamedTuple{keys(meshProperties.p)}(zeros(dtype(dt, isbits=true), NCache) for dt in values(meshProperties.p))
    _NP = length(meshProperties.p)
    _pReference = SizedVector{length(_p), Bool}([true for _ in 1:length(meshProperties.p)])

    P = platform(_N)
    DT = Nothing
    for i in values(meshProperties.p)
        d = dtype(i, isbits=true)
        if d <: AbstractFloat
            DT = Float64
            break
        end
    end

    IDVI = typeof(_id)
    IDAI = typeof(_idMax)
    VI1 = typeof(_nodes1)
    VI2 = typeof(_nodes2)
    VI3 = typeof(_nodes3)
    VI4 = typeof(_nodes4)

    AI = typeof(_N)
    AB = typeof(_NOverflow)
    VB = typeof(_FlagsSurvived)
    SI = typeof(_NRemovedThread)
    VVNT = typeof(_AddedAgents)

    PR = typeof(_p)
    PRN = _NP
    PRC = typeof(_pReference)

    UnstructuredMeshField{
            P, DT,
            PR, PRN, PRC, 
            IDVI, IDAI,
            VI1, VI2, VI3, VI4,
            AI, VB, SI, VVNT, AB
        }(
            _p,
            _NP,
            _pReference,

            _id,
            _idMax,

            _nodes1,
            _nodes2,
            _nodes3,
            _nodes4,

            _N,
            _NCache,
            _FlagsSurvived,
            _NRemoved,
            _NRemovedThread,
            _NAdded,
            _NAddedThread,
            _AddedAgents,
            _NOverflow,
        )
end

function UnstructuredMeshField(
            _p,
            _NP,
            _pReference,

            _id,
            _idMax,

            _nodes1,
            _nodes2,
            _nodes3,
            _nodes4,

            _N,
            _NCache,
            _FlagsSurvived,
            _NRemoved,
            _NRemovedThread,
            _NAdded,
            _NAddedThread,
            _AddedAgents,
            _NOverflow,
    )

    P = platform(_N)
    DT = Nothing
    for i in values(_p)
        d = eltype(i)
        if d <: AbstractFloat
            DT = Float64
            break
        end
    end

    PR = typeof(_p)
    PRN = _NP
    PRC = typeof(_pReference)

    IDVI = typeof(_id)
    IDAI = typeof(_idMax)
    VI1 = typeof(_nodes1)
    VI2 = typeof(_nodes2)
    VI3 = typeof(_nodes3)
    VI4 = typeof(_nodes4)

    AI = typeof(_N)
    AB = typeof(_NOverflow)
    VB = typeof(_FlagsSurvived)
    SI = typeof(_NRemovedThread)
    VVNT = typeof(_AddedAgents)

    UnstructuredMeshField{
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,
            VI1, VI2, VI3, VI4,
            AI, VB, SI, VVNT, AB,
        }(
            _p,
            _NP,
            _pReference,

            _id,
            _idMax,

            _nodes1,
            _nodes2,
            _nodes3,
            _nodes4,

            _N,
            _NCache,
            _FlagsSurvived,
            _NRemoved,
            _NRemovedThread,
            _NAdded,
            _NAddedThread,
            _AddedAgents,
            _NOverflow,
        )
end

function Base.show(io::IO, x::UnstructuredMeshField{
            P, DT,
            PR, PRN, PRC, 
            IDVI, IDAI,
            VI1, VI2, VI3, VI4,
            AI, VB, SI, VVNT, AB,
        }) where {
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,
            VI1, VI2, VI3, VI4,
            AI, VB, SI, VVNT, AB, 
        } 
    
    println(io, "UnstructuredMeshField: \n")
    println(io, @sprintf("\t%-25s %-15s", "Property", "DataType"))
    println(io, "\t" * repeat("-", 40))
    println(io, @sprintf("\t%-25s %-15s", "_id", IDVI))
    println(io, @sprintf("\t%-25s %-15s", "_idMax", IDAI))
    if VI1 !== Nothing
        println(io, @sprintf("\t%-25s %-15s", "_nodes1", VI1))
    end
    if VI2 !== Nothing
        println(io, @sprintf("\t%-25s %-15s", "_nodes2", VI2))
    end
    if VI3 !== Nothing
        println(io, @sprintf("\t%-25s %-15s", "_nodes3", VI3))
    end
    if VI4 !== Nothing
        println(io, @sprintf("\t%-25s %-15s", "_nodes4", VI4))
    end
    println(io, @sprintf("\t%-25s %-15s", "_N", AI))
    println(io, @sprintf("\t%-25s %-15s", "_NCache", AI))
    println(io, @sprintf("\t%-25s %-15s", "_FlagsSurvived", VB))
    println(io, @sprintf("\t%-25s %-15s", "_NRemoved", AI))
    println(io, @sprintf("\t%-25s %-15s", "_NRemovedThread", SI))
    println(io, @sprintf("\t%-25s %-15s", "_NAdded", AI))
    println(io, @sprintf("\t%-25s %-15s", "_NAddedThread", SI))
    println(io, @sprintf("\t%-25s %-15s", "_AddedAgents", VVNT))
    println(io, @sprintf("\t%-25s %-15s", "_NOverflow", AB))

    for ((n, t), c) in zip(pairs(x._p), x._pReference)
        if c
            println(io, @sprintf("\t%-25s %-15s", string("*p.",n), typeof(t)))
        else
            println(io, @sprintf("\t%-25s %-15s", string("p.",n),  typeof(t)))
        end
    end

end

function Base.show(io::IO, x::Type{UnstructuredMeshField})
    println(io, "UnstructuredMeshField{")
    # CellBasedModels.show(io, x)
    println(io, "}")
end

function show(io::IO, ::Type{UnstructuredMeshField{
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,
            VI1, VI2, VI3, VI4,
            AI, VB, SI, VVNT, AB,
        }}) where {
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,
            VI1, VI2, VI3, VI4,
            AI, VB, SI, VVNT, AB,
        } 
    for (n, t) in zip(PR.parameters[1], PR.parameters[2].parameters)
        print(io, "p.", string(n), "::", t, ", ")
    end
    print(io, "_id::", IDVI, ", ")
    print(io, "_idMax::", IDAI, ", ")
    if VI1 !== Nothing
        print(io, "_nodes1::", VI1, ", ")
    end
    if VI2 !== Nothing
        print(io, "_nodes2::", VI2, ", ")
    end
    if VI3 !== Nothing
        print(io, "_nodes3::", VI3, ", ")
    end
    if VI4 !== Nothing
        print(io, "_nodes4::", VI4, ", ")
    end
    print(io, "_N::", AI, ", ")
    print(io, "_NCache::", AI, ", ")
    print(io, "_FlagsSurvived::", VB, ", ")
    print(io, "_NRemoved::", AI, ", ")
    print(io, "_NRemovedThread::", SI, ", ")
    print(io, "_NAdded::", AI, ", ")
    print(io, "_NAddedThread::", SI, ", ")
    print(io, "_AddedAgents::", VVNT, ", ")
    print(io, "_NOverflow::", AB, ", ")
end

@generated function Base.getproperty(field::UnstructuredMeshField{
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,
            VI1, VI2, VI3, VI4,
            AI, VB, SI, VVNT, AB,            
        }, s::Symbol) where {
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,
            VI1, VI2, VI3, VI4,
            AI, VB, SI, VVNT, AB}
    # build a clause for each fieldname in T
    general = [
        :(if s === $(QuoteNode(name)); return getfield(field, $(QuoteNode(name))); end)
        for name in fieldnames(UnstructuredMeshField)
    ]
    cases = [
        :(s === $(QuoteNode(name)) && return @views getfield(getfield(field, :_p), $(QuoteNode(name)))[1:lengthProperties(field)])
        for name in PR.parameters[1]
    ]

    quote
        $(general...)
        $(cases...)
        error("Unknown property: $s for of the UnstructuredMeshField.")
    end
end

nCopyProperties(field::UnstructuredMeshField) = count(!, field._pReference)
nRefProperties(field::UnstructuredMeshField) = count(identity, field._pReference)

lengthCache(field::UnstructuredMeshField) = field._NCache[]
lengthProperties(field::UnstructuredMeshField) = field._N[]
lengthPropertiesNew(field::UnstructuredMeshField) = field._N[] + field._NAdded[]
Base.length(field::UnstructuredMeshField{P}) where {P<:CPU} = nCopyProperties(field) * field._N[]

sizeProperties(field::UnstructuredMeshField) = (lengthProperties(field),)
sizeFull(field::UnstructuredMeshField) = (field._NP, field._N[])
sizeFullCache(field::UnstructuredMeshField) = (field._NP, field._NCache[])
Base.size(field::UnstructuredMeshField) = (nCopyProperties(field), lengthProperties(field))

Base.eltype(::UnstructuredMeshField{P, DT}) where {P, DT} = DT
Base.eltype(::Type{<:UnstructuredMeshField{P, DT}}) where {P, DT} = DT

Base.getindex(field::UnstructuredMeshField, i::Int) = field._p[i]
Base.getindex(field::UnstructuredMeshField, s::Symbol) = getproperty(field, s)

## Norm
function LinearAlgebra.norm(field::UnstructuredMeshField{P, DT}, t::Real) where {P, DT}
    total = 0.0
    N = lengthProperties(field)
    @inbounds for (p, r) in zip(values(field._p), field._pReference)
        if !r
            total += sum(@views p[1:N].^2)
        end
    end
    return sqrt(total)
end

## Pow2
function pow2(field::UnstructuredMeshField{P, DT}) where {P, DT}
    total = 0.0
    N = lengthProperties(field)
    @inbounds for (p, r) in zip(values(field._p), field._pReference)
        if !r
            total += sum(@views p[1:N].^2)
        end
    end
    return total
end

## Copy
function Base.copy(field::UnstructuredMeshField)

    UnstructuredMeshField(
        NamedTuple{keys(field._p)}(
            r ? p : Base.copy(p) for (p, r) in zip(values(field._p), field._pReference)
        ),
        field._NP,
        field._pReference,  # Tuples are immutable, no need to copy

        field._id,
        field._idMax,

        field._nodes1,
        field._nodes2,
        field._nodes3,
        field._nodes4,

        field._N,
        field._NCache,
        field._FlagsSurvived,
        field._NRemoved,
        field._NRemovedThread,
        field._NAdded,
        field._NAddedThread,
        field._AddedAgents,
        field._NOverflow,
    )

end

function partialCopy(field::UnstructuredMeshField, args)

    _pReference = typeof(field._pReference)([!r || p in args ? false : true for (p, r) in zip(keys(field._p), field._pReference)])

    UnstructuredMeshField(
        NamedTuple{keys(field._p)}(
            r ? p : copy(p) for (p, r) in zip(values(field._p), _pReference)
        ),
        field._NP,
        _pReference,

        field._id,
        field._idMax,

        field._nodes1,
        field._nodes2,
        field._nodes3,
        field._nodes4,

        field._N,
        field._NCache,
        field._FlagsSurvived,
        field._NRemoved,
        field._NRemovedThread,
        field._NAdded,
        field._NAddedThread,
        field._AddedAgents,
        field._NOverflow,
    )

end

## Similar

function Base.similar(field::UnstructuredMeshField)

    UnstructuredMeshField(
        NamedTuple{keys(field._p)}(
            r ? p : similar(p) for (p, r) in zip(values(field._p), field._pReference)
        ),
        field._NP,
        field._pReference,

        field._id,
        field._idMax,

        field._nodes1,
        field._nodes2,
        field._nodes3,
        field._nodes4,

        field._N,
        field._NCache,
        field._FlagsSurvived,
        field._NRemoved,
        field._NRemovedThread,
        field._NAdded,
        field._NAddedThread,
        field._AddedAgents,
        field._NOverflow,
    )
end

## Zero
function Base.zero(field::UnstructuredMeshField)

    UnstructuredMeshField(
        NamedTuple{keys(field._p)}(
            r ? p : zero(p) for (p, r) in zip(values(field._p), field._pReference)
        ),
        field._NP,
        field._pReference,

        field._id,
        field._idMax,

        field._nodes1,
        field._nodes2,
        field._nodes3,
        field._nodes4,

        field._N,
        field._NCache,
        field._FlagsSurvived,
        field._NRemoved,
        field._NRemovedThread,
        field._NAdded,
        field._NAddedThread,
        field._AddedAgents,
        field._NOverflow,
    )
end

## Copyto!
@eval @inline function Base.copyto!(
    dest::UnstructuredMeshField{P, DT, PR, PRN, PRC},
    bc::UnstructuredMeshField{P, DT, PR, PRN, PRC}) where {P, DT, PR, PRN, PRC}
    N = lengthPropertiesNew(dest)
    @inbounds for i in 1:PRN
        if !bc._pReference[i]
            copyto!(dest._p[i], 1, bc._p[i], 1, N)
        end
    end
    dest
end

## Copyfrom!
@eval @inline function copyfrom!(
    dest::UnstructuredMeshField{P, DT, PR, PRN, PRC},
    bc::UnstructuredMeshField{P, DT, PR, PRN, PRC}) where {P, DT, PR, PRN, PRC}
    N = lengthPropertiesNew(dest)
    @inbounds for i in 1:PRN
        if !dest._pReference[i]
            copyto!(dest._p[i], 1, bc._p[i], 1, N)
        end
    end
    dest
end

## recursivefill!
function RecursiveArrayTools.recursivefill!(
    dest::UnstructuredMeshField{P, DT, PR, PRN, PRC},
    value) where {P, DT, PR, PRN, PRC}
    N = lengthProperties(dest)
    @inbounds for i in 1:PRN
        if !dest._pReference[i]
            @views fill!(dest._p[i][1:N], value)
        end
    end
    dest
end

# Special version for functions that should be called per element (like randn)
function RecursiveArrayTools.recursivefill!(
    dest::UnstructuredMeshField{P, DT, PR, PRN, PRC},
    value::Function) where {P, DT, PR, PRN, PRC}
    N = lengthProperties(dest)
    @inbounds for i in 1:PRN
        if !dest._pReference[i]
            # Call the function for each element individually
            for j in 1:N
                dest._p[i][j] = value()
            end
        end
    end
    dest
end

## Vec
function Base.vec(field::UnstructuredMeshField{P, DT, PR, PRN, PRC}) where {P, DT, PR, PRN, PRC}
    result = Float64[]
    N = lengthProperties(field)
    @inbounds for i in 1:PRN
        if !field._pReference[i]
            append!(result, @views field._p[i][1:N])
        end
    end
    return result
end

## Broadcasting
struct UnstructuredMeshFieldStyle{N} <: Broadcast.AbstractArrayStyle{N} end

# Allow constructing the style from Val or Int
UnstructuredMeshFieldStyle(::Val{N}) where {N} = UnstructuredMeshFieldStyle{N}()
UnstructuredMeshFieldStyle(N::Int) = UnstructuredMeshFieldStyle{N}()

# Your UnstructuredMeshField acts like a 2D array
Base.BroadcastStyle(::Type{<:UnstructuredMeshField}) = UnstructuredMeshFieldStyle{2}()

# Combine styles safely
Base.Broadcast.result_style(::UnstructuredMeshFieldStyle{M}) where {M} =
    UnstructuredMeshFieldStyle{M}()
Base.Broadcast.result_style(::UnstructuredMeshFieldStyle{M}, ::UnstructuredMeshFieldStyle{N}) where {M,N} =
    UnstructuredMeshFieldStyle{max(M,N)}()
Base.Broadcast.result_style(::UnstructuredMeshFieldStyle{M}, ::Base.Broadcast.AbstractArrayStyle{N}) where {M,N} =
    UnstructuredMeshFieldStyle{max(M,N)}()
Base.Broadcast.result_style(::Base.Broadcast.AbstractArrayStyle{M}, ::UnstructuredMeshFieldStyle{N}) where {M,N} =
    UnstructuredMeshFieldStyle{max(M,N)}()

Broadcast.broadcastable(x::UnstructuredMeshField) = x

# Add similar method for Broadcasted objects
function Base.similar(bc::Broadcast.Broadcasted{UnstructuredMeshFieldStyle{N}}, ::Type{ElType}) where {N, ElType}
    # Find the first UnstructuredMeshField in the arguments to use as template
    A = find_umof(bc)
    return similar(A)
end

# Helper function to find UnstructuredMeshField in broadcast arguments
find_umof(bc::Base.Broadcast.Broadcasted) = find_umof(bc.args)
find_umof(args::Tuple) = find_umof(find_umof(args[1]), Base.tail(args))
find_umof(x) = x
find_umof(a::UnstructuredMeshField, rest) = a
find_umof(::Any, rest) = find_umof(rest)
find_umof(x::UnstructuredMeshField) = x
find_umof(::Tuple{}) = nothing

for type in [
        Broadcast.Broadcasted{<:UnstructuredMeshField},
        Broadcast.Broadcasted{<:UnstructuredMeshFieldStyle},
    ]

    @eval @inline function Base.copyto!(
            dest::UnstructuredMeshField{P, DT, PR, PRN, PRC},
            bc::$type) where {P, DT, PR, PRN, PRC}
        bc = Broadcast.flatten(bc)
        N = lengthProperties(dest)
        @inbounds for i in 1:PRN
            if !dest._pReference[i]
                copyto!(dest._p[i], 1, unpack_voa(bc, i), 1, N)
            end
        end
        dest
    end
end

# # drop axes because it is easier to recompute
@inline function unpack_voa(bc::Broadcast.Broadcasted{<:UnstructuredMeshField}, i)
    Broadcast.Broadcasted(bc.f, unpack_args_voa(i, bc.args))
end

function unpack_voa(x::UnstructuredMeshField, i)
    x._p[i]
end

# # updateAdditions!
# function updateAdditions!(mesh::UnstructuredMeshField)

#     N = mesh._N[]
#     NNew = sum(mesh._NAddedThread)

#     # Check for overflow and increase cache
#     if N + NNew > mesh._NCache[]
#         warning("MeshObjectField overflow: current N=$(N), added N=$(NNew), NCache=$(mesh._NCache[]). If this is happening constantly, consider allocating with NCache before the simulation.")
#         for i in 1:mesh._NP
#             append!(mesh._p[i], similar(mesh._p[i], NNew))
#         end
#         mesh._NCache[] += NNew
#     end

#     # Add new agents
#     NCum = [0, cumsum(mesh._NAddedThread)...][1:end-1]
#     Threads.@threads for (offset, NThread, field) in zip(NCum, mesh._NAddedThread, mesh._AddedAgents)
#         for i in 1:NThread
#             idx = N + offset + 1
#             agent = field[i]
#             for (name, value) in pairs(agent)
#                 mesh._p[name][idx] = value
#             end
#             N += 1
#         end
#     end

#     # Reset added and removed counters
#     mesh._N[] += NNew 
#     mesh._NAdded[] = 0
#     fill!(mesh._NAddedThread, 0)

#     return
# end

iterateOver(mesh::UnstructuredMeshField) = 1:lengthProperties(mesh)

## Preallocate
function preallocate!(field::UnstructuredMeshField, additionalCache::Int=field._NCache[])
    """
    Allocate additional cache memory for a UnstructuredMeshField.
    Resizes all property arrays and supporting data structures.
    """
    newNCache = Array(field._NCache)[1] + additionalCache
    
    # Resize property arrays
    for i in 1:field._NP
        resize!(field._p[i], newNCache)
    end
    
    # Resize supporting arrays
    resize!(field._id, newNCache)
    field._nodes1 !== nothing && resize!(field._nodes1, newNCache)
    field._nodes2 !== nothing && resize!(field._nodes2, newNCache)
    field._nodes3 !== nothing && resize!(field._nodes3, newNCache)
    field._nodes4 !== nothing && resize!(field._nodes4, newNCache)
    resize!(field._FlagsSurvived, newNCache)
    
    # Update cache size
    field._NCache .= newNCache
    
    return nothing
end

## getOverflow
function getOverflow(field::UnstructuredMeshField, factor=1)
    """
    Extract overflow count from a field.
    Returns the overflow counter value (0 if no overflow).
    Does not reset the counter - that's handled by mesh-level getOverflow.
    """
    overflow_val = Array(field._NOverflow)[1]
    return round(Int, overflow_val * factor)
end

######################################################################################################
# UnstructuredMeshObject
######################################################################################################
struct UnstructuredMeshObject{
            P, D, S, DT, NN,
            PAR, AB
    } <: AbstractMeshObject
    _p::PAR
    _neighbors::NN
    _FlagOverflow::AB
end
Adapt.@adapt_structure UnstructuredMeshObject

mesh2Object(::Type{<:UnstructuredMesh}) = UnstructuredMeshObject
object2mesh(::Type{<:UnstructuredMeshObject}) = UnstructuredMesh

function UnstructuredMeshObject(
        mesh::UnstructuredMesh{D, S};
        neighbors::AbstractNeighbors=NeighborsFull(),
        kwargs...
    ) where {D, S}

    fields = []
    P = platform()
    DT = Nothing
    for i in values(mesh._p)
        for j in values(i.p)
            d = dtype(j; isbits=true)
            if d <: AbstractFloat
                DT = Float64
                break
            end
        end
    end

    for (p, prop) in pairs(mesh._p)

        if !(p in keys(kwargs))
           error("UnstructuredMeshObject requires all properties defined in the UnstructuredMesh. Missing property: $p")
        elseif !(kwargs[p] isa Number) && !(kwargs[p] isa Tuple{Int, Int})
            error("UnstructuredMeshObject requires N to be an integer or a tuple of integers. Found $(typeof(kwargs[p])) for property: $p")
        end

        N_ = 0
        if kwargs[p] isa Number
            N_ = kwargs[p]
        elseif kwargs[p] isa Tuple{Int, Int}
            N_ = kwargs[p][1]
        end

        if N_ < 0
            error("$(name)N must be greater than 0. Found N=$N_")
        end

        NCache_ = 0
        if kwargs[p] isa Number
            NCache_ = kwargs[p]
        elseif kwargs[p] isa Tuple{Int, Int}
            NCache_ = kwargs[p][2]
        end

        field = UnstructuredMeshField(prop, N = N_, NCache = NCache_)
        push!(fields, field)

    end

    params = NamedTuple{tuple(keys(mesh._p)...)}(fields)
    neighbors_ = initNeighbors(D, neighbors, params)
    _FlagOverflow = SizedVector{1}(false)

    mesh = UnstructuredMeshObject{
            P, D, S, DT, typeof(neighbors_),
            typeof(params), typeof(_FlagOverflow)
        }(
            params, neighbors_, _FlagOverflow
        )

    return mesh
end

function UnstructuredMeshObject(
            p, neighbors, _FlagOverflow
    )

    D = 0
    for n in values(p) #To FIX
        D = max(D, length(filter(k -> k in (:x, :y, :z), keys(n._p))))
    end
    P = platform()
    S = Nothing
    DT = Nothing
    for i in values(p)
        if i !== nothing
            d = eltype(i)
            if d <: AbstractFloat
                DT = Float64
                break
            end
        end
    end

    return UnstructuredMeshObject{
            P, D, S, DT, typeof(neighbors),
            typeof(p), typeof(_FlagOverflow)
        }(
            p, neighbors, _FlagOverflow
        )
end

function Base.show(io::IO, x::UnstructuredMeshObject{P, D, S}) where {P, D, S}
    println(io, "\nUnstructuredMeshObject platform=$P dimensions=$D specialization=$S \n")
    CellBasedModels.show(io, x)
    println(io, "\t* -> indicates passed by reference\n")
end

function show(io::IO, x::UnstructuredMeshObject, full=false)
    for (f,n) in pairs(x._p)
        println(io, "\t", f, " (", typeof(n).name.name, ")")
        println(io, @sprintf("\t%-20s %-15s", "Name (Public)", "DataType"))
        println(io, "\t" * repeat("-", 85))
        for ((name, par), c) in zip(pairs(n._p), n._pReference)
            println(io, @sprintf("\t%-20s %-15s", 
                c ? string("*", name) : string(name),
                typeof(par)))
        end
        if full
            println(io, @sprintf("\n\t%-20s %-15s", "Name (Protected)", "DataType"))
            println(io, "\t" * repeat("-", 85))
            fields = fieldnames(typeof(f))
            for name in fields
                v = typeof(getfield(f, name))
                println(io, @sprintf("\t%-20s %-15s", 
                    "*$name",
                    v))
            end
        end
        println(io)
    end
end

function Base.show(io::IO, x::Type{UnstructuredMeshObject{P, D, S}}) where {P, D, S}
    println(io, "UnstructuredMesh{platform=", P, ", dimension=", D, ", specialization=", S,)
    CellBasedModels.show(io, x)
    println(io, "}")
end

function show(io::IO, ::Type{UnstructuredMeshObject{P, D, S, DT, NN, PAR, AB}}) where {P, D, S, DT, NN, PAR, AB}
    for (props, propsnames) in zip((PAR), ("a", "PropertiesNode", "PropertiesEdge", "PropertiesFace", "PropertiesVolume"))
        if props !== Nothing
            print(io, "\t", string(propsnames), "Meta", "=(")
            CellBasedModels.show(io, props)
            println(io, ")")
        end
    end
end

function lengthProperties(::UnstructuredMeshObject{P, D, S, DT, NN, PAR, AB}) where {P, D, S, DT, NN, PAR, AB}
    return length(PAR.parameters[1])
end    
function Base.length(mesh::UnstructuredMeshObject{P, D, S, DT, NN, PAR, AB}) where {P, D, S, DT, NN, PAR, AB}
    c = 0
    for i in values(mesh._p)
        c += length(i)
    end
    return c
end    

Base.size(mesh::UnstructuredMeshObject) = (lengthProperties(mesh),)

Base.eltype(::UnstructuredMeshObject{P, D, S, DT}) where {P, D, S, DT} = DT
Base.eltype(::Type{<:UnstructuredMeshObject{P, D, S, DT}}) where {P, D, S, DT} = DT

Base.ndims(::UnstructuredMeshObject) = 1
Base.ndims(::Type{<:UnstructuredMeshObject}) = 1

Base.axes(x::UnstructuredMeshObject) = (Base.OneTo(1),)

function Base.iterate(::UnstructuredMeshObject, state = 1)
    state >= 5 ? nothing : (state, state + 1)
end

platform(mesh::UnstructuredMeshObject{P}) where {P} = P
spatialDims(::UnstructuredMeshObject{P, D}) where {P, D} = D
spatialDims(::Type{<:UnstructuredMeshObject{P, D}}) where {P, D} = D
specialization(mesh::UnstructuredMeshObject{P, D, S}) where {P, D, S} = S

#Getindex
@generated function Base.getproperty(field::UnstructuredMeshObject{P, D, S, DT, NN, PAR, AB}, s::Symbol) where {P, D, S, DT, NN, PAR, AB}
    # build a clause for each fieldname in T
    general = [
        :(if s === $(QuoteNode(name)); return getfield(field, $(QuoteNode(name))); end)
        for name in fieldnames(UnstructuredMeshObject)
    ]
    cases = [
        :(s === $(QuoteNode(name)) && return @views getfield(getfield(field, :_p), $(QuoteNode(name))))
        for name in PAR.parameters[1]
    ]

    quote
        $(general...)
        $(cases...)
        error("Unknown property: $s for the UnstructuredMeshObject.")
    end
end

Base.getindex(community::UnstructuredMeshObject, i::Integer) =
    getfield(community._p, i)
Base.getindex(community::UnstructuredMeshObject, s::Symbol) =
    getfield(community._p, s)

# Norm
function LinearAlgebra.norm(u::UnstructuredMeshObject, t::Real)
    n = zero(eltype(u))

    for i in values(u._p)
        n += LinearAlgebra.norm(i, t)^2
    end

    return sqrt(n)
end

## Copy
function Base.copy(field::UnstructuredMeshObject{P, D, S, DT, NN, PAR, AB}) where {P, D, S, DT, NN, PAR, AB}

    UnstructuredMeshObject{P, D, S, DT, NN, PAR, AB}(
        NamedTuple{keys(field._p)}(
            copy(getfield(field._p, name)) for name in keys(field._p)
        ),
        field._neighbors,
        field._FlagOverflow
    )

end

function partialCopy(field::UnstructuredMeshObject{P, D, S, DT, NN, PAR, AB}, copyArgs) where {P, D, S, DT, NN, PAR, AB}

    UnstructuredMeshObject{P, D, S, DT, NN, PAR, AB}(
        NamedTuple{keys(field._p)}(
            partialCopy(getfield(field._p, name), [i[2] for i in copyArgs if i[1] == name]) for name in keys(field._p)
        ),
        field._neighbors,
        field._FlagOverflow
    )

end

## Similar
function Base.similar(field::UnstructuredMeshObject{P, D, S, DT, NN, PAR}) where {P, D, S, DT, NN, PAR}

    UnstructuredMeshObject{P, D, S, DT, NN, PAR}(
        NamedTuple{keys(field._p)}(
            similar(getfield(field._p, name)) for name in keys(field._p)
        ),
        field._neighbors,
        field._FlagOverflow
    )

end

function Base.similar(field::UnstructuredMeshObject{P, D, S, DT, NN, PAR}, _) where {P, D, S, DT, NN, PAR}

    UnstructuredMeshObject{P, D, S, DT, NN, PAR}(
        NamedTuple{keys(field._p)}(
            similar(getfield(field._p, name)) for name in keys(field._p)
        ),
        field._neighbors,
        field._FlagOverflow
    )

end

## Zero
function Base.zero(field::UnstructuredMeshObject{P, D, S, DT, NN, PAR}) where {P, D, S, DT, NN, PAR}

    UnstructuredMeshObject{P, D, S, DT, NN, PAR}(
        NamedTuple{keys(field._p)}(
            zero(getfield(field._p, name)) for name in keys(field._p)
        ),
        field._neighbors,
        field._FlagOverflow
    )

end

## Copyto!
@eval @inline function Base.copyto!(
    dest::UnstructuredMeshObject,
    bc::UnstructuredMeshObject)

    for name in keys(dest._p)
        copyto!(getfield(dest._p, name), getfield(bc._p, name))
    end

    dest
end

## Copyfrom!
@eval @inline function copyfrom!(
    dest::UnstructuredMeshObject,
    bc::UnstructuredMeshObject)

    for name in keys(dest._p)
        copyfrom!(getfield(dest._p, name), getfield(bc._p, name))
    end

    dest
end

## Recursivefill!
function RecursiveArrayTools.recursivefill!(
    dest::UnstructuredMeshObject,
    value)

    for name in keys(dest._p)
        RecursiveArrayTools.recursivefill!(getfield(dest._p, name), value)
    end

    dest
end

## Fill!
function Base.fill!(
    dest::UnstructuredMeshObject,
    value)

    # For SDE noise generation, we should not fill with the same value everywhere
    # Instead, delegate to recursivefill! which handles the proper filling per field
    RecursiveArrayTools.recursivefill!(dest, value)
    dest
end

## Preallocate
function preallocate!(mesh::UnstructuredMeshObject{P, D, S, DT, NN, PAR, AB}, additionalCache::NamedTuple = (;)) where {P, D, S, DT, NN, PAR, AB}
    """
    Allocate additional cache memory for specific fields in an UnstructuredMeshObject.
    additionalCache should be a NamedTuple with field names as keys and additional cache sizes as values.
    Fields not specified in the NamedTuple will not be preallocated.
    
    Example:
        preallocate!(mesh, (n=100, e=50))  # Preallocate 100 for field n, 50 for field e
    """
    for (field_name, additional) in pairs(additionalCache)
        if field_name in keys(mesh._p)
            field = getfield(mesh._p, field_name)
            preallocate!(field, additional)
        else
            @warn "Field $field_name not found in mesh. Skipping preallocation."
        end
    end

    preallocate!(mesh._neighbors, additionalCache)
    
    return nothing
end

## getOverflow
function getOverflow(mesh::UnstructuredMeshObject{P, D, S, DT, NN, PAR, AB}, factor=1) where {P, D, S, DT, NN, PAR, AB}
    """
    Extract overflow information from all fields in an UnstructuredMeshObject.
    Returns a NamedTuple with field names as keys and overflow counts as values.
    Only includes fields that have overflowed (overflow count > 0).
    
    Example:
        overflows = getOverflow(mesh)  # Returns (n=5, a=2) if those fields overflowed
    """
    overflows = Dict{Symbol, Int}()
    
    # Iterate through all fields in the mesh and collect overflow values
    for field_name in keys(mesh._p)
        field = getfield(mesh._p, field_name)
        if field !== nothing
            # Extract overflow value without resetting yet
            overflow_val = Array(field._NOverflow)[1]
            if overflow_val > 0
                overflows[field_name] = round(Int, overflow_val * factor)
            end
        end
    end
        
    # Convert dict to NamedTuple
    return (;overflows...)
end

function resetOverflow!(mesh::UnstructuredMeshObject{P, D, S, DT, NN, PAR, AB}) where {P, D, S, DT, NN, PAR, AB}
    """
    Reset overflow counters for all fields in an UnstructuredMeshObject.
    """
    for field_name in keys(mesh._p)
        field = getfield(mesh._p, field_name)
        if field !== nothing
            field._NOverflow .= 0
            field._NAdded .= 0
        end
    end
    mesh._FlagOverflow .= false
    return nothing
end

function isOverflowed(mesh::UnstructuredMeshObject{P, D, S, DT, NN, PAR, AB}) where {P, D, S, DT, NN, PAR, AB}
    return Array(mesh._FlagOverflow)[1]
end

## Vec  
function Base.vec(u::UnstructuredMeshObject)
    result = Float64[]

    for name in keys(u._p)
        append!(result, vec(getfield(u._p, name)))
    end

    return result
end

## Broadcasting
struct UnstructuredMeshObjectStyle{N} <: Broadcast.AbstractArrayStyle{N} end

# Allow constructing the style from Val or Int
UnstructuredMeshObjectStyle(::Val{N}) where {N} = UnstructuredMeshObjectStyle{N}()
UnstructuredMeshObjectStyle(N::Int) = UnstructuredMeshObjectStyle{N}()

# Your UnstructuredMeshObject acts like a 2D array
Base.BroadcastStyle(::Type{<:UnstructuredMeshObject}) = UnstructuredMeshObjectStyle{1}()

# Combine styles safely
Base.Broadcast.result_style(::UnstructuredMeshObjectStyle{M}) where {M} =
    UnstructuredMeshObjectStyle{M}()
Base.Broadcast.result_style(::UnstructuredMeshObjectStyle{M}, ::UnstructuredMeshObjectStyle{N}) where {M,N} =
    UnstructuredMeshObjectStyle{max(M,N)}()
Base.Broadcast.result_style(::UnstructuredMeshObjectStyle{M}, ::Base.Broadcast.AbstractArrayStyle{N}) where {M,N} =
    UnstructuredMeshObjectStyle{max(M,N)}()
Base.Broadcast.result_style(::Base.Broadcast.AbstractArrayStyle{M}, ::UnstructuredMeshObjectStyle{N}) where {M,N} =
    UnstructuredMeshObjectStyle{max(M,N)}()

Broadcast.broadcastable(x::UnstructuredMeshObject) = x

# Add similar method for Broadcasted objects
function Base.similar(bc::Broadcast.Broadcasted{UnstructuredMeshObjectStyle{N}}, ::Type{ElType}) where {N, ElType}
    # Find the first UnstructuredMeshObject in the arguments to use as template
    A = find_umo(bc)
    return similar(A)
end

# Helper function to find UnstructuredMeshObject in broadcast arguments
find_umo(bc::Base.Broadcast.Broadcasted) = find_umo(bc.args)
find_umo(args::Tuple) = find_umo(find_umo(args[1]), Base.tail(args))
find_umo(x) = x
find_umo(a::UnstructuredMeshObject, rest) = a
find_umo(::Any, rest) = find_umo(rest)
find_umo(x::UnstructuredMeshObject) = x
find_umo(::Tuple{}) = nothing

for type in [
        Broadcast.Broadcasted{<:UnstructuredMeshObject},
        Broadcast.Broadcasted{<:UnstructuredMeshObjectStyle},
    ]

    @eval @inline function Base.copyto!(
            dest::UnstructuredMeshObject{P, PAR},
            bc::$type) where {P, PAR}
        bc = Broadcast.flatten(bc)

        for name in keys(dest._p)
            d = getfield(dest._p, name)
            if d !== nothing
                np, n = sizeFull(d)
                for j in 1:np
                    if !d._pReference[j]
                        # dest_ = @views d._p[j][1:n]
                        copyto!(d._p[j], 1, unpack_voa(bc, name, j, n), 1, n)
                    end
                end
            end
        end

        dest
    end
end

# General fallback for any broadcast style
@inline function Base.copyto!(
        dest::UnstructuredMeshObject,
        bc::Base.Broadcast.Broadcasted)
    # Special handling for random number generation
    if bc.f isa typeof(identity) && length(bc.args) == 1
        arg = bc.args[1]
        if arg isa Base.Broadcast.Broadcasted && arg.f isa typeof(randn) && isempty(arg.args)
            # This is randn.() - generate different random numbers for each element
            for i in 1:length(dest._p)
                field = getfield(dest._p, keys(dest._p)[i])
                if field !== nothing
                    RecursiveArrayTools.recursivefill!(field, randn)
                end
            end
            return dest
        end
    end
    
    # For other broadcasts, try to evaluate as scalar
    try
        val = bc[]  # Try to extract a scalar value
        fill!(dest, val)
    catch
        # If that fails, we need a more sophisticated approach
        error("Unsupported broadcast operation: $(typeof(bc))")
    end
    dest
end

#Specialized unpacking
@inline function unpack_voa(bc::Broadcast.Broadcasted{<:UnstructuredMeshObject}, i, j, n)
    Broadcast.Broadcasted(bc.f, unpack_args_voa(i, j, n, bc.args))
end
function unpack_voa(x::UnstructuredMeshObject, i, j, n)
    # @views x[i]._p[j][1:n]
    x[i]._p[j]
end

# # updateAdditions!
# function updateAdditions!(
#         mesh::UnstructuredMeshObject{P, D, S, DT, NN, PAR}
#     ) where {P, D, S, DT, NN, PAR}

#     for name in names(mesh._p)
#         field = getfield(mesh._p, name)
#         if field !== nothing
#             updateAdditions!(field)
#         end
#     end

#     mesh
# end

# # updateAdditions!
# function updateRemovals!(
#         mesh::UnstructuredMeshObject{P, D, S, DT, NN, PAR}
#     ) where {P, D, S, DT, NN, PAR}

#     for name in names(mesh._p)
#         field = getfield(mesh._p, name)
#         if field !== nothing
#             updateRemovals!(field)
#         end
#     end

#     mesh
# end

# # update!
# function update!(
#         mesh::UnstructuredMeshObject{P, D, S, DT, NN, PAR}
#     ) where {P, D, S, DT, NN, PAR}

#     updateAdditions!(mesh)
#     updateRemovals!(mesh)

#     mesh
# end

## Update function (placeholder for future extensions)
function update!(mesh::UnstructuredMeshObject)
    """
    Update mesh after rule applications (e.g., add/remove agents).
    Currently a placeholder for future extensions.
    """
    return nothing
end

# ######################################################################################################
# # ForwardDiff Support
# ######################################################################################################

# # Make UnstructuredMeshObject work with ForwardDiff for automatic differentiation
# # ForwardDiff needs to know how to create chunks and work with our custom array type

# # Tell ForwardDiff that our object behaves like an AbstractArray
# ForwardDiff.pickchunksize(x::UnstructuredMeshObject) = ForwardDiff.pickchunksize(length(x))

# # ForwardDiff needs to know how to extract values for differentiation
# function ForwardDiff.extract_gradient!(::Type{T}, result, x::UnstructuredMeshObject) where T
#     # This should extract gradients from the ForwardDiff dual numbers
#     # For now, delegate to the default behavior by converting to a regular array representation
#     error("ForwardDiff gradient extraction not implemented for UnstructuredMeshObject")
# end

# # Add methods to make UnstructuredMeshObject work with ForwardDiff operations
# Base.vec(x::UnstructuredMeshObject) = vec(collect(Iterators.flatten([
#     getfield(x, :a) !== nothing ? vec(getfield(x, :a)) : Float64[],
#     getfield(x, :n) !== nothing ? vec(getfield(x, :n)) : Float64[],
#     getfield(x, :e) !== nothing ? vec(getfield(x, :e)) : Float64[],
#     getfield(x, :f) !== nothing ? vec(getfield(x, :f)) : Float64[],
#     getfield(x, :v) !== nothing ? vec(getfield(x, :v)) : Float64[]
# ])))

# # ForwardDiff support for UnstructuredMeshField as well
# ForwardDiff.pickchunksize(x::UnstructuredMeshField) = ForwardDiff.pickchunksize(length(x))

# # Add JacobianConfig support for UnstructuredMeshObject
# function ForwardDiff.JacobianConfig(f, y::UnstructuredMeshObject, x::UnstructuredMeshObject, chunk::ForwardDiff.Chunk, tag::ForwardDiff.Tag)
#     # Convert to vectors and use standard JacobianConfig
#     ForwardDiff.JacobianConfig(f, vec(y), vec(x), chunk, tag)
# end

# function ForwardDiff.JacobianConfig(::Nothing, y::UnstructuredMeshObject, x::UnstructuredMeshObject, chunk::ForwardDiff.Chunk, tag::ForwardDiff.Tag)
#     # Handle case where function is Nothing
#     ForwardDiff.JacobianConfig(nothing, vec(y), vec(x), chunk, tag)
# end

# # Add ForwardDiff.Chunk support for UnstructuredMeshObject
# ForwardDiff.pickchunksize(x::UnstructuredMeshObject) = ForwardDiff.pickchunksize(length(x))

# # Provide ForwardDiff.Chunk constructor for our type by converting to array-like representation
# function ForwardDiff.Chunk(x::UnstructuredMeshObject)
#     return ForwardDiff.Chunk(length(x))
# end

# # Make UnstructuredMeshObject work with ForwardDiff chunking
# # Instead of conflicting getindex, just ensure length() works properly for ForwardDiff

# # Implement jacobian! method in the proper OrdinaryDiffEqDifferentiation context
# # The error shows it's looking for: jacobian!(::AbstractMatrix{<:Number}, ::F, ::AbstractArray{<:Number}, ::AbstractArray{<:Number}, ::SciMLBase.DEIntegrator, ::Any)
# function OrdinaryDiffEqDifferentiation.jacobian!(J::AbstractMatrix{<:Number}, f, x::UnstructuredMeshObject, fx::UnstructuredMeshObject, integrator, jac_config)
#     # Use finite differences as a simple placeholder for now
#     # In a full implementation, you would compute the actual Jacobian here
#     fill!(J, 0.0)
#     n = min(size(J, 1), size(J, 2))
#     for i in 1:n
#         J[i, i] = 1.0  # Identity matrix for numerical stability
#     end
#     return J
# end

# # Fallback method for when OrdinaryDiffEqDifferentiation is not loaded
# if !@isdefined(OrdinaryDiffEqDifferentiation)
#     function jacobian!(J::AbstractMatrix{<:Number}, f, x::UnstructuredMeshObject, fx::UnstructuredMeshObject, integrator, jac_config)
#         fill!(J, 0.0)
#         n = min(size(J, 1), size(J, 2))
#         for i in 1:n
#             J[i, i] = 1.0
#         end
#         return J
#     end
# end

function KernelAbstractions.get_backend(::UnstructuredMeshObject{P}) where {P<:CPU}
    return KernelAbstractions.CPU()
end