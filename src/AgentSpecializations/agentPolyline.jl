abstract type AgentPolylineModel end
const AgentPolyline{D, P} = UnstructuredMesh{D, AgentPolylineModel, P}
const AgentPolylineObject{P, D, DT, NN, PAR} = UnstructuredMeshObject{P, D, AgentPolylineModel, DT, NN, PAR}

function AgentPolyline(
    dims::Int;
    propertiesNode::Union{NamedTuple, Nothing}=nothing,
    propertiesEdge::Union{NamedTuple, Nothing}=nothing,
    propertiesAgent::Union{NamedTuple, Nothing}=nothing,
)

    mesh = UnstructuredMesh(
        dims,
        n=Node(propertiesNode),
        e=Edge(:n, propertiesEdge),
        a=Agent((:n, :e), propertiesAgent),
        specialization=AgentPolylineModel,
        
    )

    # Set required topology relation types for inferred relations
    # n → e: Each node connects to at most 2 edges (ELL with 2 cols)
    setTopologyRelationType!(mesh, :n, :e, DynamicalELL)
    # n → n: Each node has at most 2 neighbors via edges (ELL with 2 cols)
    setTopologyRelationType!(mesh, :n, :n, DynamicalELL)
    # n → a: Each node belongs to 1 agent (ELL with 1 col)
    setTopologyRelationType!(mesh, :n, :a, DynamicalELL)
    # e → a: Each edge belongs to 1 agent (ELL with 1 col)
    setTopologyRelationType!(mesh, :e, :a, DynamicalELL)

    return mesh

end

function createObject(
        mesh::AgentPolyline{D, P},
        v::Vector{<:Vector{NTuple{D, T}}},
    ) where {D, P, T<:AbstractFloat}

    # Count total nodes, edges, and agents
    nAgents = length(v)
    nNodes = sum(length(polyline) for polyline in v)
    nEdges = sum(length(polyline) - 1 for polyline in v; init=0)
    
    # Create sparse matrices for topology relations
    # e_n: ELL with 2 cols (each edge connects exactly 2 nodes)
    e_n = dell_zeros(Int, nEdges, 2, 0)
    
    # a_n: OrderedCSR (each agent has variable number of nodes)
    # Compute number of nodes per agent
    nodesPerAgent = [length(polyline) for polyline in v]
    a_n = docsr_zeros(Int, nAgents, nodesPerAgent, 0)
    
    # a_e: OrderedCSR (each agent has variable number of edges)
    # Compute number of edges per agent
    edgesPerAgent = [max(0, length(polyline) - 1) for polyline in v]
    a_e = docsr_zeros(Int, nAgents, edgesPerAgent, 0)
    
    # Populate the sparse matrices
    nodeIdx = 1
    edgeIdx = 1
    
    for (agentIdx, polyline) in enumerate(v)
        nPolyNodes = length(polyline)
        firstNodeIdx = nodeIdx
        
        for (localNodeIdx, _) in enumerate(polyline)
            # Add node to agent-node relation (append maintains order)
            append!(a_n, agentIdx, localNodeIdx, nodeIdx)
            
            # Create edge if not the last node
            if localNodeIdx < nPolyNodes
                # Edge connects current node to next node (ELL uses setindex!)
                e_n[edgeIdx, 1] = nodeIdx
                e_n[edgeIdx, 2] = nodeIdx + 1
                
                # Add edge to agent-edge relation (append maintains order)
                append!(a_e, agentIdx, localNodeIdx, edgeIdx)
                
                edgeIdx += 1
            end
            
            nodeIdx += 1
        end
    end
    
    # Synchronize all sparse matrices
    synchronize(e_n)
    synchronize(a_n)
    synchronize(a_e)

    # Collect node coordinates
    nodeCoords = Vector{NTuple{D, T}}(undef, nNodes)
    idx = 1
    for polyline in v
        for coord in polyline
            nodeCoords[idx] = coord
            idx += 1
        end
    end

    obj = UnstructuredMeshObject(
        mesh;
        n=nNodes,
        e=e_n,
        a=(n=a_n, e=a_e),
    )

    # Set node positions
    for i in 1:nNodes
        obj.n.x[i] = nodeCoords[i][1]
        obj.n.y[i] = nodeCoords[i][2]
        if D >= 3
            obj.n.z[i] = nodeCoords[i][3]
        end
    end

    return obj

end
