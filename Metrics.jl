
function euclidianMetric(pos1::Array{<:Number,1},pos2::Array{<:Number,1})::Float64
    """
    Calculates the euclidian metric of the 

    parameters
    ------------------
        pos1::Array{<:Number}: array with first vector
        pos2::Array{<:Number}: array with second vector

    returns
    ------------------
        Float64: euclidean distance
    """

    return sqrt(sum((pos1 - pos2).^2))
end

function nearestNeighbours(cell1::cell, cell2::cell, expFactor::Number=1.1)
    """
    Calculates if two cells are nearest neighbours from the cell radius and their distance

        d < (r1+r2)*expFactor

    parameters
    ------------------
        cell1::cell: first cell structure
        cell2::cell: second cell structure
        expFactor::Number: augmentation factor to consider them neighbours

    returns
    ------------------
        bool: true if neighbours, false if not
    """

    d = euler(cell1.pos,cell2.pos)
    if d < (cell1.radius + cell2.radius)*expFactor #Expansion factor
        return true 
    else
        return false
    end
end