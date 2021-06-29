function randomSphereFilling(volume,r,seed)

    #Create emptyobjects
    frontSpheresQueue = []
    assemblyList = []
    gridIndex = []
    prevRejectedQueue = []
    newlyRejectedQueue = []
    δbox = 3*r

    #Create seed spheres
    ##First
    push!(frontSpheresQueue,seed)
    push!(assemblyList,seed)
    push!(gridIndex,seed)
    ##Second
    v = rand(Normal(0,1),3)
    v ./= sqrt(sum(v.^2))
    pos2 = seed .+ 2*r .*v
    push!(frontSpheresQueue,pos2)
    push!(assemblyList,pos2)
    push!(gridIndex,pos2)
    ##Third
    mid = seed .+ r .*v
    if v[1] != 0 || v[2] != 0 #Make first orthogonal vector
        orth1 = [v[2],-v[1],0]
    else
        orth1 = [0,v[3],-v[2]]
    end
    orth1 ./= sqrt(sum(orth1.^2))
    orth2 = cross(v,orth1)
    v = rand(Normal(0,1)).*orth1 + rand(Normal(0,1)).*orth2
    v ./= sqrt(sum(v.^2))
    pos2 = mid .+ 2*r*cos(pi/6) .*v
    push!(frontSpheresQueue,pos2)
    push!(assemblyList,pos2)
    push!(gridIndex,pos2)    

    #while loop
    while !isempty(frontSpheresQueue)
        #Retrieve one active sphere
        currentSphere = frontSpheresQueue[1]
        #Add neighbour Spheres to currect sphere
        neighboringSpheres = []
        for s in gridIndex
            if sqrt(sum((s-currentSphere).^2)) <= δbox
                push!(neighboringSpheres,s)
            end
        end
        #Candidate point list

    end

    return
end