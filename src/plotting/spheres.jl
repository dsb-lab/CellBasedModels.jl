"""
    function plotCylinders(a::GridPosition,
        com::Community,
        radius::Union{Symbol,Vector{<:Real}};
        factor::Real=10,
    )

Function that given a grid position figure form Makie, plots spherical agents over the space and returns the corresponding axis.
"""
function plotSpheres(a::GLMakie.GridPosition,
    com::Community,
    radius::Union{Symbol,Vector{<:Real}};
    factor::Real=10,
)

    if com.dims == 2 
        ax = GLMakie.Axis3(a,elevation=.5*π,azimuth=1.5*π,viewmode=:fitzoom,aspect = :data)
    else com.dims == 3
        ax = GLMakie.Axis3(a,viewmode=:fitzoom,aspect = :data)
    end

    for i in range(1,com.N,step=1)
        
        if com.dims == 2 
            pos = [0,0]
            pos = Point(pos...)
        else com.dims == 3
            pos = [0,0,0]
            pos = Point(pos...)
        end        
        
        if typeof(radius) == Symbol
            r = factor*getproperty(com,radius)[i]
        else
            r = radius[i]
        end
            
        c = GeometryBasics.Sphere(pos,Float64(r))
            
        if com.dims == 2 
            GLMakie.meshscatter!(ax,com.x[i:i],com.y[i:i],zeros(1),color="blue",marker=c)
        else com.dims == 3
            GLMakie.meshscatter!(ax,com.x[i:i],com.y[i:i],com.z[i:i],color="blue",marker=c)
        end  

    end

    return ax
end