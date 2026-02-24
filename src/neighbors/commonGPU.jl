import CellBasedModels: compactArray!, compactUnstructuredMeshField!
import KernelAbstractions

function compactUnstructuredMeshField!(prop::UnstructuredMeshField{P}, perm, aux::NamedTuple, NNew) where {P <: GPU}
    N = lengthPropertiesNew(prop)
    for (fieldname, field) in pairs(prop._p)
        aux_field = getfield(aux, fieldname)
        compactArrayGPU!(field, aux_field, perm, N, NNew)
    end
    compactArrayGPU!(prop._id, prop._id, perm, N, NNew)
    @inbounds @views prop._FlagsSurvived[1:NNew] .= true
    prop._N .= NNew
    return nothing
end

function compactArrayGPU!(data, auxBuffer, perm, N::Int, NNew::Int)
    @kernel function compactArray_kernel!(data, auxBuffer, perm, N)
        i = @index Global
        if i <= N
            if perm[i] != 0
                auxBuffer[perm[i]] = data[i]
            end
        end
    end

    # Copy data to target positions using auxiliary buffer (parallelizable)
    # threads = 256
    # blocks = cld(N, threads)
    # @cuda threads=threads blocks=blocks compactArray_kernel!(data, auxBuffer, perm, N)
    # # Synchronize to ensure kernel completion
    # CUDA.synchronize()
    backend = get_backend(data)
    compactArray_kernel!(backend, 256)(data, auxBuffer, perm, N, ndrange=size(data))
    KernelAbstractions.synchronize(backend)
    # Copy back from auxiliary buffer to original array
    @inbounds @views data[1:NNew] .= auxBuffer[1:NNew]
    return nothing
end
