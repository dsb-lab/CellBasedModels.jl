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
function latticeCubic(box::Array{Array{Float64,1},1},r::Number;noiseRatio::Number=0.,holesRatio::Number=0)

    d = length(box)
    if !(d in [1,2,3])
        error("Incompatible number of dimensions ", d)
    end

    #Make first dimension
    lineX = Array(box[1][1]:2*r:box[1][2])

    #Make second dimension
    if d > 1
        lineY = fill(box[2][1]+r,length(lineX))
        nY = ceil(Int,(box[2][2]-box[2][1])/(2*r))
        areaX = Float64[]
        areaY = Float64[]
        dx = 2*r
        dy = 2*r
        for i in 0:nY-1
            append!(areaX,lineX)
            append!(areaY,lineY.+dy*i)
        end
    end

    #Make third dimension
    if d == 3
        areaZ = fill(box[2][1]+r,length(areaX))
        nZ = ceil(Int,(box[3][2]-box[3][1])/(2*r))
        volumeX = Float64[]
        volumeY = Float64[]
        volumeZ = Float64[]
        dy = 2*r
        dz = 2*r
        for i in 0:nZ-1
            append!(volumeX,areaX)
            append!(volumeY,areaY)
            append!(volumeZ,areaZ.+dz*i)
        end    
    end

    #Add noise
    if noiseRatio > 0
        dist = Normal(0,r*noiseRatio)
        if d == 1
            n = length(lineX)
            lineX += rand(dist,n); 
        elseif d == 2
            n = length(areaX)
            areaX += rand(dist,n); 
            areaY += rand(dist,n);
        else
            n = length(volumeX)
            volumeX += rand(dist,n)
            volumeY += rand(dist,n); 
            volumeZ += rand(dist,n) 
        end
    end

    #Add holes
    if holesRatio > 0
        if d == 1
            l = rand(length(lineX))
            l = l .> holesRatio
        
            lineX = lineX[l]
        elseif d == 2
            l = rand(length(areaX))
            l = l .> holesRatio
        
            areaX = areaX[l]
            areaY = areaY[l]
        else
            l = rand(length(volumeX))
            l = l .> holesRatio
        
            volumeX = volumeX[l]
            volumeY = volumeY[l]
            volumeZ = volumeZ[l]
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

