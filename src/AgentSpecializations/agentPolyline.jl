abstract type AgentPolylineModel end
const AgentPolyline{D, P} = UnstructuredMesh{D, AgentPolylineModel, P}
const AgentPolylineObject{P, D, DT, NN, PAR} = UnstructuredMeshObject{P, D, AgentPolylineModel, DT, NN, PAR}

function AgentPolyline(
    dims::Int,
    properties::Union{NamedTuple, Nothing}=nothing,
)

    UnstructuredMesh(
        dims,
        n=Node(properties),
        specialization=AgentPolylineModel,
    )

end

function createObject(
        mesh::AgentPolyline;
        n::Union{Integer,Tuple{Integer, Integer}}=0,
    )

    UnstructuredMeshObject(
        mesh;
        n=n,
    )

end

##########################################################################
# Functions for working with AgentPolyline
##########################################################################

function isNodeExtreme(mesh::AgentPolylineObject, nodeIndex::Integer)
    edge1, edge2 = mesh.n._neighbors[nodeIndex]
    return edge1 == 0 || edge2 == 0
end

function neighborEdgesOfNode(mesh::AgentPolylineObject, nodeIndex::Integer)
    return mesh.n._neighbors[nodeIndex]
end

function neighborEdgesOfEdge(mesh::AgentPolylineObject, edgeIndex::Integer)
    node1, node2 = mesh.e.nodes[edgeIndex]
    edge1, edge2 = mesh.n._neighbors[node1]
    edge3, edge4 = mesh.n._neighbors[node2]
    return (edge1 == edgeIndex ? edge2 : edge1, edge3 == edgeIndex ? edge4 : edge3)
end

macro AgentPolyline_markSplitEdge!(ex...)

    if length(ex) != 2
        error("AgentPolyline_markSplitEdge!: incorrect number of arguments provided. Expected (AgentPolylineObject, edgePosition).")
    end
    var = ex[1]
    e1 = ex[2]

    code = quote
        CellBasedModels.@markEdge!($var, $e1)
    end

    return esc(code)

end

macro AgentPolyline_proceedSplitEdge!(ex...)

    length(ex) < 5 && error("AgentPolyline_divideEdge!: not enough arguments provided. Expected (AgentPolylineObject, edgePosition, n=nodeAttrs, e1=edge1Attrs, e2=edge2Attrs).")
    var = ex[1]
    e1 = ex[2]
    nn_attrs = nothing
    ne1_attrs = nothing
    ne2_attrs = nothing

    for i in ex[3:end]
        captured = @capture(i, n_ = v_)
        if n == :n
            nn_attrs = v
        elseif n == :e1
            ne1_attrs = v
        elseif n == :e2
            ne2_attrs = v
        else
            error("AgentPolyline_divideEdge!: arguments should be (AgentPolylineObject, edgePosition, n=nodeAttrs, e1=edge1Attrs, e2=edge2Attrs).")
        end
    end

    updates_n = [:($var.n._p.$n[_nn1_] = $v) for (n, v) in pairs(nn_attrs)]
    updates_e1 = [:($var.e._p.$n[_ne1_] = $v) for (n, v) in pairs(ne1_attrs)]
    updates_e2 = [:($var.e._p.$n[_ne2_] = $v) for (n, v) in pairs(ne2_attrs)]
    code = quote
        # Get event IDs
        _n1_, _n2_, _isEvent_ = @getEdgeEvent($var, $e1)

        # Proceed only if this id is the winner for all involved structures
        if _isEvent_
            # Inline the logic from divideAgentEdge_! for GPU compatibility
            _agent_ = $var.e._agent[$e1]

            _nn1_ = CellBasedModels.@addOne($var, :n)
            _ne1_ = CellBasedModels.@addOne($var, :e)
            _ne2_ = CellBasedModels.@addOne($var, :e)

            if _nn1_ != 0 && _ne1_ != 0 && _ne2_ != 0
                # Update neighbors of existing nodes
                $var.n._neighbors[_n1_] = (edgeA1, _ne1_)
                $var.n._neighbors[_n2_] = (_ne2_ , edgeB2)

                # Remove old edge
                $var.e._FlagsSurvived[$e1] = false

                # Create new node and edges
                #Node
                $var.n._neighbors[_nn1_] = (_ne1_, _ne2_)
                $var.n._agent[_nn1_] = _agent_
                $var.n._FlagsSurvived[_nn1_] = true
                $(updates_n...)
                #Edge 1
                $var.e.nodes[_ne1_] = (_n1_, _nn1_)
                $var.e._agent[_ne1_] = _agent_
                $var.e._FlagsSurvived[_ne1_] = true
                $(updates_e1...)
                #Edge 2
                $var.e.nodes[_ne2_] = (_nn1_, _n2_)
                $var.e._agent[_ne2_] = _agent_
                $var.e._FlagsSurvived[_ne2_] = true
                $(updates_e2...)
            end
        end
    end

    return esc(code)
end

macro AgentPolyline_markRemoveEdge!(var, e1)

    code = quote
        CellBasedModels.@markEdge2!($var, $e1)
    end

    return esc(code)

end

macro AgentPolyline_proceeedRemoveEdge!(ex...)

    if length(ex) != 3
        error("AgentPolyline_removeEdge!: incorrect number of arguments provided. Expected (AgentPolylineObject, edgePosition, n=nodeAttrs).")
    end
    var = ex[1]
    e1 = ex[2]

    for i in ex[3:end]
        captured = @capture(i, n_ = v_)
        if n != :n
            error("AgentPolyline_removeEdge!: arguments should be (AgentPolylineObject, edgePosition, n=nodeAttrs).")
        end
    end

    code = quote
        # Get event IDs
        _n1_, _n2_, _e1_, _e2_, _isEvent_ = @getEdgeEvent2($var, $e1)

        # Proceed only if this id is the winner for all involved structures
        if _isEvent_

            _nn1_ = CellBasedModels.@addOne($var, :n)

            if _nn1_ != 0
                # Update neighbor edges
                _node1_, _ = $var.e.nodes[$e1]
                $var.e.nodes[_e2_] = (_node1_, _nn1_)
                _, _node2_ = $var.e.nodes[$e1]
                $var.e.nodes[_e1_] = (_nn1_, _node2_)

                # Remove old edge and nodes
                $var.e._FlagsSurvived[$e1] = false
                $var.n._FlagsSurvived[_n1_] = false
                $var.n._FlagsSurvived[_n2_] = false

                # Create new node
                #Node
                $var.n._neighbors[_nn1_] = (_e1_, _e2_)
                $var.n._agent[_nn1_] = $var.e._agent[$e1]
                $var.n._FlagsSurvived[_nn1_] = true
                $(updates_n...)
            end
    end

    return esc(code)

end

macro AgentPolyline_markDivideAgent!(ex...)

    if length(ex) != 2
        error("markDivideAgent!: incorrect number of arguments provided. Expected (AgentPolylineObject, agentIndex).")
    end
    var = ex[1]
    agentIndex = ex[2]

    code = quote 
        @markAgent!($var, $agentIndex)
    end

    return esc(code)
end

macro AgentPolyline_proceedDivideAgent!(ex...)

    if length(ex) != 2
        error("markDivideAgent!: incorrect number of arguments provided. Expected (AgentPolylineObject, agentIndex).")
    end
    var = ex[1]
    agentIndex = ex[2]
    nodeDiv = ex[3]
    n1 = ex[4]
    n2 = ex[5]

    updates_n1 = [:($var.n._p.$n[_nn1_] = $v) for (n, v) in pairs(n1)]
    updates_n2 = [:($var.n._p.$n[_nn2_] = $v) for (n, v) in pairs(n2)]
    code = quote 
        _id_ = $var.a._EventThread[$agentIndex]
        if _id_ != 0
            _nn1_ = @addOne($var, :n)
            _nn2_ = @addOne($var, :n)
            if _n1_ == 0 || _n2_ == 0
                _agent1_ = Atomix.@atomic $var.a._idMax += 1
                _agent2_ = Atomix.@atomic $var.a._idMax += 1
                _edge1_, _edge2_ = $var.n._neighbors[$nodeDiv]
                
                # Rename agent id
                _nFound_ = false
                for _n1_ in iterateOverAgentNodes($var, $agentIndex)
                    if _n1_ == $nodeDiv
                        _nFound_ = true
                    end
                    $var.n._agent[_n1_] = _nFound_ ? _agent2_ : _agent1_
                end
                _nFound_ = false
                for _e1_ in iterateOverAgentEdges($var, $agentIndex)
                    _n1_, _n2_ = $var.e.nodes[_e1_]
                    if _n1_ == $nodeDiv || _n2_ == $nodeDiv
                        $var.e.nodes[_e1_] = _nFound_ ? (_n1_, _nn1_) : (_nn2_, _nn2_)
                        _nFound_ = true
                    end
                    $var.e._agent[_e1_] = _nFound_ ? _agent2_ : _agent1_
                end

                # Remove node
                $var.n._FlagsSurvived[$nodeDiv] = false

                # Add new nodes
                #Node 1
                $var.n._neighbors[_nn1_] = (_edge1_, 0)
                $var.n._agent[_nn1_] = _agent1_
                $var.n._FlagsSurvived[_nn1_] = true
                $(updates_n1...)
                #Node 2
                $var.n._neighbors[_nn2_] = (0, _edge2_)
                $var.n._agent[_nn2_] = _agent2_
                $var.n._FlagsSurvived[_nn2_] = true
                $(updates_n2...)
            end
        end
    end

    return esc(code)

end