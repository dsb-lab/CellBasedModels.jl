module CBMMetrics

    import CellBasedModels: COMUNITY

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