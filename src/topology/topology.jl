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
# Topology Structure - Schema only (stored in UnstructuredMesh)
######################################################################################################

"""
    Topology{E, BR, IR}

Stores topological schema (metadata) - no actual data, just the structure.
This is stored in UnstructuredMesh and is NOT passed to GPU kernels.

Type parameters:
- E: Elements type (Set of entity symbols)
- BR: Basic relations type
- IR: Inference table type

Fields:
- _elements: Set of entity symbols (e.g., :n, :e, :c)
- _basicRelations: List of basic relation pairs
- _inferenceTable: Path computation table for traversing relations
"""
struct Topology{E, BR, IR}
    _elements::E
    _basicRelations::BR
    _inferenceTable::IR
end

# Empty topology type
const TopologyEmpty = Topology{Nothing, Nothing, Nothing}

function Topology(::Nothing)
    return TopologyEmpty(nothing, nothing, nothing)
end

######################################################################################################
# TopologyObject Structure - Data only (stored in UnstructuredMeshObject)
######################################################################################################

"""
    TopologyObject{P, R}

Stores topological data (sparse matrices) - this is GPU-compatible.
This is stored in UnstructuredMeshObject and IS passed to GPU kernels.

Type parameters:
- P: Platform type (CPU/GPU)
- R: Relations type (NamedTuple of sparse matrices)

Fields:
- _relations: NamedTuple storing sparse matrices for each relation
"""
struct TopologyObject{P, R}
    _relations::R
end
Adapt.@adapt_structure TopologyObject

# Positional constructor for Adapt.@adapt_structure compatibility
# Infers platform from the relations
function TopologyObject(relations::R) where {R}
    # Infer platform from relations if possible
    P = typeof(CPU())
    if R <: NamedTuple && R !== Nothing
        # Try to get platform from first relation matrix
        for origin_key in keys(relations)
            inner = relations[origin_key]
            for target_key in keys(inner)
                mat = inner[target_key]
                P = typeof(KernelAbstractions.get_backend(mat))
                break
            end
            break
        end
    end
    return TopologyObject{P, R}(relations)
end

# Empty topology object type
const TopologyObjectEmpty = TopologyObject{Nothing, Nothing}

function TopologyObject(::Nothing)
    return TopologyObjectEmpty(nothing)
end

# Allow direct property access: topology.e.n instead of topology._relations.e.n
# Using @generated for GPU compatibility
@generated function Base.getproperty(topology::TopologyObject{P, R}, s::Symbol) where {P, R}
    # Build clauses for internal fields
    general = [
        :(if s === $(QuoteNode(name)); return getfield(topology, $(QuoteNode(name))); end)
        for name in fieldnames(TopologyObject)
    ]
    
    # Build clauses for relation entities (from R type parameter)
    if R <: NamedTuple && R !== Nothing
        relation_keys = R.parameters[1]  # Get keys from NamedTuple type
        cases = [
            :(s === $(QuoteNode(name)) && return getfield(getfield(topology, :_relations), $(QuoteNode(name))))
            for name in relation_keys
        ]
    else
        cases = []
    end
    
    quote
        $(general...)
        $(cases...)
        error("TopologyObject has no entity: $s")
    end
end

# Bracket access: topology[:a, :e] instead of topology.a.e
# Using @generated for GPU compatibility - direct relations are resolved at compile time
@generated function Base.getindex(topology::TopologyObject{P, R}, origin::Symbol, target::Symbol) where {P, R}
    if R <: NamedTuple && R !== Nothing
        origin_keys = R.parameters[1]
        # Build nested cases for each origin -> target pair
        cases = []
        for o_key in origin_keys
            # Get the inner NamedTuple type for this origin
            o_idx = findfirst(==(o_key), origin_keys)
            inner_type = R.parameters[2].parameters[o_idx]
            if inner_type <: NamedTuple
                target_keys = inner_type.parameters[1]
                for t_key in target_keys
                    push!(cases, quote
                        if origin === $(QuoteNode(o_key)) && target === $(QuoteNode(t_key))
                            return getfield(getfield(getfield(topology, :_relations), $(QuoteNode(o_key))), $(QuoteNode(t_key)))
                        end
                    end)
                end
            end
        end
        quote
            $(cases...)
            # Relation not found directly - compute it at runtime (CPU only)
            return _computeDerivedRelation(topology, origin, target)
        end
    else
        quote
            error("TopologyObject has no relations")
        end
    end
end

"""
    _computeDerivedRelation(topology::TopologyObject, origin::Symbol, target::Symbol)

Compute a derived relation (inverse or transitive) at runtime.
This only works on CPU - GPU kernels should only access direct relations.
"""
function _computeDerivedRelation(topology::TopologyObject{P, R}, origin::Symbol, target::Symbol) where {P, R}
    # Find path from origin to target using available relations
    path = _findRelationPath(topology, origin, target)
    
    if isempty(path)
        error("Cannot compute relation $origin -> $target: no path found")
    end
    
    # Compute the relation by following the path
    result = _computeRelationFromPath(topology, path)
    
    # For self-relations (e.g., n->n), remove self-references
    # A node should not be its own neighbor
    if origin == target
        result = _removeSelfReferences(result)
    end
    
    return result
end

"""
    _findRelationPath(topology::TopologyObject, origin::Symbol, target::Symbol)

Find a path of relations from origin to target.
Returns a list of (from, to, :direct/:inverse) tuples.

Uses weighted search preferring paths through lower-dimensional elements:
Nodes < Edges < Faces < Volumes < Agents
"""
function _findRelationPath(topology::TopologyObject{P, R}, origin::Symbol, target::Symbol) where {P, R}
    if R === Nothing
        return []
    end
    
    # Element priority: lower = preferred (prefer going through edges over agents)
    # Standard naming conventions: n=node, e=edge, f=face, v=volume, a=agent
    function element_priority(sym::Symbol)
        s = string(sym)
        if startswith(s, "n")
            return 0  # node
        elseif startswith(s, "e")
            return 1  # edge
        elseif startswith(s, "f")
            return 2  # face
        elseif startswith(s, "v")
            return 3  # volume
        elseif startswith(s, "a")
            return 4  # agent
        else
            return 5  # unknown - lowest priority
        end
    end
    
    # Build graph of available relations (both direct and inverse)
    relations = topology._relations
    edges = Dict{Symbol, Vector{Tuple{Symbol, Symbol, Symbol}}}()  # from -> [(to, actual_from, actual_to)]
    
    for o_key in keys(relations)
        for t_key in keys(relations[o_key])
            # Direct edge
            if !haskey(edges, o_key)
                edges[o_key] = []
            end
            push!(edges[o_key], (t_key, o_key, t_key))
            
            # Inverse edge
            if !haskey(edges, t_key)
                edges[t_key] = []
            end
            push!(edges[t_key], (o_key, o_key, t_key))  # Note: stores original direction
        end
    end
    
    # Priority search to find path with lowest max intermediate priority
    if !haskey(edges, origin)
        return []
    end
    
    # Track best path found and its max priority
    best_path = Tuple{Symbol, Symbol, Symbol}[]
    best_max_priority = typemax(Int)
    
    # For self-relations (origin == target), we need to find a path through intermediate nodes
    # (current_node, path_so_far, is_start, max_priority_so_far, visited_set)
    queue = [(origin, Tuple{Symbol, Symbol, Symbol}[], true, 0, Set{Symbol}())]
    
    while !isempty(queue)
        current, path, is_start, max_priority, visited = popfirst!(queue)
        
        # Only match target if we've taken at least one step (path is non-empty)
        if current == target && !is_start
            if max_priority < best_max_priority || (max_priority == best_max_priority && length(path) < length(best_path))
                best_path = path
                best_max_priority = max_priority
            end
            continue  # Keep searching for potentially better paths
        end
        
        # Skip if we've already found a better path
        if max_priority > best_max_priority
            continue
        end
        
        if haskey(edges, current)
            for (next_node, actual_from, actual_to) in edges[current]
                # Allow returning to origin for self-relations, but not revisiting other nodes
                if next_node ∉ visited || (next_node == origin && next_node == target && !is_start)
                    # Calculate new priority (max of current and intermediate node priority)
                    # For intermediate steps, consider the "bridge" element priority
                    intermediate_priority = element_priority(next_node)
                    new_max_priority = max(max_priority, intermediate_priority)
                    
                    # Skip if this path is already worse than best found
                    if new_max_priority > best_max_priority
                        continue
                    end
                    
                    # Determine if this is direct or inverse
                    direction = (current == actual_from) ? :direct : :inverse
                    new_path = [path..., (actual_from, actual_to, direction)]
                    
                    # Create new visited set for this branch
                    new_visited = copy(visited)
                    if !is_start
                        push!(new_visited, current)
                    end
                    
                    push!(queue, (next_node, new_path, false, new_max_priority, new_visited))
                end
            end
        end
    end
    
    return best_path
end

"""
    _computeRelationFromPath(topology::TopologyObject, path)

Compute a relation matrix by following a path of relations.
"""
function _computeRelationFromPath(topology::TopologyObject, path)
    if isempty(path)
        error("Empty path")
    end
    
    # Start with the first relation
    actual_from, actual_to, direction = path[1]
    mat = topology._relations[actual_from][actual_to]
    
    if direction == :inverse
        result = _transposeToCSR(mat)
    else
        result = _copyToCSR(mat)
    end
    
    # Chain the rest
    for i in 2:length(path)
        actual_from, actual_to, direction = path[i]
        mat = topology._relations[actual_from][actual_to]
        
        if direction == :inverse
            next_mat = _transposeToCSR(mat)
        else
            next_mat = mat
        end
        
        result = _multiplyRelations(result, next_mat)
    end
    
    return result
end

"""
    _transposeToCSR(mat::AbstractSparseMatrix)

Transpose a sparse matrix and return as a new CSR matrix.
The VALUE stored at mat[row, col] is the target index.
The transposed matrix will have: result[target_idx, position] = row (the source row as value).
"""
function _transposeToCSR(mat::AbstractSparseMatrix)
    # Get dimensions - nRows is number of source entities
    nRows = numberOfRows(mat)
    
    # Find max value (target index) to determine result rows
    max_value = 0
    for row in 1:nRows
        for col in iterateRow(mat, row)
            val = mat[row, col]
            if val > 0
                max_value = max(max_value, val)
            end
        end
    end
    
    if max_value == 0
        return dcsr_zeros(Int, 1, 1, 0)
    end
    
    # Count entries per new row (new row = old value = target index)
    new_row_counts = zeros(Int, max_value)
    for old_row in 1:nRows
        for col in iterateRow(mat, old_row)
            val = mat[old_row, col]
            if val > 0
                new_row_counts[val] += 1
            end
        end
    end
    
    # Create CSR with enough space (using dcsr_zeros for simpler array storage)
    result = dcsr_zeros(Int, max_value, new_row_counts, 0)
    
    # Track current position per new row
    current_pos = zeros(Int, max_value)
    
    # Fill in the transposed data
    # For each entry (old_row, col) with value=target_idx,
    # add entry (target_idx, position) with value=old_row
    for old_row in 1:nRows
        for col in iterateRow(mat, old_row)
            target_idx = mat[old_row, col]
            if target_idx > 0
                current_pos[target_idx] += 1
                result[target_idx, current_pos[target_idx]] = old_row
            end
        end
    end
    
    return result
end

"""
    _copyToCSR(mat::AbstractSparseMatrix)

Copy a sparse matrix to a new CSR matrix.
Preserves the values (target indices).
"""
function _copyToCSR(mat::AbstractSparseMatrix)
    nRows = numberOfRows(mat)
    
    # Count entries per row
    row_counts = zeros(Int, nRows)
    for row in 1:nRows
        for col in iterateRow(mat, row)
            val = mat[row, col]
            if val > 0
                row_counts[row] += 1
            end
        end
    end
    
    result = dcsr_zeros(Int, nRows, row_counts, 0)
    
    current_pos = zeros(Int, nRows)
    for row in 1:nRows
        for col in iterateRow(mat, row)
            val = mat[row, col]
            if val > 0
                current_pos[row] += 1
                result[row, current_pos[row]] = val
            end
        end
    end
    
    return result
end

"""
    _multiplyRelations(a::AbstractSparseMatrix, b::AbstractSparseMatrix)

Multiply two relation matrices.
For each row i in a, find all reachable targets in b following the chain:
  a[i, _] = j  -> b[j, _] = k
Result[i, _] = k (the targets reachable via the chain)
"""
function _multiplyRelations(a::AbstractSparseMatrix, b::AbstractSparseMatrix)
    nRowsA = numberOfRows(a)
    
    # For each row of a, find all reachable targets in b
    result_rows = Dict{Int, Vector{Int}}()
    
    for i in 1:nRowsA
        targets = Set{Int}()
        for col_a in iterateRow(a, i)
            j = a[i, col_a]  # Get intermediate target (row in b)
            if j > 0 && j <= numberOfRows(b)
                for col_b in iterateRow(b, j)
                    k = b[j, col_b]  # Get final target
                    if k > 0
                        push!(targets, k)
                    end
                end
            end
        end
        result_rows[i] = collect(targets)
    end
    
    # Create result matrix
    row_counts = [length(get(result_rows, i, Int[])) for i in 1:nRowsA]
    result = dcsr_zeros(Int, nRowsA, row_counts, 0)
    
    for i in 1:nRowsA
        targets = get(result_rows, i, Int[])
        for (pos, target) in enumerate(targets)
            result[i, pos] = target
        end
    end
    
    return result
end

"""
    _removeSelfReferences(mat::AbstractSparseMatrix)

Remove self-references from a relation matrix.
For each row i, removes any entry where the value equals i.
Used for self-relations (e.g., n->n) where a node should not be its own neighbor.
"""
function _removeSelfReferences(mat::AbstractSparseMatrix)
    nRows = numberOfRows(mat)
    
    # Collect filtered entries per row
    result_rows = Dict{Int, Vector{Int}}()
    
    for i in 1:nRows
        targets = Int[]
        for col in iterateRow(mat, i)
            val = mat[i, col]
            # Skip self-references (where value == row)
            if val > 0 && val != i
                push!(targets, val)
            end
        end
        result_rows[i] = targets
    end
    
    # Create result matrix
    row_counts = [length(get(result_rows, i, Int[])) for i in 1:nRows]
    result = dcsr_zeros(Int, nRows, row_counts, 0)
    
    for i in 1:nRows
        targets = get(result_rows, i, Int[])
        for (pos, target) in enumerate(targets)
            result[i, pos] = target
        end
    end
    
    return result
end

######################################################################################################
# Sparse Matrix Type Conversion
######################################################################################################

"""
    _convertToType(mat::AbstractSparseMatrix, targetType::Type)

Convert a sparse matrix to the specified type.
Supported target types:
- DynamicalCSR
- DynamicalELL
- DynamicalOrderedCSR
- DynamicalOrderedELL

If the matrix is already the target type, returns it unchanged.
"""
function _convertToType(mat::AbstractSparseMatrix, targetType::Type)
    # If already the right type, return as-is
    if mat isa targetType
        return mat
    end
    
    # Convert to the target type
    if targetType <: DynamicalELL || targetType == DynamicalELL
        return _convertToELL(mat)
    elseif targetType <: DynamicalOrderedELL || targetType == DynamicalOrderedELL
        return _convertToOrderedELL(mat)
    elseif targetType <: DynamicalOrderedCSR || targetType == DynamicalOrderedCSR
        return _convertToOrderedCSR(mat)
    else
        # Default: keep as CSR (or convert to CSR if needed)
        if mat isa DynamicalCSR
            return mat
        else
            return _copyToCSR(mat)
        end
    end
end

"""
    _convertToELL(mat::AbstractSparseMatrix)

Convert a sparse matrix to DynamicalELL format.
ELL format requires fixed number of columns per row, so we use the maximum row size.
"""
function _convertToELL(mat::AbstractSparseMatrix)
    nRows = numberOfRows(mat)
    
    # Find max entries per row
    maxEntriesPerRow = 0
    for row in 1:nRows
        count = 0
        for col in iterateRow(mat, row)
            if mat[row, col] > 0
                count += 1
            end
        end
        maxEntriesPerRow = max(maxEntriesPerRow, count)
    end
    
    if maxEntriesPerRow == 0
        return dell_zeros(Int, nRows, 1, 0)
    end
    
    # Create ELL matrix
    result = dell_zeros(Int, nRows, maxEntriesPerRow, 0)
    
    # Fill in values
    for row in 1:nRows
        pos = 1
        for col in iterateRow(mat, row)
            val = mat[row, col]
            if val > 0
                result[row, pos] = val
                pos += 1
            end
        end
    end
    
    return result
end

"""
    _convertToOrderedELL(mat::AbstractSparseMatrix)

Convert a sparse matrix to DynamicalOrderedELL format.
"""
function _convertToOrderedELL(mat::AbstractSparseMatrix)
    nRows = numberOfRows(mat)
    
    # Find max entries per row
    maxEntriesPerRow = 0
    for row in 1:nRows
        count = 0
        for col in iterateRow(mat, row)
            if mat[row, col] > 0
                count += 1
            end
        end
        maxEntriesPerRow = max(maxEntriesPerRow, count)
    end
    
    if maxEntriesPerRow == 0
        return doell_zeros(Int, nRows, 1, 0)
    end
    
    # Create Ordered ELL matrix
    result = doell_zeros(Int, nRows, maxEntriesPerRow, 0)
    
    # Fill in values using append for ordering
    for row in 1:nRows
        pos = 1
        for col in iterateRow(mat, row)
            val = mat[row, col]
            if val > 0
                append!(result, row, pos, val)
                pos += 1
            end
        end
    end
    
    synchronize(result)
    return result
end

"""
    _convertToOrderedCSR(mat::AbstractSparseMatrix)

Convert a sparse matrix to DynamicalOrderedCSR format.
"""
function _convertToOrderedCSR(mat::AbstractSparseMatrix)
    nRows = numberOfRows(mat)
    
    # Count entries per row
    row_counts = zeros(Int, nRows)
    for row in 1:nRows
        for col in iterateRow(mat, row)
            if mat[row, col] > 0
                row_counts[row] += 1
            end
        end
    end
    
    # Create Ordered CSR matrix
    result = docsr_zeros(Int, nRows, row_counts, 0)
    
    # Fill in values using append for ordering
    for row in 1:nRows
        pos = 1
        for col in iterateRow(mat, row)
            val = mat[row, col]
            if val > 0
                append!(result, row, pos, val)
                pos += 1
            end
        end
    end
    
    synchronize(result)
    return result
end

"""
    Topology(mes_properties::NamedTuple)

Build a schema-only Topology from mesh properties.
This is used when creating the UnstructuredMesh schema.
"""
function Topology(mes_properties::NamedTuple)
    entities, basicRelations, inferenceTable = buildTopologySchema(mes_properties)
    
    if isnothing(entities)
        return Topology(nothing)
    end
    
    E = typeof(entities)
    BR = typeof(basicRelations)
    IR = typeof(inferenceTable)
    
    return Topology{E, BR, IR}(entities, basicRelations, inferenceTable)
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
    buildTopologyObject(schemaTopology::Topology, kwargs::Base.Pairs, params::NamedTuple; requiredRelations)

Build a TopologyObject with sparse matrices from a schema-only Topology and kwargs.
This is used when creating UnstructuredMeshObject from UnstructuredMesh.

Args:
- schemaTopology: Schema-only Topology from UnstructuredMesh
- kwargs: Keyword arguments containing sparse matrices for each relation
- params: NamedTuple of UnstructuredMeshField objects (unused but kept for compatibility)
- requiredRelations: Set of (origin, target) pairs that need to be precomputed

Returns:
- TopologyObject with sparse matrix data, or TopologyObjectEmpty if no relations
"""
function buildTopologyObject(schemaTopology::Topology{E, BR, IR}, kwargs::Base.Pairs, params::NamedTuple; requiredRelations=Set{Tuple{Symbol,Symbol}}(), requiredRelationTypes=Dict{Tuple{Symbol,Symbol},Type}()) where {E, BR, IR}
    if schemaTopology._elements === nothing
        return TopologyObject(nothing)
    end
    
    basicRelations = schemaTopology._basicRelations
    basicRelationsSet = Set(basicRelations)
    
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
        return TopologyObject(nothing)
    end
    
    origin_keys = Tuple(sort(collect(keys(nested_dict))))
    inner_nts = [begin
        targets = nested_dict[k]
        target_keys = Tuple(sort(collect(keys(targets))))
        NamedTuple{target_keys}(Tuple(targets[tk] for tk in target_keys))
    end for k in origin_keys]
    relations = NamedTuple{origin_keys}(Tuple(inner_nts))
    
    P = typeof(CPU())  # Default platform
    R = typeof(relations)
    
    # Create initial topology object
    topoObj = TopologyObject{P, R}(relations)
    
    # Precompute required derived relations (inverse/transitive that are not basic)
    derivedToCompute = [(o, t) for (o, t) in requiredRelations if (o, t) ∉ basicRelationsSet]
    
    if !isempty(derivedToCompute)
        # Create a mutable version to add derived relations
        extended_dict = Dict{Symbol, Dict{Symbol, AbstractSparseMatrix}}()
        for k in keys(nested_dict)
            extended_dict[k] = copy(nested_dict[k])
        end
        
        # Compute each required derived relation
        for (origin, target) in derivedToCompute
            # Use the current topoObj to compute derived relations
            derived_mat = _computeDerivedRelation(topoObj, origin, target)
            
            # Convert to requested type if specified
            if haskey(requiredRelationTypes, (origin, target))
                targetType = requiredRelationTypes[(origin, target)]
                derived_mat = _convertToType(derived_mat, targetType)
            end
            
            if !haskey(extended_dict, origin)
                extended_dict[origin] = Dict{Symbol, AbstractSparseMatrix}()
            end
            extended_dict[origin][target] = derived_mat
        end
        
        # Rebuild the NamedTuple with the extended relations
        new_origin_keys = Tuple(sort(collect(keys(extended_dict))))
        new_inner_nts = [begin
            targets = extended_dict[k]
            target_keys = Tuple(sort(collect(keys(targets))))
            NamedTuple{target_keys}(Tuple(targets[tk] for tk in target_keys))
        end for k in new_origin_keys]
        new_relations = NamedTuple{new_origin_keys}(Tuple(new_inner_nts))
        
        R_new = typeof(new_relations)
        return TopologyObject{P, R_new}(new_relations)
    end
    
    return topoObj
end

# Handle empty topology
function buildTopologyObject(::TopologyEmpty, kwargs::Base.Pairs, params::NamedTuple; requiredRelations=Set{Tuple{Symbol,Symbol}}(), requiredRelationTypes=Dict{Tuple{Symbol,Symbol},Type}())
    return TopologyObject(nothing)
end

# Backwards compatibility alias
buildTopology(t::Topology, k::Base.Pairs, p::NamedTuple; requiredRelations=Set{Tuple{Symbol,Symbol}}(), requiredRelationTypes=Dict{Tuple{Symbol,Symbol},Type}()) = buildTopologyObject(t, k, p; requiredRelations=requiredRelations, requiredRelationTypes=requiredRelationTypes)

######################################################################################################
# TopologyObject accessors and utilities
######################################################################################################

"""
    getrelation(topology::TopologyObject, origin::Symbol, target::Symbol)

Get the sparse matrix for the relation from origin to target.
"""
function getrelation(topology::TopologyObject, origin::Symbol, target::Symbol)
    if topology._relations === nothing
        error("TopologyObject has no relation data")
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
    hasrelation(topology::TopologyObject, origin::Symbol, target::Symbol)

Check if a direct relation exists from origin to target.
"""
function hasrelation(topology::TopologyObject, origin::Symbol, target::Symbol)
    if topology._relations === nothing
        return false
    end
    return haskey(topology._relations, origin) && haskey(topology._relations[origin], target)
end

######################################################################################################
# Topology (schema) accessors
######################################################################################################

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

function Base.show(io::IO, topology::Topology{E, BR, IR}) where {E, BR, IR}
    println(io, "Topology (schema)")
    if topology._elements !== nothing
        println(io, "  Entities: ", join(topology._elements, ", "))
        println(io, "  Basic relations:")
        for (origin, target) in topology._basicRelations
            println(io, "    $origin -> $target")
        end
    else
        println(io, "  (empty)")
    end
end

function Base.show(io::IO, ::TopologyEmpty)
    println(io, "Topology (empty)")
end

function Base.show(io::IO, topology::TopologyObject{P, R}) where {P, R}
    println(io, "TopologyObject{$P}")
    if topology._relations !== nothing
        for origin in keys(topology._relations)
            for target in keys(topology._relations[origin])
                mat = topology._relations[origin][target]
                println(io, "  $origin -> $target : $(typeof(mat).name.name) with $(numberOfEntries(mat)) entries")
            end
        end
    else
        println(io, "  (empty)")
    end
end

function Base.show(io::IO, ::TopologyObjectEmpty)
    println(io, "TopologyObject (empty)")
end

######################################################################################################
# Platform adaptation for TopologyObject
######################################################################################################

KernelAbstractions.get_backend(::TopologyObject{P}) where {P} = P()

toBackend(topology::TopologyObjectEmpty, ::Any) = topology
toBackend(topology::TopologyObjectEmpty, ::KernelAbstractions.GPU) = topology
toBackend(topology::TopologyObjectEmpty, ::KernelAbstractions.CPU) = topology  # Fix ambiguity

toBackend(topology::TopologyObject{P}, ::KernelAbstractions.CPU) where {P<:Type{<:KernelAbstractions.CPU}} = topology

function toBackend(topology::TopologyObject{P, R}, ::KernelAbstractions.CPU) where {P, R}
    # Convert all sparse matrices to CPU
    new_relations = _convertRelations(topology._relations, CPU())
    
    TopologyObject{typeof(CPU()), typeof(new_relations)}(new_relations)
end

toBackend(topology::TopologyObject{P}, ::KernelAbstractions.GPU) where {P<:KernelAbstractions.GPU} = topology

function toBackend(topology::TopologyObject{P, R}, backend::KernelAbstractions.GPU) where {P, R}
    # Convert all sparse matrices to GPU
    new_relations = _convertRelations(topology._relations, backend)
    
    TopologyObject{typeof(backend), typeof(new_relations)}(new_relations)
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
    iterateOverNeighbors(topology::TopologyObject, from::Symbol, to::Symbol, idx::Int)

Iterate over the neighbors of entity `idx` in the relation from `from` to `to`.
Returns an iterator over neighbor_idx values.
"""
function iterateOverNeighbors(topology::TopologyObject, from::Symbol, to::Symbol, idx::Int)
    mat = getrelation(topology, from, to)
    return iterateRow(mat, idx)
end

######################################################################################################
# Validation
######################################################################################################

"""
    validateTopologyObject(schema::Topology, topoObj::TopologyObject, elementCounts::Dict{Symbol, Int})

Validate that all sparse matrix entries reference valid elements.
"""
function validateTopologyObject(schema::Topology, topoObj::TopologyObject, elementCounts::Dict{Symbol, Int})
    for (origin, target) in schema._basicRelations
        if !hasrelation(topoObj, origin, target)
            continue
        end
        
        mat = getrelation(topoObj, origin, target)
        target_count = get(elementCounts, target, 0)
        
        # Check all entries in the sparse matrix
        for row in 1:numberOfRows(mat)
            for col in iterateRow(mat, row)
                val = mat[row, col]  # Get the actual target index
                if val < 1 || val > target_count
                    error("Invalid reference in relation $origin -> $target: " *
                          "element $row references $target element $val, but only $target_count exist")
                end
            end
        end
    end
    return true
end
