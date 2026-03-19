import KernelAbstractions
using KernelAbstractions: @kernel, @index

abstract type AgentPointDelaunayModel end
const AgentPointDelaunay{D, P} = UnstructuredMesh{D, AgentPointDelaunayModel, P}
const AgentPointDelaunayObject{P, D, DT, NN, PAR} = UnstructuredMeshObject{P, D, AgentPointDelaunayModel, DT, NN, PAR}

"""
    AgentPointDelaunay(dims::Int, properties::Union{NamedTuple, Nothing}=nothing)

Create an AgentPointDelaunay mesh - a point-based agent model with a n->n topology 
relation for storing local Delaunay triangulation edges.

Arguments:
- `dims`: Number of spatial dimensions (2 or 3)
- `properties`: Optional NamedTuple of additional agent properties

Example:
```julia
model = AgentPointDelaunay(2, (mass = AbstractFloat,))
```
"""
function AgentPointDelaunay(
    dims::Int,
    properties::Union{NamedTuple, Nothing}=nothing;
    maxNeighborsPerNode::Int = dims == 2 ? 12 : 20  # Reasonable default for Delaunay
)

    if dims < 2 || dims > 3
        error("AgentPointDelaunay only supports 2D and 3D. Found dims=$dims")
    end

    mesh = UnstructuredMesh(
        dims,
        n=Node(properties),
        specialization=AgentPointDelaunayModel,
    )

    # Add n->n topology relation for Delaunay edges
    # Use DynamicalELL with maxNeighborsPerNode columns per row
    push!(mesh._requiredTopologyRelations, (:n, :n))
    setTopologyRelationType!(mesh, :n, :n, DynamicalELL)
    
    # Store the max neighbors per node in the mesh functions dict for later use
    mesh._functions[:_maxNeighborsPerNode] = maxNeighborsPerNode

    return mesh

end

"""
    createObject(mesh::AgentPointDelaunay; n, neighbors, maxNeighborsPerNode)

Create an AgentPointDelaunayObject with allocated memory.

Arguments:
- `mesh`: The AgentPointDelaunay mesh definition
- `n`: Number of agents or tuple (initial, cache) for initial agents with cache for growth
- `neighbors`: Neighbor algorithm (default: NeighborsFull())
- `maxNeighborsPerNode`: Maximum Delaunay neighbors per node (default from mesh)

Example:
```julia
obj = createObject(model, n=(100, 200), neighbors=NeighborsCellLinked(2.0))
```
"""
function createObject(
        mesh::AgentPointDelaunay{D, P};
        n::Union{Integer,Tuple{Integer, Integer}}=0,
        neighbors::AbstractNeighbors=NeighborsFull(),
        maxNeighborsPerNode::Union{Int, Nothing}=nothing
    ) where {D, P}

    # Get max neighbors per node from mesh or override
    maxNbrs = maxNeighborsPerNode !== nothing ? maxNeighborsPerNode : get(mesh._functions, :_maxNeighborsPerNode, D == 2 ? 12 : 20)
    
    # Determine number of nodes
    nNodes, nCache = n isa Tuple ? n : (n, n)
    
    # Create n->n topology matrix (DynamicalELL format)
    # Each row corresponds to a node, columns are its Delaunay neighbors
    n_n_matrix = dell_zeros(Int, nCache, maxNbrs, 0)
    
    # Create the base object
    obj = UnstructuredMeshObject(
        mesh;
        n=n,
        neighbors=neighbors,
        n_n=n_n_matrix,  # Pass the topology matrix
    )

    return obj

end

#####################################################################################
# Delaunay triangulation computation - kernel functions
#####################################################################################

"""
    @inline inCircumcircle2D(ax, ay, bx, by, cx, cy, dx, dy)

Test if point (dx, dy) lies inside the circumcircle of triangle (a, b, c).
Returns positive if inside, negative if outside, zero if on circle.
Uses the standard 4x4 determinant criterion.
"""
@inline function inCircumcircle2D(ax, ay, bx, by, cx, cy, dx, dy)
    # Compute the determinant:
    # | ax-dx  ay-dy  (ax-dx)²+(ay-dy)² |
    # | bx-dx  by-dy  (bx-dx)²+(by-dy)² |
    # | cx-dx  cy-dy  (cx-dx)²+(cy-dy)² |
    
    adx = ax - dx
    ady = ay - dy
    bdx = bx - dx
    bdy = by - dy
    cdx = cx - dx
    cdy = cy - dy
    
    abdet = adx * bdy - bdx * ady
    bcdet = bdx * cdy - cdx * bdy
    cadet = cdx * ady - adx * cdy
    
    alift = adx * adx + ady * ady
    blift = bdx * bdx + bdy * bdy
    clift = cdx * cdx + cdy * cdy
    
    return alift * bcdet + blift * cadet + clift * abdet
end

"""
    @inline inCircumsphere3D(ax, ay, az, bx, by, bz, cx, cy, cz, dx, dy, dz, ex, ey, ez)

Test if point (ex, ey, ez) lies inside the circumsphere of tetrahedron (a, b, c, d).
Returns positive if inside, negative if outside, zero if on sphere.
Uses the standard 5x5 determinant criterion.
"""
@inline function inCircumsphere3D(ax, ay, az, bx, by, bz, cx, cy, cz, dx, dy, dz, ex, ey, ez)
    # Translate so that e is at origin
    aex = ax - ex
    aey = ay - ey
    aez = az - ez
    bex = bx - ex
    bey = by - ey
    bez = bz - ez
    cex = cx - cy
    cey = cy - ey
    cez = cz - ez
    dex = dx - ex
    dey = dy - ey
    dez = dz - ez
    
    # Compute cofactors of 4x4 submatrix
    aexbey = aex * bey
    bexaey = bex * aey
    ab = aexbey - bexaey
    bexcey = bex * cey
    cexbey = cex * bey
    bc = bexcey - cexbey
    cexdey = cex * dey
    dexcey = dex * cey
    cd = cexdey - dexcey
    dexaey = dex * aey
    aexdey = aex * dey
    da = dexaey - aexdey
    aexcey = aex * cey
    cexaey = cex * aey
    ac = aexcey - cexaey
    bexdey = bex * dey
    dexbey = dex * bey
    bd = bexdey - dexbey
    
    # Compute xyz cofactors
    abc = aez * bc - bez * ac + cez * ab
    bcd = bez * cd - cez * bd + dez * bc
    cda = cez * da + dez * ac + aez * cd
    dab = dez * ab + aez * bd + bez * da
    
    # Compute lifts
    alift = aex * aex + aey * aey + aez * aez
    blift = bex * bex + bey * bey + bez * bez
    clift = cex * cex + cey * cey + cez * cez
    dlift = dex * dex + dey * dey + dez * dez
    
    return dlift * abc - clift * dab + blift * cda - alift * bcd
end

"""
    @inline triangleOrientation2D(ax, ay, bx, by, cx, cy)

Compute the orientation of triangle (a, b, c).
Returns positive if counterclockwise, negative if clockwise, zero if collinear.
"""
@inline function triangleOrientation2D(ax, ay, bx, by, cx, cy)
    return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
end

"""
    @inline tetrahedronOrientation3D(ax, ay, az, bx, by, bz, cx, cy, cz, dx, dy, dz)

Compute the orientation of tetrahedron (a, b, c, d).
Returns positive if d is above plane (a,b,c), negative if below, zero if coplanar.
"""
@inline function tetrahedronOrientation3D(ax, ay, az, bx, by, bz, cx, cy, cz, dx, dy, dz)
    adx = ax - dx
    ady = ay - dy
    adz = az - dz
    bdx = bx - dx
    bdy = by - dy
    bdz = bz - dz
    cdx = cx - dx
    cdy = cy - dy
    cdz = cz - dz
    
    return adx * (bdy * cdz - bdz * cdy) - 
           ady * (bdx * cdz - bdz * cdx) + 
           adz * (bdx * cdy - bdy * cdx)
end

#####################################################################################
# Local Delaunay computation rule
#####################################################################################

"""
    computeLocalDelaunay!(obj::AgentPointDelaunayObject)

Compute the local Delaunay triangulation for all agents using their spatial neighbors.
This clears the existing n->n topology and rebuilds it based on the current positions.

The triangulation is "local" because it only considers points that are spatial neighbors
according to the neighbor structure (e.g., NeighborsCellLinked). This means:
- With NeighborsFull: Full Delaunay triangulation
- With NeighborsCellLinked/NeighborsHash: Approximate Delaunay using nearby points

Example:
```julia
# After updating positions, recompute Delaunay
computeLocalDelaunay!(obj)

# Access Delaunay neighbors
for j in iterateRow(obj.topo[:n,:n], i)
    # j is a Delaunay neighbor of i
end
```
"""
function computeLocalDelaunay!(obj)
    # Get dimensionality from object
    D = length(filter(k -> k in (:x, :y, :z), keys(obj.n._p)))
    
    if D == 2
        _computeLocalDelaunay2D_impl!(obj)
    else
        _computeLocalDelaunay3D_impl!(obj)
    end
end

"""
    addDelaunayRule!(model::AgentPointDelaunay)

Add a rule that computes the local Delaunay triangulation at each timestep.
The rule clears the n->n topology and rebuilds it based on current positions.

Example:
```julia
model = AgentPointDelaunay(2)
addDelaunayRule!(model)

# Now the Delaunay triangulation is computed automatically each step
```
"""
function addDelaunayRule!(model::AgentPointDelaunay{D, P}) where {D, P}
    if D == 2
        @addRule model=model function _delaunay_update_2D!(uNew, u, p, t)
            _computeLocalDelaunay2D_kernel!(uNew, u)
        end
    else
        @addRule model=model function _delaunay_update_3D!(uNew, u, p, t)
            _computeLocalDelaunay3D_kernel!(uNew, u)
        end
    end
end

# Internal implementation using KernelAbstractions directly
function _computeLocalDelaunay2D_impl!(obj)
    n_n = obj.topo[:n, :n]
    nPoints = lengthProperties(obj.n)
    
    backend = KernelAbstractions.get_backend(obj.n.x)
    threads = backend isa KernelAbstractions.CPU ? Threads.nthreads() : 256
    
    # Clear existing connections
    _clear_topology_kernel!(backend, threads)(n_n, ndrange=numberOfRows(n_n))
    KernelAbstractions.synchronize(backend)
    
    # Build local Delaunay edges
    _build_delaunay_2D_kernel!(backend, threads)(obj, ndrange=nPoints)
    KernelAbstractions.synchronize(backend)
    
    # Synchronize the topology matrix
    CellBasedModels.synchronize(n_n)
    
    return nothing
end

function _computeLocalDelaunay3D_impl!(obj)
    n_n = obj.topo[:n, :n]
    nPoints = lengthProperties(obj.n)
    
    backend = KernelAbstractions.get_backend(obj.n.x)
    threads = backend isa KernelAbstractions.CPU ? Threads.nthreads() : 256
    
    # Clear existing connections
    _clear_topology_kernel!(backend, threads)(n_n, ndrange=numberOfRows(n_n))
    KernelAbstractions.synchronize(backend)
    
    # Build local Delaunay edges
    _build_delaunay_3D_kernel!(backend, threads)(obj, ndrange=nPoints)
    KernelAbstractions.synchronize(backend)
    
    # Synchronize the topology matrix
    CellBasedModels.synchronize(n_n)
    
    return nothing
end

# Kernel to clear topology
@kernel function _clear_topology_kernel!(n_n)
    i = @index(Global)
    n_n[i, :] = nothing
end

# 2D Delaunay kernel
@kernel function _build_delaunay_2D_kernel!(obj)
    i = @index(Global)
    
    if isAlive(obj.n, i)
        n_n_rel = obj.topo[:n, :n]
        
        xi = obj.n.x[i]
        yi = obj.n.y[i]
        
        # Collect neighbors for this point and check all pairs
        for j in iterateOverNeighbors(obj.n, i)
            if isAlive(obj.n, j) && j != i
                xj = obj.n.x[j]
                yj = obj.n.y[j]
                
                for k in iterateOverNeighbors(obj.n, i)
                    if isAlive(obj.n, k) && k != i && k > j
                        xk = obj.n.x[k]
                        yk = obj.n.y[k]
                        
                        # Check triangle orientation (must be positive for valid triangle)
                        orient = triangleOrientation2D(xi, yi, xj, yj, xk, yk)
                        if orient > 0
                            # Check if any other neighbor is inside the circumcircle
                            isDelaunay = true
                            for m in iterateOverNeighbors(obj.n, i)
                                if isAlive(obj.n, m) && m != i && m != j && m != k
                                    xm = obj.n.x[m]
                                    ym = obj.n.y[m]
                                    
                                    # If m is inside circumcircle of (i, j, k), this triangle is not Delaunay
                                    if inCircumcircle2D(xi, yi, xj, yj, xk, yk, xm, ym) > 0
                                        isDelaunay = false
                                        break
                                    end
                                end
                            end
                            
                            # If triangle (i, j, k) is locally Delaunay, add edges i->j and i->k
                            if isDelaunay
                                n_n_rel[i, j] = j
                                n_n_rel[i, k] = k
                            end
                        end
                    end
                end
            end
        end
    end
end

# 3D Delaunay kernel
@kernel function _build_delaunay_3D_kernel!(obj)
    i = @index(Global)
    
    if isAlive(obj.n, i)
        n_n_rel = obj.topo[:n, :n]
        
        xi = obj.n.x[i]
        yi = obj.n.y[i]
        zi = obj.n.z[i]
        
        for j in iterateOverNeighbors(obj.n, i)
            if isAlive(obj.n, j) && j != i
                xj = obj.n.x[j]
                yj = obj.n.y[j]
                zj = obj.n.z[j]
                
                for k in iterateOverNeighbors(obj.n, i)
                    if isAlive(obj.n, k) && k != i && k > j
                        xk = obj.n.x[k]
                        yk = obj.n.y[k]
                        zk = obj.n.z[k]
                        
                        for l in iterateOverNeighbors(obj.n, i)
                            if isAlive(obj.n, l) && l != i && l > k
                                xl = obj.n.x[l]
                                yl = obj.n.y[l]
                                zl = obj.n.z[l]
                                
                                # Check tetrahedron orientation (must be positive for valid tetrahedron)
                                orient = tetrahedronOrientation3D(xi, yi, zi, xj, yj, zj, xk, yk, zk, xl, yl, zl)
                                if orient > 0
                                    # Check if any other neighbor is inside the circumsphere
                                    isDelaunay = true
                                    for m in iterateOverNeighbors(obj.n, i)
                                        if isAlive(obj.n, m) && m != i && m != j && m != k && m != l
                                            xm = obj.n.x[m]
                                            ym = obj.n.y[m]
                                            zm = obj.n.z[m]
                                            
                                            # If m is inside circumsphere of (i, j, k, l), this tetra is not Delaunay
                                            if inCircumsphere3D(xi, yi, zi, xj, yj, zj, xk, yk, zk, xl, yl, zl, xm, ym, zm) > 0
                                                isDelaunay = false
                                                break
                                            end
                                        end
                                    end
                                    
                                    # If tetrahedron (i, j, k, l) is locally Delaunay, add edges
                                    if isDelaunay
                                        n_n_rel[i, j] = j
                                        n_n_rel[i, k] = k
                                        n_n_rel[i, l] = l
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

# Kernel functions for use inside @addRule
function _computeLocalDelaunay2D_kernel!(uNew, u)
    n_n = u.topo[:n, :n]
    nPoints = lengthProperties(u.n)
    
    backend = KernelAbstractions.get_backend(u.n.x)
    threads = backend isa KernelAbstractions.CPU ? Threads.nthreads() : 256
    
    _clear_topology_kernel!(backend, threads)(n_n, ndrange=numberOfRows(n_n))
    KernelAbstractions.synchronize(backend)
    
    _build_delaunay_2D_kernel!(backend, threads)(u, ndrange=nPoints)
    KernelAbstractions.synchronize(backend)
    
    CellBasedModels.synchronize(n_n)
end

function _computeLocalDelaunay3D_kernel!(uNew, u)
    n_n = u.topo[:n, :n]
    nPoints = lengthProperties(u.n)
    
    backend = KernelAbstractions.get_backend(u.n.x)
    threads = backend isa KernelAbstractions.CPU ? Threads.nthreads() : 256
    
    _clear_topology_kernel!(backend, threads)(n_n, ndrange=numberOfRows(n_n))
    KernelAbstractions.synchronize(backend)
    
    _build_delaunay_3D_kernel!(backend, threads)(u, ndrange=nPoints)
    KernelAbstractions.synchronize(backend)
    
    CellBasedModels.synchronize(n_n)
end

#####################################################################################
# Functions to add/remove agents of type AgentPointDelaunay
#####################################################################################

"""
    addAgent!(obj::AgentPointDelaunayObject, nodeProps::NamedTuple)

Add a new agent (point) to the AgentPointDelaunayObject.
Returns the position index where the agent was added, or 0 if overflow.

Note: After adding agents, call computeLocalDelaunay! to update the triangulation.

Example:
```julia
pos = addAgent!(obj, (x=1.0, y=2.0))
if pos != 0
    println("Added agent at position \$pos")
    computeLocalDelaunay!(obj)  # Update triangulation
end
```
"""
function addAgent!(
        obj::AgentPointDelaunayObject,
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
    removeAgent!(obj::AgentPointDelaunayObject, agentIdx::Int)

Remove an agent (point) from the AgentPointDelaunayObject at the given index.
The position becomes available for reuse after calling synchronize(obj.n).

Note: After removing agents, call computeLocalDelaunay! to update the triangulation.

Example:
```julia
removeAgent!(obj, 5)
synchronize(obj.n)
computeLocalDelaunay!(obj)  # Update triangulation
```
"""
function removeAgent!(
        obj::AgentPointDelaunayObject,
        agentIdx::Int
    )
    # Also remove topology connections for this agent
    n_n = obj.topo[:n, :n]
    n_n[agentIdx, :] = nothing
    
    releasePos!(obj.n, agentIdx)
    obj.n._N[1] -= 1
    return nothing
end

#####################################################################################
# Utility functions
#####################################################################################

"""
    getDelaunayNeighbors(obj::AgentPointDelaunayObject, i::Int)

Get an iterator over the Delaunay neighbors of point i.

Example:
```julia
for j in getDelaunayNeighbors(obj, i)
    # j is a Delaunay neighbor of i
end
```
"""
function getDelaunayNeighbors(obj::AgentPointDelaunayObject, i::Int)
    return iterateRow(obj.topo[:n, :n], i)
end
