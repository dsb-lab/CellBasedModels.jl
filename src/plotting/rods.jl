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

"""
    function videoRods(fig, comt; save, 
        color = (x) -> x.theta, 
        colorrange=[0,1], 
        framerate=30, 
        sampling=2:1:length(comt))
    )

Function that makes a recording of the rods.
"""
function videoRods(fig, comt; save, 
                color = (x) -> x.theta, 
                colorrange=[0,1], 
                framerate=30, 
                sampling=2:1:length(comt))

    #Make mesh object for the base of the rod.
    c = GLMakie.Cylinder(GLMakie.Point3f(0,0,0),GLMakie.Point3f(1,0,0),Float32(1))

    t = sampling[1]

    x = GLMakie.Observable(zeros(comt[t].N))
    y = GLMakie.Observable(zeros(comt[t].N))
    z = GLMakie.Observable(zeros(comt[t].N))
    col = GLMakie.Observable(zeros(comt[t].N))
    rot = GLMakie.Observable(comt[t].theta[:,1])
    p = GLMakie.Observable([])
    xp = GLMakie.Observable(zeros(comt[t].N*2))
    yp = GLMakie.Observable(zeros(comt[t].N*2))
    zp = GLMakie.Observable(zeros(comt[t].N*2))
    col2 = GLMakie.Observable(zeros(comt[t].N*2))

    p = GLMakie.Observable([])
    l = comt[t].l
    d = comt[t].d
    xx = comt[t].x
    yy = comt[t].y
    theta = comt[t].theta[:,1]
    col[] = color(comt[t])
    col2[] = [col[];col[]]
    for i in 1:comt[t].N
        push!(p[], GLMakie.Point3f(l[i],d[i]/2,1))
        x[][i] = xx[i]-l[i]/2*cos(theta[i])
        z[][i] = yy[i]-l[i]/2*sin(theta[i])
        xp[][i] = xx[i]-l[i]/2*cos(theta[i])
        yp[][i] = yy[i]-l[i]/2*sin(theta[i])    
        xp[][i+comt[t].N] = xx[i]+l[i]/2*cos(theta[i])
        yp[][i+comt[t].N] = yy[i]+l[i]/2*sin(theta[i])    
    end

    ax = GLMakie.Axis3(fig[1,1],aspect = :data, elevation=π/2, azimuth=0)
    GLMakie.meshscatter!(ax,x,y,z,marker=c,markersize=p,rotations=rot,color=col,colorrange=colorrange)
    GLMakie.meshscatter!(ax,xp,yp,zp,markersize=.5,color=col2,colorrange=colorrange)
    GLMakie.xlims!(ax,com.simulationBox[1,1],com.simulationBox[1,2])
    GLMakie.ylims!(ax,com.simulationBox[2,1],com.simulationBox[2,2])

    GLMakie.record(fig,save,sampling[2:end],framerate=framerate) do frame
       t = frame
       p.val = []
       x.val = zeros(comt[t].N)
       y.val = zeros(comt[t].N)
       z.val = zeros(comt[t].N)
       rot.val = comt[t].theta[:,1] 
       xp.val = zeros(comt[t].N*2)
       yp.val = zeros(comt[t].N*2)
       zp.val = zeros(comt[t].N*2)
       l = comt[t].l
       d = comt[t].d
       xx = comt[t].x
       yy = comt[t].y
       theta = comt[t].theta[:,1]
       col.val = color(comt[t])
       zip.val = 2 .*ones(comt[t].N*2)
       col2.val = [col.val;col.val]
       for i in 1:comt[t].N
        push!(p.val, GLMakie.Point3f(l[i],d[i]/2,1))
          x.val[i] = xx[i]-l[i]/2*cos(theta[i])
          y.val[i] = yy[i]-l[i]/2*sin(theta[i])
          xp.val[i] = xx[i]-l[i]/2*cos(theta[i])
          yp.val[i] = yy[i]-l[i]/2*sin(theta[i])    
          xp.val[i+comt[t].N] = xx[i]+l[i]/2*cos(theta[i])
          yp.val[i+comt[t].N] = yy[i]+l[i]/2*sin(theta[i])  
       end
       GLMakie.notify.((x, y, z, p, rot, xp, yp, zp, col, col2))
    end
end