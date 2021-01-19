function plotCommunitySpheres(com::Community, pos::Array{Symbol}, rad::Symbol)

    x = com[pos[1]]
    y = com[pos[2]]
    z = com[pos[3]]
    r = com[rad]
    
    i=1
    figure = mesh(Sphere(Point3f0([x[i],y[i],z[i]]),r[i]))
    for i in 2:com[:N]
        figure = mesh!(Sphere(Point3f0([x[i],y[i],z[i]]),r[i]))
    end

    return figure

end

function plotCommunitySpheres(com::Community, pos::Array{Symbol}, rad::Symbol, color::Symbol, cmap::String="Reds")

    x = com[pos[1]]
    y = com[pos[2]]
    z = com[pos[3]]
    r = com[rad]
    fate = com[color]
    diff = (maximum(fate)-minimum(fate))
    if diff ≈ 0.
        fate = floor.(Int,99 .*(fate .-minimum(fate))./1).+1
    else
        fate = floor.(Int,99 .*(fate .-minimum(fate))./diff).+1
    end
    color = Array(colormap(cmap))
        
    i=1
    figure = mesh(Sphere(Point3f0([x[i],y[i],z[i]]),r[i]),color=color[fate[i]])
    for i in 2:com[:N]
        figure = mesh!(Sphere(Point3f0([x[i],y[i],z[i]]),r[i]),color=color[fate[i]])
    end
    
    return figure

end