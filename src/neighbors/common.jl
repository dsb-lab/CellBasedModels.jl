function compactUnstructuredMeshField!(prop::UnstructuredMeshField{P}, perm, aux::NamedTuple, NNew) where {P<:CPU}
    N = lengthPropertiesNew(prop)
    for (fieldname, field) in pairs(prop._p)
        aux_field = getfield(aux, fieldname)
        compactArray!(field, aux_field, perm, N, NNew)
    end
    compactArray!(prop._id, prop._id, perm, N, NNew)
    @inbounds @views prop._FlagsSurvived[1:NNew] .= true
    prop._N[] = NNew
    return nothing
end

function compactArray!(data::AbstractArray, auxBuffer::AbstractArray, perm::AbstractVector{Int}, N::Int, NNew::Int)
    # Copy data to target positions using auxiliary buffer (parallelizable)
    # println("N: ", NNew)
    # println("d: ", data)
    # println("p: ", perm)
    @inbounds for i in 1:N
        if perm[i] != 0
            auxBuffer[perm[i]] = data[i]
        end
    end
    # Copy back from auxiliary buffer to original array
    @inbounds @views data[1:NNew] .= auxBuffer[1:NNew]
    return nothing
end

function renameElements!(mesh::UnstructuredMeshObject)

end