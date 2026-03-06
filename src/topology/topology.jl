######################################################################################################
# Topology - Contains both schema and sparse matrix relations
######################################################################################################

"""
    getAllEntities(pairs)

Extract all unique entity symbols from a list of relation pairs.
"""
function getAllEntities(pairs)
    entities = Set{Symbol}()
    for (origin, target) in pairs
        push!(entities, origin)
        push!(entities, target)
    end
    return entities
end

"""
    allShortestPaths(pairs)

Compute all shortest paths between entities using the given relation pairs.
Returns a nested dictionary: origin -> target -> path
where path is a tuple of (from, to, direction) triples.
"""
function allShortestPaths(pairs)
    s = getAllEntities(pairs)
    all_paths = Dict{Tuple{Symbol, Symbol}, Tuple}()
    
    # Initialize with direct relations
    for (origin, target) in pairs
        all_paths[(origin, target)] = ((origin, target, :d),)
    end
    
    # Find paths using direct relations
    l = length(all_paths)
    l_new = 0
    while l != l_new
        l = length(all_paths)
        for origin in s
            for target in s
                if (origin, target) ∉ keys(all_paths) && origin != target
                    for intermediate in s
                        if (origin, intermediate) in keys(all_paths) && (intermediate, target) in keys(all_paths)
                            all_paths[(origin, target)] = (all_paths[(origin, intermediate)]..., all_paths[(intermediate, target)]...)
                        end
                    end
                end
            end
        end
        l_new = length(all_paths)
    end
    
    # Add inverse relations
    for (origin, target) in pairs
        if !haskey(all_paths, (target, origin))
            all_paths[(target, origin)] = ((target, origin, :i),)
        end
    end
    
    # Find paths including inverse relations
    l = length(all_paths)
    l_new = 0
    while l != l_new
        l = length(all_paths)
        for origin in s
            for target in s
                if (origin, target) ∉ keys(all_paths) && origin != target
                    for intermediate in s
                        if (origin, intermediate) in keys(all_paths) && (intermediate, target) in keys(all_paths)
                            all_paths[(origin, target)] = (all_paths[(origin, intermediate)]..., all_paths[(intermediate, target)]...)
                        end
                    end
                end
            end
        end
        l_new = length(all_paths)
    end

    # Convert to nested dictionary
    nested_dict = Dict{Symbol, Dict{Symbol, Tuple}}()
    for ((origin, target), path) in all_paths
        if !haskey(nested_dict, origin)
            nested_dict[origin] = Dict{Symbol, Tuple}()
        end
        nested_dict[origin][target] = path
    end
    
    return nested_dict
end

"""
    isConnected(pairs)

Check if all entities can reach each other through the given relations.
"""
function isConnected(pairs)
    entities = getAllEntities(pairs)
    paths = allShortestPaths(pairs)
    lpaths = sum(length(v) for v in values(paths))
    return length(entities)^2 - length(entities) == lpaths
end

######################################################################################################
# Topology Structure - Contains schema and sparse matrix data
######################################################################################################

"""
    Topology{P, E, BR, IR, R}

Stores topological relationships using sparse matrices.

Type parameters:
- P: Platform type (CPU/GPU)
- E: Elements type (Set of entity symbols)
- BR: Basic relations type
- IR: Inference table type
- R: Relations type (NamedTuple of sparse matrices)

Fields:
- _elements: Set of entity symbols (e.g., :n, :e, :c)
- _basicRelations: List of basic relation pairs
- _inferenceTable: Path computation table for traversing relations
- _relations: NamedTuple storing sparse matrices for each relation
"""
struct Topology{P, E, BR, IR, R}
    _elements::E
    _basicRelations::BR
    _inferenceTable::IR
    _relations::R
end
Adapt.@adapt_structure Topology

# Empty topology type
const TopologyEmpty = Topology{Nothing, Nothing, Nothing, Nothing, Nothing}

function Topology(::Nothing)
    return TopologyEmpty(nothing, nothing, nothing, nothing)
end

"""
    Topology(mes_properties::NamedTuple)

Build a schema-only Topology (without sparse matrix data) from mesh properties.
This is used when creating the UnstructuredMesh schema.
"""
function Topology(mes_properties::NamedTuple)
    entities, basicRelations, inferenceTable = buildTopologySchema(mes_properties)
    
    if isnothing(entities)
        return Topology(nothing)
    end
    
    P = typeof(CPU())
    E = typeof(entities)
    BR = typeof(basicRelations)
    IR = typeof(inferenceTable)
    
    # Schema-only: no relations stored yet
    return Topology{P, E, BR, IR, Nothing}(entities, basicRelations, inferenceTable, nothing)
end

######################################################################################################
# Build Topology from mesh properties
######################################################################################################

"""
    extractBasicRelations(mes_properties::NamedTuple)

Extract basic relations from mesh property definitions.
Returns a list of (origin, target) tuples.
"""
function extractBasicRelations(mes_properties::NamedTuple)
    list = Tuple{Symbol, Symbol}[]
    for (name, prop) in pairs(mes_properties)
        if prop isa Edge
            push!(list, (name, prop.c))
        elseif prop isa Face
            push!(list, (name, prop.c))
        elseif prop isa Volume
            push!(list, (name, prop.c))
        elseif prop isa Agent
            for connected in prop.cs
                push!(list, (name, connected))
            end
        end
    end
    return list
end

"""
    buildTopologySchema(mes_properties::NamedTuple)

Build the topology schema (without data) from mesh properties.
"""
function buildTopologySchema(mes_properties::NamedTuple)
    basicRelations = extractBasicRelations(mes_properties)
    
    if isempty(basicRelations)
        return nothing, nothing, nothing
    end
    
    if !isConnected(basicRelations)
        error("The basic relations derived from the mesh structure are not fully connected. Please check the mesh definition.")
    end
    
    entities = getAllEntities(basicRelations)
    inferenceTable = allShortestPaths(tuple(basicRelations...))
    
    return entities, basicRelations, inferenceTable
end

"""
    Topology(mes_properties::NamedTuple, kwargs::Base.Pairs)

Build a Topology with sparse matrices from mesh properties and relation data.

The kwargs should contain:
- For each entity with relations: the sparse matrix or NamedTuple of sparse matrices

Example:
    Topology(mesh._p, (n=10, e=dcsr_zeros(...), c=(n=dcsr_zeros(...), e=dcsr_zeros(...))))
"""
function Topology(
    mes_properties::NamedTuple,
    kwargs::Base.Pairs
)
    # Build schema
    entities, basicRelations, inferenceTable = buildTopologySchema(mes_properties)
    
    if isnothing(entities)
        return Topology(nothing)
    end
    
    # Extract sparse matrices for each basic relation from kwargs
    relations_dict = Dict{Tuple{Symbol, Symbol}, AbstractSparseMatrix}()
    
    for (origin, target) in basicRelations
        # Get the data for this origin entity
        if !haskey(kwargs, origin)
            error("Missing topology data for relation $origin -> $target")
        end
        
        origin_data = kwargs[origin]
        
        if origin_data isa AbstractSparseMatrix
            # Single connection (Edge, Face, Volume, or Agent with one connection)
            relations_dict[(origin, target)] = origin_data
        elseif origin_data isa NamedTuple
            # Multiple connections (Agent with multiple connections)
            if !haskey(origin_data, target)
                error("Missing sparse matrix for relation $origin -> $target in NamedTuple")
            end
            relations_dict[(origin, target)] = origin_data[target]
        elseif origin_data isa Number || origin_data isa Tuple
            # Node - no outgoing relations to store
            continue
        else
            error("Invalid data type for relation $origin -> $target: $(typeof(origin_data))")
        end
    end
    
    # Convert to nested NamedTuple: origin -> target -> sparse_matrix
    nested_dict = Dict{Symbol, Dict{Symbol, AbstractSparseMatrix}}()
    for ((origin, target), matrix) in relations_dict
        if !haskey(nested_dict, origin)
            nested_dict[origin] = Dict{Symbol, AbstractSparseMatrix}()
        end
        nested_dict[origin][target] = matrix
    end
    
    # Convert to NamedTuple
    if isempty(nested_dict)
        return Topology(nothing)
    end
    
    origin_keys = Tuple(sort(collect(keys(nested_dict))))
    inner_nts = [begin
        targets = nested_dict[k]
        target_keys = Tuple(sort(collect(keys(targets))))
        NamedTuple{target_keys}(Tuple(targets[tk] for tk in target_keys))
    end for k in origin_keys]
    relations = NamedTuple{origin_keys}(Tuple(inner_nts))
    
    P = typeof(CPU())  # Default platform
    E = typeof(entities)
    BR = typeof(basicRelations)
    IR = typeof(inferenceTable)
    R = typeof(relations)
    
    return Topology{P, E, BR, IR, R}(entities, basicRelations, inferenceTable, relations)
end

"""
    buildTopology(schemaTopology::Topology, kwargs::Base.Pairs, params::NamedTuple)

Build a full Topology with sparse matrices from a schema-only Topology and kwargs.
This is used when creating UnstructuredMeshObject from UnstructuredMesh.

Args:
- schemaTopology: Schema-only Topology from UnstructuredMesh
- kwargs: Keyword arguments containing sparse matrices for each relation
- params: NamedTuple of UnstructuredMeshField objects (unused but kept for compatibility)

Returns:
- Topology with sparse matrix data, or TopologyEmpty if no relations
"""
function buildTopology(schemaTopology::Topology{P, E, BR, IR, Nothing}, kwargs::Base.Pairs, params::NamedTuple) where {P, E, BR, IR}
    # Schema-only topology - need to build with data
    if schemaTopology._elements === nothing
        return Topology(nothing)
    end
    
    basicRelations = schemaTopology._basicRelations
    entities = schemaTopology._elements
    inferenceTable = schemaTopology._inferenceTable
    
    # Extract sparse matrices for each basic relation from kwargs
    relations_dict = Dict{Tuple{Symbol, Symbol}, AbstractSparseMatrix}()
    
    for (origin, target) in basicRelations
        # Get the data for this origin entity
        if !haskey(kwargs, origin)
            error("Missing topology data for relation $origin -> $target")
        end
        
        origin_data = kwargs[origin]
        
        if origin_data isa AbstractSparseMatrix
            # Single connection (Edge, Face, Volume, or Agent with one connection)
            relations_dict[(origin, target)] = origin_data
        elseif origin_data isa NamedTuple
            # Multiple connections (Agent with multiple connections)
            if !haskey(origin_data, target)
                error("Missing sparse matrix for relation $origin -> $target in NamedTuple")
            end
            relations_dict[(origin, target)] = origin_data[target]
        elseif origin_data isa Number || origin_data isa Tuple
            # Node - no outgoing relations stored
            continue
        else
            error("Invalid data type for relation $origin -> $target: $(typeof(origin_data))")
        end
    end
    
    # Convert to nested NamedTuple: origin -> target -> sparse_matrix
    nested_dict = Dict{Symbol, Dict{Symbol, AbstractSparseMatrix}}()
    for ((o, t), matrix) in relations_dict
        if !haskey(nested_dict, o)
            nested_dict[o] = Dict{Symbol, AbstractSparseMatrix}()
        end
        nested_dict[o][t] = matrix
    end
    
    # Convert to NamedTuple
    if isempty(nested_dict)
        return Topology(nothing)
    end
    
    origin_keys = Tuple(sort(collect(keys(nested_dict))))
    inner_nts = [begin
        targets = nested_dict[k]
        target_keys = Tuple(sort(collect(keys(targets))))
        NamedTuple{target_keys}(Tuple(targets[tk] for tk in target_keys))
    end for k in origin_keys]
    relations = NamedTuple{origin_keys}(Tuple(inner_nts))
    
    NewP = typeof(CPU())
    NewE = typeof(entities)
    NewBR = typeof(basicRelations)
    NewIR = typeof(inferenceTable)
    NewR = typeof(relations)
    
    return Topology{NewP, NewE, NewBR, NewIR, NewR}(entities, basicRelations, inferenceTable, relations)
end

# Handle already-complete topology (shouldn't happen, but for safety)
function buildTopology(topology::Topology{P, E, BR, IR, R}, kwargs::Base.Pairs, params::NamedTuple) where {P, E, BR, IR, R}
    # Topology already has relations, just return it
    return topology
end

# Handle empty topology
function buildTopology(::TopologyEmpty, kwargs::Base.Pairs, params::NamedTuple)
    return Topology(nothing)
end

######################################################################################################
# Topology accessors and utilities
######################################################################################################

"""
    getrelation(topology::Topology, origin::Symbol, target::Symbol)

Get the sparse matrix for the relation from origin to target.
"""
function getrelation(topology::Topology, origin::Symbol, target::Symbol)
    if topology._relations === nothing
        error("Topology has no relation data (schema-only)")
    end
    if !haskey(topology._relations, origin)
        error("No relations from entity: $origin")
    end
    if !haskey(topology._relations[origin], target)
        error("No relation from $origin to $target")
    end
    return topology._relations[origin][target]
end

"""
    hasrelation(topology::Topology, origin::Symbol, target::Symbol)

Check if a direct relation exists from origin to target.
"""
function hasrelation(topology::Topology, origin::Symbol, target::Symbol)
    if topology._relations === nothing
        return false
    end
    return haskey(topology._relations, origin) && haskey(topology._relations[origin], target)
end

"""
    getpath(topology::Topology, origin::Symbol, target::Symbol)

Get the inference path from origin to target.
Returns a tuple of (from, to, direction) triples.
"""
function getpath(topology::Topology, origin::Symbol, target::Symbol)
    if !haskey(topology._inferenceTable, origin)
        error("No paths from entity: $origin")
    end
    if !haskey(topology._inferenceTable[origin], target)
        error("No path from $origin to $target")
    end
    return topology._inferenceTable[origin][target]
end

"""
    entities(topology::Topology)

Get the set of entity symbols in the topology.
"""
entities(topology::Topology) = topology._elements
entities(::TopologyEmpty) = Set{Symbol}()

"""
    basicRelations(topology::Topology)

Get the list of basic relation pairs.
"""
basicRelations(topology::Topology) = topology._basicRelations
basicRelations(::TopologyEmpty) = Tuple{Symbol, Symbol}[]

######################################################################################################
# Show methods
######################################################################################################

function Base.show(io::IO, topology::Topology{P, E, BR, IR, R}) where {P, E, BR, IR, R}
    println(io, "Topology{$P}")
    println(io, "  Entities: ", join(topology._elements, ", "))
    println(io, "  Basic relations:")
    for (origin, target) in topology._basicRelations
        print(io, "    $origin -> $target")
        if hasrelation(topology, origin, target)
            mat = getrelation(topology, origin, target)
            println(io, " : $(typeof(mat).name.name) with $(numberOfEntries(mat)) entries")
        else
            println(io)
        end
    end
end

function Base.show(io::IO, ::TopologyEmpty)
    println(io, "Topology (empty)")
end

######################################################################################################
# Platform adaptation
######################################################################################################

KernelAbstractions.get_backend(topology::Topology{P}) where {P} = P()

toBackend(topology::TopologyEmpty, ::Any) = topology

toBackend(topology::Topology{P}, ::KernelAbstractions.CPU) where {P<:Type{<:KernelAbstractions.CPU}} = topology

# Handle schema-only topology (R = Nothing)
function toBackend(topology::Topology{P, E, BR, IR, Nothing}, ::KernelAbstractions.CPU) where {P, E, BR, IR}
    return topology  # Nothing to convert
end

function toBackend(topology::Topology{P, E, BR, IR, Nothing}, backend::KernelAbstractions.GPU) where {P, E, BR, IR}
    return topology  # Schema-only, nothing to convert
end

function toBackend(topology::Topology{P, E, BR, IR, R}, ::KernelAbstractions.CPU) where {P, E, BR, IR, R}
    # Convert all sparse matrices to CPU
    new_relations = _convertRelations(topology._relations, CPU())
    
    Topology{typeof(CPU()), E, BR, IR, typeof(new_relations)}(
        topology._elements,
        topology._basicRelations,
        topology._inferenceTable,
        new_relations
    )
end

toBackend(topology::Topology{P}, ::KernelAbstractions.GPU) where {P<:KernelAbstractions.GPU} = topology

function toBackend(topology::Topology{P, E, BR, IR, R}, backend::KernelAbstractions.GPU) where {P, E, BR, IR, R}
    # Convert all sparse matrices to GPU
    new_relations = _convertRelations(topology._relations, backend)
    
    Topology{typeof(backend), E, BR, IR, typeof(new_relations)}(
        topology._elements,
        topology._basicRelations,
        topology._inferenceTable,
        new_relations
    )
end

"""
    _convertRelations(relations::NamedTuple, backend)

Convert all sparse matrices in the relations NamedTuple to the given backend.
"""
function _convertRelations(relations::NamedTuple, backend)
    origin_keys = keys(relations)
    new_inner = []
    for origin in origin_keys
        targets = relations[origin]
        target_keys = keys(targets)
        new_matrices = [toBackend(backend, targets[tk]) for tk in target_keys]
        push!(new_inner, NamedTuple{target_keys}(Tuple(new_matrices)))
    end
    return NamedTuple{origin_keys}(Tuple(new_inner))
end

_convertRelations(::Nothing, _) = nothing

######################################################################################################
# Iteration support
######################################################################################################

"""
    iterateOverNeighbors(topology::Topology, from::Symbol, to::Symbol, idx::Int)

Iterate over the neighbors of entity `idx` in the relation from `from` to `to`.
Returns an iterator over (neighbor_idx, value) pairs.
"""
function iterateOverNeighbors(topology::Topology, from::Symbol, to::Symbol, idx::Int)
    mat = getrelation(topology, from, to)
    return iterateRow(mat, idx)
end

######################################################################################################
# Validation
######################################################################################################

"""
    validateTopology(topology::Topology, elementCounts::Dict{Symbol, Int})

Validate that all sparse matrix entries reference valid elements.
"""
function validateTopology(topology::Topology, elementCounts::Dict{Symbol, Int})
    for (origin, target) in topology._basicRelations
        if !hasrelation(topology, origin, target)
            continue
        end
        
        mat = getrelation(topology, origin, target)
        target_count = get(elementCounts, target, 0)
        
        # Check all entries in the sparse matrix
        for row in 1:numberOfRows(mat)
            for (col, val) in iterateRow(mat, row)
                if col < 1 || col > target_count
                    error("Invalid reference in relation $origin -> $target: " *
                          "element $row references $target element $col, but only $target_count exist")
                end
            end
        end
    end
    return true
end
