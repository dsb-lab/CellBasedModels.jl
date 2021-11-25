"""
    function latticeCompactHexagonal(box,r)

Make a lattice with compact hexagonal structure in box with spheres of radius r.

# Returns
[posX,posY,posZ] Where pos are arrays with the positions of the cells for each component.
"""
function compactHexagonal(box::Array{<:Real,2},r::Number)

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

