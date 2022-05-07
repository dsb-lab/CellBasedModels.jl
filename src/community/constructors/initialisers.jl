acceptAll(x) = true

"""
    function initialiseCommunityCompactHexagonal(model,box,r;fExtrude=acceptAll,N=NaN,mediumN::Array{Int,1}=Array{Int,1}([]))

Create Community object with the positions of the agents in positioned in volume in hexagonal packing.

# Args 
 - **model** Compiled agent based model
 - **box** Maximum box where to fill the spheres.
 - **r** Radius of the spheres

# KwArgs
 - **fExtrude=acceptAll** Function that returns true if center of the sphere is inside the volume. Helpts to define non-cubic shapes
 - **N=NaN** Maximum number of particles inside the volume. If NaN, there is not upper bound.
 - **mediumN::Array{Int,1}=Array{Int,1}([])** Grid dimensions of medium if Medium is declared.
"""
function initialiseCommunityCompactHexagonal(model,box,r;fExtrude::Function=acceptAll,N=NaN,mediumN::Array{Int,1}=Array{Int,1}([]))

    if model.agent.dims != 3
        error("Initialiser only works with 3D models.")
    end

    X = compactHexagonal(box,r)

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

"""
    function initialiseCommunityCompactCubic(model,box,r;fExtrude=acceptAll,N=NaN,mediumN::Array{Int,1}=Array{Int,1}([]))

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
function initialiseCommunityCompactCubic(model,box,r;fExtrude=acceptAll,N=NaN,mediumN::Array{Int,1}=Array{Int,1}([]))

    if model.agent.dims != 3
        error("Initialiser only works with 3D models.")
    end

    X = cubic(box,r)

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