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
    fate = floor.(Int,99 .*(fate .-minimum(fate))./(maximum(fate)-minimum(fate))).+1

    color = Array(colormap(cmap))
        
    i=1
    figure = mesh(Sphere(Point3f0([x[i],y[i],z[i]]),r[i]),color=color[fate[i]])
    for i in 2:com[:N]
        figure = mesh!(Sphere(Point3f0([x[i],y[i],z[i]]),r[i]),color=color[fate[i]])
    end
    
    return figure

end