##############################################################################################################################
# Extrude
##############################################################################################################################

"""
    function removePositions(xyz,f::Function)

Remove all points that do not follow the rule `f` (`true` if inside, `false` if outside).
Returns points that are kept.
"""
function removePositions(xyz,f::Function)
    l = f(xyz...)
    xyzAux = []
    for i in xyz
        push!(xyzAux,copy(i[l]))
    end

    return xyzAux
end

##############################################################################################################################
# Community initializers
##############################################################################################################################
acceptAll(x) = true

"""
    packagingCompactHexagonal(box::Array{<:Real,2},r::Number)

Make a 3D hexagonal lattice filled with spheres of radius `r`.
"""
function packagingCompactHexagonal(box::Array{<:Real,2},r::Number)

    d = size(box)
    if d != (3,2)
        error("Incompatible box shape ", d, ". Expected (3,2)")
    end

    #Make first dimension
    lineX = Array(box[1,1]:2*r:box[1,2])

    #Make second dimension
    lineY = fill(box[2,1]+r,length(lineX))
    nY = ceil(Int64,(box[2,2]-box[2,1])/(4*sin(pi/3)*r))
    areaX = zeros(Float64,1)
    areaY = zeros(Float64,1)
    dx = 2*r*cos(pi/3)
    dy = 2*r*sin(pi/3)
    for i in 0:nY-1
        append!(areaX,lineX)
        append!(areaX,lineX.+dx)

        append!(areaY,lineY.+dy*2*i)
        append!(areaY,lineY.+dy*2*i.+dy)
    end

    #Make third dimension
    areaZ = fill(box[2,1]+r,length(areaX))
    nZ = ceil(Int64,(box[3,2]-box[3,1])/(4*sin(pi/3)*r))
    volumeX = zeros(Float64,1)
    volumeY = zeros(Float64,1)
    volumeZ = zeros(Float64,1)
    dy = 2*r/2/cos(pi/6)
    dz = 2*sqrt(2/3)*r
    for i in 0:nZ-1
        append!(volumeX,areaX)
        append!(volumeX,areaX)

        append!(volumeY,areaY)
        append!(volumeY,areaY.+dy)

        append!(volumeZ,areaZ.+dz*2*i)
        append!(volumeZ,areaZ.+dz*2*i.+dz)  
    end

    #Return
    return [volumeX volumeY volumeZ]

end

"""
    packagingCubic(box::Array{<:Real,2},r::Number)

Make a 3D cubic lattice filled with spheres of radius `r`.
"""
function packagingCubic(box::Array{<:Real,2},r::Number)

    d = size(box)
    if d != (3,2)
        error("Incompatible box shape ", d, ". Expected (3,2)")
    end

    #Make first dimension
    lineX = Array(box[1,1]:2*r:box[1,2])

    #Make second dimension
    lineY = fill(box[2,1]+r,length(lineX))
    nY = ceil(Int64,(box[2,2]-box[2,1])/(2*r))
    areaX = zeros(Float64,1)
    areaY = zeros(Float64,1)
    dx = 2*r
    dy = 2*r
    for i in 0:nY-1
        append!(areaX,lineX)
        append!(areaY,lineY.+dy*i)
    end

    #Make third dimension
    areaZ = fill(box[2,1]+r,length(areaX))
    nZ = ceil(Int64,(box[3,2]-box[3,1])/(2*r))
    volumeX = zeros(Float64,1)
    volumeY = zeros(Float64,1)
    volumeZ = zeros(Float64,1)
    dy = 2*r
    dz = 2*r
    for i in 0:nZ-1
        append!(volumeX,areaX)
        append!(volumeY,areaY)
        append!(volumeZ,areaZ.+dz*i)
    end    

    #Return
    return [volumeX volumeY volumeZ]

end

"""
    function initializeCommunity(model,box,r;packaging::Function,fExtrude=acceptAll,args...)

Create Community object with the positions of the agents in positioned in an specific packing.

||Name|Description|
|Args| model | Sgent based model. |
||box| Maximum box to fill by spheres. |
||r| Radius of the spheres. |
|KwArgs|packaging:Function|Method of packaging of the spheres. (See packaging methods)|
||fExtrude|Function that given an array of positions, returns true for positions that want to be kept.|
||args...|Arguments to be passed to Community structure for initialization (except `N`)|
"""
function initializeSpheresCommunity(model,box,r;packaging::Function,fExtrude=acceptAll,args...)

    if :N in keys(args)
        error("For shape initialization, no N has to be passed.")
    end

    X = packaging(box,r)

    #Extrude
    ext = fExtrude.([X[i,:] for i in 1:size(X)[1]])
    X = X[ext,:]
        
    com = Community(model,N=[size(X)[1]],args...)
    if com.agent.dims > 0
        com.x = X[:,1]
    end
    if com.agent.dims > 1
        com.y = X[:,2]
    end
    if com.agent.dims > 2
        com.z = X[:,3]
    end

    return com
end