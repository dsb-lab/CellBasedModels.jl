"""
    function rodForces(
        x,y,d,l,theta,vx,vy,m,
        x2,y2,d2,l2,theta2,vx2,vy2,m2,
        kn,γn,γt,μcc,μcw
    )

Function that return the forces in x and y and the torque force W for the rod model of [Volfson et al.](https://www.pnas.org/content/105/40/15346).

 - `x`: x position of the rod
 - `y`: y position of the rod
 - `d`: diameter of the rod
 - `theta`: angle of the rod in the plane
 - `vx`: velocity of the rod in the x coordinates
 - `vy`: velocity of the rod in the y coordinates
 - `m`: mass of the rod

The same for all the parameters with 2 for the other interacting rod.
Constants are defined in the paper and in the Models section of the documentation.
"""
function rodForces(
    x,y,d,l,theta,vx,vy,m,
    x2,y2,d2,l2,theta2,vx2,vy2,m2,
    kn,γn,γt,μcc,μcw
)

    Fijx = 0.
    Fijy = 0.
    Wij = 0.

    #Function that finds the virtual spheres of contact between both rods
    xiAux,yiAux,xjAux,yjAux = CBMMetrics.rodIntersection(x,y,l,theta,x2,y2,l2,theta2)

    #Compute distance between virtual spheres
    rij = sqrt((xiAux-xjAux)^2 +(yiAux-yjAux)^2)
    if rij > 0. && rij < (d+d2)/2 #If it is smaller than a diameter compute forces
        #Compute auxiliar
        δAux = d - rij
        MeAux = m/2
        #Compute interaction
        nijx = (xiAux-xjAux)/rij
        nijy = (yiAux-yjAux)/rij
        vijx = (vx-vx2)
        vijy = (vy-vy2)
        #Compute inner product
        vnAux = nijx*vijx+nijy*vijy
        #Compute normal and tangential forces
        FnAux = kn*δAux^1.5-γn*MeAux*δAux*vnAux
        FtAux = -min(γt*MeAux*δAux^.5,μcc*FnAux)
        #Compute the interaction forces
        Fijx = FnAux*nijx + FtAux*(vijx-vnAux*nijx)
        Fijy = FnAux*nijy + FtAux*(vijy-vnAux*nijy)
        #Append radial forces
        Wij = ((xiAux-x)*Fijy - (yiAux-y)*Fijx)
    end

    return Fijx, Fijy, Wij

end

rods2D = ABM(2,
    agent = Dict(
            :vx=>Float64,
            :vy=>Float64,
            :theta=>Float64,
            :ω=>Float64,
            :d=>Float64,
            :l=>Float64,
            :m=>Float64,
            :fx=>Float64,
            :fy=>Float64,
            :W=>Float64,
            :pressure=>Float64
        ),    #Local Interaction Parameters

    model = Dict(
            :kn=>Float64,
            :γn=>Float64,
            :γt=>Float64,
            :μcc=>Float64,
            :μcw=>Float64,
            :β=>Float64,
            :βω=>Float64
        ),        #Global parameters

    agentODE = quote

        fx = 0
        fy = 0
        W = 0
        pressure = 0
        @loopOverNeighbors i2 begin

            Fijx, Fijy, Wij = CBMModels.rodForces(
                                    x,y,d,l,theta,vx,vy,m,
                                    x[i2],y[i2],d[i2],l[i2],theta[i2],vx[i2],vy[i2],m[i2],
                                    kn,γn,γt,μcc,μcw
                                )

            #Append the interaction forces
            fx += Fijx
            fy += Fijy
            #Append radial forces
            W += Wij
            #Keep track of preassure in the media
            pressure += sqrt(Fijx^2+Fijy^2)
            
        end

        #Equations
        dt(x) =  vx 
        dt(y) =  vy 
        dt(vx) =  -β*vx+fx/m 
        dt(vy) =  -β*vy+fy/m 
        dt(theta) =  ω 
        dt(ω) =  W/(m*(d+l)^2/12+m*d^2)-βω*ω 
        
    end
);

rods2dGrowth = ABM(2,
    baseModelInit = [rods2D],

    agent = Dict(
                :lTarget => Float64
            ),

    model = Dict(
                :growth=>Float64,
                :σlTarget=>Float64,
                :lMax=>Float64,
                :α=>Float64
            ),

    agentODE = quote
        dt(l) = growth/(1+α*pressure) #linear growth
    end,

    agentRule = quote #Bound cells
        #Add division
        if l > lTarget
            ww = CBMDistributions.uniform(-.1,.1)
            @addAgent(
                    x=(l+d)/4*cos(theta)+x,
                    y=(l+d)/4*sin(theta)+y,
                    l=(l-d)/2,
                    ω = ω+ww,
                    lTarget = CBMDistributions.uniform(lMax-σlTarget,lMax+σlTarget)
                    )
            @addAgent(
                    x=-(l+d)/4*cos(theta)+x,
                    y=-(l+d)/4*sin(theta)+y,
                    l=(l-d)/2,
                    ω = ω-ww,
                    lTarget = CBMDistributions.uniform(lMax-σlTarget,lMax+σlTarget)
                    )
            @removeAgent()
        end
    end,
);