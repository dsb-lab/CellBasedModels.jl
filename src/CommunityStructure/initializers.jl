##############################################################################################################################
# Extrude
##############################################################################################################################

"""
Remove all points that are not inside a specified volume.

# Arguments
 - **xyz** (Array{Array{Any}}) Array containing all the list of position parameters.
 - **f** (Function) Function that returns true if the position is inside the volume.
 
# Returns
Array{Array{Any}} Extruded points.
"""
function extrude(xyz,f::Function)
    l = f(xyz...)
    xyzAux = []
    for i in xyz
        push!(xyzAux,copy(i[l]))
    end

    return xyzAux
end

"""
Remove all points that are not inside a specified volume.

# Arguments
 - **com** (Community) Community to extrude.
 - **f** (Function) Function that returns true if the position is inside the volume.
 
# Returns
nothing
"""
function extrude!(com::Community,f::Function)

    x = com.loc[:,1:com.dims]
    l = f(x)

    if size(com.var)[2] > 0
        com.var = com.var[l,:]
    end
    if size(com.inter)[2] > 0
        com.inter = com.inter[l,:]
    end
    if size(com.loc)[2] > 0
        com.loc = com.loc[l,:]
    end
    if size(com.locInter)[2] > 0
        com.locInter = com.locInter[l,:]
    end
    if size(com.ids)[2] > 0
        com.ids = com.ids[l,:]
    end
    com.N = sum(l)

    return 
end

##############################################################################################################################
# Community initializers
##############################################################################################################################
acceptAll(x) = true

"""
    compactHexagonal(box::Array{<:Real,2},r::Number)

Make a 3D lattice with hexagonal structure.

# Args

 - **box::Array{<:Real,2}**: 3D Box to be filled with spheres of radius r. e.g. [[0,1],[1,2],[0,4]]
 - **r::Number**: Radius of the sphere

# Return
    `Comunnity` object with the spheres
"""
function compactHexagonalPackaging(box::Array{<:Real,2},r::Number)

    d = size(box)
    if d != (3,2)
        error("Incompatible number of dimensions ", d)
    end

    #Make first dimension
    lineX = Array(box[1,1]:2*r:box[1,2])

    #Make second dimension
    lineY = fill(box[2,1]+r,length(lineX))
    nY = ceil(INT,(box[2,2]-box[2,1])/(4*sin(pi/3)*r))
    areaX = zeros(FLOAT,1)
    areaY = zeros(FLOAT,1)
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
    nZ = ceil(INT,(box[3,2]-box[3,1])/(4*sin(pi/3)*r))
    volumeX = zeros(FLOAT,1)
    volumeY = zeros(FLOAT,1)
    volumeZ = zeros(FLOAT,1)
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
    cubic(box::Array{<:Real,2},r::Number)

Make a 3D lattice with cubic structure.

# Args

 - **box::Array{<:Real,2}**: 3D Box to be filled with spheres of radius r. e.g. [[0,1],[1,2],[0,4]]
 - **r::Number**: Radius of the sphere

# Return
    `Comunnity` object with the spheres
"""
function cubicPackaging(box::Array{<:Real,2},r::Number)

    d = size(box)
    if d != (3,2)
        error("Incompatible number of dimensions ", d)
    end

    #Make first dimension
    lineX = Array(box[1,1]:2*r:box[1,2])

    #Make second dimension
    lineY = fill(box[2,1]+r,length(lineX))
    nY = ceil(INT,(box[2,2]-box[2,1])/(2*r))
    areaX = zeros(FLOAT,1)
    areaY = zeros(FLOAT,1)
    dx = 2*r
    dy = 2*r
    for i in 0:nY-1
        append!(areaX,lineX)
        append!(areaY,lineY.+dy*i)
    end

    #Make third dimension
    areaZ = fill(box[2,1]+r,length(areaX))
    nZ = ceil(INT,(box[3,2]-box[3,1])/(2*r))
    volumeX = zeros(FLOAT,1)
    volumeY = zeros(FLOAT,1)
    volumeZ = zeros(FLOAT,1)
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
    function initializeCommunityCompactCubic(model,box,r;fExtrude=acceptAll,N=NaN,mediumN::Array{Int,1}=Array{Int,1}([]))

Create Community object with the positions of the agents in positioned in volume in cubic packing.

# Args 
 - **model** Compiled agent based model
 - **box** Maximum box where to fill the spheres.
 - **r** Radius of the spheres

# KwArgs
 - **fExtrude=acceptAll** Function that returns true if center of the sphere is inside the volume. Helpts to define non-cubic shapes
 - **N=NaN** Maximum number of particles inside the volume. If NaN, there is not upper bound.
 - **mediumN::Array{Int,1}=Array{Int,1}([])** Grid dimensions of medium if Medium is declared.
"""
function initializeCommunity(model,box,r;packaging::Function,fExtrude=acceptAll,args...)

    if model.agent.dims != 3
        error("Initializer only works with 3D models.")
    elseif :N in keys(args)
        error("For shape initialization, no packaging is needed.")
    end

    X = packaging(box,r)

    #Extrude
    ext = fExtrude.([X[i,:] for i in 1:size(X)[1]])
    X = X[ext,:]

    #Remove exceding cells
    if N != NaN
        l = size(X)[1]
        while size(X)[1] > N
            rem = rand(1:length(volumeX),l-N)
            nrem = [i for i in 1:l if !(i in rem)]
            X = X[nrem,:];
            l = size(X)[1]
        end
    end    
        
    com = Community(model,N=size(X)[1],mediumN=mediumN)
    com.x = X[:,1]
    com.y = X[:,2]
    com.z = X[:,3]

    return com
end