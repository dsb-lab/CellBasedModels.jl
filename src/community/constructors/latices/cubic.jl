"""
Make a lattice with cubic structure.

# Arguments

 - **box** (Array) 3D Box to be filled with spheres of radius r. e.g. [[0,1],[1,2],[0,4]]
 - **r** (Number) Radius of the sphere

# Optional keyword arguments
 - **noiseRatio** (Number) Noise ratio to add to the center of the cells. Default 0.
 - **holesRatio** (Number) Probability of holes in lattice. Default 0.

# Returns
[posX,posY,posZ] Where pos are arrays with the positions of the cells for each component.
"""
function cubic(box::Array{<:Real,2},r::Number)

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

