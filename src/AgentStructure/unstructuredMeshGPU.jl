import CellBasedModels: DATATYPE
import CellBasedModels: lengthCache, lengthProperties, sizeFull, sizeFullCache, nCopyProperties
import CellBasedModels: UnstructuredMeshField, UnstructuredMeshFieldStyle, UnstructuredMeshObject, UnstructuredMeshObjectStyle, unpack_voa
import CellBasedModels: CPU, GPU
import CellBasedModels: initNeighbors
import KernelAbstractions

########################################################################################
# broadcasting support
########################################################################################
for type in [
        Broadcast.Broadcasted{<:UnstructuredMeshField},
        Broadcast.Broadcasted{<:UnstructuredMeshFieldStyle},
    ]

    @eval @inline function Base.copyto!(
            dest::UnstructuredMeshField{P, DT, PR, PRN, PRC},
            bc::$type) where {P<:Union{<:GPU}, DT, PR, PRN, PRC}
        bc = Broadcast.flatten(bc)
        N = lengthProperties(dest)
        @inbounds for i in 1:PRN
            if !dest._pReference[i]
                dest_ = @views dest._p[i][1:N]
                dest_ .= unpack_voa(bc, i)
            end
        end
        dest
    end
end

function unpack_voa(x::UnstructuredMeshField{P}, i) where {P<:Union{<:GPU}}
    @views x._p[i][1:lengthProperties(x)]
end

for type in [
        Broadcast.Broadcasted{<:UnstructuredMeshObject},
        Broadcast.Broadcasted{<:UnstructuredMeshObjectStyle},
    ]

    @eval @inline function Base.copyto!(
            dest::UnstructuredMeshObject{P, A, N, E, F, V},
            bc::$type) where {P<:Union{<:GPU}, A, N, E, F, V}
        bc = Broadcast.flatten(bc)

        for name in keys(dest._p)
            d = getfield(dest._p, name)
            if d !== nothing
                np, n = sizeFull(d)
                for j in 1:np
                    if !d._pReference[j]
                        dest_ = @views d._p[j][1:n]
                        dest_ .= unpack_voa(bc, name, j, n)
                    end
                end
            end
        end

        dest
    end
end

function unpack_voa(x::UnstructuredMeshObject{P}, i, j, n) where {P<:Union{<:GPU}}
    @views x[i]._p[j][1:n]
    # x[i]._p[j]
end

# ########################################################################################
# # to CPU / to GPU conversions
# ########################################################################################
toBackend(field::UnstructuredMeshField{P}, ::CPU) where {P<:CPU} = field

function toBackend(field::UnstructuredMeshField{P}, ::CPU) where {P<:GPU}
    
    UnstructuredMeshField(
        field._p              === nothing ? nothing : Adapt.adapt(Array, field._p),
        field._NP             === nothing ? nothing : field._NP,
        field._pReference     === nothing ? nothing : SizedVector{field._NP, Bool}([field._pReference...]),
        field._id             === nothing ? nothing : Vector{Int}(field._id),
        field._idMax          === nothing ? nothing : SizedVector{1}(Array(field._idMax)[1]),
        field._nodes          === nothing ? nothing : Vector{Int}(field._nodes),
        field._N              === nothing ? nothing : SizedVector{1}(Array(field._N)[1]),
        field._NCache         === nothing ? nothing : SizedVector{1}(Array(field._NCache)[1]),
        field._FlagsSurvived  === nothing ? nothing : Vector{Bool}(field._FlagsSurvived),
        field._NAdded         === nothing ? nothing : SizedVector{1}(0),
        field._NOverflow      === nothing ? nothing : SizedVector{1}(0),
    )
end

toBackend(mesh::UnstructuredMeshObject{P}, ::CPU) where {P<:CPU} = mesh

function toBackend(field::UnstructuredMeshObject{P, D, S, DT, NN, PAR, TOPO, AB}, ::CPU) where {P<:GPU, D, S, DT, NN, PAR, TOPO, AB}

    PNew = platform()
    DTNew = DT <: AbstractFloat ? DATATYPE[AbstractFloat] : DT

    p = NamedTuple{keys(field._p)}(
        toBackend(p, CPU()) for p in values(field._p)
    )
    n = initNeighbors(D, field._neighbors, p)
    t = toBackend(field._topology, CPU())
    _FlagOverflow = SizedVector{1}(false)

    PARNew = typeof(p)
    NNNew = typeof(n)
    TOPONew = typeof(t)
    ABNew = typeof(_FlagOverflow)

    UnstructuredMeshObject{PNew, D, S, DTNew, NNNew, PARNew, TOPONew, ABNew}(
        p,
        n,
        t,
        _FlagOverflow
    )
end