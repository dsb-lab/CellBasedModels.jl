module CBMMetrics

    import CellBasedModels: COMUNITY

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

        com = COMUNITY
    
        args = [:(x[i1_]), :(x[$it2])]
        if com.abm.dims > 1
            args = [args;[:(y[i1_]), :(y[$it2])]]
        end
        if com.abm.dims > 2
            args = [args;[:(z[i1_]), :(z[$it2])]]
        end
    
        return esc(:(CBMMetrics.euclidean($(args...))))
    
    end
    
    macro euclidean(it1,it2)
    
        com = COMUNITY
    
        args = [:(x[$it1]), :(x[$it2])]
        if com.abm.dims > 1
            args = [args;[:(y[$it1]), :(y[$it2])]]
        end
        if com.abm.dims > 2
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
    
        com = COMUNITY
    
        args = [:(x[i1_]), :(x[$it2])]
        if com.abm.dims > 1
            args = [args;[:(y[i1_]), :(y[$it2])]]
        end
        if com.abm.dims > 2
            args = [args;[:(z[i1_]), :(z[$it2])]]
        end
    
        return esc(:(CBMMetrics.manhattan($(args...))))
    
    end

    macro manhattan(it1,it2)
    
        com = COMUNITY
    
        args = [:(x[$it1]), :(x[$it2])]
        if com.abm.dims > 1
            args = [args;[:(y[$it1]), :(y[$it2])]]
        end
        if com.abm.dims > 2
            args = [args;[:(z[$it1]), :(z[$it2])]]
        end
    
        return esc(:(CBMMetrics.manhattan($(args...))))
    
    end

end