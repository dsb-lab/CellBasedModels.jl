"""
Fill volume with spheres of certain radius. 

In brief, the model generates a box with spheres in hexagonal packaging, removes the ones outside the volume. 
The positions are perturbed by the noise term and finally the system is left to relax by a simple particle model.

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
function fillVolumeSpheres(f,box,rr;N=NaN,noise=0.1,platform="cpu")
        
    r = rr*0.9
    volumeX, volumeY, volumeZ = latticeCompactHexagonal(box,r,noiseRatio=noise) 

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
    
    #Model relax
    relax!(volumeX, volumeY, volumeZ, rr, noise, platform)

    #Remove exceding cells after relaxation
    if N != NaN
        l = length(volumeX)
        while length(volumeX) > N
            rem = rand(1:length(volumeX),l-N)
            nrem = [i for i in 1:l if !(i in rem)]
            volumeX = volumeX[nrem]; volumeY = volumeY[nrem]; volumeZ = volumeZ[nrem];
            l = length(volumeX)
        end
    end    
    
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
    com[:nn] = 1
    
    counter = 10

    c = model.evolve(com,dt=0.1,tMax=20.,tSaveStep=19.9)
    com = c[end]
    f = maximum(sqrt.(com[:fx].^2+com[:fy].^2+com[:fz].^2))
    while f > 0.001 && counter > 0
        c = model.evolve(com,dt=0.1,tMax=20.,tSaveStep=19.9)
        com = c[end]
        f = maximum(sqrt.(com[:fx].^2+com[:fy].^2+com[:fz].^2))

        counter -= 1
    end

    volumeX .= c[end][:x]
    volumeY .= c[end][:y]
    volumeZ .= c[end][:z]
    
    return nothing

end