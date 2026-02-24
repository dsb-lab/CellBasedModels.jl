module CellBasedModels

    using Adapt
    using StaticArrays
    using Printf
    export CPU, GPU
    using KernelAbstractions
    using Atomix
    import KernelAbstractions: @index
    export @index
    import Base: push!

    hasCuda() = false
    getDeviceIndex(arr, i=1) = Array(arr)[i] #TO BE BETTER DONE
    setDeviceIndex!(arr, val) = arr .= val   #TO BE BETTER DONE

    #Auxiliar
    # export Unit, UnitScalar, UnitArray
    # include("./auxiliar/units.jl")
    export Parameter
    include("./auxiliar/parameter.jl")
    export @diffsym, @diffauto, @consistency_diffauto
    include("./auxiliar/diffsym.jl")
    include("./auxiliar/diffauto.jl")
    include("./auxiliar/debugging.jl")
    export @dot, @cross, @norm, @normSquared, @normalize
    include("./auxiliar/algebra.jl")
    include("./auxiliar/indexing.jl")
    # include("./auxiliar/meta.jl")
    # include("./auxiliar/recursiveCachedArrays.jl")

    # include("./baseStructs.jl")
    # include("./constants.jl")

    #Custom integrators
    # export CBMIntegrators
    # export Rule, ODE, DynamicalODE, SplitODE, SDE, RODE, ADIODE
    # include("./integrators/abstractTypes.jl")
    # include("./integrators/integratorsFunctionGeneration.jl")

    # #Random
    # export CBMDistributions
    # include("./random.jl")
    # using .CBMDistributions

    # #Distance functions
    # export CBMMetrics
    # include("./metrics.jl")
    # using .CBMMetrics

    #Platforms
    # export CPU, GPU
    export toBackend
    include("./platforms.jl")

    #Abstraact types
    # include("./neighbors/abstractTypes.jl")
    # include("./AgentStructure/abstractTypes.jl")
    # include("./CommunityStructure/abstractTypes.jl")
    include("./neighbors/abstractTypes.jl")

    #Topology
    export AuxiliarFields
    include("./topology/auxiliar.jl")

    include("./topology/abstractCSR.jl")
    export DynamicalCOO, dcoo_zeros
    include("./topology/DynamicalCOO.jl")
    export DynamicalCSR, dcsr_zeros
    include("./topology/abstractCSR.jl")
    # export CSRTuple
    # include("./topology/CSRTuple.jl")
    # export CSRCache
    # include("./topology/CSRCache.jl")
    export DynamicalCSR, dcsr_zeros
    include("./topology/DynamicalCSR.jl")
    export Topology
    include("./topology/topology.jl")

    #Agent
    include("./AgentStructure/auxiliar.jl")
    export Node, Edge, Face, Volume, Agent
    export UnstructuredMesh, UnstructuredMeshField, UnstructuredMeshObject
    export iterateOver
    include("./AgentStructure/unstructuredMesh.jl")
    include("./AgentStructure/unstructuredMeshGPU.jl")
    export iterateOverNeighbors, getNeighbors

    #Agent Specializations
    export createObject
    export AgentGlobal
    include("./AgentSpecializations/agentGlobal.jl")
    export AgentPoint, @addAgentPoint!, @removeAgentPoint!
    include("./AgentSpecializations/agentPoint.jl")

    include("./neighbors/common.jl")
    include("../src/neighbors/commonGPU.jl")
    export NeighborsFull
    include("./neighbors/neighborsFull.jl")
    export NeighborsCellLinked
    include("./neighbors/neighborsCellLinked.jl")
    # export StructuredMesh, StructuredMeshObject
    # include("./AgentStructure/structuredMesh.jl")
    # export MultiMesh, MultiMeshObject
    # include("./AgentStructure/multiMesh.jl")

    export @addRule, @addODE, @addSDE
    export @kernel_launch
    include("./integrators/addFunctions.jl")
    export RuleProblem, Rule
    include("./integrators/ruleProblem.jl")
    export CBProblem, CBIntegrator, init, step!, preallocate!
    include("./integrators/cellBasedProblem.jl")

    #Neighbors
    # NEIGHBORS_ALGS = (:NeighborsFull, :NeighborsCellLinked)
    # export NeighborsFull
    # include("./neighbors/neighborsFull.jl")
    # export NeighborsCellLinked
    # include("./neighbors/neighborsCellLinked.jl")
    # export CBMNeighbors, computeNeighbors!
    # include("./neighbors.jl")
    # using .CBMNeighbors

end