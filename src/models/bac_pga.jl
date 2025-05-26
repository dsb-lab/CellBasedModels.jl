"""
    repulsiveForces(
        x, y, d, l, theta, etab, type,
        x2, y2, d2, l2, theta2, etag, type2,
        Ebb, Ebg, Egg
    ) -> (Fijx, Fijy, Wij)

Computes the repulsive interaction forces between two agents (either rods or gels), based on their type and geometry. If both are of the same type and are gels, direct contact is assumed; otherwise, virtual contact points are calculated.

### Parameters
- `x, y`: coordinates of the first agent.
- `d, l, theta`: diameter, length, and orientation angle of the first agent.
- `etab, type`: effective viscosity and type of the first agent (`0` for rod, `1` for gel).
- `x2, y2`: coordinates of the second agent.
- `d2, l2, theta2`: diameter, length, and orientation angle of the second agent.
- `etag, type2`: effective viscosity and type of the second agent.
- `Ebb, Ebg, Egg`: elastic moduli for rod-rod, rod-gel, and gel-gel interactions.

### Returns
- `Fijx, Fijy`: components of the repulsive force between the agents.
- `Wij`: radial torque-like contribution (only non-zero when the first agent is a rod).
"""
function repulsiveForces(
    x,y,d,l,theta,etab,type,
    x2,y2,d2,l2,theta2,etag,type2, Ebb, Ebg, Egg )

    Fijx = 0.
    Fijy = 0.
    Wij = 0.

    if type==type2 && type==1
        xiAux,yiAux,xjAux,yjAux=x,y,x2,y2
    else
        #Function that finds the virtual spheres of contact between both rods
        xiAux,yiAux,xjAux,yjAux = CBMMetrics.rodIntersection(x,y,l,theta,x2,y2,l2,theta2)
    end

    #Compute distance between virtual spheres
    rij = sqrt((xiAux-xjAux)^2 +(yiAux-yjAux)^2)
    if rij > 0. && rij < (d+d2)/2. #If it is smaller than a diameter compute forces
        #Compute auxiliar
        hAux = (d+d2)/2. - rij
        #Compute direction
        nijx = (xiAux-xjAux)/rij
        nijy = (yiAux-yjAux)/rij
        if type == 0
            if type2 == 0
                FnAux = Ebb * sqrt(d2* hAux^3)  / (etab * (l + d))
            else
                FnAux = Ebg * sqrt(d2* hAux^3) / (etab * (l + d))
            end
            Fijx = FnAux * nijx
            Fijy = FnAux * nijy
            Wij = ((xiAux-x)*Fijy - (yiAux-y)*Fijx) * 12. / (etab * (l + d)^3)
        else
            if type2 == 0
                FnAux = Ebg * sqrt(d2* hAux^3) / (etag * d)
            else
                FnAux = Egg * sqrt(d2* hAux^3) / (etag * d)
            end
            Fijx = FnAux * nijx
            Fijy = FnAux * nijy
        end
    end

    return Fijx, Fijy, Wij

end

"""
    attractiveForces(
        x, y, d, l, theta, etab, type,
        x2, y2, d2, l2, theta2, etag, type2,
        epsbb, epsbg, epsgg
    ) -> (Fijx, Fijy, Wij)

Computes the attractive interaction forces between two agents (rods or gels) based on their relative distance. The force is only applied when the distance between their centers lies within a specific interaction range.

### Parameters
- `x, y`: coordinates of the first agent.
- `d, l, theta`: diameter, length, and orientation angle of the first agent.
- `etab, type`: effective viscosity and type of the first agent (`0` for rod, `1` for gel).
- `x2, y2`: coordinates of the second agent.
- `d2, l2, theta2`: diameter, length, and orientation angle of the second agent.
- `etag, type2`: effective viscosity and type of the second agent.
- `epsbb, epsbg, epsgg`: adhesion strengths for rod-rod, rod-gel, and gel-gel interactions.

### Returns
- `Fijx, Fijy`: components of the attractive force between the agents.
- `Wij`: radial torque-like contribution (only non-zero when the first agent is a rod).
"""
function attractiveForces(
    x,y,d,l,theta,etab,type,
    x2,y2,d2,l2,theta2,etag,type2, epsbb, epsbg, epsgg
    
)

  
    Fijx = 0.
    Fijy = 0.
    Wij = 0.

    xiAux = x
    yiAux = y
    xjAux = x2
    yjAux = y2
    #Compute distance between central masses
    rij = sqrt((xiAux-xjAux)^2 +(yiAux-yjAux)^2)
    if rij > (d+d2)/2 && rij < (2*d+l/2) #If it is smaller than a diameter compute forces
        #Compute direction
        nijx = (xiAux-xjAux)/rij
        nijy = (yiAux-yjAux)/rij
        M=(d+d2)/2
        D=(2*d+l)
        if type==0 #rod

            #Compute the forces
            if type2==0 #rod-rod
               
                FnAux = epsbb*(rij/D-1.)*(rij/M-1.)*(rij/D)/(etab*d) 
                
            else #rod-gel
                FnAux = epsbg*(rij/D-1.)*(rij/M-1.)*(rij/D)/(etab*d) 
          
            end
            #Compute the interaction forces
            Fijx = FnAux*nijx
            Fijy = FnAux*nijy
            #Append radial forces
            Wij = ((xiAux-x)*Fijy - (yiAux-y)*Fijx)* 12. /(etab*(l+d)^3)
        else # gel
            #Compute the forces
            if type2==0 #gel-rod
                FnAux = epsbg*(rij/D-1.)*(rij/M-1.)*(rij/D)/(etag*d) 
            else #gel-gel
                FnAux = epsgg*(rij/D-1.)*(rij/M-1.)*(rij/D)/(etag*d) 
            end
            #Compute the interaction forces
            Fijx = FnAux*nijx
            Fijy = FnAux*nijy
            #No radial forces
        end
    end

    return Fijx, Fijy, Wij

end