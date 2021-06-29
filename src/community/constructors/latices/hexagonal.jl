"""
    function latticeCompactHexagonal(box,r)

Make a lattice with compact hexagonal structure in box with spheres of radius r.

# Returns
[posX,posY,posZ] Where pos are arrays with the positions of the cells for each component.
"""
function compactHexagonal(box::Array{Array{Float64,1},1},r::Number)

    d = length(box)
    if !(d in [1,2,3])
        error("Incompatible number of dimensions ", d)
    end

    #Make first dimension
    lineX = Array(box[1][1]:2*r:box[1][2])

    #Make second dimension
    if d > 1
        lineY = fill(box[2][1]+r,length(lineX))
        nY = ceil(Int,(box[2][2]-box[2][1])/(4*sin(pi/3)*r))
        areaX = Float64[]
        areaY = Float64[]
        dx = 2*r*cos(pi/3)
        dy = 2*r*sin(pi/3)
        for i in 0:nY-1
            append!(areaX,lineX)
            append!(areaX,lineX.+dx)

            append!(areaY,lineY.+dy*2*i)
            append!(areaY,lineY.+dy*2*i.+dy)
        end
    end

    #Make third dimension
    if d == 3
        areaZ = fill(box[2][1]+r,length(areaX))
        nZ = ceil(Int,(box[3][2]-box[3][1])/(4*sin(pi/3)*r))
        volumeX = Float64[]
        volumeY = Float64[]
        volumeZ = Float64[]
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
    end

    #Return
    if d == 1
        return lineX
    elseif d == 2
        return areaX, areaY
    else
        return volumeX, volumeY, volumeZ
    end

end

