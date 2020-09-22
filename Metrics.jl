push!(LOAD_PATH,"./")
import CellStruct

function euler(pos1::Arange{Float32},pos2::Arange{Float32})
    return sqrt(sum((pos1 - pos2).^2))
end

function nearestNeighbours(cell1::CellStruct.cell, cell2::CellStruct.cell)
    d = euler(cell1.pos,cell2.pos)
    if d < (cell1.radius - cell2.radius)*1.1 #Expansion factor
        return true 
    else
        return false
    end
end
