module CellBasedModelsGPUCudaExt

    using CellBasedModels
    using CUDA
    using Adapt
    import CUDA: CuArray
    import StaticArrays: SizedVector, SizedArray

    include("../src/platformsGPUCuda.jl")
    include("../src/neighbors/neighborsFullGPUCuda.jl")
    include("../src/neighbors/neighborsCellLinkedGPUCuda.jl")
    include("../src/AgentStructure/unstructuredMeshGPUCuda.jl")
    # include("../src/AgentStructure/structuredMeshGPUCuda.jl")
    # include("../src/AgentStructure/multiMeshGPUCuda.jl")

end