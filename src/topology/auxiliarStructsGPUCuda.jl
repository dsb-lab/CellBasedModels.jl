import CellBasedModels: toDevice, CSRBlock, CSRSlack

######################################################################################################
# toDevice - CUDA device transfer functions for CSR structures
######################################################################################################

# CSRBlock to CUDA
function toDevice(field::CSRBlock{P}, ::Type{CUDA.CUDABackend}) where {P<:CPU}
    CSRBlock(
        CUDA.CuArray(field._map),

        CUDA.CuArray(field._N),
        CUDA.CuArray(field._NBlock),
        CUDA.CuArray(field._NCache),

        field._ActiveSection === nothing ? nothing : CUDA.CuArray(field._ActiveSection),

        CUDA.CuArray(field._FlagsSurvived),

        CUDA.CuArray(field._NAdded),
        CUDA.CuArray(field._NOverflow),
        CUDA.CuArray(field._NOverflowBlock),
    )
end

toDevice(field::CSRBlock{P}, ::Type{CUDA.CUDABackend}) where {P<:GPUCuda} = field

# CSRSlack to CUDA
function toDevice(field::CSRSlack{P, PR, AI, VI, VI2, VB}, ::Type{CUDA.CUDABackend}) where {P<:CPU, PR, AI, VI, VI2, VB}
    CSRSlack(
        CUDA.CuArray(field._map),
        CUDA.CuArray(field._N),
        CUDA.CuArray(field._offsets),
        field._ActiveSection === nothing ? nothing : CUDA.CuArray(field._ActiveSection),
        CUDA.CuArray(field._FlagsSurvived),
        CUDA.CuArray(field._NAdded),
        CUDA.CuArray(field._NOverflow),
        CUDA.CuArray(field._NOverflowBlock),
    )
end

toDevice(field::CSRSlack{P}, ::Type{CUDA.CUDABackend}) where {P<:GPUCuda} = field
