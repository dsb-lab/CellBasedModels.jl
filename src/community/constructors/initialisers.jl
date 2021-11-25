acceptAll(x) = true

"""
Fill volume with spheres of certain radius. 

In brief, the model generates a box with spheres in hexagonal packaging, removes the ones outside the volume. 
The positions are perturbed by the noise term.

# Parameters 
 - **f** (Function) Function that returns true if center of sphere is inside the volume
 - **box** (Array{Float,2}) Maximum box where to fill the volumes.
 - **r** (Number) Radius of the spheres

# Optional keyword parameters

 - **N** (Int) Maximum number of particles inside the volume. If NaN (default), there is not upper bound.
 - **noise** (Number) Noise ratio used to perturb the particles from the hexagonal lattice.
 - **platform** (String) Platform in which perform the relaxation step after the noise perturbation.

# Example
```Julia
julia> using AgentBasedModels;
julia> f(x,y,z) = sqrt(x^2+y^2+z^2) < 10;
julia> pos = fillVolumeSpheres(f,[[-10,-10,-10],[10,10,10]],1,noise=0.25);
```
![Figure](assets/FillVolumeSpheres.png)
Figure rendered with [Makie.jl](https://github.com/JuliaPlots/Makie.jl) using meshscatter function.
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