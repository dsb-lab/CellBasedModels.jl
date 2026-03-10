import CellBasedModels: AbstractMeshObject, GPU, platform, toBackend, getDeviceIndex
import KernelAbstractions

abstract type GPUCuda <: GPU end
abstract type GPUCuDevice <: GPU end

function platform(::CUDA.CuArray)
    return GPUCuda
end

function platform(::CUDA.CuDeviceArray)
    return GPUCuDevice
end

# For CuArray (host-side GPU array), copy to CPU first
getDeviceIndex(arr::CUDA.CuArray, i=1) = Array(arr)[i]

function toBackend(::CUDA.CUDABackend, x::AbstractArray)
    return CUDA.CuArray(x)
end

function toBackend(::Type{CUDA.CUDABackend}, x::AbstractArray)
    return CUDA.CuArray(x)
end

function KernelAbstractions.get_backend(::CUDA.CuDeviceArray) 
    return CUDA.CUDABackend()
end