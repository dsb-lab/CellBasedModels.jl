module CBMMetrics

    using CUDA

    """
        function cellInMesh(edge,x,xMin,xMax,nX) 

    Give the integer position in a regular discrete mesh with poits separamtions of `edge`, given a position in `x`. The simulation domain being (`xMin`, `xMax`) and maximum number of mesh points `nX`.

    e.g Grid with 6 points at [0,.1,.2,.3,.4,.5]
    ```
    >>> cellInMesh(.1,.29,0.,.5,6)
    4
    ```
    which if the closest point in the mesh.
    """
    function cellInMesh(edge,x,xMin,xMax,nX) 
        return if x > xMax nX elseif x < xMin 1 else Int((x-xMin)÷edge)+1 end
    end

    ##############################################################################################################################
    # Distance metrics
    ##############################################################################################################################
    """
        euclidean(x1,x2)
        euclidean(x1,x2,y1,y2)
        euclidean(x1,x2,y1,y2,z1,z2)

    Euclidean distance metric between two positions.

    d = (x₁-x₂)²
    """
    euclidean(x1,x2) = sqrt((x1-x2)^2)
    euclidean(x1,x2,y1,y2) = sqrt((x1-x2)^2+(y1-y2)^2)
    euclidean(x1,x2,y1,y2,z1,z2) = sqrt((x1-x2)^2+(y1-y2)^2+(z1-z2)^2)

    """
        macro euclidean(it2)
        macro euclidean(it1,it2)

    Macro that given the iterator symbos it1 and it2, give the corresponding euclidean distanve in the correct dimentions. 
    If it1 is not provided it asumes the default iteration index of agents (i1_).
    """
    macro euclidean(it2)
    
        args = [:(x[i1_]), :(x[$it2])]
        if abm.dims > 1
            args = [args;[:(y[i1_]), :(y[$it2])]]
        end
        if abm.dims > 2
            args = [args;[:(z[i1_]), :(z[$it2])]]
        end
    
        return esc(:(CBMMetrics.euclidean($(args...))))
    
    end
    
    macro euclidean(it1,it2)
        
        args = [:(x[$it1]), :(x[$it2])]
        if abm.dims > 1
            args = [args;[:(y[$it1]), :(y[$it2])]]
        end
        if abm.dims > 2
            args = [args;[:(z[$it1]), :(z[$it2])]]
        end
    
        return esc(:(CBMMetrics.euclidean($(args...))))
    
    end

    """
        manhattan(x1,x2)
        manhattan(x1,x2,y1,y2)
        manhattan(x1,x2,y1,y2,z1,z2)

    Manhattan distance metric between two positions.

    d = |x₁-x₂|
    """
    manhattan(x1,x2) = abs(x1-x2)
    manhattan(x1,x2,y1,y2) = abs(x1-x2)+abs(y1-y2)
    manhattan(x1,x2,y1,y2,z1,z2) = abs(x1-x2)+abs(y1-y2)+abs(z1-z2)
    
    """
        macro manhattan(it2)
        macro manhattan(it1,it2)

    Macro that given the iterator symbos it1 and it2, give the corresponding manhattan distanve in the correct dimentions. 
    If it1 is not provided it asumes the default iteration index of agents (i1_).
    """
    macro manhattan(it2)
        
        args = [:(x[i1_]), :(x[$it2])]
        if abm.dims > 1
            args = [args;[:(y[i1_]), :(y[$it2])]]
        end
        if abm.dims > 2
            args = [args;[:(z[i1_]), :(z[$it2])]]
        end
    
        return esc(:(CBMMetrics.manhattan($(args...))))
    
    end

    macro manhattan(it1,it2)
        
        args = [:(x[$it1]), :(x[$it2])]
        if abm.dims > 1
            args = [args;[:(y[$it1]), :(y[$it2])]]
        end
        if abm.dims > 2
            args = [args;[:(z[$it1]), :(z[$it2])]]
        end
    
        return esc(:(CBMMetrics.manhattan($(args...))))
    
    end

    """
        function intersection2lines(x1,y1,theta1,x2,y2,theta2,inf_eff=100000)
    
    Finds the point of intersection of two lines. You have to provide a point in space and and angle for eachline: (x1,y1,theta1) and (x2,y2,theta2).
    
    If the lines are parallel, it returns a point effectively in the infinite. The effective distance is described by `inf_eff``.
    
    Returns the point of intersection.
    """
    function intersection2lines(x1,y1,theta1,x2,y2,theta2,inf_eff=100000)

        pxIntersect = 0.
        pyIntersect = 0.
    
        cxAux = (x1-x2)
        cyAux = (y1-y2)
        normAux = cos(theta1)*sin(theta2)-sin(theta1)*cos(theta2)
        if abs(normAux) > 0.0000001
            scaleAux = (-sin(theta2)*cxAux+cos(theta2)*cyAux)/normAux
            pxIntersect = scaleAux*cos(theta1)+x1
            pyIntersect = scaleAux*sin(theta1)+y1
        else #if parallel send  point to an infinite
            pxIntersect = (x1+x2)/2
            pyIntersect = (y1+y2)/2
        end
    
        return pxIntersect,pyIntersect
    end

    """
        function point2line(x1,y1,x2,y2,theta2)
    
    Given a point (x1,x2), finds the closest point projected over a line described by a point in the line and the angle: (x2,y2,theta2).
    
    Returns the coordinates of the closest point over the line.
    """
    function point2line(x1,y1,x2,y2,theta2)
        #Compute closest point over the line axis of the other rod
        cx = x2-x1
        cy = y2-y1
        xjAux = (sin(theta2)*cx-cos(theta2)*cy)*sin(theta2)+x1
        yjAux = -(sin(theta2)*cx-cos(theta2)*cy)*cos(theta2)+y1
    
        return xjAux,yjAux
    end

    """
        function pointInsideRod(x1,y1,l1,theta1,pxAux,pyAux,separation)
    
    Given a line segment described by it central point (x1,y1), its angle in the plate theta1 and its length l1;
    and given a point over the save line (pxAux,pyAux), returns the point if inside the segment or the closes extreme of the segment. 
    If provided a separation (0,1), it moves the point that separation.
            
    Returns the coordinates of the closest point over the segment.
    """
    function pointInsideRod(x1,y1,l1,theta1,pxAux,pyAux,separation)
    
        di = max(sqrt((x1-pxAux)^2+(y1-pyAux)^2),0.00000001)
    
        dxi = (pxAux-x1)/di
        dyi = (pyAux-y1)/di
        return separation*min(di,l1/2)*dxi+x1, separation*min(di,l1/2)*dyi+y1
    
    end

    """
        function rodIntersection(x1,y1,l1,theta1,x2,y2,l2,theta2;separation=0.99)
    
    Given a two line segment described by it central point (x1,y2), its angle in the plate theta1 and its length l1;
    finds the closest spheres of both segments.
    
    Returns the coordinates of the closest spheres (x1Aux,y1Aux), (x2Aux,y2Aux).
    """
    function rodIntersection(x1,y1,l1,theta1,x2,y2,l2,theta2;separation=0.99)
            
        #Compute distance between centers of mass
        x1Aux = x1; x2Aux = x2; y1Aux = y1; y2Aux = y2; #Declare them in the global scope
    
        #Compute intersecting point of the extended direction
        pxAux, pyAux = intersection2lines(x1,y1,theta1,x2,y2,theta2)
    
        #Compute distance from mass center of both rods
        di = sqrt((x1-pxAux)^2+(y1-pyAux)^2)
        dj = sqrt((x2-pxAux)^2+(y2-pyAux)^2)
        normAux = cos(theta1)*sin(theta2)-sin(theta1)*cos(theta2)
        if abs(normAux) < 0.000001
            x1Aux,y1Aux= point2line(pxAux,pyAux,x1,y1,theta1)
            x1Aux,y1Aux = pointInsideRod(x1,y1,l1,theta1,x1Aux,y1Aux,separation)
    
            x2Aux,y2Aux= point2line(pxAux,pyAux,x2,y2,theta2)
            x2Aux,y2Aux = pointInsideRod(x2,y2,l2,theta2,x2Aux,y2Aux,separation) 
        elseif di<=l1/2 && dj<=l2/2 #Case that the intersecting point lies inside both rods
            x1Aux,y1Aux = pointInsideRod(x1,y1,l1,theta1,pxAux,pyAux,separation)
            x2Aux,y2Aux = pointInsideRod(x2,y2,l2,theta2,pxAux,pyAux,separation) 
        elseif di<=l1/2 && dj>l2/2
            x2Aux,y2Aux = pointInsideRod(x2,y2,l2,theta2,pxAux,pyAux,separation)    
            x1Aux,y1Aux= point2line(x2Aux,y2Aux,x1,y1,theta1)
        elseif di>l1/2 && dj<=l2/2
            x1Aux,y1Aux = pointInsideRod(x1,y1,l1,theta1,pxAux,pyAux,separation)    
            x2Aux,y2Aux= point2line(x1Aux,y1Aux,x2,y2,theta2)  
        else
            x2Aux,y2Aux = pointInsideRod(x2,y2,l2,theta2,pxAux,pyAux,separation)    
            x1Aux,y1Aux= point2line(x2Aux,y2Aux,x1,y1,theta1)
            dj = sqrt((x1-x1Aux)^2+(y1-y1Aux)^2)
            if dj > l1/2
                x1Aux,y1Aux = pointInsideRod(x1,y1,l1,theta1,pxAux,pyAux,separation)
                x2Aux_,y2Aux_= point2line(x1Aux,y1Aux,x2,y2,theta2)
    
                dj = sqrt((x2-x2Aux_)^2+(y2-y2Aux_)^2)
                if dj < l2/2
                    x2Aux = x2Aux_
                    y2Aux = y2Aux_
                end
            end
        end
    
        return x1Aux,y1Aux,x2Aux,y2Aux
    end
    
end