function posPeriodicBoundary(x, x_min, x_max)
    if x < x_min
        return x + (x_max - x_min)
    elseif x > x_max
        return x - (x_max - x_min)
    else
        return x
    end
end

function posPeriodicBoundary(x, x_min, x_max, y, y_min, y_max)
    x_best = posPeriodicBoundary(x, x_min, x_max)
    y_best = posPeriodicBoundary(y, y_min, y_max)

    return x_best, y_best
end

function posPeriodicBoundary(x, x_min, x_max, y, y_min, y_max, z, z_min, z_max)
    x_best = posPeriodicBoundary(x, x_min, x_max)
    y_best = posPeriodicBoundary(y, y_min, y_max)
    z_best = posPeriodicBoundary(z, z_min, z_max)

    return x_best, y_best, z_best
end

function posRelPeriodicBoundary(x, x0, x_min, x_max)
    L = x_max - x_min

    l_best = abs(x-x0)
    x_best = x

    l = abs(x-x0+L)
    if l < l_best
        l_best = l
        x_best = x + L
    end

    l = abs(x-x0-L)
    if l < l_best
        l_best = l
        x_best = x - L
    end

    return x_best
end

function posRelPeriodicBoundary(x, x0, x_min, x_max, y, y0, y_min, y_max)
    x_best = posRelPeriodicBoundary(x, x0, x_min, x_max)
    y_best = posRelPeriodicBoundary(y, y0, y_min, y_max)

    return x_best, y_best
end

function posRelPeriodicBoundary(x, x0, x_min, x_max, y, y0, y_min, y_max, z, z0, z_min, z_max)
    x_best = posRelPeriodicBoundary(x, x0, x_min, x_max)
    y_best = posRelPeriodicBoundary(y, y0, y_min, y_max)
    z_best = posRelPeriodicBoundary(z, z0, z_min, z_max)

    return x_best, y_best, z_best
end

module Geometry

    ##############################################################################################################################
    # Distance metrics
    ##############################################################################################################################
    """
        macro euclidean(x1,x2)
        macro euclidean(x1,y1,x2,y2)
        macro euclidean(x1,y1,z1,x2,y2,z2)

    Macro that given the iterator symbos it1 and it2, give the corresponding euclidean distanve in the correct dimentions. 
    If it1 is not provided it asumes the default iteration index of agents (i1_).
    """
    macro euclidean(x1,x2)
        return :(sqrt(($x1-$x2)^2))
    end
    macro euclidean(x1,y1,x2,y2)
        return :(sqrt(($x1-$x2)^2+($y1-$y2)^2))
    end
    macro euclidean(x1,y1,z1,x2,y2,z2)
        return :(sqrt(($x1-$x2)^2+($y1-$y2)^2+($z1-$z2)^2))
    end

    """
        manhattan(x1,x2)
        manhattan(x1,y1,x2,y2)
        manhattan(x1,y1,z1,x2,y2,z2)

    Manhattan distance metric between two positions.

    d = |x₁-x₂|
    """
    macro manhattan(x1,x2)
        return :(abs($x1-$x2))
    end
    macro manhattan(x1,y1,x2,y2)
        return :(abs($x1-$x2)+abs($y1-$y2))
    end
    macro manhattan(x1,y1,z1,x2,y2,z2)
        return :(abs($x1-$x2)+abs($y1-$y2)+abs($z1-$z2))
    end

    ##############################################################################################################################
    # Geometrical auxiliar functions
    ##############################################################################################################################
    """
        function intersection2lines(x1,y1,vx1,vy1,x2,y2,vx2,vy2,norm=1E-5,inf_eff=1E10)
    
    Finds the point of intersection of two lines. You have to provide a point in space and vector director for eachline: (x1,y1) (vx1, vy1) and (x2,y2) (vx2, vy2).
    
    If the lines are parallel, it returns a point effectively in the infinite. The effective distance is described by `inf_eff``.
    
    Returns the point of intersection.
    """
    function intersection2lines(x1,y1,vx1,vy1,x2,y2,vx2,vy2,norm=1E-5,inf_eff=1E10)

        #Compute determinant
        normAux = vx1*vy2 - vy1*vx2
        pxIntersect = 0.
        pyIntersect = 0.
        if abs(normAux) > norm
            #Using Cramer's rule
            D = normAux
            Dx = (x1*vy1 - y1*vx1)*vy2 - (x2*vy2 - y2*vx2)*vy1
            Dy = vx1*(x2*vx2 - y2*vy2) - vx2*(x1*vx1 - y1*vy1)

            pxIntersect = Dx / D
            pyIntersect = Dy / D
        else #if parallel send  point to an infinite
            pxIntersect = (x1+x2)/2 + inf_eff * (vx1/norm(vx1,vy1))
            pyIntersect = (y1+y2)/2 + inf_eff * (vy1/norm(vx1,vy1))
        end

        return pxIntersect, pyIntersect

    end

    """
        function projectPoint2Line(x1,y1,x2,y2,vx2,vy2)
        function projectPoint2Line(x1,y1,z1,x2,y2,z2,vx2,vy2,vz2)
    
    2D: Given a point (x1,y1), finds the closest point projected over a line described by a point in the line and director vector: (x2,y2) (vx2,vy2).
    3D: Given a point (x1,y1,z1), finds the closest point projected over a line described by a point in the line and director vector: (x2,y2,z2) (vx2,vy2,vz2).
    
    Returns the coordinates of the closest point over the line.
    """
    function projectPoint2Line(x1,y1,x2,y2,vx1,vy2)
        #Compute vector from point in line to point
        dx = x1 - x2
        dy = y1 - y2

        #Compute projection over the line direction
        normAux = vx2^2 + vy2^2
        scaleAux = (dx*vx2 + dy*vy2) / normAux

        #Compute projected point
        pxProj = x2 + scaleAux * vx2
        pyProj = y2 + scaleAux * vy2

        return pxProj, pyProj
    end

    function projectPoint2Line(x1,y1,z1,x2,y2,z2,vx2,vy2,vz2)
        #Compute vector from point in line to point
        dx = x1 - x2
        dy = y1 - y2
        dz = z1 - z2

        #Compute projection over the line direction
        normAux = vx2^2 + vy2^2 + vz2^2
        scaleAux = (dx*vx2 + dy*vy2 + dz*vz2) / normAux

        #Compute projected point
        pxProj = x2 + scaleAux * vx2
        pyProj = y2 + scaleAux * vy2
        pzProj = z2 + scaleAux * vz2

        return pxProj, pyProj, pzProj
    end

    """
        function projectionPoint2Segment(x1,y1,x2,y2,x3,y3)
        function projectionPoint2Segment(x1,y1,z1,x2,y2,z2,x3,y3,z3)

    2D: Given a point (x1,y1), finds the closest point projected over a line segment described by its two extremes: (x2,y2) and (x3,y3).
    3D: Given a point (x1,y1,z1), finds the closest point projected over a line segment described by its two extremes: (x2,y2,z2) and (x3,y3,z3).

    Returns the coordinates of the closest point over the segment.
    """
    function projectionPoint2Segment(x1,y1,x2,y2,x3,y3)
        #Compute segment vector
        sx = x3 - x2
        sy = y3 - y2

        #Compute vector from first extreme to point
        dx = x1 - x2
        dy = y1 - y2

        #Compute projection over the segment
        normAux = sx^2 + sy^2
        scaleAux = (dx*sx + dy*sy) / normAux
        #Clamp scaleAux to [0, 1] to stay within the segment
        scaleAux = max(0, min(1, scaleAux))
        #Compute projected point
        pxProj = x2 + scaleAux * sx
        pyProj = y2 + scaleAux * sy

        return pxProj, pyProj
    end

    function projectionPoint2Segment(x1,y1,z1,x2,y2,z2,x3,y3,z3)
        #Compute segment vector
        sx = x3 - x2
        sy = y3 - y2
        sz = z3 - z2

        #Compute vector from first extreme to point
        dx = x1 - x2
        dy = y1 - y2
        dz = z1 - z2

        #Compute projection over the segment
        normAux = sx^2 + sy^2 + sz^2
        scaleAux = (dx*sx + dy*sy + dz*sz) / normAux
        #Clamp scaleAux to [0, 1] to stay within the segment
        scaleAux = max(0, min(1, scaleAux))
        #Compute projected point
        pxProj = x2 + scaleAux * sx
        pyProj = y2 + scaleAux * sy
        pzProj = z2 + scaleAux * sz

        return pxProj, pyProj, pzProj
    end

    """
        function closesPoints2Lines(x1,y1,z1,vx1,vy1,vz1,x2,y2,z2,vx2,vy2,vz2)

    Finds the closest points between two lines in 3D space. Each line is described by a point and a direction vector: (x1,y1,z1) (vx1,vy1,vz1) and (x2,y2,z2) (vx2,vy2,vz2).

    Returns the coordinates of the closest points over each line.
    """
    function closesPoints2Lines(x1,y1,z1,vx1,vy1,vz1,x2,y2,z2,vx2,vy2,vz2)

        #Compute direction vector between lines
        dx = x2 - x1
        dy = y2 - y1
        dz = z2 - z1

        #Compute coefficients of the linear system
        a = vx1*vx1 + vy1*vy1 + vz1*vz1
        b = vx1*vx2 + vy1*vy2 + vz1*vz2
        c = vx2*vx2 + vy2*vy2 + vz2*vz2
        d = vx1*dx + vy1*dy + vz1*dz
        e = vx2*dx + vy2*dy + vz2*dz

        denom = a*c - b*b

        s = (b*e - c*d) / denom
        t = (a*e - b*d) / denom

        #Compute closest points
        px1 = x1 + s * vx1
        py1 = y1 + s * vy1
        pz1 = z1 + s * vz1

        px2 = x2 + t * vx2
        py2 = y2 + t * vy2
        pz2 = z2 + t * vz2

        return px1, py1, pz1, px2, py2, pz2

    end

    """
        function closestPoints2Segments(x1,y1,x2,y2,x3,y3,x4,y4)
        function closestPoints2Segments(x1,y1,z1,x2,y2,z2,x3,y3,z3,x4,y4,z4)

    2D: Finds the closest points between two line segments in 2D space. Each segment is described by its two extremes: (x1,y1)-(x2,y2) and (x3,y3)-(x4,y4).
    3D: Finds the closest points between two line segments in 3D space. Each segment is described by its two extremes: (x1,y1,z1)-(x2,y2,z2) and (x3,y3,z3)-(x4,y4,z4).

    Returns the coordinates of the closest points over each segment.
    """
    function closestPoints2Segments(x1,y1,x2,y2,x3,y3,x4,y4)
        #Compute direction vectors of the segments
        vx1 = x2 - x1
        vy1 = y2 - y1
        vx2 = x4 - x3
        vy2 = y4 - y3

        #Compute direction vector between segment starts
        dx = x3 - x1
        dy = y3 - y1

        #Compute coefficients of the linear system
        a = vx1*vx1 + vy1*vy1
        b = vx1*vx2 + vy1*vy2
        c = vx2*vx2 + vy2*vy2
        d = vx1*dx + vy1*dy
        e = vx2*dx + vy2*dy

        denom = a*c - b*b

        s = (b*e - c*d) / denom
        t = (a*e - b*d) / denom

        #Clamp s and t to [0, 1] to stay within the segments
        s = max(0, min(1, s))
        t = max(0, min(1, t))

        #Compute closest points
        px1 = x1 + s * vx1
        py1 = y1 + s * vy1

        px2 = x3 + t * vx2
        py2 = y3 + t * vy2

        return px1, py1, px2, py2
    end

    function closestPoints2Segments(x1,y1,z1,x2,y2,z2,x3,y3,z3,x4,y4,z4)
        #Compute direction vectors of the segments
        vx1 = x2 - x1
        vy1 = y2 - y1
        vz1 = z2 - z1
        vx2 = x4 - x3
        vy2 = y4 - y3
        vz2 = z4 - z3

        #Compute direction vector between segment starts
        dx = x3 - x1
        dy = y3 - y1
        dz = z3 - z1

        #Compute coefficients of the linear system
        a = vx1*vx1 + vy1*vy1 + vz1*vz1
        b = vx1*vx2 + vy1*vy2 + vz1*vz2
        c = vx2*vx2 + vy2*vy2 + vz2*vz2
        d = vx1*dx + vy1*dy + vz1*dz
        e = vx2*dx + vy2*dy + vz2*dz

        denom = a*c - b*b

        s = (b*e - c*d) / denom
        t = (a*e - b*d) / denom

        #Clamp s and t to [0, 1] to stay within the segments
        s = max(0, min(1, s))
        t = max(0, min(1, t))

        #Compute closest points
        px1 = x1 + s * vx1
        py1 = y1 + s * vy1
        pz1 = z1 + s * vz1

        px2 = x3 + t * vx2
        py2 = y3 + t * vy2
        pz2 = z3 + t * vz2

        return px1, py1, pz1, px2, py2, pz2
    end
    
    """
        function intersection2planes(x1,y1,z1,vx1,vy1,vz1,x2,y2,z2,vx2,vy2,vz2,norm=1E-5,inf_eff=1E10)

    Finds the line of intersection of two planes. You have to provide a point in space and and the normal vector of each plane: (x1,y1,z1,vx1,vy1,vz1) and (x2,y2,z2,vx2,vy2,vz2).
    If the planes are parallel, it returns a point effectively in the infinite. The effective distance is described by `inf_eff``.

    Returns a point of the line of intersection and the direction vector of the line.
    """
    function intersection2planes(x1,y1,z1,vx1,vy1,vz1,x2,y2,z2,vx2,vy2,vz2,norm=1E-5,inf_eff=1E10)

        #Direction of the line of intersection
        dx = vy1*vz2 - vz1*vy2
        dy = vz1*vx2 - vx1*vz2
        dz = vx1*vy2 - vy1*vx2

        #Check if planes are parallel
        normAux = sqrt(dx^2+dy^2+dz^2)
        pxIntersect = 0.
        pyIntersect = 0.
        pzIntersect = 0.
        if normAux > norm
            #Find a point in the line of intersection solving the plane equations
            #Using Cramer's rule
            D = vx1*(vy2*vz2 - vz2*vy2) - vy1*(vx2*vz2 - vz1*vx2) + vz1*(vx2*vy2 - vy2*vx2)
            Dx = (x1*(vy1*vz2 - vz1*vy2) - y1*(vx1*vz2 - vz1*vx1) + z1*(vx1*vy2 - vy1*vx1))
            Dy = (vx1*(y1*vz2 - z1*vy2) - vy1*(x1*vz2 - z1*vx2) + vz1*(x1*vy2 - y1*vx2))
            Dz = (vx1*(vy2*z1 - vz2*y1) - vy1*(vx2*z1 - vz2*x1) + vz1*(vx2*y1 - vy2*x1))

            pxIntersect = Dx / D
            pyIntersect = Dy / D
            pzIntersect = Dz / D
        else #if parallel send  point to an infinite
            pxIntersect = (x1+x2)/2
            pyIntersect = (y1+y2)/2
            pzIntersect = (z1+z2)/2
        end

        return pxIntersect,pyIntersect,pzIntersect,dx,dy,dz
    end

    """
        function projectPoint2Plane(x1,y1,z1,x2,y2,z2,vx2,vy2,vz2)
    
    Given a point (x1,y1,z1), finds the closest point projected over a plane described by a point in the plane and normal vector: (x2,y2,z2) (vx2,vy2,vz2).

    Returns the coordinates of the closest point over the plane.
    """
    function projectPoint2Plane(x1,y1,z1,x2,y2,z2,vx2,vy2,vz2)
        #Compute vector from point in plane to point
        dx = x1 - x2
        dy = y1 - y2
        dz = z1 - z2

        #Compute projection over the plane normal
        normAux = vx2^2 + vy2^2 + vz2^2
        scaleAux = (dx*vx2 + dy*vy2 + dz*vz2) / normAux

        #Compute projected point
        pxProj = x1 - scaleAux * vx2
        pyProj = y1 - scaleAux * vy2
        pzProj = z1 - scaleAux * vz2

        return pxProj, pyProj, pzProj
    end

    """
        function projectPoint2Triangle(x1,y1,z1,x2,y2,z2,x3,y3,z3,x4,y4,z4)

    Given a point (x1,y1,z1), finds the closest point projected over a triangle described by its three vertices: (x2,y2,z2), (x3,y3,z3), and (x4,y4,z4).

    Returns the coordinates of the closest point over the triangle.
    """
    function projectPoint2Triangle(x1,y1,z1,x2,y2,z2,x3,y3,z3,x4,y4,z4)
        #Compute plane normal
        vx1 = x3 - x2
        vy1 = y3 - y2
        vz1 = z3 - z2
        vx2 = x4 - x2
        vy2 = y4 - y2
        vz2 = z4 - z2

        nx = vy1*vz2 - vz1*vy2
        ny = vz1*vx2 - vx1*vz2
        nz = vx1*vy2 - vy1*vx2

        #Project point onto plane of the triangle
        pxProj, pyProj, pzProj = projectPoint2Plane(x1,y1,z1,x2,y2,z2,nx,ny,nz)

        #Check if projected point is inside the triangle using barycentric coordinates
        #Vectors from triangle vertices to projected point
        v0x = x3 - x2
        v0y = y3 - y2
        v0z = z3 - z2
        v1x = x4 - x2
        v1y = y4 - y2
        v1z = z4 - z2
        v2x = pxProj - x2
        v2y = pyProj - y2
        v2z = pzProj - z2

        #Dot products
        d00 = v0x*v0x + v0y*v0y + v0z*v0z
        d01 = v0x*v1x + v0y*v1y + v0z*v1z
        d11 = v1x*v1x + v1y*v1y + v1z*v1z
        d20 = v2x*v0x + v2y*v0y + v2z*v0z
        d21 = v2x*v1x + v2y*v1y + v2z*v1z

        denom = d00 * d11 - d01 * d01
        v = (d11 * d20 - d01 * d21) / denom
        w = (d00 * d21 - d01 * d20) / denom
        u = 1.0 - v - w
        if u >= 0 && v >= 0 && w >= 0
            #Projected point is inside the triangle
            return pxProj, pyProj, pzProj
        else
            #Projected point is outside the triangle, find closest point on triangle edges
            px1, py1, pz1 = projectionPoint2Segment(pxProj, pyProj, pzProj, x2,y2,z2, x3,y3,z3)
            px2, py2, pz2 = projectionPoint2Segment(pxProj, pyProj, pzProj, x3,y3,z3, x4,y4,z4)
            px3, py3, pz3 = projectionPoint2Segment(pxProj, pyProj, pzProj, x4,y4,z4, x2,y2,z2)

            #Find closest of the three projected points
            d1 = (pxProj - px1)^2 + (pyProj - py1)^2 + (pzProj - pz1)^2
            d2 = (pxProj - px2)^2 + (pyProj - py2)^2 + (pzProj - pz2)^2
            d3 = (pxProj - px3)^2 + (pyProj - py3)^2 + (pzProj - pz3)^2

            if d1 <= d2 && d1 <= d3
                return px1, py1, pz1
            elseif d2 <= d1 && d2 <= d3
                return px2, py2, pz2
            else
                return px3, py3, pz3
            end
        end
    end

end