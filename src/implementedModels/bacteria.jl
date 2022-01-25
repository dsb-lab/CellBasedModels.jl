"""
Bacterial model of pysical interactions.

Bacterial cells are implemented as rod shape like bacteria. The model is implemented in https://www.pnas.org/content/105/40/15346.

Parameters:

vx,vy (Local): Velocity of the center of mass in the x,y directions
theta (Local): orientation of the rod along the symmetry axis
ω (Local): Angular velocity
d (Local): Diameter of the cylinder
l (Local): Length of the cylinder
m (Local): Mass of the cylinder
fx,fy (LocalInteraction): Forces in the x,y directions
W (LocalInteraction): Angular momentum
kn (Global): Strength of repulsion
γn (Global): Material coefficient tangential
γt (Global): Material coefficient tangential
μcc (Global): Friction coefficient of cell-cell
β (Global): Fricction coeficient
βω (Global): Angular friction coefficient

For more details check the paper of the Documentation on the Models section.
"""
Bacteria2D = @agent(2,
[vx,vy,theta,ω,d,l,m]::Local, #Local parameters
[fx,fy,W]::LocalInteraction,    #Local Interaction Parameters
[kn,γn,γt,μcc,β,βω]::Global,#Global parameters

UpdateInteraction = begin
    #Compute distance between centers of mass
    dAux = sqrt((x.i-x.j)^2+(y.i-y.j)^2)
    xiAux = 0; xjAux = 0; yiAux = 0; yjAux = 0; #Declare them in the global scope
    if dAux > 0 && dAux < (l.i+d.i+l.j+d.j)/2
        if abs(sin(theta.i-theta.j))>0.001 #If not aligned
            #Compute intersecting point of the extended direction
            cxAux = (x.i-x.j)
            cyAux = (y.i-y.j)
            normAux = cos(theta.i)*sin(theta.j)-sin(theta.i)*cos(theta.j)
            scaleAux = (-sin(theta.j)*cxAux+cos(theta.j)*cyAux)/normAux
            pxAux = scaleAux*cos(theta.i)+x.i
            pyAux = scaleAux*sin(theta.i)+y.i
            
            #Compute distance from mass center of both rods
            di = sqrt((x.i-pxAux)^2+(y.i-pyAux)^2)
            dj = sqrt((x.j-pxAux)^2+(y.j-pyAux)^2)

            if di<=l.i/2 && dj<=l.j/2 #Case that the intersecting point lies inside both rods
                if di != 0
                    dxi = (pxAux-x.i)/di
                    dyi = (pyAux-y.i)/di
                    xiAux = .9999*min(di,l.i/2)*dxi+x.i
                    yiAux = .9999*min(di,l.i/2)*dyi+y.i
                else
                    xiAux = x.i
                    yiAux = y.i
                end

                if dj != 0
                    dxj = (pxAux-x.j)/dj
                    dyj = (pyAux-y.j)/dj
                    xjAux = .9999*min(dj,l.j/2)*dxj+x.j
                    yjAux = .9999*min(dj,l.j/2)*dyj+y.j
                else
                    xjAux = x.j
                    yjAux = y.j
                end
            elseif di>l.i/2 #Case that the intersecting point inside second rod
                #Compute position of the tip of the rod 1
                dxi = (pxAux-x.i)/di
                dyi = (pyAux-y.i)/di
                xiAux = l.i/2*dxi+x.i
                yiAux = l.i/2*dyi+y.i                            
                #Compute closest point over the line axis of the other rod
                cx = x.j-xiAux
                cy = y.j-yiAux
                xjAux = (sin(theta.j)*cx-cos(theta.j)*cy)*sin(theta.j)+xiAux
                yjAux = -(sin(theta.j)*cx-cos(theta.j)*cy)*cos(theta.j)+yiAux
                #Compute distance to center of the other rod
                dj = sqrt((x.j-xjAux)^2+(y.j-yjAux)^2)
            elseif dj>l.j/2 #Case that the intersecting point inside first rod
                #Compute position of the tip of the rod 1
                dxj = (pxAux-x.j)/dj
                dyj = (pyAux-y.j)/dj
                xjAux = l.j/2*dxj+x.j
                yjAux = l.j/2*dyj+y.j                            
                #Compute closest point over the line axis of the other rod
                cx = x.i-xjAux
                cy = y.i-yjAux
                xiAux = (sin(theta.i)*cx-cos(theta.i)*cy)*sin(theta.i)+xjAux
                yiAux = -(sin(theta.i)*cx-cos(theta.i)*cy)*cos(theta.i)+yjAux
                #Compute distance to center of the other rod
                di = sqrt((x.i-xiAux)^2+(y.i-yiAux)^2)
            else  #Case that the intersecting point lies outside both rods
                #Compute position of the tip of the rod 1
                dxi = (pxAux-x.i)/di
                dyi = (pyAux-y.i)/di
                xiAux = l.i/2*dxi+x.i
                yiAux = l.i/2*dyi+y.i                            
                #Compute closest point over the line axis of the other rod
                cx = x.j-xiAux
                cy = y.j-yiAux
                xjAux = -(-cos(theta.j)*cx-sin(theta.j)*cy)*sin(theta.j)+xiAux
                yjAux = (-cos(theta.j)*cx-sin(theta.j)*cy)*cos(theta.j)+yiAux
                #Compute distance to center of the other rod
                dj = sqrt((x.j-xjAux)^2+(y.j-yjAux)^2)
                if dj>=l.j/2 #If the projected point outside the rod 2, we compute the other projection
                    #Compute position of the tip of the rod 1
                    dxj = (pxAux-x.j)/di
                    dyj = (pyAux-y.j)/di
                    xjAux = l.j/2*dxj+x.j
                    yjAux = l.j/2*dyj+y.j                            
                    #Compute closest point over the line axis of the other rod
                    cx = x.i-xjAux
                    cy = y.i-yjAux
                    xiAux = (-cos(theta.i)*cx-sin(theta.i)*cy)*sin(theta.i)+xjAux
                    yiAux = -(-cos(theta.i)*cx-sin(theta.i)*cy)*cos(theta.i)+yjAux
                end
            end
        else #If aligned
            xiAux = 0.99*sign(x.j-x.i)*min(abs(x.j-x.i)/2,l.i/2)*cos(theta.i)+x.i
            yiAux = 0.99*sign(y.j-y.i)*min(abs(y.j-y.i)/2,l.i/2)*sin(theta.i)+y.i
            xjAux = 0.99*sign(x.i-x.j)*min(abs(x.j-x.i)/2,l.j/2)*cos(theta.j)+x.j
            yjAux = 0.99*sign(y.i-y.j)*min(abs(y.j-y.i)/2,l.j/2)*sin(theta.j)+y.j         
        end

        #Compute distance between virtual spheres
        rij = sqrt((xiAux-xjAux)^2 +(yiAux-yjAux)^2)
        if rij > 0 && rij < d.i #If it is smaller than a diameter
            #Compute auxiliar
            δAux = d.i - rij
            MeAux = m.i/2
            #Compute interaction
            nijx = (xiAux-xjAux)/rij
            nijy = (yiAux-yjAux)/rij
            vijx = (vx.i-vx.j)
            vijy = (vy.i-vy.j)
            #Compute inner product
            vnAux = nijx*vijx+nijy*vijy
            #Compute normal and tangential forces
            FnAux = kn*δAux^1.5-γn*MeAux*δAux*vnAux
            FtAux = -min(γt*MeAux*δAux^.5,μcc*FnAux)
            #Compute the interaction forces
            Fijx = FnAux*nijx + FtAux*(vijx-vnAux*nijx)
            Fijy = FnAux*nijy + FtAux*(vijy-vnAux*nijy)
            #Append the interaction forces
            fx.i += Fijx
            fy.i += Fijy
            #Append radial forces
            W.i += ((xiAux-x.i)*Fijy - (yiAux-y.i)*Fijx)
        end
    end
end,

UpdateVariable = begin
    d(x) = vx*dt
    d(y) = vy*dt
    d(vx) = -β*vx*dt+fx/m*dt
    d(vy) = -β*vy*dt+fy/m*dt
    d(ω) = W/(m*(d+l)^2/12+m*d^2)*dt-βω*ω*dt
    d(theta) = ω*dt
end,

UpdateLocal = begin #Bound cells
    if theta < -π/2
        theta += π
    elseif theta > π/2
        theta -= π
    end
end
);


"""
Bacterial model of pysical interactions within a 2D channel where the Y-axis boundaries are closed and agents leaving the X-axis are removed.

Bacterial cells are implemented as rod shape like bacteria. The model is implemented in https://www.pnas.org/content/105/40/15346.

Parameters:

vx,vy (Local): Velocity of the center of mass in the x,y directions
theta (Local): orientation of the rod along the symmetry axis
ω (Local): Angular velocity
d (Local): Diameter of the cylinder
l (Local): Length of the cylinder
m (Local): Mass of the cylinder
fx,fy (LocalInteraction): Forces in the x,y directions
W (LocalInteraction): Angular momentum
kn (Global): Strength of repulsion
γn (Global): Material coefficient tangential
γt (Global): Material coefficient tangential
μcc (Global): Friction coefficient of cell-cell
μcw (Global): Friction coefficient of cell-wall
β (Global): Fricction coeficient
βω (Global): Angular friction coefficient

For more details check the paper of the Documentation on the Models section.
"""
Bacteria2DChannel = @agent(2,

μcw::Global,
#Add boundary characteristics
UpdateVariable=begin
    #Boundary conditions in y
    xiAux = 0; yiAux = 0; xjAux=0; yjAux=0; #Declare them in the global scope
    if y + l/2 + d/2 > simulationBox[2,2] || y - l/2 - d/2 < simulationBox[2,1] #In the upper boundary region
        signAux = -1; yjAux = simulationBox[2,1]
        if y + l/2 + d/2 > simulationBox[2,2] 
            signAux = +1
            yjAux = simulationBox[2,2]
        end
        if abs(sin(theta)) > .0001 #If is some angle against the wall
            a = sin(theta)
            xiAux = x + signAux*sign(a)*cos(theta)*l/2
            yiAux = y + signAux*abs(a)*l/2
        else #Otherwise
            xiAux = x
            yiAux = y
        end

        if yiAux >= simulationBox[2,2] || yiAux <= simulationBox[2,1]#If the bead has surpassed the axis
            xjAux = xiAux
            yjAux = yiAux+signAux*0.00001
        else
            xjAux = xiAux
        end

#println(y," ",xiAux," ",yiAux," ",xjAux," ",yjAux)

        #Compute distance between virtual spheres
        rij = sqrt((xiAux-xjAux)^2 +(yiAux-yjAux)^2)
        if rij > 0 && rij < d #If it is smaller than a diameter
            #Compute auxiliar
            δAux = d - rij
            MeAux = m.i/2
            #Compute interaction
            nijx = (xiAux-xjAux)/rij
            nijy = (yiAux-yjAux)/rij
            vijx = vx
            vijy = vy
            #Compute inner product
            vnAux = nijx*vijx+nijy*vijy
            #Compute normal and tangential forces
            FnAux = kn*δAux^1.5-γn*MeAux*δAux*vnAux
            FtAux = -min(γt*MeAux*δAux^.5,μcw*FnAux)
            #Compute the interaction forces
            Fijx = FnAux*nijx + FtAux*(vijx-vnAux*nijx)
            Fijy = FnAux*nijy + FtAux*(vijy-vnAux*nijy)
            #Append the interaction forces
            Fx += Fijx
            Fy += Fijy
            #Append radial forces
            W += ((xiAux-x)*Fijy - (yiAux-y)*Fijx)
        end
     end
end,

UpdateLocal = begin
    if x < simulationBox[1,1] || x > simulationBox[1,2]
        removeAgent()
    end
end,

AgentBasedModels.Models.Bacteria2D::BaseModel #Put the other first as I want it to be computed before the motion equations
)