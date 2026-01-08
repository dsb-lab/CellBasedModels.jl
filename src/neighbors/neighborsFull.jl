struct NeighborsFull{P, UM, PT, AB} <: AbstractNeighbors 

    u::UM
    permTable::PT
    auxBuffers::AB  # Auxiliary buffers for each property to enable non-allocating compaction

end
Adapt.@adapt_structure NeighborsFull

NeighborsFull() = NeighborsFull(nothing, nothing, nothing)

function NeighborsFull(
    mesh,
    neighbors,
    auxBuffers=nothing,
)

    P = platform()
    NeighborsFull{P, typeof(mesh), typeof(neighbors), typeof(auxBuffers)}(mesh, neighbors, auxBuffers)

end

function initNeighbors(
        ::Int,
        ::NeighborsFull,
        meshParameters::NamedTuple
    )

    permTable = Dict()
    
    # Find the maximum cache size across all properties
    maxCacheSize = 0
    for (name, prop) in pairs(meshParameters)
        maxCacheSize = max(maxCacheSize, lengthCache(prop))
    end
    
    # Create one reusable buffer per element type across all properties and fields
    typeBuffers = Dict()
    
    for (name, prop) in pairs(meshParameters)
        permTable[name] = zeros(Int, lengthCache(prop))
        
        # Create or reuse buffer for each field based on its element type
        for (fieldname, field) in pairs(prop._p)
            elemType = eltype(field)
            if !haskey(typeBuffers, elemType)
                typeBuffers[elemType] = similar(field, maxCacheSize)
            end
        end
    end
    
    # Map each property's fields to their corresponding type buffer
    auxBuffers = Dict()
    for (name, prop) in pairs(meshParameters)
        auxBuffers[name] = NamedTuple{fieldnames(typeof(prop._p))}(
            [typeBuffers[eltype(prop._p[fname])] for fname in fieldnames(typeof(prop._p))]
        )
    end

    permTableNamed = NamedTuple{tuple(keys(permTable)...)}(values(permTable))
    auxBuffersNamed = NamedTuple{tuple(keys(auxBuffers)...)}(values(auxBuffers))

    NeighborsFull{platform(), typeof(meshParameters), typeof(permTableNamed), typeof(auxBuffersNamed)}(meshParameters, permTableNamed, auxBuffersNamed)

end

function update!(mesh::UnstructuredMeshObject{P, D, S, DT, NN, PAR}) where {P, D, S, DT, NN<:NeighborsFull, PAR}

    # Compaction
    for (name, prop) in pairs(mesh._p)
        NAddedNew = lengthPropertiesNew(prop)
        NNew = fillPermTable!(mesh._neighbors.permTable[name], prop._FlagsSurvived, NAddedNew)
        compactUnstructuredMeshField!(mesh._p[name], mesh._neighbors.permTable[name], mesh._neighbors.auxBuffers[name], NNew)
    end

    # println("P: ", mesh._neighbors.permTable[:n])

    renameElements!(mesh)

end

function fillPermTable!(perm, flags, N)

    count = 1
    @inbounds for i in 1:N
        if flags[i]
            perm[i] = count
            count += 1
        else
            perm[i] = 0
        end
        #reset flags
        flags[i] = true
    end
    return count - 1

end

function iterateOverNeighbors(mesh::UnstructuredMeshObject{P, D, S, DT, NN}, symbol::Symbol, index::Int) where {P, D, S, DT, NN<:NeighborsFull}

    return 1:lengthProperties(mesh._p[symbol])

end

function iterateOverNeighbors(mesh::UnstructuredMeshObject{P, D, S, DT, NN}, symbol::Symbol, ::Any) where {P, D, S, DT, NN<:NeighborsFull}

    return 1:lengthProperties(mesh._p[symbol])

end

function iterateOverNeighbors(mesh::UnstructuredMeshObject{P, D, S, DT, NN}, symbol::Symbol, ::Any, ::Any) where {P, D, S, DT, NN<:NeighborsFull}

    return 1:lengthProperties(mesh._p[symbol])

end

function iterateOverNeighbors(mesh::UnstructuredMeshObject{P, D, S, DT, NN}, symbol::Symbol, ::Any, ::Any, ::Any) where {P, D, S, DT, NN<:NeighborsFull}

    return 1:lengthProperties(mesh._p[symbol])

end

function getNeighbors(mesh::UnstructuredMeshObject{P, D, S, DT, NN}, symbol::Symbol, index::Int) where {P, D, S, DT, NN<:NeighborsFull}

    return collect(iterateOverNeighbors(mesh, symbol, index))

end


