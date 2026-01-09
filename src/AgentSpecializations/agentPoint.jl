abstract type AgentPointModel end
const AgentPoint{D, P} = UnstructuredMesh{D, AgentPointModel, P}
const AgentPointObject{P, D, DT, NN, PAR} = UnstructuredMeshObject{P, D, AgentPointModel, DT, NN, PAR}

function AgentPoint(
    dims::Int,
    properties::Union{NamedTuple, Nothing}=nothing,
)

    UnstructuredMesh(
        dims,
        n=Node(properties),
        specialization=AgentPointModel,
    )

end

function createObject(
        mesh::AgentPoint;
        n::Union{Integer,Tuple{Integer, Integer}}=0,
    )

    UnstructuredMeshObject(
        mesh;
        n=n,
    )

end

##########################################################################
# Functions for working with Agents
##########################################################################

iterateOverNeighbors(mesh::AgentPointObject, agentIndex::Integer) = iterateOverNeighbors(mesh, :n, agentIndex)

function extract_unstructuredmeshparameters(
    PN
)
    l = []
    for i in 1:length(PN.parameters[1])
        push!(l, PN.parameters[2].parameters[i].parameters[3].parameters[1])
    end

end

macro addAgentPoint!(
    ex...
)

    var = ex[1]

    fields = []
    for arg in ex[2:end]
       captured = @capture(arg, n_ = v_)
       if captured !== nothing
           push!(fields, (n, v))
       else
           error("addAgent!: arguments should be (AgentPointObject, parameter1=value1, parameter2=value2...).")
       end
    end

    updates = [:($var.n._p.$n[_nid_] = $v) for (n, v) in fields]

    code = quote
        # Inline the logic from addAgentPoint_! for GPU compatibility
        _nPos_ = CellBasedModels.@atomic $var.n._NAdded[1] += 1     
        _nPos_ += $var.n._N[1]
        if _nPos_ > $var.n._NCache[1]
            _ = CellBasedModels.@atomic $var.n._NOverflow[1] += 1
            $var._FlagOverflow[1] = true
            _nPos_ = 0
        else
            _nid_ = CellBasedModels.@atomic $var.n._idMax[1] += 1
            $var.n._FlagsSurvived[_nPos_] = true
            $var.n._id[_nPos_] = _nid_
        end
        
        if _nPos_ != 0
            $(updates...)
        end
    end

    return esc(code)

end

macro removeAgentPoint!(
    meshObject,
    agentIndex,
)

    # Inline the logic for GPU compatibility
    return esc(:($meshObject.n._FlagsSurvived[$agentIndex] = false))

end