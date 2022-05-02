"""
Parameters proposed of the Bacterial2DGrowth model.
"""
Bacteria2DParameters = constants = Dict([
    :kn => .0001,
    :γn => 1,
    :γt => 1,
    :μcc => 0.1,
    :μcw => 0.8,
    :β => .5,
    :βω => .1
    ]);

"""
Parameters proposed of the Bacterial2DGrowth model.
"""
Bacteria2DGrowthParameters = Dict([
    :growth => 0.0001,
    :lMax => 3,
    :σLTarget => 1,
    :σTorqueDivision => .01
    ]);

"""
Bacterial model of pysical interactions.

Bacterial cells are implemented as rod shape like bacteria. The model is implemented in https://www.pnas.org/content/105/40/15346.

Parameters:

 - vx,vy (Local): Velocity of the center of mass in the x,y directions
 - theta (Local): orientation of the rod along the symmetry axis
 - ω (Local): Angular velocity
 - d (Local): Diameter of the cylinder
 - l (Local): Length of the cylinder
 - m (Local): Mass of the cylinder
 - fx,fy (LocalInteraction): Forces in the x,y directions
 - W (LocalInteraction): Angular momentum
 - kn (Global): Strength of repulsion
 - γn (Global): Material coefficient tangential
 - γt (Global): Material coefficient tangential
 - μcc (Global): Friction coefficient of cell-cell
 - β (Global): Fricction coeficient
 - βω (Global): Angular friction coefficient

For more details check the paper of the Documentation on the Models section.
"""
Bacteria2D = @agent(2,
[vx,vy,theta,ω,d,l,m]::Local, #Local parameters
[Fx,Fy,W]::LocalInteraction,    #Local Interaction Parameters
[kn,γn,γt,μcc,μcw,β,βω]::Global,#Global parameters

UpdateInteraction = begin
    #Compute distance between centers of mass
    dAux = sqrt((x.i-x.j)^2+(y.i-y.j)^2)
    xiAux = x.i; xjAux = x.j; yiAux = y.i; yjAux = y.j; #Declare them in the global scope
    if dAux > 0 && dAux < (l.i+d.i+l.j+d.j)/2
        #Compute intersecting point of the extended direction
        cxAux = (x.i-x.j)
        cyAux = (y.i-y.j)
        normAux = cos(theta.i)*sin(theta.j)-sin(theta.i)*cos(theta.j)
        if abs(normAux) > 0.0000001
            scaleAux = (-sin(theta.j)*cxAux+cos(theta.j)*cyAux)/normAux
            pxAux = scaleAux*cos(theta.i)+x.i
            pyAux = scaleAux*sin(theta.i)+y.i
        else
            pxAux = x.i+10000*l.i*cos(theta.i)
            pyAux = y.i+10000*l.i*sin(theta.i)
        end
            
        #Compute distance from mass center of both rods
        di = sqrt((x.i-pxAux)^2+(y.i-pyAux)^2)
        dj = sqrt((x.j-pxAux)^2+(y.j-pyAux)^2)

        if di<=l.i/2 && dj<=l.j/2 #Case that the intersecting point lies inside both rods
            if di != 0
                dxi = (pxAux-x.i)/di
                dyi = (pyAux-y.i)/di
                xiAux = .99*min(di,l.i/2)*dxi+x.i
                yiAux = .99*min(di,l.i/2)*dyi+y.i
            else
                xiAux = x.i
                yiAux = y.i
            end

            if dj != 0
                dxj = (pxAux-x.j)/dj
                dyj = (pyAux-y.j)/dj
                xjAux = .99*min(dj,l.j/2)*dxj+x.j
                yjAux = .99*min(dj,l.j/2)*dyj+y.j
            else
                xjAux = x.j
                yjAux = y.j
            end
        elseif di>l.i/2 && dj<=l.j/2 #Case that the intersecting point inside second rod
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
        elseif dj>l.j/2 && di<=l.i/2#Case that the intersecting point inside first rod
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
            xiAux = l.i/2*cos(theta.i)+x.i
            yiAux = l.i/2*sin(theta.i)+y.i       
            #Compute closest point over the line axis of the other rod
            cx = x.j-xiAux
            cy = y.j-yiAux
            xjAux = (sin(theta.j)*cx-cos(theta.j)*cy)*sin(theta.j)+xiAux
            yjAux = -(sin(theta.j)*cx-cos(theta.j)*cy)*cos(theta.j)+yiAux
            dj = sqrt((xjAux-x.j)^2+(yjAux-y.j)^2)
            if dj > l.j/2
                dxj = (xjAux-x.j)/dj
                dyj = (yjAux-y.j)/dj
                xjAux = l.j/2*dxj+x.j
                yjAux = l.j/2*dyj+y.j   
            end
            rij = sqrt((xiAux-xjAux)^2 +(yiAux-yjAux)^2)
        
            xiAux2 = -l.i/2*cos(theta.i)+x.i
            yiAux2 = -l.i/2*sin(theta.i)+y.i       
            #Compute closest point over the line axis of the other rod
            cx = x.j-xiAux2
            cy = y.j-yiAux2
            xjAux2 = (sin(theta.j)*cx-cos(theta.j)*cy)*sin(theta.j)+xiAux2
            yjAux2 = -(sin(theta.j)*cx-cos(theta.j)*cy)*cos(theta.j)+yiAux2
            dj = sqrt((xjAux2-x.j)^2+(yjAux2-y.j)^2)
            if dj > l.j/2
                dxj = (xjAux2-x.j)/dj
                dyj = (yjAux2-y.j)/dj
                xjAux2 = l.j/2*dxj+x.j
                yjAux2 = l.j/2*dyj+y.j   
            end
            rij2 = sqrt((xiAux2-xjAux2)^2 +(yiAux2-yjAux2)^2)
            if rij2 < rij
                xiAux = xiAux2
                xjAux = xjAux2
                yiAux = yiAux2
                yjAux = yjAux2
                rij = rij2
            end

            xjAux2 = l.j/2*cos(theta.j)+x.j
            yjAux2 = l.j/2*sin(theta.j)+y.j       
            #Compute closest point over the line axis of the other rod
            cx = x.i-xjAux2
            cy = y.i-yjAux2
            xiAux2 = (sin(theta.i)*cx-cos(theta.i)*cy)*sin(theta.i)+xjAux2
            yiAux2 = -(sin(theta.i)*cx-cos(theta.i)*cy)*cos(theta.i)+yjAux2
            di = sqrt((xiAux2-x.i)^2+(yiAux2-y.i)^2)
            if di > l.i/2
                dxi = (xiAux2-x.i)/di
                dyi = (yiAux2-y.i)/di
                xiAux2 = l.i/2*dxi+x.i
                yiAux2 = l.i/2*dyi+y.i   
            end
            rij2 = sqrt((xiAux2-xjAux2)^2 +(yiAux2-yjAux2)^2)
            if rij2 < rij
                xiAux = xiAux2
                xjAux = xjAux2
                yiAux = yiAux2
                yjAux = yjAux2
                rij = rij2
            end           
    
            xjAux2 = -l.j/2*cos(theta.j)+x.j
            yjAux2 = -l.j/2*sin(theta.j)+y.j       
            #Compute closest point over the line axis of the other rod
            cx = x.i-xjAux2
            cy = y.i-yjAux2
            xiAux2 = (sin(theta.i)*cx-cos(theta.i)*cy)*sin(theta.i)+xjAux2
            yiAux2 = -(sin(theta.i)*cx-cos(theta.i)*cy)*cos(theta.i)+yjAux2
            di = sqrt((xiAux2-x.i)^2+(yiAux2-y.i)^2)
            if di > l.i/2
                dxi = (xiAux2-x.i)/di
                dyi = (yiAux2-y.i)/di
                xiAux2 = l.i/2*dxi+x.i
                yiAux2 = l.i/2*dyi+y.i   
            end
            rij2 = sqrt((xiAux2-xjAux2)^2 +(yiAux2-yjAux2)^2)
            if rij2 < rij
                xiAux = xiAux2
                xjAux = xjAux2
                yiAux = yiAux2
                yjAux = yjAux2
                rij = rij2
            end  

            if rij < (d.i+d.j)/2
                s = sign((x.j-x.i)*cos(theta.i)+(y.j-y.i)*sin(theta.i))
                Fx.i -= kn*s*(d.i-rij)*cos(theta.i)/2
                Fy.i -= kn*s*(d.i-rij)*sin(theta.i)/2
                Fx.j += kn*s*(d.i-rij)*cos(theta.i)/2
                Fy.j += kn*s*(d.i-rij)*sin(theta.i)/2
            end
        end
    
        #Compute distance between virtual spheres
        rij = sqrt((xiAux-xjAux)^2 +(yiAux-yjAux)^2)
        if rij > 0 && rij < (d.i+d.j)/2 #If it is smaller than a diameter
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
            Fx.i += Fijx/2
            Fy.i += Fijy/2
            #Append radial forces
            W.i += ((xiAux-x.i)*Fijy - (yiAux-y.i)*Fijx)/2
            #Append the interaction forces
            Fx.j -= Fijx/2
            Fy.j -= Fijy/2
            #Append radial forces
            W.j -= ((xiAux-x.i)*Fijy - (yiAux-y.i)*Fijx)/2
        end
    end
end,

UpdateVariable = begin
    d(x) = vx*dt
    d(y) = vy*dt
    d(vx) = -β*vx*dt+Fx/m*dt
    d(vy) = -β*vy*dt+Fy/m*dt
    d(theta) = ω*dt
    d(ω) = W/(m*(d+l)^2/12+m*d^2)*dt-βω*ω*dt
end,
);


"""
Addon to the Bacteria2D model of pysical interactions within a 2D channel where the Y-axis boundaries are closed and agents leaving the X-axis are removed. The model is implemented in https://www.pnas.org/content/105/40/15346.

Add the model before the Bacteria2D model.

    @agent(
        Bacteria2DChannel::BaseModel,
        Bacteria2D::BaseModel
    )

For more details check the paper of the Documentation on the Models section.
"""
Bacteria2DChannel = @agent(2,
    #Add boundary characteristics
    UpdateVariable=begin

            #Boundary conditions in y
            xiAux = x; yiAux = y; xjAux=0; yjAux=0; #Declare them in the global scope
            if y + l/2 + d/2 > simulationBox[2,2] #In the upper boundary region
                a = -sign(sin(theta))
                xiAux = x - a*cos(theta)*l/2
                yiAux = y + abs(sin(theta))*l/2

                if yiAux >= simulationBox[2,2]#If the bead has surpassed the axis
                    xjAux = xiAux
                    yjAux = yiAux+.0001*d
                else
                    xjAux = xiAux
                    yjAux = simulationBox[2,2] + d/2
                end
            end

            #Compute distance between virtual spheres
            rij = sqrt((xiAux-xjAux)^2 +(yiAux-yjAux)^2)
            if rij > 0 && rij < d #If it is smaller than a diameter
                #Compute auxiliar
                δAux = d - rij
                MeAux = m/2
                #Compute interaction
                nijx = (xiAux-xjAux)/rij
                nijy = (yiAux-yjAux)/rij
                vijx = vx
                vijy = vy
                #Compute inner product
                vnAux = nijx*vijx+nijy*vijy
                #Compute normal and tangential forces
                FnAux = kn*δAux^1.5-γn*MeAux*δAux*vnAux
                FtAux = -min(γt*MeAux*δAux^.5,μcc*FnAux)
                #Compute the interaction forces
                Fijx = FnAux*nijx + FtAux*(vijx-vnAux*nijx)
                Fijy = FnAux*nijy + FtAux*(vijy-vnAux*nijy)
                #Append the interaction forces
                Fx += Fijx
                Fy += Fijy
                #Append radial forces
                W += ((xiAux-x)*Fijy - (yiAux-y)*Fijx)
            end

            xiAux = x; yiAux = y; xjAux=0; yjAux=0; #Declare them in the global scope
            if y - l/2 - d/2 < simulationBox[2,1] #In the upper boundary region
                a = sign(sin(theta))
                xiAux = x - a*cos(theta)*l/2
                yiAux = y - abs(sin(theta))*l/2

                if yiAux <= simulationBox[2,1]#If the bead has surpassed the axis
                    xjAux = xiAux
                    yjAux = yiAux-.001*d
                else
                    xjAux = xiAux
                    yjAux = simulationBox[2,1] - d/2
                end
            end

            #Compute distance between virtual spheres
            rij = sqrt((xiAux-xjAux)^2 +(yiAux-yjAux)^2)
            if rij > 0 && rij < d #If it is smaller than a diameter
                #Compute auxiliar
                δAux = d - rij
                MeAux = m/2
                #Compute interaction
                nijx = (xiAux-xjAux)/rij
                nijy = (yiAux-yjAux)/rij
                vijx = vx
                vijy = vy
                #Compute inner product
                vnAux = nijx*vijx+nijy*vijy
                #Compute normal and tangential forces
                FnAux = kn*δAux^1.5-γn*MeAux*δAux*vnAux
                FtAux = -min(γt*MeAux*δAux^.5,μcc*FnAux)
                #Compute the interaction forces
                Fijx = FnAux*nijx + FtAux*(vijx-vnAux*nijx)
                Fijy = FnAux*nijy + FtAux*(vijy-vnAux*nijy)
                #Append the interaction forces
                Fx += Fijx
                Fy += Fijy
                #Append radial forces
                W += ((xiAux-x)*Fijy - (yiAux-y)*Fijx)
            end

    end,

    UpdateLocal = begin
        if x < simulationBox[1,1] || x > simulationBox[1,2]
            removeAgent()
        end
    end
)


"""
Addon to the Bacteria2D model incorporating growth. The model is implemented in https://www.pnas.org/content/105/40/15346.

Add the model before the Bacteria2D model.

    @agent(
        Bacteria2D::BaseModel
        Bacteria2DGrowth::BaseModel,
    )

Parameters:

 - lTarget (Local): Friction coefficient of cell-wall.
 - growth (Global): Growth factor.
 - lMax (Global): Max length of the bacteria before division.
 - σLTarget (Global): Standard deviation around the maximum length of growth. Adds sandomness to the division event.
 - σTorqueDivision (Global): Torque that generates a small missalignement to the cells when dividing.

For more details check the paper of the Documentation on the Models section.
"""
Bacteria2DGrowth = @agent(2,
    
            lTarget::Local,
            [growth,lMax,σLTarget,σTorqueDivision]::Global, #Growth parameters

            UpdateVariable = begin
                    d(l) = growth*dt
            end,

            UpdateLocal = begin #Bound cells

                #Add division
                if l > lTarget
                    torque = σLTarget*Uniform(-σTorqueDivision,σTorqueDivision)
                    addAgent(
                            x=(l+d)/4*cos(theta)+x,
                            y=(l+d)/4*sin(theta)+y,
                            l=l/2,
                            vx = vx,
                            vy = vy,
                            theta = theta+Uniform(-.1,.1),
                            ω = torque,
                            d = d,
                            m = m/2,
                            lTarget = lMax+σLTarget*Uniform(-1,1)
                            )
                    addAgent(
                            x=-(l+d)/4*cos(theta)+x,
                            y=-(l+d)/4*sin(theta)+y,
                            l=l/2,
                            vx = vx,
                            vy = vy,
                            theta = theta,
                            ω = -torque,
                            d = d,
                            m = m/2,
                            lTarget = lMax+σLTarget*Uniform(-1,1)
                            )
                    removeAgent()
                end
                
                m = l/5
            end
    );
