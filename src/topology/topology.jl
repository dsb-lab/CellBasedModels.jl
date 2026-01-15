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

struct TopologyObject{P, T, R}
    _topology::T
    _relations::R
end

function TopologyObject(
    topology::Topology,
    structures::NamedTuple;
) where {P<:Union{<:CPU, <:GPU}, D, S, DT, NN, PAR, AB, RREL, RB, RA, RI}

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