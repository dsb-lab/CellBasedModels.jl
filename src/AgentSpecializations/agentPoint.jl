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

#####################################################################################
# Functions to add/remove agents of type AgentPoint
#####################################################################################

function addAgent!(
        obj::AgentPointObject,
        nodeProps::NamedTuple
    )

    newPos = 

end
