"""
    function plotCylinders(a::GridPosition,
        com::Community,
        direction::Union{Vector{Symbol},Matrix{<:Real}},
        len::Union{Symbol,Vector{<:Real}},
        radius::Union{Symbol,Vector{<:Real}};
        factor::Real=10,
    )

Function that given a grid position figure form Makie, plots rod-shaped agents over the space and returns the corresponding axis.
"""
function plotCylinders(a::GLMakie.GridPosition,
    com::Community,
    direction::Union{Vector{Symbol},Matrix{<:Real}},
    len::Union{Symbol,Vector{<:Real}},
    radius::Union{Symbol,Vector{<:Real}};
    factor::Real=10,
)

    if com.dims == 2 
        ax = GLMakie.Axis3(a,elevation=.5*π,azimuth=1.5*π,viewmode=:fitzoom,aspect = :data)
    else com.dims == 3
        ax = GLMakie.Axis3(a,viewmode=:fitzoom,aspect = :data)
    end

    for i in range(1,com.N,step=1)
        
        if typeof(direction) == Vector{Symbol}
            if com.dims == 2 
                dir = [getproperty(com,direction[1])[i],getproperty(com,direction[2])[i]]
            else com.dims == 3
                dir = [getproperty(com,direction[1])[i],getproperty(com,direction[2])[i],getproperty(com,direction[3])[i]]
            end        
            dir = dir/sqrt(sum(dir.^2))
        else
            dir = direction[i,:]/sqrt(sum(direction[i,:].^2))
        end
        
        if typeof(len) == Symbol
            l = getproperty(com,len)[i]
        else
            l = len[i]
        end
        
        if com.dims == 2 
            pos = [0,0]
            extreme1 = factor*GeometryBasics.Point((pos+l/2*dir)...)
            extreme2 = factor*GeometryBasics.Point((pos-l/2*dir)...)
        else com.dims == 3
            pos = [0,0,0]
            extreme1 = factor*GeometryBasics.Point((pos+l/2*dir)...)
            extreme2 = factor*GeometryBasics.Point((pos-l/2*dir)...)
        end        
        
        if typeof(radius) == Symbol
            r = factor*getproperty(com,radius)[i]
        else
            r = factor*radius[i]
        end
            
        c = GeometryBasics.Cylinder(extreme1,extreme2,Float64(r))
            
        if com.dims == 2 
            GLMakie.meshscatter!(ax,com.x[i:i],com.y[i:i],zeros(1),color="blue",marker=c)
        else com.dims == 3
            GLMakie.meshscatter!(ax,com.x[i:i],com.y[i:i],com.z[i:i],color="blue",marker=c)
        end  

    end

    return ax
end