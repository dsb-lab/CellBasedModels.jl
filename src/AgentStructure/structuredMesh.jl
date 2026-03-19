######################################################################################################
# AGENT STRUCTURE
######################################################################################################
struct StructuredMesh{D, S, PC, PA} <: AbstractMesh

    c::Union{Nothing, NamedTuple}                   # Dictionary to hold cell properties
    a::Union{Nothing, NamedTuple}                   # Dictionary to hold agent properties
    _functions::Dict{Symbol, Any}    # Dictionary to hold functions associated with the mesh

end

function StructuredMesh(
    dims::Int;
    propertiesCell::Union{Nothing, NamedTuple} = nothing,
    propertiesAgent::Union{Nothing, NamedTuple} = nothing,
)

    if dims < 1 || dims > 3
        error("dims must be between 1 and 3. Found $dims")
    end

    _c = nothing
    if propertiesCell !== nothing
        _c = parameterConvert(propertiesCell)
    end

    _a = nothing
    if propertiesAgent !== nothing
        _a = parameterConvert(propertiesAgent)
    end

    return StructuredMesh{dims, Nothing, typeof(_c), typeof(_a)}(
        _c,
        _a,
        Dict{Symbol, Any}()
    )
end

function Base.show(io::IO, x::StructuredMesh{D}) where {D}
    println(io, "StructuredMesh with dimensions $(D): \n")
    CellBasedModels.show(io, x)
end

function show(io::IO, x::StructuredMesh{D}) where {D}
    for p in propertynames(x)
        props = getfield(x, p)
        if props !== nothing
            println(io, p)
            println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-20s %-s", "Name", "DataType", "Dimensions", "Default_Value", "ModifiedIn", "Description"))
            println(io, "\t" * repeat("-", 85))
            for (name, par) in pairs(props)
                dv = if par.defaultValue === nothing
                    ""
                elseif par.defaultValue isa Function
                    "<Function> " * string(nameof(par.defaultValue))
                else
                    string(par.defaultValue)
                end
                println(io, @sprintf("\t%-15s %-15s %-15s %-20s %-20s %-s", 
                    name, 
                    dtype(par), 
                    par.dimensions === nothing ? "" : string(par.dimensions),
                    dv, 
                    length(par._modifiedIn) === 0 ? "" : string(tuple(par._modifiedIn)),
                    par.description))
            end
            println(io)
        end
    end
end

function Base.show(io::IO, ::Type{StructuredMesh{D, S, P}}) where {D, S, P}
    println(io, "StructuredMesh{dims=", D, ", specialization=", S, ",")
    for (i, (n, t)) in enumerate(zip(P.parameters[1], P.parameters[2].parameters))
        i > 1 && print(io, ", ")
        print(io, string(n), "::", t.parameters[1])
    end
    println(io, ")")
    println(io, "}")
end

spatialDims(::StructuredMesh{D}) where {D} = D
specialization(::StructuredMesh{D, S}) where {D, S} = S

function addFunction!(mesh::StructuredMesh, type, scope, params, functions)

    for param in params
        if length(param) != 2
            error("Each parameter modification must be a tuple of (field, parameter_name). Found: $param. Most probably you assigned incorrectly a parameter in a function (e.g. mesh.$field_name.$parameter_name). Valid parameters are: \n $mesh")
        end

        field_name, parameter_name = param

        field = nothing
        if field_name in fieldnames(typeof(mesh))
            field = getfield(mesh, field_name)
        else
            error("Mesh does not have field $field_name. Available fields are: $(fieldnames(typeof(mesh))). Most probably you assigned incorrectly a parameter in a function (e.g. mesh.$field_name.$parameter_name). Valid parameters are: \n $mesh")
        end  

        if parameter_name in keys(field)
            par = field[parameter_name]
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

function modifiedInScope(mesh::StructuredMesh, scope::Symbol)

    modified = []

    for field in (:c, :a)
        props = getfield(mesh, field)
        if props !== nothing
            for (name, par) in pairs(props)
                for (t, s) in par._modifiedIn
                    if s == scope
                        push!(modified, (field, name))
                    end
                end
            end
        end
    end

    return modified
end

function modifiedInScope(mesh::StructuredMesh)

    modified = []

    for field in (:c, :a)
        props = getfield(mesh, field)
        if props !== nothing
            for (name, par) in pairs(props)
                for (t, s) in par._modifiedIn
                    push!(modified, (field, name))
                end
            end
        end
    end

    return modified
end

######################################################################################################
# StructuredMeshObject
######################################################################################################
struct StructuredMeshObject{
        P, D, S, PC, PA, PCRef, PARef, SB, NG
    } <: AbstractMeshObject
    c::PC
    a::PA
    _pcReference::PCRef
    _paReference::PARef
    _simulationBox::SB
    _gridSpacing::NG
end
Adapt.@adapt_structure StructuredMeshObject

mesh2Object(::Type{<:StructuredMesh}) = StructuredMeshObject
object2mesh(::Type{<:StructuredMeshObject}) = StructuredMesh

function StructuredMeshObject(
        mesh::StructuredMesh{D, S};
        simulationBox,
        gridSpacing,
    ) where {D, S}

    if size(simulationBox) != (D, 2)
        error("simulationBox must be of size ($(D), 2). Found size $(size(simulationBox))")
    end
    if length(gridSpacing) == 0
        gridSpacing = fill(gridSpacing, D)
    elseif length(gridSpacing) != D
        error("gridSpacing must be of length $(D). Found length $(length(gridSpacing))")
    end

    simulationBox = SizedMatrix{D, 2, standardDataType(AbstractFloat)}(simulationBox)
    gridSpacing = SizedVector{D,standardDataType(AbstractFloat)}(gridSpacing)

    gridSize = Int.(ceil.((simulationBox[:, 2] .- simulationBox[:, 1]) ./ gridSpacing))
    
    fieldsCell = nothing
    _pcReference = SizedVector{0, Bool}([])
    if mesh.c !== nothing
        fieldsCell = NamedTuple{keys(mesh.c)}([zeros(dtype(j, isbits=true), gridSize...) for (i,j) in pairs(mesh.c)])
        _pcReference = SizedVector{length(fieldsCell), Bool}([true for _ in 1:length(fieldsCell)])
    end

    fieldsAgent = nothing
    _paReference = SizedVector{0, Bool}([])
    if mesh.a !== nothing
        fieldsAgent = NamedTuple{keys(mesh.a)}([zeros(dtype(j, isbits=true), gridSize...) for (i,j) in pairs(mesh.a)])
        _paReference = SizedVector{length(fieldsAgent), Bool}([true for _ in 1:length(fieldsAgent)])
    end

    P = platform()

    return StructuredMeshObject{
            P, D, S, typeof(fieldsCell), typeof(fieldsAgent), typeof(_pcReference), typeof(_paReference), typeof(simulationBox), typeof(gridSpacing)
        }(
            fieldsCell, fieldsAgent, _pcReference, _paReference, simulationBox, gridSpacing
        )
end

function StructuredMeshObject(
        fieldsCell, fieldsAgent, pReferenceCell, pReferenceAgent, simulationBox, gridSpacing
    )

    P = platform()
    D = length(gridSpacing)
    S = Nothing
    PC = typeof(fieldsCell)
    PA = typeof(fieldsAgent)
    PCRef = typeof(pReferenceCell)
    PARef = typeof(pReferenceAgent)
    SB = typeof(simulationBox)
    NG = typeof(gridSpacing)

    return StructuredMeshObject{
            P, D, S, PC, PA, PCRef, PARef, SB, NG
        }(
            fieldsCell, fieldsAgent, pReferenceCell, pReferenceAgent, simulationBox, gridSpacing
        )
end

function show(io::IO, x::StructuredMeshObject{P, D, S, PC, PA, PCRef, PARef, SB, NG}, full=false) where {P, D, S, PC, PA, PCRef, PARef, SB, NG}
    if x.c !== nothing
        println(io, "Properties Cell:")
        println(io, @sprintf("\t%-20s %-15s", "Name (Public)", "DataType"))
        println(io, "\t" * repeat("-", 85))
        for ((name, par), c) in zip(pairs(x.c), x._pcReference)
            println(io, @sprintf("\t%-20s %-15s", 
                c ? string("*", name) : string(name),
                typeof(par)))
        end
    end
    if x.a !== nothing
        println(io, "Properties Agent:")
        println(io, @sprintf("\t%-20s %-15s", "Name (Public)", "DataType"))
        println(io, "\t" * repeat("-", 85))
        for ((name, par), c) in zip(pairs(x.a), x._paReference)
            println(io, @sprintf("\t%-20s %-15s", 
                c ? string("*", name) : string(name),
                typeof(par)))
        end
    end
end

# function Base.show(io::IO, x::Type{StructuredMeshObject{
#             P, D, S, A, N, E, F, V,
#         }}) where {
#             P, D, S, A, N, E, F, V,
#         }
#     println(io, "StructuredMesh{platform=", P, ", dimension=", D, ", scopePosition=", S,)
#     CellBasedModels.show(io, x)
#     println(io, "}")
# end

# function show(io::IO, ::Type{StructuredMeshObject{
#             P, D, S, A, N, E, F, V,
#         }}) where {
#             P, D, S, A, N, E, F, V,
#         }
#     for (props, propsnames) in zip((A, N, E, F, V), ("a", "PropertiesNode", "PropertiesEdge", "PropertiesFace", "PropertiesVolume"))
#         if props !== Nothing
#             print(io, "\t", string(propsnames), "Meta", "=(")
#             # println(propsmeta)
#             CellBasedModels.show(io, props)
#             println(io, ")")
#             # print(io, "\t", string(props), "=(")
#             # for (i, (n, t)) in enumerate(zip(props.parameters[1], props.parameters[2].parameters))
#             #     i > 1 && print(io, ", ")
#             #     print(io, string(n), "::", t)
#             # end
#             # println(io, ")")
#         end
#     end
# end

function Base.length(x::StructuredMeshObject{P, D, S, PC, PA}) where {P, D, S, PC, PA}
    l = 0
    l += x.c === nothing ? 0 : length(x.c) * length(x.c[1])
    l += x.a === nothing ? 0 : length(x.a) * length(x.a[1])
    return l
end 
Base.size(mesh::StructuredMeshObject) = (length(mesh.c), size(mesh.c[1])...)

import SparseConnectivityTracer

# Allocate index matrix - should return similar structure with Int indices
function SparseConnectivityTracer.allocate_index_matrix(A::StructuredMeshObject{P, D, S, PC, PA}) where {P, D, S, PC, PA}
    fieldsCell = nothing
    if A.c !== nothing
        fieldsCell = NamedTuple{keys(A.c)}([similar(field, Int) for field in values(A.c)])
    end
    
    fieldsAgent = nothing  
    if A.a !== nothing
        fieldsAgent = NamedTuple{keys(A.a)}([similar(field, Int) for field in values(A.a)])
    end
    
    return StructuredMeshObject(
        fieldsCell, fieldsAgent, A._pcReference, A._paReference, A._simulationBox, A._gridSpacing
    )
end

# Trace input - enumerate indices and create tracers
function SparseConnectivityTracer.trace_input(::Type{T}, xs::StructuredMeshObject, i) where {T <: Union{SparseConnectivityTracer.AbstractTracer, SparseConnectivityTracer.Dual}}
    # Create index matrix
    is = SparseConnectivityTracer.allocate_index_matrix(xs)
    
    # Fill with enumerated indices
    current_idx = i - 1
    
    if xs.c !== nothing
        for field in values(is.c)
            num_elements = length(field)
            field .= reshape(current_idx+1:current_idx+num_elements, size(field))
            current_idx += num_elements
        end
    end
    
    if xs.a !== nothing
        for field in values(is.a)
            num_elements = length(field)
            field .= reshape(current_idx+1:current_idx+num_elements, size(field))
            current_idx += num_elements
        end
    end
    
    # Create tracers using the index matrix
    return create_tracers(T, xs, is)
end

# Create tracers method for your type
function create_tracers(::Type{T}, xs::G, is) where {T, G<:StructuredMeshObject}
    fieldsCell = nothing
    if xs.c !== nothing
        fieldsCell = NamedTuple{keys(xs.c)}([
            SparseConnectivityTracer.create_tracers(T, xs.c[k], is.c[k]) 
            for k in keys(xs.c)
        ])
    end
    
    fieldsAgent = nothing
    if xs.a !== nothing  
        fieldsAgent = NamedTuple{keys(xs.a)}([
            SparseConnectivityTracer.create_tracers(T, xs.a[k], is.a[k])
            for k in keys(xs.a)
        ])
    end
    
    return StructuredMeshObject(
        fieldsCell, fieldsAgent, xs._pcReference, xs._paReference, xs._simulationBox, xs._gridSpacing
    )
end

# Add similar method for SparseConnectivityTracer compatibility
function Base.similar(x::StructuredMeshObject{P, D, S, PC, PA}, ::Type{T}) where {P, D, S, PC, PA, T}
    fieldsCell = nothing
    if x.c !== nothing
        fieldsCell = NamedTuple{keys(x.c)}([similar(field, T) for field in values(x.c)])
    end
    
    fieldsAgent = nothing  
    if x.a !== nothing
        fieldsAgent = NamedTuple{keys(x.a)}([similar(field, T) for field in values(x.a)])
    end
    
    return StructuredMeshObject(
        fieldsCell, fieldsAgent, x._pcReference, x._paReference, x._simulationBox, x._gridSpacing
    )
end

# Also add the standard similar method
function Base.similar(x::StructuredMeshObject{P, D, S, PC, PA}) where {P, D, S, PC, PA}
    return similar(x, eltype(x))
end

# Add fill! method for SparseConnectivityTracer compatibility
function Base.fill!(x::StructuredMeshObject, value)
    if x.c !== nothing
        for field in values(x.c)
            fill!(field, value)
        end
    end
    
    if x.a !== nothing
        for field in values(x.a)
            fill!(field, value)
        end
    end
    
    return x
end

# Add to_array method for SparseConnectivityTracer compatibility
function SparseConnectivityTracer.to_array(x::StructuredMeshObject)
    arrays = []
    
    # Collect cell fields
    if x.c !== nothing
        for field in values(x.c)
            push!(arrays, vec(field))  # Flatten each field to 1D
        end
    end
    
    # Collect agent fields  
    if x.a !== nothing
        for field in values(x.a)
            push!(arrays, vec(field))  # Flatten each field to 1D
        end
    end
    
    # Concatenate all fields into a single vector
    return vcat(arrays...)
end

Base.ndims(::StructuredMeshObject{P, D}) where {P, D} = 1 + D
Base.ndims(::Type{<:StructuredMeshObject{P, D}}) where {P, D} = 1 + D

function Base.eltype(::Type{<:StructuredMeshObject})
    return CellBasedModels.concreteDataType(AbstractFloat)
end

function Base.iterate(mesh::StructuredMeshObject, state = 1)
    state >= length(mesh) ? nothing : (state, state + 1)
end

platform(mesh::StructuredMeshObject{P}) where {P} = P
spatialDims(::StructuredMeshObject{P, D}) where {P, D} = D
specialization(::StructuredMeshObject{P, D, S}) where {P, D, S} = S

#Getindex
Base.getindex(community::StructuredMeshObject, i::Integer) = community.p[i]
Base.getindex(community::StructuredMeshObject, s::Symbol) = community.p[s]

## Copy
function Base.copy(field::StructuredMeshObject{P, D, S}) where {P, D, S}

    StructuredMeshObject{P, D, S, typeof(field.c), typeof(field.a), typeof(field._pcReference), typeof(field._paReference), typeof(field._simulationBox), typeof(field._gridSpacing)}(
        field.c === nothing ? field.c : NamedTuple{keys(field.c)}([r ? field.c[i] : copy(field.c[i]) for (i,r) in zip(keys(field.c), field._pcReference)]),
        field.a === nothing ? field.a : NamedTuple{keys(field.a)}([r ? field.a[i] : copy(field.a[i]) for (i,r) in zip(keys(field.a), field._paReference)]),
        field._pcReference,
        field._paReference,
        field._simulationBox,
        field._gridSpacing,
    )

end

## Zero
function Base.zero(field::StructuredMeshObject{P, D, S}) where {P, D, S}

    StructuredMeshObject{P, D, S, typeof(field.c), typeof(field.a), typeof(field._pcReference), typeof(field._paReference), typeof(field._simulationBox), typeof(field._gridSpacing)}(
        field.c === nothing ? field.c : NamedTuple{keys(field.c)}([r ? field.c[i] : zeros(field.c[i]) for (i,r) in zip(keys(field.c), field._pcReference)]),
        field.a === nothing ? field.a : NamedTuple{keys(field.a)}([r ? field.a[i] : zeros(field.a[i]) for (i,r) in zip(keys(field.a), field._paReference)]),
        field._pcReference,
        field._paReference,
        field._simulationBox,
        field._gridSpacing,
    )

end

## Copyto!
@eval @inline function Base.copyto!(
    dest::StructuredMeshObject,
    bc::StructuredMeshObject)
    for (i,r) in zip(1:length(dest), dest._pReference)
        if !r
            copyto!(dest[i], bc[i])
        end
    end
    dest
end

## Broadcasting
struct StructuredMeshObjectStyle{N} <: Broadcast.AbstractArrayStyle{N} end

# Allow constructing the style from Val or Int
StructuredMeshObjectStyle(::Val{N}) where {N} = StructuredMeshObjectStyle{N}()
StructuredMeshObjectStyle(N::Int) = StructuredMeshObjectStyle{N}()

# Your StructuredMeshObject acts like a 2D array
Base.BroadcastStyle(::Type{<:StructuredMeshObject{P, D}}) where {P, D} = StructuredMeshObjectStyle{D}()

# Combine styles safely
Base.Broadcast.result_style(::StructuredMeshObjectStyle{M}) where {M} =
    StructuredMeshObjectStyle{M}()
Base.Broadcast.result_style(::StructuredMeshObjectStyle{M}, ::StructuredMeshObjectStyle{N}) where {M,N} =
    StructuredMeshObjectStyle{max(M,N)}()
Base.Broadcast.result_style(::StructuredMeshObjectStyle{M}, ::Base.Broadcast.AbstractArrayStyle{N}) where {M,N} =
    StructuredMeshObjectStyle{max(M,N)}()
Base.Broadcast.result_style(::Base.Broadcast.AbstractArrayStyle{M}, ::StructuredMeshObjectStyle{N}) where {M,N} =
    StructuredMeshObjectStyle{max(M,N)}()

Broadcast.broadcastable(x::StructuredMeshObject) = x

for type in [
        Broadcast.Broadcasted{<:StructuredMeshObject},
        Broadcast.Broadcasted{<:StructuredMeshObjectStyle},
    ]

    @eval @inline function Base.copyto!(
            dest::StructuredMeshObject,
            bc::$type)
        bc = Broadcast.flatten(bc)
        @inbounds for i in 1:length(dest)
            if !dest._pReference[i]
                copyto!(dest[i], unpack_voa(bc, i))
            end
        end
        dest
    end
end

#Specialized unpacking
@inline function unpack_voa(bc::Broadcast.Broadcasted{<:StructuredMeshObject}, i)
    Broadcast.Broadcasted(bc.f, unpack_args_voa(i, bc.args))
end
function unpack_voa(x::StructuredMeshObject, i)
    x[i]
end