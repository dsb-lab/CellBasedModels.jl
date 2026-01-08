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

# function addAgentPoint_!(
#     meshObject::AgentPointObject{P, D, DT, NN, PAR},
# ) where {P, D, DT, NN, PAR}

#     # Get new position and ID atomically
#     nPos = @atomic meshObject.n._NAdded[1] += 1     
#     nPos += meshObject.n._N[1]
#     nId = @atomic meshObject.n._idMax[1] = meshObject.n._idMax[1] + 1
#     if nPos > meshObject.n._NCache[1]
#         @print "Not enough space to add new AgentPoint. Please increase cache size."
#         @atomic meshObject.m._FlagOverflow[1] = meshObject.m._FlagOverflow[1] + 1
#     else
#         meshObject.n._FlagsSurvived[nPos] = true
#         meshObject.n._id[nPos] = nId
#     end

#     return nPos

# end

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
        _nid_ = CellBasedModels.@atomic $var.n._idMax[1] += 1
        # if _nPos_ > $var.n._NCache[1]
        #     CellBasedModels.@print "Not enough space to add new AgentPoint. Please increase cache size."
        #     _ = CellBasedModels.@atomic $var.n._FlagOverflow[1] += 1
        #     _nid_ = 0
        # else
            $var.n._FlagsSurvived[_nPos_] = true
            $var.n._id[_nPos_] = _nid_
        # end
        
        if _nid_ != 0
            $(updates...)
        end
    end

    return esc(code)

end

# function removeAgentPoint!(
#     meshObject::AgentPointObject{P, D, DT, NN, PAR},
#     agentIndex::I,
# ) where {P, D, DT, NN, PAR, I}

#     meshObject.n._FlagsSurvived[agentIndex] = false

# end

macro removeAgentPoint!(
    meshObject,
    agentIndex,
)

    # Inline the logic for GPU compatibility
    # return esc(:(CellBasedModels.removeAgentPoint!($meshObject, $agentIndex)))
    return esc(:($meshObject.n._FlagsSurvived[$agentIndex] = false))

end