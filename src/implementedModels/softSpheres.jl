softSpheres2D = Agent(2,
    
    #Parameters
    globalFloat = [:b,:μ],
    localFloat = [:f0,:m,:r,:vx,:vy],
    localFloatInteraction = [:fx,:fy],
    
    #Mechanics
    updateVariable = quote
        d(vx) = dt( -b*vx/m+fx/m )
        d(vy) = dt( -b*vy/m+fy/m )
        d(x) = dt( vx )
        d(y) = dt( vy )
    end,
    
    updateInteraction = quote
        dij = sqrt((x.i-x.j)^2+(y.i-y.j)^2)
        rij = r.i+r.j
        if dij < μ*rij && dij > 0
            fx.i += f0*(rij/dij-1)*(μ*rij/dij-1)*(x.i-x.j)/dij
            fy.i += f0*(rij/dij-1)*(μ*rij/dij-1)*(y.i-y.j)/dij
        end
    end,

    compile = false
)

softSpheres3D = Agent(3,
    
    #Parameters
    globalFloat = [:b,:μ],
    localFloat = [:f0,:m,:r,:vx,:vy,:vz],
    localFloatInteraction = [:fx,:fy,:fz],
    
    #Mechanics
    updateVariable = quote
        d(vx) = dt( -b*vx/m+fx/m )
        d(vy) = dt( -b*vy/m+fy/m )
        d(vz) = dt( -b*vz/m+fz/m )
        d(x) = dt( vx )
        d(y) = dt( vy )
        d(z) = dt( vz )
    end,
    
    updateInteraction = quote
        dij = sqrt((x.i-x.j)^2+(y.i-y.j)^2+(z.i-z.j)^2)
        rij = r.i+r.j
        if dij < μ*rij && dij > 0
            fx.i += f0*(rij/dij-1)*(μ*rij/dij-1)*(x.i-x.j)/dij
            fy.i += f0*(rij/dij-1)*(μ*rij/dij-1)*(y.i-y.j)/dij
            fz.i += f0*(rij/dij-1)*(μ*rij/dij-1)*(z.i-z.j)/dij   
        end
    end,

    compile = false
)