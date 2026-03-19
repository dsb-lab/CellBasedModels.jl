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
    c::Symbol
    p::NamedTuple{N, P}    # Dictionary to hold agent properties
end

function Edge(c::Symbol, p::NamedTuple=(;))
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

struct Agent{N, P, C} <: AbstractUnstructuredMeshProperty
    cs::NTuple{C, Symbol}
    p::NamedTuple{N, P}    # Dictionary to hold agent properties
end

function Agent(cs::NTuple{C,Symbol}, p::NamedTuple=(;)) where {C}
    p_ = parameterConvert(p)
    Agent{typeof(p_).parameters[1], typeof(p_).parameters[2], C}(
        cs,
        p_
    )
end

function Agent(cs::Symbol, p::NamedTuple=(;))
    p_ = parameterConvert(p)
    Agent{typeof(p_).parameters[1], typeof(p_).parameters[2], 1}(
        (cs,),
        p_
    )
end

# Convenience constructor with default connection to :n
function Agent(p::NamedTuple)
    Agent(:n, p)
end

######################################################################################################
# AGENT STRUCTURE
######################################################################################################
struct UnstructuredMesh{D, S, P, PAR} <: AbstractMesh

    _p::NamedTuple    # Dictionary to hold agent properties
    _parameters::PAR  # NamedTuple of shared parameters (accessed via obj.p.X)
    _functions::Dict{Symbol, Any}    # Dictionary to hold functions associated with the mesh
    _requiredTopologyRelations::Set{Tuple{Symbol, Symbol}}  # Relations needed by rules (for precomputation)
    _requiredTopologyRelationTypes::Dict{Tuple{Symbol, Symbol}, Type}  # Sparse matrix types for inferred relations
    topo::Topology

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
    parameters::NamedTuple=(;),
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

    # Convert shared parameters
    sharedParameters = parameterConvert(parameters)

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
    edges = [k for (k, v) in pairs(kwargs) if v isa Edge]
    faces = [k for (k, v) in pairs(kwargs) if v isa Face]
    volumes = [k for (k, v) in pairs(kwargs) if v isa Volume]
    agents = [k for (k, v) in pairs(kwargs) if v isa Agent]

    propertiesAdapted = Dict()
    for (n,i) in kwargs
        if i isa Edge
            if !(i.c in nodes)
                error("Edge properties must reference existing Node properties. Found Edge referencing $(i.c[1]) and $(i.c[2]), but existing Node properties are: $nodes")
            end
        elseif i isa Face
            if !(i.c in nodes) && !(i.c in edges)
                error("Face properties must reference existing Node or Edge properties. Found referencing $(i.c), but existing Node properties are: $nodes")
            end
        elseif i isa Volume
            if !(i.c in nodes) && !(i.c in edges) && !(i.c in faces)
                error("Volume properties must reference existing Node, Edge or Face properties. Found referencing $(i.c), but existing Node properties are: $nodes")
            end
        elseif i isa Agent
            for c in i.cs
                if !(c in nodes) && !(c in edges) && !(c in faces) && !(c in volumes)
                    error("Agent properties must reference existing Node, Edge, Face or Volume properties. Found referencing $c, but existing Node properties are: $nodes")
                end
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
            propertiesAdapted[n] = Agent(i.cs, i.p)
        else
            error("Unknown property type: $(typeof(i))")
        end
    end

    propertiesTuple = NamedTuple{Tuple(k for (k,v) in pairs(propertiesAdapted))}(
        (v for (k,v) in pairs(propertiesAdapted))
    )

    # Initialize topology from mesh properties
    topology = Topology(propertiesTuple)

    return UnstructuredMesh{dims, specialization, typeof(propertiesTuple), typeof(sharedParameters)}(
        propertiesTuple,
        sharedParameters,
        Dict{Symbol, Any}(),
        Set{Tuple{Symbol, Symbol}}(),
        Dict{Tuple{Symbol, Symbol}, Type}(),
        topology
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
    
    # Display shared parameters
    if length(x._parameters) > 0
        println(io, "(Parameters) mesh.p.")
        println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-60s %-s", "Name", "DataType", "Dimensions", "Default_Value", "ModifiedIn", "Description"))
        println(io, "\t" * repeat("-", 145))
        for (n, par) in pairs(x._parameters)
            dv = if par.defaultValue === nothing
                ""
            elseif par.defaultValue isa Function
                "<Function> " * string(nameof(par.defaultValue))
            else
                string(par.defaultValue)
            end
            println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-60s %-s", 
                n, 
                dtype(par), 
                par.dimensions === nothing ? "" : string(par.dimensions),
                dv, 
                length(par._modifiedIn) === 0 ? "" : string(tuple([i[2] for i in par._modifiedIn]...)),
                par.description))
        end
        println(io)
    end
    
    for (name, props) in pairs(x._p)
        println(io, "(", typeof(props).name.name, ") mesh.",string(name),".")
        println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-60s %-s", "Name", "DataType", "Dimensions", "Default_Value", "ModifiedIn", "Description"))
        println(io, "\t" * repeat("-", 145))
        for (n, par) in pairs(props.p)
            dv = if par.defaultValue === nothing
                ""
            elseif par.defaultValue isa Function
                "<Function> " * string(nameof(par.defaultValue))
            else
                string(par.defaultValue)
            end
            println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-60s %-s", 
                n, 
                dtype(par), 
                par.dimensions === nothing ? "" : string(par.dimensions),
                dv, 
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
    # Display topological relations
    println(io, "\nTopological Relations")
    if x.topo._basicRelations !== nothing
        relationsbase = collect(x.topo._basicRelations)
        relations = collect(x._requiredTopologyRelations)
        sort!(relationsbase, by = r -> (r[1], r[2]))
        println(io, "  Basic relations:")
        for (origin, target) in relationsbase
            println(io, "\t", origin, " → ", target)
        end
        if !isempty(relations)
            println(io, "  Required derived relations:")
            sort!(relations, by = r -> (r[1], r[2]))
            for (origin, target) in relations
                if (origin, target) ∉ relationsbase
                    println(io, "\t", origin, " → ", target)
                end
            end
        end
    else
        println(io, "\t(none)")
    end
end

function Base.show(io::IO, ::Type{UnstructuredMesh{D, S, P, PAR}}) where {D, S, P, PAR}
    if S === Nothing
        print(io, "UnstructuredMesh{dims=", D, ",")
    else
        print(io, string(S), "{dims=", D, ",")
    end
    # for (name, prop) in zip(P.parameters[1], P.parameters[2].parameters[1].parameters)
    #     print(io, string(name), "=(")
    #     for i in prop[1:end-1]
    #         print(io, i, ",")
    #     end
    #     print(io, prop[end], ")")
    #     # for p in prop.parameters[2].parameters[1]
    #     #     print(io, string(p), "::", t.parameters[1])
    #     # end
    # end
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
            error("Parameter '$parameter_name' does not exist in field '$field_name'. Most probably you assigned incorrectly a parameter in a function (e.g. mesh.$field_name.$parameter_name). Valid parameters are: \n $mesh")
        end
    end

    if scope in keys(mesh._functions)
        error("Function scope $scope is already defined for the mesh. Multiple definitions are not allowed.")
    else
        mesh._functions[scope] = (type, functions)
    end

    return
end

function addTopologicalRelations!(mesh::UnstructuredMesh, pairs::Tuple)
    """
    Store topological relations needed by rules.
    This is called automatically by @addODE, @addRule, @addSDE macros.
    Non-basic relations will be precomputed during createObject.
    
    Args:
        mesh: The UnstructuredMesh
        pairs: Tuple of (origin, target) or (origin, target, MatrixType) tuples
               extracted from topo[:origin, :target] calls
    """
    for pair in pairs
        if length(pair) == 2
            # (origin, target) - no type specified
            push!(mesh._requiredTopologyRelations, (pair[1], pair[2]))
        elseif length(pair) == 3
            # (origin, target, MatrixType)
            push!(mesh._requiredTopologyRelations, (pair[1], pair[2]))
            mesh._requiredTopologyRelationTypes[(pair[1], pair[2])] = pair[3]
        end
    end

    return
end

"""
    setTopologyRelationType!(mesh::UnstructuredMesh, origin::Symbol, target::Symbol, matrixType::Type)

Set the sparse matrix type to use for a specific inferred relation.
This allows control over the storage format of derived relations (e.g., n->n, e->a).

Supported types:
- DynamicalCSR: Compressed Sparse Row (variable entries per row)
- DynamicalELL: ELLPACK format (fixed entries per row, more GPU efficient)
- DynamicalOrderedCSR: Ordered CSR
- DynamicalOrderedELL: Ordered ELLPACK

Example:
```julia
model = AgentPolyline(3)
setTopologyRelationType!(model, :n, :n, DynamicalELL)  # n->n will use ELL format
```
"""
function setTopologyRelationType!(mesh::UnstructuredMesh, origin::Symbol, target::Symbol, matrixType::Type)
    mesh._requiredTopologyRelationTypes[(origin, target)] = matrixType
    return nothing
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
            VN,
            AI, VB, AB,
            NN,  # Neighbors type
            FI   # Free indices array type
        }
    _p::PR
    _NP::Int
    _pReference::PRC

    _id::IDVI
    _idMax::IDAI

    _nodes::VN

    _N::AI
    _NCache::AI
    _FlagsSurvived::VB
    _NAdded::AI
    _NOverflow::AB

    # Neighbors structure (e.g., NeighborsFull, NeighborsHash, etc.)
    _neighbors::NN

    # Free entries tracking (for dynamic add/remove without compaction)
    _NFree::AI
    _entriesFree::FI
    _NFreeNextInit::AI
    _NFreeNext::AI
end
Adapt.@adapt_structure UnstructuredMeshField

function UnstructuredMeshField(
        meshProperties::AbstractUnstructuredMeshProperty;
        N::Int=0,
        NCache::Int=0,
        id=true,
        neighbors=:auto  # :auto uses createDefaultNeighbors, nothing for no neighbors
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
    _nodes = zeros(Int, NCache)

    _N = SizedVector{1}(N)
    _NCache = SizedVector{1}(NCache)
    _FlagsSurvived = ones(Bool, NCache)
    _NAdded = SizedVector{1}(0)
    _NOverflow = SizedVector{1}(0)

    # Initialize free entries tracking
    # Initially, positions N+1 to NCache are free
    nFree = NCache - N
    _NFree = SizedVector{1}(nFree)
    _entriesFree = Vector{Int}(undef, NCache)
    # Fill free entries in reverse order (pop from end is O(1))
    for i in 1:nFree
        _entriesFree[i] = NCache - i + 1
    end
    _NFreeNextInit = SizedVector{1}(nFree + 1)
    _NFreeNext = SizedVector{1}(0)

    # Initialize properties with default values if available (skip functions - applied later)
    _p_arrays = []
    for (name, param) in pairs(meshProperties.p)
        dt = dtype(param, isbits=true)
        arr = zeros(dt, NCache)
        # Apply default value to all N initialized elements (skip functions)
        if param.defaultValue !== nothing && !(param.defaultValue isa Function)
            arr[1:N] .= param.defaultValue
        elseif param.defaultValue === nothing && dt <: AbstractFloat
            # Mark uninitialized Float values with NaN for validation
            arr[1:N] .= NaN
        end
        push!(_p_arrays, arr)
    end
    _p = NamedTuple{keys(meshProperties.p)}(_p_arrays)
    _NP = length(meshProperties.p)
    _pReference = SizedVector{length(_p), Bool}([true for _ in 1:length(meshProperties.p)])

    # First create field structure
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
    VN = typeof(_nodes)

    AI = typeof(_N)
    AB = typeof(_NOverflow)
    VB = typeof(_FlagsSurvived)
    FI = typeof(_entriesFree)

    PR = typeof(_p)
    PRN = _NP
    PRC = typeof(_pReference)
    
    # Now initialize neighbors
    _neighbors = if neighbors === :auto
        createDefaultNeighbors(NCache, meshProperties)
    elseif neighbors === nothing
        nothing
    else
        # For all neighbor types, create temp field with template neighbors, then call initNeighbors
        temp_field = UnstructuredMeshField{
                P, DT,
                PR, PRN, PRC, 
                IDVI, IDAI,
                VN,
                AI, VB, AB,
                typeof(neighbors),
                FI
            }(
                _p,
                _NP,
                _pReference,

                _id,
                _idMax,

                _nodes,

                _N,
                _NCache,
                _FlagsSurvived,
                _NAdded,
                _NOverflow,
                
                neighbors,

                _NFree,
                _entriesFree,
                _NFreeNextInit,
                _NFreeNext,
            )
        initNeighbors(temp_field)
    end
    
    NN = typeof(_neighbors)

    # Return final field with proper neighbors
    UnstructuredMeshField{
            P, DT,
            PR, PRN, PRC, 
            IDVI, IDAI,
            VN,
            AI, VB, AB,
            NN,
            FI
        }(
            _p,
            _NP,
            _pReference,

            _id,
            _idMax,

            _nodes,

            _N,
            _NCache,
            _FlagsSurvived,
            _NAdded,
            _NOverflow,
            
            _neighbors,

            _NFree,
            _entriesFree,
            _NFreeNextInit,
            _NFreeNext,
        )
end

function UnstructuredMeshField(
            _p,
            _NP,
            _pReference,

            _id,
            _idMax,

            _nodes,

            _N,
            _NCache,
            _FlagsSurvived,
            _NAdded,
            _NOverflow,
            
            _neighbors,

            _NFree,
            _entriesFree,
            _NFreeNextInit,
            _NFreeNext,
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
    VN = typeof(_nodes)

    AI = typeof(_N)
    AB = typeof(_NOverflow)
    VB = typeof(_FlagsSurvived)
    FI = typeof(_entriesFree)
    
    NN = typeof(_neighbors)

    UnstructuredMeshField{
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,
            VN,
            AI, VB, AB,
            NN,
            FI,
        }(
            _p,
            _NP,
            _pReference,

            _id,
            _idMax,

            _nodes,

            _N,
            _NCache,
            _FlagsSurvived,
            _NAdded,
            _NOverflow,
            
            _neighbors,

            _NFree,
            _entriesFree,
            _NFreeNextInit,
            _NFreeNext,
        )
end

function Base.show(io::IO, x::UnstructuredMeshField{
            P, DT,
            PR, PRN, PRC, 
            IDVI, IDAI,
            VN,
            AI, VB, AB,
            NN, FI,
        }) where {
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,
            VN,
            AI, VB, AB,
            NN, FI,
        } 
    
    println(io, "UnstructuredMeshField: \n")
    println(io, @sprintf("\t%-25s %-15s", "Property", "DataType"))
    println(io, "\t" * repeat("-", 40))
    println(io, @sprintf("\t%-25s %-15s", "_id", IDVI))
    println(io, @sprintf("\t%-25s %-15s", "_idMax", IDAI))
    for (i, T) in enumerate(VN.parameters)
        if T !== Nothing
            println(io, @sprintf("\t%-25s %-15s", "_nodes[$i]", T))
        end
    end
    println(io, @sprintf("\t%-25s %-15s", "_N", AI))
    println(io, @sprintf("\t%-25s %-15s", "_NCache", AI))
    println(io, @sprintf("\t%-25s %-15s", "_FlagsSurvived", VB))
    println(io, @sprintf("\t%-25s %-15s", "_NAdded", AI))
    println(io, @sprintf("\t%-25s %-15s", "_NOverflow", AB))
    println(io, @sprintf("\t%-25s %-15s", "_neighbors", NN))
    println(io, @sprintf("\t%-25s %-15s", "_NFree", AI))
    println(io, @sprintf("\t%-25s %-15s", "_entriesFree", FI))

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
            VN,
            AI, VB, AB,
            NN, FI,
        }}) where {
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,
            VN,
            AI, VB, AB,
            NN, FI,
        } 
    for (n, t) in zip(PR.parameters[1], PR.parameters[2].parameters)
        print(io, "p.", string(n), "::", t, ", ")
    end
    print(io, "_id::", IDVI, ", ")
    print(io, "_idMax::", IDAI, ", ")
    for (i, T) in enumerate(VN.parameters)
        if T !== Nothing
            print(io, "_nodes[$i]::", T, ", ")
        end
    end
    print(io, "_N::", AI, ", ")
    print(io, "_NCache::", AI, ", ")
    print(io, "_FlagsSurvived::", VB, ", ")
    print(io, "_NAdded::", AI, ", ")
    print(io, "_NOverflow::", AB, ", ")
    print(io, "_neighbors::", NN, ", ")
    print(io, "_NFree::", AI, ", ")
    print(io, "_entriesFree::", FI, ", ")
end

@generated function Base.getproperty(field::UnstructuredMeshField{
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,
            VN,
            AI, VB, AB,            
        }, s::Symbol) where {
            P, DT,
            PR, PRN, PRC,
            IDVI, IDAI,
            VN,
            AI, VB, AB}
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

# Provide clear error message when trying to assign with = instead of .=
function Base.setproperty!(field::UnstructuredMeshField, s::Symbol, v)
    # Check if s is a user property (not an internal field)
    if s in keys(field._p)
        error("Cannot assign to property '$s' using '='. Use '.=' for in-place broadcast assignment instead.\n" *
              "Example: field.$s .= value  # correct\n" *
              "         field.$s = value   # incorrect")
    else
        # For internal fields, give the standard error
        error("type UnstructuredMeshField is immutable and has no field $s that can be set")
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

        field._nodes,

        field._N,
        field._NCache,
        field._FlagsSurvived,
        field._NAdded,
        field._NOverflow,
        
        field._neighbors,

        field._NFree,
        field._entriesFree,
        field._NFreeNextInit,
        field._NFreeNext,
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

        field._nodes,

        field._N,
        field._NCache,
        field._FlagsSurvived,
        field._NAdded,
        field._NOverflow,
        
        field._neighbors,

        field._NFree,
        field._entriesFree,
        field._NFreeNextInit,
        field._NFreeNext,
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

        field._nodes,

        field._N,
        field._NCache,
        field._FlagsSurvived,
        field._NAdded,
        field._NOverflow,
        
        field._neighbors,

        field._NFree,
        field._entriesFree,
        field._NFreeNextInit,
        field._NFreeNext,
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

        field._nodes,

        field._N,
        field._NCache,
        field._FlagsSurvived,
        field._NAdded,
        field._NOverflow,
        
        field._neighbors,

        field._NFree,
        field._entriesFree,
        field._NFreeNextInit,
        field._NFreeNext,
    )
end

## Deepcopy - preserve _neighbors reference
function Base.deepcopy_internal(field::UnstructuredMeshField{P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}, stackdict::IdDict) where {P, DT, PR, PRN, PRC, IDVI, IDAI, VN, AI, VB, AB, NN, FI}
    if haskey(stackdict, field)
        return stackdict[field]
    end
    
    # Deepcopy the data arrays but preserve _neighbors reference
    new_field = UnstructuredMeshField(
        NamedTuple{keys(field._p)}(
            r ? p : Base.deepcopy_internal(p, stackdict) for (p, r) in zip(values(field._p), field._pReference)
        ),
        field._NP,
        field._pReference,

        field._id,
        field._idMax,

        field._nodes,

        field._N,
        field._NCache,
        field._FlagsSurvived,
        field._NAdded,
        field._NOverflow,
        
        field._neighbors,  # Preserve reference - do NOT deepcopy neighbor structure

        field._NFree,
        field._entriesFree,
        field._NFreeNextInit,
        field._NFreeNext,
    )
    
    stackdict[field] = new_field
    return new_field
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
    oldNCache = Array(field._NCache)[1]
    newNCache = oldNCache + additionalCache
    
    # Resize property arrays
    for i in 1:field._NP
        resize!(field._p[i], newNCache)
    end
    
    # Resize supporting arrays
    resize!(field._id, newNCache)
    # _nodes is a single Vector, not a collection
    if field._nodes !== nothing
        resize!(field._nodes, newNCache)
    end
    resize!(field._FlagsSurvived, newNCache)
    
    # Resize free entries array and add new free positions
    oldNFree = field._NFree[1]
    resize!(field._entriesFree, newNCache)
    # Add new positions to free list (in reverse order for efficient pop)
    for i in 1:additionalCache
        field._entriesFree[oldNFree + i] = newNCache - i + 1
    end
    field._NFree[1] = oldNFree + additionalCache
    field._NFreeNextInit[1] = oldNFree + additionalCache + 1
    
    # Preallocate neighbors (if present)
    if field._neighbors !== nothing
        preallocate!(field._neighbors, newNCache)
    end
    
    # Update cache size
    field._NCache .= newNCache
    
    return nothing
end

######################################################################################################
# Free entries management (for dynamic add/remove without compaction)
######################################################################################################

"""
    numberOfFree(field::UnstructuredMeshField)

Get the number of free positions available in the field.
"""
@inline numberOfFree(field::UnstructuredMeshField) = field._NFree[1]

"""
    isAlive(field::UnstructuredMeshField, i::Int)

Check if the agent at position `i` is alive (not removed).
Returns `true` if the agent is alive, `false` if it has been removed.

This is GPU-compatible and can be used inside kernels.

Example:
```julia
@kernel_launch ndrange=length(u.n.value) function my_kernel!(uNew, u, p, t)
    i = @index(Global)
    if isAlive(u.n, i)
        # Process only alive agents
        uNew.n.value[i] = u.n.value[i] * 2
    end
end
```
"""
@inline isAlive(field::UnstructuredMeshField, i::Int) = field._FlagsSurvived[i]

"""
    getFreePos!(field::UnstructuredMeshField)

Atomically get a free position from the field.
Returns the position index if available, or 0 if no free positions (overflow).
Thread-safe for use in parallel kernels.
"""
@inline function getFreePos!(field::UnstructuredMeshField{P}) where {P<:CPU}
    newFreePos = Atomix.@atomic field._NFree[1] -= 1
    if newFreePos >= 0
        pos = field._entriesFree[newFreePos + 1]
        field._entriesFree[newFreePos + 1] = 0
        # Mark as alive
        field._FlagsSurvived[pos] = true
        # Assign new id
        newId = Atomix.@atomic field._idMax[1] += 1
        field._id[pos] = newId
        # Increment count
        Atomix.@atomic field._N[1] += 1
        return pos
    else
        # Overflow - no free positions
        Atomix.@atomic field._NFree[1] += 1
        Atomix.@atomic field._NOverflow[1] += 1
        return 0
    end
end

@inline function getFreePos!(field::UnstructuredMeshField{P}) where {P<:GPU}
    newFreePos = Atomix.@atomic field._NFree[1] -= 1
    if newFreePos >= 0
        pos = field._entriesFree[newFreePos + 1]
        field._entriesFree[newFreePos + 1] = 0
        # Mark as alive
        field._FlagsSurvived[pos] = true
        # Assign new id
        newId = Atomix.@atomic field._idMax[1] += 1
        field._id[pos] = newId
        # Increment count
        Atomix.@atomic field._N[1] += 1
        return pos
    else
        # Overflow - no free positions
        Atomix.@atomic field._NFree[1] += 1
        Atomix.@atomic field._NOverflow[1] += 1
        return 0
    end
end

"""
    releasePos!(field::UnstructuredMeshField, pos::Int)

Release a position back to the free pool.
Thread-safe for use in parallel kernels.
The position will be available for reuse after synchronize(field) is called.
"""
@inline function releasePos!(field::UnstructuredMeshField{P}, pos::Int) where {P<:CPU}
    # Mark as dead
    field._FlagsSurvived[pos] = false
    field._id[pos] = 0
    # NOTE: Do NOT decrement _N here - it would shrink views mid-kernel.
    # _N will be updated in synchronize() after kernel completes.
    # Add to pending free list (will be compacted on synchronize)
    nextIdx = Atomix.@atomic field._NFreeNext[1] += 1
    insertIdx = field._NFreeNextInit[1] + nextIdx - 1
    if insertIdx <= length(field._entriesFree)
        field._entriesFree[insertIdx] = pos
    end
    return nothing
end

@inline function releasePos!(field::UnstructuredMeshField{P}, pos::Int) where {P<:GPU}
    # Mark as dead
    field._FlagsSurvived[pos] = false
    field._id[pos] = 0
    # NOTE: Do NOT decrement _N here - it would shrink views mid-kernel.
    # _N will be updated in synchronize() after kernel completes.
    # Add to pending free list (will be compacted on synchronize)
    nextIdx = Atomix.@atomic field._NFreeNext[1] += 1
    insertIdx = field._NFreeNextInit[1] + nextIdx - 1
    if insertIdx <= length(field._entriesFree)
        field._entriesFree[insertIdx] = pos
    end
    return nothing
end

"""
    synchronize(field::UnstructuredMeshField)

Compact the free entries list after add/remove operations.
Should be called after a batch of getFreePos!/releasePos! operations
to make released positions available for reuse.
"""
function synchronize(field::UnstructuredMeshField)
    # Copy values from arrays (handles both CPU and GPU by copying to host)
    chunk = Array(field._NFreeNext)[1]
    
    if chunk > 0
        nfree_current = Array(field._NFree)[1]
        chunkNewInit = nfree_current + 1
        chunkNewEnd = chunkNewInit + chunk - 1
        
        chunkOldInit = Array(field._NFreeNextInit)[1]
        chunkOldEnd = chunkOldInit + chunk - 1
        
        # Copy pending releases to main free list (use copyto! for GPU compatibility)
        copyto!(field._entriesFree, chunkNewInit, field._entriesFree, chunkOldInit, chunk)
        # Zero out the old pending slots
        fill!(@view(field._entriesFree[chunkOldInit:chunkOldEnd]), 0)
        
        # Update free list counters (use copyto! for GPU compatibility)
        # NOTE: _N is NOT modified here. With no-compaction design:
        # - Dead agents leave holes at their original positions
        # - _N stays as max used index to keep views valid
        # - Use _FlagsSurvived to check which positions are alive
        if field._NFree isa AbstractArray
            copyto!(field._NFree, 1, typeof(field._NFree)([chunkNewEnd]), 1, 1)
            copyto!(field._NFreeNext, 1, typeof(field._NFreeNext)([0]), 1, 1)
            copyto!(field._NFreeNextInit, 1, typeof(field._NFreeNextInit)([chunkNewEnd + 1]), 1, 1)
        end
    end
    return nothing
end

######################################################################################################
# UnstructuredMeshObject
######################################################################################################
struct UnstructuredMeshObject{
            P, D, S, DT,
            PAR, PARAMS, TOPO, AB
    } <: AbstractMeshObject
    _p::PAR
    _parameters::PARAMS  # Shared parameters field (accessed via obj.p.X)
    topo::TOPO
    _FlagOverflow::AB
end
Adapt.@adapt_structure UnstructuredMeshObject

mesh2Object(::Type{<:UnstructuredMesh}) = UnstructuredMeshObject
object2mesh(::Type{<:UnstructuredMeshObject}) = UnstructuredMesh

# Helper functions to get element count from sparse matrices
lengthElements(mat::AbstractSparseMatrix) = numberOfRows(mat)
lengthElementsCache(mat::AbstractSparseMatrix) = numberOfEntriesCache(mat)

function UnstructuredMeshObject(
        mesh::UnstructuredMesh{D, S};
        kwargs...
    ) where {D, S}

    # Extract neighbors parameter if provided, default to :auto
    neighbors = get(kwargs, :neighbors, :auto)

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
        end

        # Validate input type based on property type
        if prop isa Node
            # Node can be a Number or Tuple{Int, Int}
            if !(kwargs[p] isa Number) && !(kwargs[p] isa Tuple{Int, Int})
                error("Node property '$p' must be a Number or Tuple{Int, Int}. Found $(typeof(kwargs[p]))")
            end
            
            N_ = 0
            if kwargs[p] isa Number
                N_ = kwargs[p]
            elseif kwargs[p] isa Tuple{Int, Int}
                N_ = kwargs[p][1]
            end

            if N_ < 0
                error("Node property '$p' N must be greater than 0. Found N=$N_")
            end

            NCache_ = 0
            if kwargs[p] isa Number
                NCache_ = kwargs[p]
            elseif kwargs[p] isa Tuple{Int, Int}
                NCache_ = kwargs[p][2]
            end

            field = UnstructuredMeshField(prop, N = N_, NCache = NCache_, neighbors = neighbors)
            push!(fields, field)
            
        elseif prop isa Edge || prop isa Face || prop isa Volume
            # Edge, Face, Volume must be AbstractSparseMatrix
            if !(kwargs[p] isa AbstractSparseMatrix)
                error("$(typeof(prop).name.name) property '$p' must be an AbstractSparseMatrix. Found $(typeof(kwargs[p]))")
            end
            
            field = UnstructuredMeshField(prop, N = lengthElements(kwargs[p]), NCache = lengthElementsCache(kwargs[p]), neighbors = neighbors)
            push!(fields, field)
            
        elseif prop isa Agent
            # Agent depends on number of associated symbols
            if length(prop.cs) == 1
                # Single symbol: must be AbstractSparseMatrix
                if !(kwargs[p] isa AbstractSparseMatrix)
                    error("Agent property '$p' with single connection ($(prop.cs[1])) must be an AbstractSparseMatrix. Found $(typeof(kwargs[p]))")
                end
                
                field = UnstructuredMeshField(prop, N = lengthElements(kwargs[p]), NCache = lengthElementsCache(kwargs[p]), neighbors = neighbors)
                push!(fields, field)
                
            else
                # Multiple symbols: must be NamedTuple with AbstractSparseMatrix for each symbol
                if !(kwargs[p] isa NamedTuple)
                    error("Agent property '$p' with multiple connections $(prop.cs) must be a NamedTuple. Found $(typeof(kwargs[p]))")
                end
                
                # Check that all required symbols are present
                for sym in prop.cs
                    if !(sym in keys(kwargs[p]))
                        error("Agent property '$p' is missing connection to '$sym' in NamedTuple")
                    end
                    if !(kwargs[p][sym] isa AbstractSparseMatrix)
                        error("Agent property '$p' connection to '$sym' must be an AbstractSparseMatrix. Found $(typeof(kwargs[p][sym]))")
                    end
                end

                #Check all symbols have same lengthElements
                if all(lengthElements(kwargs[p][prop.cs[1]]) != lengthElements(kwargs[p][sym]) for sym in prop.cs)
                    error("Agent property '$p' connections $(prop.cs) must have the same number of elements. Found lengths: " *
                        join([string(sym, "=", lengthElements(kwargs[p][sym])) for sym in prop.cs], ", "))
                end

                field = UnstructuredMeshField(prop, N = lengthElements(kwargs[p][prop.cs[1]]), NCache = lengthElementsCache(kwargs[p][prop.cs[1]]), neighbors = neighbors)
                push!(fields, field)
            end
        else
            error("Unknown property type: $(typeof(prop))")
        end

    end

    params = NamedTuple{tuple(keys(mesh._p)...)}(fields)
    _FlagOverflow = SizedVector{1}(false)
    
    # Create parameters field if mesh has shared parameters
    # Parameters are global (size 1) unless specified as an array type
    # Function defaults are skipped here and applied after object creation
    parametersField = if length(mesh._parameters) > 0
        parametersDict = Dict{Symbol, Any}()
        for (name, param) in pairs(mesh._parameters)
            dt = dtype(param; isbits=true)
            if dt <: AbstractArray
                # Array type: use default value if available (skip functions), otherwise zeros
                if param.defaultValue !== nothing && !(param.defaultValue isa Function)
                    parametersDict[name] = [copy(param.defaultValue)]
                else
                    parametersDict[name] = zeros(eltype(dt), 1, 1)
                end
            else
                # Scalar type: use default value if available (skip functions), otherwise NaN for floats
                if param.defaultValue !== nothing && !(param.defaultValue isa Function)
                    parametersDict[name] = [param.defaultValue]
                elseif dt <: AbstractFloat
                    # Mark uninitialized Float values with NaN for validation
                    parametersDict[name] = [NaN]
                else
                    parametersDict[name] = zeros(dt, 1)
                end
            end
        end
        NamedTuple{tuple(keys(parametersDict)...)}(values(parametersDict))
    else
        nothing
    end
    
    # Build topology object from mesh topology and validate consistency
    # Pass required relations and their types for precomputation of derived relations
    topology_ = buildTopology(mesh.topo, kwargs, params; 
        requiredRelations=mesh._requiredTopologyRelations,
        requiredRelationTypes=mesh._requiredTopologyRelationTypes)

    meshObj = UnstructuredMeshObject{
            P, D, S, DT,
            typeof(params), typeof(parametersField), typeof(topology_), typeof(_FlagOverflow)
        }(
            params, parametersField, topology_, _FlagOverflow
        )

    # Apply function defaults after object is fully constructed
    _applyFunctionDefaults!(mesh, meshObj)

    return meshObj
end

"""
    _applyFunctionDefaults!(mesh, meshObj)

Apply function-based default values to the mesh object.
Functions are called with the mesh object as argument after the object is fully constructed.
"""
function _applyFunctionDefaults!(mesh::UnstructuredMesh, meshObj::UnstructuredMeshObject)
    # Apply function defaults for node/element properties
    for (scope_name, scope_prop) in pairs(mesh._p)
        if scope_prop !== nothing && hasfield(typeof(scope_prop), :p)
            mesh_obj_scope = getproperty(meshObj, scope_name)
            N = mesh_obj_scope._N[]
            for (prop_name, param) in pairs(scope_prop.p)
                if param.defaultValue isa Function && N > 0
                    # Call the function with the mesh object
                    val = getproperty(mesh_obj_scope, prop_name)
                    for i in 1:N
                        val[i] = param.defaultValue(meshObj)
                    end
                end
            end
        end
    end
    
    # Apply function defaults for shared parameters
    if hasfield(typeof(mesh), :_parameters) && mesh._parameters !== nothing
        for (name, param) in pairs(mesh._parameters)
            if param.defaultValue isa Function
                if meshObj._parameters !== nothing && haskey(meshObj._parameters, name)
                    val = meshObj._parameters[name]
                    result = param.defaultValue(meshObj)
                    if result isa AbstractArray
                        val[1] = copy(result)
                    else
                        val[1] = result
                    end
                end
            end
        end
    end
    
    return nothing
end

function UnstructuredMeshObject(
            p, parameters, topology, _FlagOverflow
    )

    D = 0
    for n in values(p) #To FIX
        D = max(D, length(filter(k -> k in (:x, :y, :z), keys(n._p))))
    end
    # Detect platform from the first field in p instead of using default
    P = nothing
    for field in values(p)
        if field !== nothing
            # Get platform from UnstructuredMeshField type parameter
            P = typeof(field).parameters[1]
            break
        end
    end
    P = P === nothing ? platform() : P
    
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
            P, D, S, DT,
            typeof(p), typeof(parameters), typeof(topology), typeof(_FlagOverflow)
        }(
            p, parameters, topology, _FlagOverflow
        )
end

function Base.show(io::IO, x::UnstructuredMeshObject{P, D, S}) where {P, D, S}
    println(io, "\nUnstructuredMeshObject platform=$P dimensions=$D specialization=$S \n")
    CellBasedModels.show(io, x)
    println(io, "\t* -> indicates passed by reference\n")
end

function show(io::IO, x::UnstructuredMeshObject, full=false)
    # Display shared parameters if present
    if x._parameters !== nothing && length(x._parameters) > 0
        println(io, "\tp (Parameters)")
        println(io, @sprintf("\t%-20s %-15s", "Name", "DataType"))
        println(io, "\t" * repeat("-", 85))
        for (name, par) in pairs(x._parameters)
            println(io, @sprintf("\t%-20s %-15s", 
                string(name),
                eltype(par)))
        end
        println(io)
    end
    
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

function show(io::IO, ::Type{UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}}) where {P, D, S, DT, PAR, PARAMS, TOPO, AB}
    for (props, propsnames) in zip((PAR), ("a", "PropertiesNode", "PropertiesEdge", "PropertiesFace", "PropertiesVolume"))
        if props !== Nothing
            print(io, "\t", string(propsnames), "Meta", "=(")
            CellBasedModels.show(io, props)
            println(io, ")")
        end
    end
end

function lengthProperties(::UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}) where {P, D, S, DT, PAR, PARAMS, TOPO, AB}
    return length(PAR.parameters[1])
end    
function Base.length(mesh::UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}) where {P, D, S, DT, PAR, PARAMS, TOPO, AB}
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
@generated function Base.getproperty(field::UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}, s::Symbol) where {P, D, S, DT, PAR, PARAMS, TOPO, AB}
    # build a clause for each fieldname in T
    general = [
        :(if s === $(QuoteNode(name)); return getfield(field, $(QuoteNode(name))); end)
        for name in fieldnames(UnstructuredMeshObject)
    ]
    cases = [
        :(s === $(QuoteNode(name)) && return @views getfield(getfield(field, :_p), $(QuoteNode(name))))
        for name in PAR.parameters[1]
    ]
    
    # Add case for :p -> parameters field
    parameterCase = if PARAMS !== Nothing
        :(s === :p && return getfield(field, :_parameters))
    else
        :(s === :p && error("This mesh has no shared parameters defined."))
    end

    quote
        $(general...)
        $parameterCase
        $(cases...)
        error("Unknown property: $s for the UnstructuredMeshObject.")
    end
end

# Provide clear error message when trying to assign with = instead of .=
function Base.setproperty!(field::UnstructuredMeshObject, s::Symbol, v)
    # Check if s is a user property (not an internal field)
    if s in keys(field._p)
        error("Cannot assign to property '$s' using '='. Access the field and use '.=' for in-place broadcast assignment.\n" *
              "Example: mesh.$s.property .= value  # correct\n" *
              "         mesh.$s = value            # incorrect")
    else
        # For internal fields, give the standard error
        error("type UnstructuredMeshObject is immutable and has no field $s that can be set")
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
# Helper to copy a NamedTuple of arrays
function _copyParametersTuple(params::NamedTuple)
    NamedTuple{keys(params)}(copy(v) for v in values(params))
end
_copyParametersTuple(::Nothing) = nothing

# Helper to create similar NamedTuple of arrays
function _similarParametersTuple(params::NamedTuple)
    NamedTuple{keys(params)}(similar(v) for v in values(params))
end
_similarParametersTuple(::Nothing) = nothing

function Base.copy(field::UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}) where {P, D, S, DT, PAR, PARAMS, TOPO, AB}

    UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}(
        NamedTuple{keys(field._p)}(
            copy(getfield(field._p, name)) for name in keys(field._p)
        ),
        _copyParametersTuple(field._parameters),
        field.topo,
        Base.copy(field._FlagOverflow)
    )

end

function partialCopy(field::UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}, copyArgs) where {P, D, S, DT, PAR, PARAMS, TOPO, AB}

    UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}(
        NamedTuple{keys(field._p)}(
            partialCopy(getfield(field._p, name), [i[2] for i in copyArgs if i[1] == name]) for name in keys(field._p)
        ),
        _copyParametersTuple(field._parameters),  # Parameters are always fully copied
        field.topo,
        field._FlagOverflow
    )

end

## Similar
function Base.similar(field::UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}) where {P, D, S, DT, PAR, PARAMS, TOPO, AB}

    UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}(
        NamedTuple{keys(field._p)}(
            similar(getfield(field._p, name)) for name in keys(field._p)
        ),
        _similarParametersTuple(field._parameters),
        field.topo,
        field._FlagOverflow
    )

end

function Base.similar(field::UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}, _) where {P, D, S, DT, PAR, PARAMS, TOPO, AB}

    UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}(
        NamedTuple{keys(field._p)}(
            similar(getfield(field._p, name)) for name in keys(field._p)
        ),
        _similarParametersTuple(field._parameters),
        field.topo,
        field._FlagOverflow
    )

end

## Deepcopy - preserve topo reference
# Helper to deepcopy a NamedTuple of arrays
function _deepcopyParametersTuple(params::NamedTuple, stackdict::IdDict)
    NamedTuple{keys(params)}(Base.deepcopy_internal(v, stackdict) for v in values(params))
end
_deepcopyParametersTuple(::Nothing, stackdict::IdDict) = nothing

function Base.deepcopy_internal(field::UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}, stackdict::IdDict) where {P, D, S, DT, PAR, PARAMS, TOPO, AB}
    if haskey(stackdict, field)
        return stackdict[field]
    end
    
    # Deepcopy the data arrays but preserve topo reference
    new_field = UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}(
        NamedTuple{keys(field._p)}(
            Base.deepcopy_internal(getfield(field._p, name), stackdict) for name in keys(field._p)
        ),
        _deepcopyParametersTuple(field._parameters, stackdict),
        field.topo,   # Preserve reference  
        deepcopy(field._FlagOverflow)
    )
    
    stackdict[field] = new_field
    return new_field
end

## Zero
# Helper to zero a NamedTuple of arrays
function _zeroParametersTuple(params::NamedTuple)
    NamedTuple{keys(params)}(zero(v) for v in values(params))
end
_zeroParametersTuple(::Nothing) = nothing

function Base.zero(field::UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}) where {P, D, S, DT, PAR, PARAMS, TOPO, AB}

    UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}(
        NamedTuple{keys(field._p)}(
            zero(getfield(field._p, name)) for name in keys(field._p)
        ),
        _zeroParametersTuple(field._parameters),
        field.topo,
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
    
    # Also copy parameters if present
    if dest._parameters !== nothing && bc._parameters !== nothing
        for name in keys(dest._parameters)
            copyto!(dest._parameters[name], bc._parameters[name])
        end
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
    
    # Also copy parameters if present
    if dest._parameters !== nothing && bc._parameters !== nothing
        for name in keys(dest._parameters)
            copyto!(dest._parameters[name], bc._parameters[name])  # copyfrom! is just copyto! for arrays
        end
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
    
    # Also fill parameters if present
    if dest._parameters !== nothing
        for name in keys(dest._parameters)
            fill!(dest._parameters[name], value)
        end
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
function preallocate!(mesh::UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}, additionalCache::NamedTuple = (;)) where {P, D, S, DT, PAR, PARAMS, TOPO, AB}
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
        elseif field_name == :p && mesh._parameters !== nothing
            preallocate!(mesh._parameters, additional)
        else
            @warn "Field $field_name not found in mesh. Skipping preallocation."
        end
    end
    
    return nothing
end

## getOverflow
function getOverflow(mesh::UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}, factor=1) where {P, D, S, DT, PAR, PARAMS, TOPO, AB}
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

function resetOverflow!(mesh::UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}) where {P, D, S, DT, PAR, PARAMS, TOPO, AB}
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

function isOverflowed(mesh::UnstructuredMeshObject{P, D, S, DT, PAR, PARAMS, TOPO, AB}) where {P, D, S, DT, PAR, PARAMS, TOPO, AB}
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

# Note: update!(mesh::UnstructuredMeshObject) is defined in neighbors/neighborsFull.jl
# It handles compaction using field._neighbors.permTable and field._neighbors.auxBuffers

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