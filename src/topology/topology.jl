function getAllEntities(pairs)
    entities = Set{Symbol}()
    for (origin, target) in pairs
        push!(entities, origin)
        push!(entities, target)
    end
    return entities
end

function allShortestPaths(pairs)

    s = getAllEntities(pairs)
    all_paths = Dict{Tuple{Symbol, Symbol}, Tuple}()
    for (origin, target) in pairs
        all_paths[(origin, target)] = ((origin, target, :d),)
    end
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
    for (origin, target) in pairs
        if !haskey(all_paths, (target, origin))
            all_paths[(target, origin)] = ((target, origin, :i),)
        end
    end
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

    # Convert dictionary to nested named tuple
    # Structure: origin -> target -> path
    nested_dict = Dict{Symbol, Dict{Symbol, Tuple}}()
    for ((origin, target), path) in all_paths
        if !haskey(nested_dict, origin)
            nested_dict[origin] = Dict{Symbol, Tuple}()
        end
        nested_dict[origin][target] = path
    end
        
    return nested_dict

end

function isConnected(pairs)

    entities = getAllEntities(pairs)
    paths = allShortestPaths(pairs)
    lpaths = sum(length(v) for v in values(paths))
    length(entities)^2 - length(entities) == lpaths

end

struct Topology{P, RB, RA, RI}
    _elements::P
    _basicRelations::RB
    _directRelations::RA
    _inferenceTable::RI
end

function Topology(
    mes_properties::NamedTuple; 
)
    # Build basic relations from mesh structure (schema only)
    # basic_pairs = buildBasicRelations(mesh, meshType)
    list = []
    for (n,s) in pairs(mes_properties)
        if s isa Edge
            push!(list, (n, s.c))
        elseif s isa Face
            push!(list, (n, s.c))
        elseif s isa Volume
            push!(list, (n, s.c))
        elseif s isa Agent
            for i in s.cs
                push!(list, (n, i))
            end
        end
    end
    basicRelations = list
    if !isConnected(basicRelations)
        error("The basic relations derived from the mesh structure are not fully connected. Please check the mesh definition.")
    end

    entities = getAllEntities(basicRelations)

    directRelations = copy(basicRelations)

    inference_table = allShortestPaths(tuple(directRelations...))    

    P = typeof(entities)
    RB = typeof(basicRelations)
    RA = typeof(directRelations)
    RI = typeof(inference_table)
    
    return Topology{P, RB, RA, RI}(entities, basicRelations, directRelations, inference_table)
end

function addRelations!(
    topology::Topology{P, RB, RA, RI}, 
    newRelations::Tuple{Vararg{Tuple{Symbol, Symbol}}}
) where {P, RB, RA, RI}

    for (origin, target) in newRelations
        if !(origin in topology._elements) || !(target in topology._elements)
            error("Cannot add relation ($origin, $target): one or both entities are not present in the topology.")
        end
    end

    pruned_new_relations = [
        (origin, target) for (origin, target) in newRelations 
        if !( (origin, target) in topology._directRelations )
    ]

    # Combine existing direct relations with new ones
    append!(topology._directRelations, pruned_new_relations)
    
    new_inference_table = allShortestPaths(topology._directRelations)
    for (k,e) in pairs(new_inference_table)
        if !(haskey(topology._inferenceTable, k))
            topology._inferenceTable[k] = e
        end
    end

    return
end

function Base.show(io::IO, topology::Topology)
    println(io, "Topology with entities: ")
    for e in topology._elements
        println(io, " - ", e)
    end
    println(io, "Direct relations: ")
    for (origin, target) in topology._directRelations
        if (origin, target) in topology._basicRelations
            print(io, " * ")
        else
            print(io, "   ")
        end
        println(io, " - ", origin, " -> ", target)
    end
    println(io, "(*) Basic relations")
end

struct TopologyObject{P, T, R}
    _topology::T
    _relations::R
end

function TopologyObject(
    topology::Topology,
    structures::NamedTuple;
)

    directRelations = topology._directRelations

    # Create CSR structures for all direct relations
    relations_dict = Dict{Tuple{Symbol, Symbol}, AbstractCSR}()
    for (origin, target) in directRelations
        # Check if user specified a custom CSR type in meshType
        if haskey(meshType, (origin, target))
            csr = meshType[(origin, target)]
        else
            # Use default CSR type based on relation
            if origin == :Edge && target == :Node
                # Edge->Node: fixed 2 nodes, use CSRTuple
                csr = CSRTuple(dtype=Int, N=0, NBlock=2, NCache=0)
            else
                # Default: variable connections, use CSRSlack
                csr = CSRSlack(dtype=Int, N=0, sizes=Int64[], NCache=0)
            end
        end
        relations_dict[(origin, target)] = csr
    end
    
    # Convert to nested NamedTuple: origin -> target -> CSR
    nested_dict = Dict{Symbol, Dict{Symbol, AbstractCSR}}()
    for ((origin, target), csr) in relations_dict
        if !haskey(nested_dict, origin)
            nested_dict[origin] = Dict{Symbol, AbstractCSR}()
        end
        nested_dict[origin][target] = csr
    end
    
    # Convert to NamedTuple
    relations_nt = NamedTuple{Tuple(keys(nested_dict))}(
        NamedTuple{Tuple(keys(targets))}(values(targets)) 
        for targets in values(nested_dict)
    )

    T = typeof(topology)

    return TopologyObject{P, T, R}(topology, relations_nt)

end

function Base.show(io::IO, tobj::TopologyObject)
    println(io, "TopologyObject with topology: ")
    Base.show(io, tobj._topology)
    println(io, "and relations CSR structures: ")
    for (origin, targets) in pairs(tobj._relations)
        for (target, csr) in pairs(targets)
            print(io, " - Relation ", origin, " -> ", target, ": ", csr)
        end
    end
end

######################################################################################################
# buildTopology - Build and validate topology for UnstructuredMeshObject
######################################################################################################
function buildTopology(topology::Topology, kwargs::Base.Pairs, params::NamedTuple; validate::Bool=true)
    """
    Build a TopologyObject from the mesh topology and provided data structures.
    Validates consistency of basic relations and builds all direct relations using the inference table.
    
    Args:
        topology: Topology schema from UnstructuredMesh
        kwargs: Keyword arguments containing CSR structures for basic relations
        params: NamedTuple of field objects for getting element counts
        validate: Whether to validate CSR references against element counts (default: true)
        
    Returns:
        TopologyObject containing all validated relations
    """
    
    # Get element counts for validation
    element_counts = Dict{Symbol, Int}()
    if validate
        for (name, field) in pairs(params)
            if field isa UnstructuredMeshField
                element_counts[name] = lengthProperties(field)
            end
        end
    end
    
    # Step 1: Validate and store basic relations
    basic_relations_dict = Dict{Tuple{Symbol, Symbol}, AbstractCSR}()
    
    for (origin, target) in topology._basicRelations
        # Get the CSR from kwargs
        if haskey(kwargs, origin)
            origin_data = kwargs[origin]
            
            # Handle different input types based on property type
            if origin_data isa AbstractCSR
                # Direct CSR provided (for Edge, Face, Volume with single connection)
                csr = origin_data
                
                # Validate: check that all references point to valid elements
                if validate
                    target_count = get(element_counts, target, 0)
                    for (blockId, value) in csr
                        if value < 1 || value > target_count
                            error("Invalid basic relation $origin -> $target: element $blockId of $origin " *
                                  "references $target element $value, but only $target_count elements exist")
                        end
                    end
                end
                
                basic_relations_dict[(origin, target)] = csr
                
            elseif origin_data isa NamedTuple
                # NamedTuple of CSRs (for Agent with multiple connections)
                if haskey(origin_data, target)
                    csr = origin_data[target]
                    
                    # Validate
                    if validate
                        target_count = get(element_counts, target, 0)
                        for (blockId, value) in csr
                            if value < 1 || value > target_count
                                error("Invalid basic relation $origin -> $target: element $blockId of $origin " *
                                      "references $target element $value, but only $target_count elements exist")
                            end
                        end
                    end
                    
                    basic_relations_dict[(origin, target)] = csr
                else
                    error("Missing CSR for basic relation $origin -> $target in NamedTuple")
                end
            end
        else
            error("Missing data for basic relation $origin -> $target")
        end
    end
    
    # Step 2: Build all direct relations using the inference table
    relations_dict = Dict{Tuple{Symbol, Symbol}, AbstractCSR}()
    
    for (origin, target) in topology._directRelations
        # Check if this is a basic relation (already validated and stored)
        if (origin, target) in keys(basic_relations_dict)
            relations_dict[(origin, target)] = basic_relations_dict[(origin, target)]
        else
            # This is a derived relation - build it using the inference table
            if haskey(topology._inferenceTable, origin) && haskey(topology._inferenceTable[origin], target)
                path = topology._inferenceTable[origin][target]
                
                # Compose the relations along the path
                # Path is a tuple of (from, to, direction) triples
                csr_result = nothing
                
                for step in path
                    (from, to, direction) = step
                    
                    # Get the basic relation CSR
                    if direction == :d  # Direct relation
                        step_csr = basic_relations_dict[(from, to)]
                    else  # :i - Inverse relation
                        # Need to invert the CSR
                        step_csr = invertMap(basic_relations_dict[(to, from)])
                    end
                    
                    if csr_result === nothing
                        csr_result = step_csr
                    else
                        # Compose csr_result with step_csr
                        # For each element in csr_result, follow the references in step_csr
                        composed_data = Vector{Vector{Int}}()
                        
                        for block_id in 1:lengthElements(csr_result)
                            new_refs = Set{Int}()
                            for (current_block_id, intermediate_id) in csr_result
                                if current_block_id == block_id
                                    # Follow this intermediate to final target
                                    for (inter_block, final_id) in step_csr
                                        if inter_block == intermediate_id
                                            push!(new_refs, final_id)
                                        end
                                    end
                                end
                            end
                            push!(composed_data, sort(collect(new_refs)))
                        end
                        
                        csr_result = CSRSlack(composed_data)
                    end
                end
                
                relations_dict[(origin, target)] = csr_result
            else
                error("No inference path found for relation $origin -> $target")
            end
        end
    end
    
    # Convert to nested NamedTuple: origin -> target -> CSR
    nested_dict = Dict{Symbol, Dict{Symbol, AbstractCSR}}()
    for ((origin, target), csr) in relations_dict
        if !haskey(nested_dict, origin)
            nested_dict[origin] = Dict{Symbol, AbstractCSR}()
        end
        nested_dict[origin][target] = csr
    end
    
    # Convert to NamedTuple
    relations_nt = NamedTuple{Tuple(keys(nested_dict))}(
        NamedTuple{Tuple(keys(targets))}(values(targets)) 
        for targets in values(nested_dict)
    )
    
    P = platform()
    T = typeof(topology)
    R = typeof(relations_nt)
    
    return TopologyObject{P, T, R}(topology, relations_nt)
end

######################################################################################################
# checkConsistency - Verify topology consistency
######################################################################################################

function checkTopologyConsistency(tobj::TopologyObject)
    """
    Check that the topological relations in a TopologyObject are correct and consistent.
    
    This function:
    1. Extracts basic relations CSR structures from the TopologyObject
    2. Calls buildTopology to reconstruct all relations from basic ones
    3. Compares the reconstructed _relations with the original
    
    Args:
        tobj: TopologyObject to check
        
    Returns:
        true if consistent
        
    Throws:
        Error with detailed message if inconsistencies are found
    """
    
    original_topology = tobj._topology
    basic_relations = original_topology._basicRelations
    
    # Extract basic relation CSR structures and build kwargs
    kwargs_dict = Dict{Symbol, Any}()
    
    for (origin, target) in basic_relations
        if !haskey(tobj._relations, origin) || !haskey(tobj._relations[origin], target)
            error("Missing CSR structure for basic relation $origin -> $target")
        end
        
        csr = tobj._relations[origin][target]
        
        # Build kwargs - group by origin entity
        if !haskey(kwargs_dict, origin)
            kwargs_dict[origin] = Dict{Symbol, AbstractCSR}()
        end
        kwargs_dict[origin][target] = csr
    end
    
    # Convert grouped CSRs to appropriate format (single CSR or NamedTuple)
    for (origin, targets) in kwargs_dict
        if length(targets) == 1
            # Single target - use CSR directly
            kwargs_dict[origin] = first(values(targets))
        else
            # Multiple targets - use NamedTuple
            kwargs_dict[origin] = NamedTuple{Tuple(keys(targets))}(values(targets))
        end
    end
    
    # Reconstruct topology using buildTopology (skip validation since we're checking consistency)
    kwargs_pairs = pairs(NamedTuple{Tuple(keys(kwargs_dict))}(values(kwargs_dict)))
    reconstructed_tobj = buildTopology(original_topology, kwargs_pairs, NamedTuple(), validate=false)
    
    # Compare _relations
    for (origin, targets) in pairs(tobj._relations)
        if !haskey(reconstructed_tobj._relations, origin)
            error("Reconstructed topology missing origin entity: $origin")
        end
        
        for (target, original_csr) in pairs(targets)
            if !haskey(reconstructed_tobj._relations[origin], target)
                error("Reconstructed topology missing relation: $origin -> $target")
            end
            
            reconstructed_csr = reconstructed_tobj._relations[origin][target]
            
            # Compare CSR contents element-by-element
            original_elements = sort([(blockId, value) for (blockId, value) in original_csr])
            reconstructed_elements = sort([(blockId, value) for (blockId, value) in reconstructed_csr])
            
            if original_elements != reconstructed_elements
                error("CSR structure mismatch for relation $origin -> $target\n" *
                      "Original has $(length(original_elements)) elements: $original_elements\n" *
                      "Reconstructed has $(length(reconstructed_elements)) elements: $reconstructed_elements")
            end
        end
    end
    
    return true
end