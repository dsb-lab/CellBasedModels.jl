import CellBasedModels: AbstractMeshObject, GPU, platform, toDevice

abstract type GPUCuda <: GPU end
abstract type GPUCuDevice <: GPU end

function platform(::CUDA.CuArray)
    return GPUCuda
end

function platform(::CUDA.CuDeviceArray)
    return GPUCuDevice
end

function toDevice(::CUDA.CUDABackend, x::AbstractArray)
    return CUDA.CuArray(x)
end

function toDevice(::Type{CUDA.CUDABackend}, x::AbstractArray)
    return CUDA.CuArray(x)
end