abstract type AgentPointModel end
const AgentPoint{D, P, PAR, BU} = UnstructuredMesh{D, AgentPointModel, P, PAR, BU}
const AgentPointObject{P, D, DT, NN, PARAMS, PAR} = UnstructuredMeshObject{P, D, AgentPointModel, DT, NN, PARAMS, PAR}

function AgentPoint(
    dims::Int,
    properties::Union{NamedTuple, Nothing}=nothing;
    parameters::NamedTuple=(;),
    baseUnits::NamedTuple=(;),
)

    UnstructuredMesh(
        dims,
        n=Node(properties),
        specialization=AgentPointModel,
        parameters=parameters,
        baseUnits=baseUnits,
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

# Register special functions for AgentPoint that should be analyzed for field modifications
register_check_function!(:addAgent!, AgentPointModel, :n, 2)

"""
    addAgent!(obj::AgentPointObject, nodeProps::NamedTuple)

Add a new agent (point) to the AgentPointObject.
Returns the position index where the agent was added, or 0 if overflow (no free positions).

Example:
```julia
pos = addAgent!(obj, (x=1.0, y=2.0, z=3.0))
if pos != 0
    println("Added agent at position \$pos")
else
    println("Overflow - need to preallocate more space")
end
```
"""
function addAgent!(
        obj::AgentPointObject,
        nodeProps::NamedTuple
    )
    # Get a free position
    pos = getFreePos!(obj.n)
    
    if pos != 0
        # Set the properties
        for (name, value) in pairs(nodeProps)
            if haskey(obj.n._p, name)
                obj.n._p[name][pos] = value
            end
        end
    end
    
    return pos
end

"""
    removeAgent!(obj::AgentPointObject, agentIdx::Int)

Remove an agent (point) from the AgentPointObject at the given index.
The position becomes available for reuse after calling synchronize(obj.n).

Example:
```julia
removeAgent!(obj, 5)  # Remove agent at position 5
synchronize(obj.n)    # Make position 5 available for reuse
```
"""
function removeAgent!(
        obj::AgentPointObject,
        agentIdx::Int
    )
    releasePos!(obj.n, agentIdx)
    # For direct API usage (outside kernels), also decrement _N immediately
    # (releasePos! doesn't modify _N to be kernel-safe)
    obj.n._N[1] -= 1
    return nothing
end
