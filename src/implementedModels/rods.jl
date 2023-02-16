rod2D = Agent(2,
    localFloat = [:vx,:vy,:theta,:ω,:d,:l,:m], #Local parameters
    localFloatInteraction = [:fx,:fy,:W],    #Local Interaction Parameters
    globalFloatInteraction = [:kn,:γn,:γt,:μcc,:μcw,:β,:βω],#Global parameters

    updateInteraction = quote
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
                    fx.i -= kn*s*(d.i-rij)*cos(theta.i)/2
                    fy.i -= kn*s*(d.i-rij)*sin(theta.i)/2
                    fx.j += kn*s*(d.i-rij)*cos(theta.i)/2
                    fy.j += kn*s*(d.i-rij)*sin(theta.i)/2
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
                fx.i += Fijx/2
                fy.i += Fijy/2
                #Append radial forces
                W.i += ((xiAux-x.i)*Fijy - (yiAux-y.i)*Fijx)/2
                #Append the interaction forces
                fx.j -= Fijx/2
                fy.j -= Fijy/2
                #Append radial forces
                W.j -= ((xiAux-x.i)*Fijy - (yiAux-y.i)*Fijx)/2
            end
        end
    end,

    updateVariable = quote
        d(x) = dt( vx )
        d(y) = dt( vy )
        d(vx) = dt( -β*vx+fx/m )
        d(vy) = dt( -β*vy+fy/m )
        d(theta) = dt( ω )
        d(ω) = dt( W/(m*(d+l)^2/12+m*d^2)-βω*ω )
    end,
)
