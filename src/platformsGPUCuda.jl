import CellBasedModels: AbstractMeshObject, GPU, platform, toBackend
import KernelAbstractions

abstract type GPUCuda <: GPU end
abstract type GPUCuDevice <: GPU end

function platform(::CUDA.CuArray)
    return GPUCuda
end

function platform(::CUDA.CuDeviceArray)
    return GPUCuDevice
end

function toBackend(::CUDA.CUDABackend, x::AbstractArray)
    return CUDA.CuArray(x)
end

function toBackend(::Type{CUDA.CUDABackend}, x::AbstractArray)
    return CUDA.CuArray(x)
end

function KernelAbstractions.get_backend(::CUDA.CuDeviceArray) 
    return CUDA.CUDABackend()
end