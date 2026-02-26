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
        neighbors::AbstractNeighbors=NeighborsFull(),
    )

    UnstructuredMeshObject(
        mesh;
        n=n,
        neighbors=neighbors,
    )

end

##########################################################################
# Functions for working with Agents
##########################################################################
macro AgentPoint_Add!(
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

    updates = [:($var.n._p.$n[_nPos_] = $v) for (n, v) in fields]

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

        _nPos_
    end

    return esc(code)

end

function AgentPoint_remove!(
    meshObject::AgentPointObject{P, D, DT, NN, PAR},
    agentIndex::T,
) where {P, D, DT, NN, PAR, T<:Integer}

    # Inline the logic for GPU compatibility
    meshObject.n._FlagsSurvived[agentIndex] = false

    return nothing
    # return esc(:($meshObject.n._FlagsSurvived[$agentIndex] = false))

end

macro removeAgentPoint!(
    meshObject,
    agentIndex,
)

    # Inline the logic for GPU compatibility
    return esc(:($meshObject.n._FlagsSurvived[$agentIndex] = false))

end