function normal(cell1::CellStruct.cell, cell2::CellStruct.cell)
    F0 = 10^-4
    μ = 2
    rij = euler(cell1.pos,cell2.pos)
    d = cell1.radius+cell2.radius

    if d < μ*rij
        return F0*(rij/d-1)*(μ*rij/d-1)/d*(cell1.pos-cell2.pos)
    else
        return 0
    end

end