import CellBasedModels: toDevice, CSRBlock, CSRTuple, CSRSlack

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

        CUDA.CuArray(field._ActiveSection),

        CUDA.CuArray(field._FlagsSurvived),

        CUDA.CuArray(field._NAdded),
        CUDA.CuArray(field._NOverflow),
        CUDA.CuArray(field._NOverflowBlock),
    )
end

toDevice(field::CSRBlock{P}, ::Type{CUDA.CUDABackend}) where {P<:GPUCuda} = field

# CSRTuple to CUDA
function toDevice(field::CSRTuple{P, NBlock}, ::Type{CUDA.CUDABackend}) where {P<:CPU, NBlock}
    CSRTuple(
        CUDA.CuArray(field._map),
        CUDA.CuArray(field._N),
        field._NBlock,
        CUDA.CuArray(field._NCache),
        CUDA.CuArray(field._FlagsSurvived),
        CUDA.CuArray(field._NAdded),
        CUDA.CuArray(field._NOverflow),
        CUDA.CuArray(field._NOverflowBlock),
    )
end

toDevice(field::CSRTuple{P, NBlock}, ::Type{CUDA.CUDABackend}) where {P<:GPUCuda, NBlock} = field

# CSRSlack to CUDA
function toDevice(field::CSRSlack{P, PR, AI, AF, VI, VI2, VB}, ::Type{CUDA.CUDABackend}) where {P<:CPU, PR, AI, AF, VI, VI2, VB}
    CSRSlack(
        CUDA.CuArray(field._map),
        CUDA.CuArray(field._N),
        CUDA.CuArray(field._NCache),
        CUDA.CuArray(field._offsets),
        CUDA.CuArray(field._ActiveSection),
        CUDA.CuArray(field._FlagsSurvived),
        CUDA.CuArray(field._incProd),
        CUDA.CuArray(field._incSum),
        CUDA.CuArray(field._NAdded),
        CUDA.CuArray(field._NOverflow),
        CUDA.CuArray(field._NOverflowBlock),
    )
end

toDevice(field::CSRSlack{P}, ::Type{CUDA.CUDABackend}) where {P<:GPUCuda} = field
