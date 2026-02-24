struct AuxiliarFields{PR}

    _map::PR
    _copy::PR
    _mapRow::PR
    _copyRow::PR

end
Adapt.@adapt_structure AuxiliarFields

function AuxiliarFields(N::Int, NRow::Int) where {Int}
    map = zeros(Int, N)
    copy = zeros(Int, N)
    mapRow = zeros(Int, NRow)
    copyRow = zeros(Int, NRow)
    PR = typeof(map)
    return AuxiliarFields{PR}(map, copy, mapRow, copyRow)
end

function preallocate!(auxiliar::AuxiliarFields; N::Int=0, NRow::Int=0)

    NMaxMax = max(N, length(auxiliar._map))
    if NMaxMax > length(auxiliar._map)
        resize!(auxiliar._map, NMaxMax)
    end
    
    NMaxCopy = max(N, length(auxiliar._copy))
    if NMaxCopy > length(auxiliar._copy)
        resize!(auxiliar._copy, NMaxCopy)
    end
    
    NMaxMapRow = max(NRow, length(auxiliar._mapRow))
    if NMaxMapRow > length(auxiliar._mapRow)
        resize!(auxiliar._mapRow, NMaxMapRow)
    end

    NMaxCopyRow = max(NRow, length(auxiliar._copyRow))
    if NMaxCopyRow > length(auxiliar._copyRow)
        resize!(auxiliar._copyRow, NMaxCopyRow)
    end

    return auxiliar
end

function clear!(auxiliar::AuxiliarFields; N::Int=0, NRow::Int=0)
    
    @views auxiliar._map[1:1:N] .= 0
    @views auxiliar._copy[1:1:N] .= 0
    @views auxiliar._mapRow[1:1:NRow] .= 0
    @views auxiliar._copyRow[1:1:NRow] .= 0

    return auxiliar
end