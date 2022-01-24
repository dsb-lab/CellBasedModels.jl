"""
    function plotRods(a::GridPosition,
        com::Community,
        direction::Union{Vector{Symbol},Matrix{<:Real}},
        len::Union{Symbol,Vector{<:Real}},
        radius::Union{Symbol,Vector{<:Real}};
        color=nothing,
        colorpalette = "RdBu",
        factor::Real=10,
    )

Function that given a grid position figure form Makie, plots rod-shaped agents over the space and returns the corresponding axis.
"""
function plotRods(a::GLMakie.GridPosition,
    com::Community,
    direction::Union{Vector{Symbol},Matrix{<:Real}},
    len::Union{Symbol,Vector{<:Real}},
    radius::Union{Symbol,Vector{<:Real}};
    color=nothing,
    colorpalette = "RdBu",
    factor::Real=1,
)

    if com.dims == 2 
        ax = GLMakie.Axis3(a,elevation=.5*π,azimuth=1.5*π,viewmode=:fitzoom,aspect = :data)
    else com.dims == 3
        ax = GLMakie.Axis3(a,viewmode=:fitzoom,aspect = :data)
    end
    
    if typeof(color) == Symbol
        colorrange = [minimum(getproperty(com,color)),maximum(getproperty(com,color))]
        palette = GLMakie.Colors.colormap(colorpalette)
    elseif typeof(color) <: Vector{<:Real}
        colorrange = [minimum(color),maximum(color)]
        if colorrange[1] == colorrange[2]
            colorrange[1] -= 1
        end
        palette = GLMakie.Colors.colormap(colorpalette)
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
            pos = [com.x[i],com.y[i]]
            extreme1 = factor*GeometryBasics.Point((pos+l/2*dir)...,0)
            extreme2 = factor*GeometryBasics.Point((pos-l/2*dir)...,0)
            
            ax.zticksvisible = false
            ax.ztickformat = ""
            ax.zlabel = ""

        else com.dims == 3
            pos = [com.x[i],com.y[i]com.z[i]]
            extreme1 = factor*GeometryBasics.Point((pos+l/2*dir)...)
            extreme2 = factor*GeometryBasics.Point((pos-l/2*dir)...)
        end        
        
        if typeof(radius) == Symbol
            r = factor*getproperty(com,radius)[i]
        else
            r = factor*radius[i]
        end
            
        ci = GeometryBasics.Cylinder(extreme1,extreme2,Float64(r))
        b1 = GeometryBasics.Sphere(extreme1,Float64(r))
        b2 = GeometryBasics.Sphere(extreme2,Float64(r))

        if color === nothing
            c = "blue"
            GLMakie.mesh!(ax,ci,color=c)
            GLMakie.mesh!(ax,b1,color=c)
            GLMakie.mesh!(ax,b2,color=c)
        elseif typeof(color) == Symbol
            c = getproperty(com,color)[i]
            c = palette[ceil(Int,(c-colorrange[1])/(colorrange[2]-colorrange[1])*99)+1]
            GLMakie.mesh!(ax,ci,color=c)
            GLMakie.mesh!(ax,b1,color=c)
            GLMakie.mesh!(ax,b2,color=c)
        elseif typeof(color) <: Array{<:Real}
            c = color[i]
            c = palette[ceil(Int,(c-colorrange[1])/(colorrange[2]-colorrange[1])*99)+1]
            GLMakie.mesh!(ax,ci,color=c)
            GLMakie.mesh!(ax,b1,color=c)
            GLMakie.mesh!(ax,b2,color=c)
        end
            
    end
        
    return ax
end