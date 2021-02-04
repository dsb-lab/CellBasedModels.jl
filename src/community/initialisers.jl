function fillVolumeSpheres(f,box,r;N=NaN,noise=0.1,platform="cpu")
    
    #Make first dimension
    lineX = Array(box[1][1]:r:box[2][1])
    lineY = fill(box[1][2],length(lineX))
    #Make second dimension
    nY = ceil(Int,(box[2][2]-box[1][2])/(2*sin(pi/3)*r))
    areaX = Float64[]
    areaY = Float64[]
    dx = r*cos(pi/3)
    dy = r*sin(pi/3)
    for i in 0:nY-1
        append!(areaX,lineX)
        append!(areaX,lineX.+dx)

        append!(areaY,lineY.+dy*2*i)
        append!(areaY,lineY.+dy*2*i.+dy)
    end
    areaZ = fill(box[1][2],length(areaX))
    #Make third dimension
    nZ = ceil(Int,(box[2][3]-box[1][3])/(2*sin(pi/3)*r))
    volumeX = Float64[]
    volumeY = Float64[]
    volumeZ = Float64[]
    dy = r/2/cos(pi/6)
    dz = sqrt(2/3)*r
    for i in 0:nZ-1
        append!(volumeX,areaX)
        append!(volumeX,areaX)

        append!(volumeY,areaY)
        append!(volumeY,areaY.+dy)

        append!(volumeZ,areaZ.+dz*2*i)
        append!(volumeZ,areaZ.+dz*2*i.+dz)
    end    
    
    #Extrude
    ext = zeros(Bool,length(volumeX))
    for i in 1:length(volumeX)
        ext[i] = f(volumeX[i],volumeY[i],volumeZ[i])
    end
    volumeX = volumeX[ext]; volumeY = volumeY[ext]; volumeZ = volumeZ[ext]; 
    
    #Remove exceding cells
    if N != NaN
        l = length(volumeX)
        while length(volumeX) > N
            rem = rand(1:length(volumeX),l-N)
            nrem = [i for i in 1:l if !(i in rem)]
            volumeX = volumeX[nrem]; volumeY = volumeY[nrem]; volumeZ = volumeZ[nrem];
            l = length(volumeX)
        end
    end
    
    #Add noise
    dist = Normal(0,r^2*noise)
    n = length(volumeX)
    volumeX += rand(dist,n); volumeY += rand(dist,n); volumeZ += rand(dist,n)
    
    #Model relax
    relax!(volumeX, volumeY, volumeZ, r, noise, platform)
        
    return volumeX, volumeY, volumeZ
end

function relax!(volumeX, volumeY, volumeZ, r, n, platform="cpu")
    
    #Community
    if platform == "cpu"
        model = MODEL_BASIC
    else
        model = MODEL_BASIC_GPU
    end

    com = Community(model,N=length(volumeX))
    com[:x] = volumeX
    com[:y] = volumeY
    com[:z] = volumeZ
    com[:D] = 5.
    com[:r] = r
    com[:n] = n
    
    c = model.evolve(com,dt=0.1,tMax_=20.,tSaveStep_=19.9)

    volumeX .= c[last][:x]
    volumeY .= c[last][:y]
    volumeZ .= c[last][:z]
    
    return nothing

end