module CBMNeighbors

    export Neighbors, neighborsLoop, computeNeighbors!

    import CellBasedModels: agentArgsNeighbors, POSITIONPARAMETERS, CPU, GPU
    import MacroTools: postwalk, @capture
    # using CUDA
    import ..CBMMetrics

    abstract type Neighbors end
    abstract type Verlet <: Neighbors end

    """
        function computeNeighbors!(community)

    Function that computes the neighbors of the community according the defined neighbor algorithm in ABM.
    """
    computeNeighbors!(com) = computeNeighbors!(com.abm.neighbors,com)

    #Full

"""
    mutable struct Full <: Neighbors

Method that computes all against all neighbors.
"""
    mutable struct Full <: Neighbors

    end

    """
        function neighborsLoop(code,abm)

    Wrapper loop for full neighbors algorithm.
    """
    function neighborsLoop(code,it,neig::Full,dims)

        return :(for $it in 1:1:N; if i1_ != $it; $code; end; end)

    end

    function initialize!(neig::Full,com)

        return nothing

    end

    """
        function computeNeighbors!(neig::NeighborsFull)

    Function that computes the neighbors of the full connected algorithm.
    """
    function computeNeighbors!(neig::Full,com)

        return nothing

    end

    #Verlet
    """
        function neighborsVerletLoop(code,abm)

    Wrapper loop for verlet neighbors algorithms.
    """
    function neighborsLoop(code,it,neig::Verlet,dims) #Macro to create the second loop in functions
        
        #Go over the list of neighbors
        code = postwalk(x->@capture(x,h_) && h == it ? :(neighborList_[i1_,$it]) : x, code)
        #make loop
        code = :(for $it in 1:1:neighborN_[i1_]; $code; end)

        # println(code)
        
        return code

    end

    """
        macro verletNeighbors(platform, args...)

    Macro to generate the code for the computation of Verlet lists for different platforms and dimensions.

    Adds the following functions to the library:

        verletNeighbors!(x::Array)
        verletNeighbors!(x::Array,y::Array)
        verletNeighbors!(x::Array,y::Array,z::Array)
        verletNeighbors!(x::CuArray)
        verletNeighbors!(x::CuArray,y::CuArray)
        verletNeighbors!(x::CuArray,y::CuArray,z::CuArray)
    """
    macro verletNeighbors(platform, args...) #Macro to make the verletNeighbor loops

        base = [:N,:neighborN_,:neighborList_,:skin]

        base = [base;[i for i in args]]

        args2 = []
        for i in args
            append!(args2,[:($i[i1_]),:($i[i2_])])
        end

        name = Meta.parse("verletNeighbors$(platform)!")

        code = 0
        if platform == :CPU
            code = :(
                function $name($(base...))
                    begin 
                        tasks = Task[]
                        for i in 1:1:Threads.nthreads()
                            task = Threads.@spawn begin 
                                Nn = ceil(Int64,N/Threads.nthreads())
                                for i1_ in (Nn*(i-1)+1):1:min((Nn*i),N)
                                    for i2_ in 1:N
                                        if i1_ != i2_
                                            d = CBMMetrics.euclidean($(args2...))
                                            if d < skin 
                                                    neighborN_[i1_] += 1
                                                    # neighborN_[i2_] += 1
                                                    neighborList_[i1_,neighborN_[i1_]] = i2_
                                                    # neighborList_[i2_,neighborN_[i2_]] = i1_
                                            end
                                        end
                                    end
                                end
                            end
                            push!(tasks,task)
                        end
                        wait.(tasks)
                    end
                end
            )
        elseif platform == :GPU
            code = :(
                function $name($(base...))
                    index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                    stride = gridDim().x * blockDim().x
                    @inbounds for i1_ in index:stride:N
                        for i2_ in (i1_+1):1:N
                            d = CBMMetrics.euclidean($(args2...))
                            if d < skin
                                pos1 = CUDA.atomic_add!(CUDA.pointer(neighborN_,i1_),1) + 1
                                pos2 = CUDA.atomic_add!(CUDA.pointer(neighborN_,i2_),1) + 1
                                neighborList_[i1_,pos1] = i2_
                                neighborList_[i2_,pos2] = i1_
                            end
                        end
                    end

                    return
                end
            )
        end

        return code

    end

    @verletNeighbors CPU x
    @verletNeighbors CPU x y
    @verletNeighbors CPU x y z
    # @verletNeighbors GPU x
    # @verletNeighbors GPU x y
    # @verletNeighbors GPU x y z

        #Verlet Time

"""
    mutable struct VerletTime <: Verlet <: Neighbors

Method that computes VerletList neighbors and updates it at fixed times.

# Constructor

    function VerletTime(;skin,dtNeighborRecompute,nMaxNeighbors)

||Parameter|Description|
|:---|:---|:---|
|KwArgs|skin is the maximum distance around center to check neighbors.|
||dtNeighborRecompute is time step at which recompute Verlet Lists.|
||nMaxNeighbors is the maximum number of neighbors that a cell may have.|
"""
    mutable struct VerletTime <: Verlet

        skin
        dtNeighborRecompute
        nMaxNeighbors
        neighborN_
        neighborList_
        neighborTimeLastRecompute_
        f_

        function VerletTime(;skin,dtNeighborRecompute,nMaxNeighbors)
            return new(skin,dtNeighborRecompute,nMaxNeighbors,nothing,nothing,nothing,nothing)
        end

    end

    function initialize!(neig::VerletTime,com)

        if typeof(com.abm.platform) <: CPU
            neig.neighborN_ = zeros(Int64,com.nMax_)
            neig.neighborList_ =  zeros(Int64,com.nMax_,neig.nMaxNeighbors)
        else
            neig.neighborN_ = CUDA.zeros(Int,com.nMax_)
            neig.neighborList_ =  CUDA.zeros(Int,com.nMax_,neig.nMaxNeighbors)
        end
        neig.neighborTimeLastRecompute_ = com.t
        neig.f_ = eval(Meta.parse("neighborsVerletTime$(com.abm.dims)$(typeof(com.abm.platform))!"))

        return

    end

    function computeNeighbors!(neig::VerletTime,com)

        neig.f_(com)

        return

    end

    """
        macro neighborsVerletTime(platform, args...)

    Macro to generate the code for the computation of Verlet lists updated by Verlet Time algorithm.

    Adds the following functions to the library: 

        neighborsVerletTime1CPU!(community)
        neighborsVerletTime2CPU!(community)
        neighborsVerletTime3CPU!(community)
        neighborsVerletTime1GPU!(community)
        neighborsVerletTime2GPU!(community)
        neighborsVerletTime3GPU!(community)
    """
    macro neighborsVerletTime(platform, args...)

        base = [
                :(community.N),
                :(community.abm.neighbors.neighborN_),
                :(community.abm.neighbors.neighborList_),
                :(community.abm.neighbors.skin)
                ]

        base = [base;[:(community.$i) for i in args]]

        namef = Meta.parse("verletNeighbors$(platform)!")
        name = Meta.parse(string("neighborsVerletTime$(length(args))$(platform)!"))
        if platform == :CPU
            code = :(
                function $name(community)

                    if community.abm.neighbors.neighborTimeLastRecompute_ <= community.t || community.flagRecomputeNeighbors_[1] == 1
                        community.abm.neighbors.neighborN_ .= 0
                        $namef($(base...),)
                        community.abm.neighbors.neighborTimeLastRecompute_ = community.t + community.abm.neighbors.dtNeighborRecompute
                        community.flagRecomputeNeighbors_ .= 0
                    end

                    return

                end
            )
        else
            code = :(
                function $name(community)
                
                    kernel = @cuda launch=false $namef($(base...),)
                    if CUDA.@allowscalar community.abm.neighbors.neighborTimeLastRecompute_ <= community.t || CUDA.@allowscalar community.flagRecomputeNeighbors_[1] == 1
                        CUDA.@sync community.abm.neighbors.neighborN_ .= 0
                        CUDA.@sync kernel($(base...);threads=community.abm.platform.agentThreads,blocks=community.abm.platform.agentBlocks)
                        CUDA.@sync community.abm.neighbors.neighborTimeLastRecompute_ .= community.t + community.abm.neighbors.dtNeighborRecompute
                        CUDA.@sync community.flagRecomputeNeighbors_ .= 0
                    end
                
                    return
                
                end
            )
        end

        return code
    end

    @neighborsVerletTime CPU x
    @neighborsVerletTime CPU x y
    @neighborsVerletTime CPU x y z
    # @neighborsVerletTime GPU x
    # @neighborsVerletTime GPU x y
    # @neighborsVerletTime GPU x y z

        #Verlet Displacement

"""
    mutable struct VerletTime <: Verlet <: Neighbors

Method that computes VerletList neighbors and updates it whenever an agent moves too far from the initial position

# Constructor

    function VerletDisplacement(;skin,nMaxNeighbors)

||Parameter|Description|
|:---|:---|:---|
|KwArgs|skin is the maximum distance around center to check neighbors.|
||nMaxNeighbors is the maximum number of neighbors that a cell may have.|
"""
    mutable struct VerletDisplacement <: Verlet

        skin
        nMaxNeighbors
        neighborN_
        neighborList_
        posOld_
        accumulatedDistance_
        f_

        function VerletDisplacement(;skin,nMaxNeighbors)
            return new(skin,nMaxNeighbors,nothing,nothing,nothing,nothing,nothing)
        end

    end

    function initialize!(neig::VerletDisplacement,com)

        if typeof(com.abm.platform) <: CPU
            neig.neighborN_ = zeros(Int64,com.nMax_)
            neig.neighborList_ =  zeros(Int64,com.nMax_,neig.nMaxNeighbors)
            neig.posOld_ =  zeros(Float64,com.nMax_,com.abm.dims)
            neig.accumulatedDistance_ = zeros(Float64,com.nMax_)
        else
            neig.neighborN_ = CUDA.zeros(Int,com.nMax_)
            neig.neighborList_ =  CUDA.zeros(Int,com.nMax_,neig.nMaxNeighbors)
            neig.posOld_ =  CUDA.zeros(com.nMax_,com.abm.dims)
            neig.accumulatedDistance_ = CUDA.zeros(com.nMax_)
        end
        neig.f_ = eval(Meta.parse("neighborsVerletDisplacement$(com.abm.dims)$(typeof(com.abm.platform))!"))

        return

    end

    function computeNeighbors!(neig::VerletDisplacement,com)

        neig.f_(com)

        return

    end

    """
        macro verletDisplacement(platform, args...)

    Macro to generate the code for the check of Verlet lists recomputation flag according to Verlet Displacement algorithm.

    Adds the following functions to the library:

        verletDisplacementCPU!(x)
        verletDisplacementCPU!(x,y)
        verletDisplacementCPU!(x,y,z)
        verletDisplacementGPU!(x)
        verletDisplacementGPU!(x,y)
        verletDisplacementGPU!(x,y,z)
    """
    macro verletDisplacement(platform, args...)

        base = agentArgsNeighbors(args,VerletDisplacement)
        
        args3 = []
        for (pos,i) in enumerate(args)
            append!(args3,[:($i[i1_]),:(posOld_[i1_,$pos])])
        end

        name = Meta.parse("verletDisplacement$(platform)!")

        code = 0
        if platform == :CPU
            code = :(
                function $name($(base...))

                    @inbounds Threads.@threads for i1_ in 1:1:N
                        accumulatedDistance_[i1_] = CBMMetrics.euclidean($(args3...))
                        if accumulatedDistance_[i1_] >= skin/2
                            flagRecomputeNeighbors_[1] = 1
                        end
                    end

                    return 

                end
            )
        else
            code = :(
                function $name($(base...))

                    index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                    stride = gridDim().x * blockDim().x

                    @inbounds for i1_ in index:stride:N
                        accumulatedDistance_[i1_] = CBMMetrics.euclidean($(args3...))
                        if accumulatedDistance_[i1_] >= skin/2
                            flagRecomputeNeighbors_[1] = 1
                        end
                    end

                    return 

                end
            )
        end

        return code
    end

    @verletDisplacement CPU x
    @verletDisplacement CPU x y
    @verletDisplacement CPU x y z
    # @verletDisplacement GPU x
    # @verletDisplacement GPU x y
    # @verletDisplacement GPU x y z

    """
        macro verletResetDisplacement(platform, args...)

    Macro to generate the code to store the positions of the agents in the last recomputation of Verlet lists for Verlet Displacement algorithm.

    Adds the following functions to the library:

        verletResetDisplacementCPU!(x)
        verletResetDisplacementCPU!(x,y)
        verletResetDisplacementCPU!(x,y,z)
        verletResetDisplacementGPU!(x)
        verletResetDisplacementGPU!(x,y)
        verletResetDisplacementGPU!(x,y,z)
    """
    macro verletResetDisplacement(platform, args...)

        base = agentArgsNeighbors(args,VerletDisplacement)
        
        up = quote end
        for (pos,i) in enumerate(args)
            push!(up.args,:(posOld_[i1_,$pos]=$i[i1_]))
        end

        name = Meta.parse("verletResetDisplacement$(platform)!")

        code = 0
        if platform == :CPU
            code = :(
                function $name($(base...))

                    @inbounds Threads.@threads for i1_ in 1:1:N
                        $up
                    end

                    return 

                end
            )
        else
            code = :(
                function $name($(base...))

                    index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                    stride = gridDim().x * blockDim().x

                    @inbounds for i1_ in index:stride:N
                        $up
                    end

                    return 

                end
            )
        end

        return code
    end

    @verletResetDisplacement CPU x
    @verletResetDisplacement CPU x y
    @verletResetDisplacement CPU x y z
    # @verletResetDisplacement GPU x
    # @verletResetDisplacement GPU x y
    # @verletResetDisplacement GPU x y z

    """
        macro neighborsVerletDisplacement(platform, args...)

    Macro to generate the code for the computation of Verlet lists updated by Verlet Displacement algorithm.
    This function puts together the action of:
    - verletDisplacement
    - resetVerletDisplacement
    - verletList

    Adds the following functions to the library:

        neighborsVerletDisplacement1CPU!(community)
        neighborsVerletDisplacement2CPU!(community)
        neighborsVerletDisplacement3CPU!(community)
        neighborsVerletDisplacement1GPU!(community)
        neighborsVerletDisplacement2GPU!(community)
        neighborsVerletDisplacement3GPU!(community)
    """
    macro neighborsVerletDisplacement(platform, args...)

        base = agentArgsNeighbors(args,VerletDisplacement,sym=:community)

        base2 = [:(community.N),:(community.abm.neighbors.neighborN_),
            :(community.abm.neighbors.neighborList_),:(community.abm.neighbors.skin)]
        base2 = [base2;[:(community.$i) for i in args]]

        name = Meta.parse(string("neighborsVerletDisplacement$(length(args))$(platform)!"))

        nameNeigh = Meta.parse(string("verletNeighbors$(platform)!"))
        nameDisp = Meta.parse(string("verletDisplacement$(platform)!"))
        nameResDisp = Meta.parse(string("verletResetDisplacement$(platform)!"))

        code = 0
        if platform == :CPU
            code = :(
                function $name(community)

                    $nameDisp($(base...),)
                    if community.flagRecomputeNeighbors_[1] == 1
                        community.abm.neighbors.neighborN_ .= 0
                        community.abm.neighbors.accumulatedDistance_ .= 0.
                        community.flagRecomputeNeighbors_ .= 0
                        $nameResDisp($(base...))
                        $nameNeigh($(base2...),)
                    end

                    return

                end
            )
        else
            code = :(
                function $name(community)

                    kernelDisp = @cuda launch=false $nameDisp($(base...),)
                    kernelResDisp = @cuda launch=false $nameResDisp($(base...),)
                    kernelNeigh = @cuda launch=false $nameNeigh($(base2...),)
                    
                    CUDA.@sync kernelDisp($(base...);threads=community.abm.platform.agentThreads,blocks=community.abm.platform.agentThreads)
                    if CUDA.@allowscalar community.flagRecomputeNeighbors_[1] == 1
                        community.abm.neighbors.neighborN_ .= 0
                        community.abm.neighbors.accumulatedDistance_ .= 0.
                        community.flagRecomputeNeighbors_ .= 0
                        CUDA.@sync kernelResDisp($(base...);threads=community.abm.platform.agentThreads,blocks=community.abm.platform.agentBlocks)
                        CUDA.@sync kernelNeigh($(base2...);threads=community.abm.platform.agentThreads,blocks=community.abm.platform.agentBlocks)
                    end

                    return

                end
            )
        end

        return code
    end

    @neighborsVerletDisplacement CPU x
    @neighborsVerletDisplacement CPU x y
    @neighborsVerletDisplacement CPU x y z
    # @neighborsVerletDisplacement GPU x
    # @neighborsVerletDisplacement GPU x y
    # @neighborsVerletDisplacement GPU x y z

    #Grid

"""
    mutable struct CellLinked <: Neighbors

Method that computes Cell Linked neighbors and updates it whenever an agent moves too far from the initial position

# Constructor

    function CellLinked(;cellEdge)

||Parameter|Description|
|:---|:---|:---|
|KwArgs|cellEdge is the grid size to use to check for neighbors around neighbor cells.|
"""
    mutable struct CellLinked <: Neighbors

        cellEdge
        nCells_
        cellAssignedToAgent_
        cellNumAgents_
        cellCumSum_
        f_

        function CellLinked(;cellEdge)
            return new(cellEdge,nothing,nothing,nothing,nothing,nothing)
        end
    end

    function initialize!(neig::CellLinked,com)

        if typeof(com.abm.platform) <: CPU
            neig.nCells_ = ceil.(Int64,(com.simBox[:,2].-com.simBox[:,1])./neig.cellEdge .+2)
            neig.cellAssignedToAgent_ = zeros(Int64,com.nMax_)
            neig.cellNumAgents_ =  zeros(Int64,prod(neig.nCells_))
            neig.cellCumSum_ =  zeros(Int64,prod(neig.nCells_))
        else
            neig.cellEdge = cu(neig.cellEdge)
            neig.nCells_ = cu(ceil.(Int64,(com.simBox[:,2].-com.simBox[:,1])./neig.cellEdge .+2))
            neig.cellAssignedToAgent_ = cu(zeros(Int64,com.nMax_))
            neig.cellNumAgents_ =  cu(zeros(Int64,prod(neig.nCells_)))
            neig.cellCumSum_ =  cu(zeros(Int64,prod(neig.nCells_)))
        end
        neig.f_ = eval(Meta.parse("neighborsCellLinked$(com.abm.dims)$(typeof(com.abm.platform))!"))

        return

    end

    function computeNeighbors!(neig::CellLinked,com)

        neig.f_(com)

        return

    end

    """
        cellPos(edge,x,xMin,xMax,nX)
        cellPos(edge,x,xMin,xMax,nX,y,yMin,yMax,nY)
        cellPos(edge,x,xMin,xMax,nX,y,yMin,yMax,nY,z,zMin,zMax,nZ)

    Function that returns the position of the abm in a cell list given their coordinates and cell grid properties.
    """
    cellPos(edge,x,xMin,xMax,nX) = if x > xMax nX elseif x < xMin 1 else Int((x-xMin)÷edge)+2 end
    cellPos(edge,x,xMin,xMax,nX,y,yMin,yMax,nY) = cellPos(edge,x,xMin,xMax,nX) + nX*(cellPos(edge,y,yMin,yMax,nY)-1)
    cellPos(edge,x,xMin,xMax,nX,y,yMin,yMax,nY,z,zMin,zMax,nZ) = cellPos(edge,x,xMin,xMax,nX) + nX*(cellPos(edge,y,yMin,yMax,nY)-1) + nX*nY*(cellPos(edge,z,zMin,zMax,nZ)-1)

    """
        function cellPosNeigh(pos,i,nX)
        function cellPosNeigh(pos,i,nX,nY)
        function cellPosNeigh(pos,i,nX,nY,nZ)

    Returns the position of the neighbors cells to the current cell i (pos in 1D = 1-3, in 2D 1-9...) and gives -1 is the pos is a boundary.

    e.g.

    grid = 

    1  2  3  4
    5  6  7  8
    9 10 11 12

    cellPosNeigh(4,5,4,3) = -1
    For i = 5 the outcomes of all the positions will be [-1,1,2,-1,5,6,-1,9,10]
    """
    function cellPosNeigh(pos,i,nX)
        px = pos + i - 2
        if px < 1 || px > nX
            return -1
        else
            return px
        end
    end

    function cellPosNeigh(pos,i,nX,nY)
        pos = pos - 1
        i = i - 1

        py = pos ÷ nX
        px = pos - nX*py

        iy = i ÷ 3
        ix = i - 3*iy

        py = py + iy - 1
        px = px + ix - 1

        if px < 0 || px >= nX || py < 0 || py >= nY
            return -1
        else
            return py*nY+px+1
        end
    end

    function cellPosNeigh(pos,i,nX,nY,nZ)
        pos = pos - 1
        i = i - 1

        pz = pos ÷ (nX * nY)
        py = (pos - nX*nY*pz) ÷ nX
        px = (pos - nX*nY*pz - nX*py)

        iz = i ÷ 9
        iy = (i - 9*iz) ÷ 3
        ix = (i - 9*iz - 3*iy)

        pz = pz + iz - 1
        py = py + iy - 1
        px = px + ix - 1

        if px < 0 || px >= nX || py < 0 || py >= nY || pz < 0 || pz >= nZ
            return -1
        else
            return pz*nY*nX+py*nX+px+1
        end
    end

    """
        function neighborsCellLinkedLoop(code,abm)

    Wrapper loop for cell linked neighbors algorithm.
    """
    function neighborsLoop(code,it,neig::CellLinked,dims)

        args = Any[:(pos_),:(i3_)]
        for i in 1:dims
            append!(args,[:(nCells_[$i])])
        end

        args2 = Any[:(cellEdge[1])]
        for (i,j) in enumerate(POSITIONPARAMETERS[1:dims])
            append!(args2,[:($j[i1_]),:(simBox[$i,1]),:(simBox[$i,2]),:(nCells_[$i])])
        end

        code = quote 
                    pos_ = CellBasedModels.CBMNeighbors.cellPos($(args2...))
                    for i3_ in 1:1:$(3^dims) #Go over the posible neighbor cells
                        posNeigh_ = CellBasedModels.CBMNeighbors.cellPosNeigh($(args...)) #Obtain the position of the neighbor cell
                        # println(i1_," ",i3_," ",posNeigh_)
                        if posNeigh_ != -1 #Ignore cells outside the boundaries
                            for i4_ in cellCumSum_[posNeigh_]-cellNumAgents_[posNeigh_]+1:1:cellCumSum_[posNeigh_] #Go over the cells of that neighbor cell
                                i2_ = cellAssignedToAgent_[i4_]
                                # println("\t"," ",i4_," ",i2_)
                                if i1_ != i2_
                                    $code 
                                end
                            end
                        end
                        # println()
                    end
                end 

        return code

    end

    """
        macro assignCells(platform, args...)

    Macro to generate the code to assign abm to a cell.

    Adds the following functions to the library:

        assignCells1CPU!(community)
        assignCells2CPU!(community)
        assignCells3CPU!(community)
        assignCells1GPU!(community)
        assignCells2GPU!(community)
        assignCells3GPU!(community)
    """
    macro assignCells(platform, args...)

        base = agentArgsNeighbors(args,CellLinked)

        args2 = Any[:(cellEdge[1])]
        for (i,j) in enumerate(args)
            append!(args2,[:($j[i1_]),:(simBox[$i,1]),:(simBox[$i,2]),:(nCells_[$i])])
        end

        name = Meta.parse(string("assignCells$(length(args))$(platform)!"))

        code = 0
        if platform == :CPU
            code = :(
                function $name($(base...))

                    @inbounds for i1_ in 1:1:N
                        pos = cellPos($(args2...))
                        cellNumAgents_[pos] += 1
                    end

                    return
                end
            )
        else
            code = :(
                function $name($(base...))

                    index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                    stride = gridDim().x * blockDim().x
                    @inbounds for i1_ in index:stride:N
                        pos = cellPos($(args2...))
                        CUDA.atomic_add!(CUDA.pointer(cellNumAgents_,pos),1)
                    end

                    return
                end
            )
        end

        return code
    end

    """
        assignCells1CPU!(community)
        assignCells2CPU!(community)
        assignCells3CPU!(community)
        assignCells1GPU!(community)
        assignCells2GPU!(community)
        assignCells3GPU!(community)

    Functions generated that assign the current positions of the agents to a cell.
    """
    @assignCells CPU x
    @assignCells CPU x y
    @assignCells CPU x y z
    # @assignCells GPU x
    # @assignCells GPU x y
    # @assignCells GPU x y z

    """
        macro sortAgentsInCells(platform, args...)

    Macro to generate the code to sort agents in cells in cell order.

    Adds the following functions to the library:

        sortAgentsInCells1CPU!(community)
        sortAgentsInCells2CPU!(community)
        sortAgentsInCells3CPU!(community)
        sortAgentsInCells1GPU!(community)
        sortAgentsInCells2GPU!(community)
        sortAgentsInCells3GPU!(community)
    """
    macro sortAgentsInCells(platform, args...)

        base = agentArgsNeighbors(args,CellLinked)

        args2 = Any[:(cellEdge[1])]
        for (i,j) in enumerate(args)
            append!(args2,[:($j[i1_]),:(simBox[$i,1]),:(simBox[$i,2]),:(nCells_[$i])])
        end

        name = Meta.parse(string("sortAgentsInCells$(length(args))$(platform)!"))

        code = 0
        if platform == :CPU
            code = :(
                function $name($(base...))

                    lk = ReentrantLock()
                    @inbounds for i1_ in 1:1:N
                        pos = cellPos($(args2...))
                        cellCumSum_[pos] += 1
                        pos = cellCumSum_[pos]
                        cellAssignedToAgent_[pos] = i1_
                    end

                    return
                end
            )
        else
            code = :(
                function $name($(base...))

                    index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                    stride = gridDim().x * blockDim().x
                    @inbounds for i1_ in index:stride:N
                        pos = cellPos($(args2...))
                        pos = CUDA.atomic_add!(CUDA.pointer(cellCumSum_,pos),1) + 1
                        cellAssignedToAgent_[pos] = i1_
                    end

                    return
                end
            )
        end

        return code
    end

    """
        sortAgentsInCells1CPU!(community)
        sortAgentsInCells2CPU!(community)
        sortAgentsInCells3CPU!(community)
        sortAgentsInCells1GPU!(community)
        sortAgentsInCells2GPU!(community)
        sortAgentsInCells3GPU!(community)

    Functions generated that assign the current positions of the agents to a cell.
    """
    @sortAgentsInCells CPU x
    @sortAgentsInCells CPU x y
    @sortAgentsInCells CPU x y z
    # @sortAgentsInCells GPU x
    # @sortAgentsInCells GPU x y
    # @sortAgentsInCells GPU x y z

    """
        macro neighborsCellLinked(platform, args...)

    Macro to generate the code to compute neighbors according to cell linked algorithm.
    This function puts together the action of:
        - assignCells
        - sortAgentsInCells

    Adds the following functions to the library:

        neighborsCellLinked1CPU!(community)
        neighborsCellLinked2CPU!(community)
        neighborsCellLinked3CPU!(community)
        neighborsCellLinked1GPU!(community)
        neighborsCellLinked2GPU!(community)
        neighborsCellLinked3GPU!(community)
    """
    macro neighborsCellLinked(platform, args...)

        base = agentArgsNeighbors(args,CellLinked,sym=:community)

        name = Meta.parse(string("neighborsCellLinked$(length(args))$(platform)!"))
        namef = Meta.parse(string("assignCells$(length(args))$(platform)!"))
        namef2 = Meta.parse(string("sortAgentsInCells$(length(args))$(platform)!"))

        code = 0
        if platform == :CPU
            code = :(
                function $name(community)

                    community.abm.neighbors.cellNumAgents_ .= 0
                    $namef($(base...),)
                    # community.abm.neighbors.cellCumSum_ .= cumsum(community.abm.neighbors.cellNumAgents_) .- community.abm.neighbors.cellNumAgents_
                    begin 
                        cumsum!(community.abm.neighbors.cellCumSum_, community.abm.neighbors.cellNumAgents_) 
                        community.abm.neighbors.cellCumSum_ .-= community.abm.neighbors.cellNumAgents_
                    end
                    $namef2($(base...),)
                    
                    return 
                end
            )
        else
            code = :(
                function $name(community)

                    community.abm.neighbors.cellNumAgents_ .= 0
                    kernel = @cuda launch=false $namef($(base...),)
                    CUDA.@sync kernel($(base...);threads=community.abm.platform.agentThreads,blocks=community.abm.platform.agentBlocks)
                    community.abm.neighbors.cellCumSum_ .= cumsum(community.abm.neighbors.cellNumAgents_) .- community.abm.neighbors.cellNumAgents_
                    # cumsum!(community.abm.neighbors.cellCumSum_, community.abm.neighbors.cellNumAgents_) 
                    # community.abm.neighbors.cellCumSum_ .-= community.abm.neighbors.cellNumAgents_
                    kernel2 = @cuda launch=false $namef2($(base...),)
                    CUDA.@sync kernel2($(base...);threads=community.abm.platform.agentThreads,blocks=community.abm.platform.agentBlocks)

                    return 
                end
            )
        end

        return code
    end

    """
        neighborsCellLinked1CPU!(community)
        neighborsCellLinked2CPU!(community)
        neighborsCellLinked3CPU!(community)
        neighborsCellLinked1GPU!(community)
        neighborsCellLinked2GPU!(community)
        neighborsCellLinked3GPU!(community)

    Functions generated to compute neighbors according to cell linked algorithm.
    """
    @neighborsCellLinked CPU x
    @neighborsCellLinked CPU x y
    @neighborsCellLinked CPU x y z
    # @neighborsCellLinked GPU x
    # @neighborsCellLinked GPU x y
    # @neighborsCellLinked GPU x y z

    #CLVD
"""
    mutable struct CLVD <: Verlet <: Neighbors

Method that computes Cell Linked and Verlet Displacement neighbors algorithms together to compute neighbors and only recompute when they left very far from center.

# Constructor

    function CLVD(;skin,nMaxNeighbors,cellEdge)

||Parameter|Description|
|:---|:---|:---|
|KwArgs|skin is the maximum distance around center to check neighbors.|
||nMaxNeighbors is the maximum number of neighbors that a cell may have.|
||cellEdge is the grid size to use to check for neighbors around neighbor cells.|
"""
    mutable struct CLVD <: Verlet

        skin
        nMaxNeighbors
        cellEdge

        neighborN_
        neighborList_
        posOld_
        accumulatedDistance_

        nCells_
        cellAssignedToAgent_
        cellNumAgents_
        cellCumSum_

        f_

        function CLVD(;skin,nMaxNeighbors,cellEdge)
            return new(skin,nMaxNeighbors,cellEdge,nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing,nothing)
        end

    end

    function initialize!(neig::CLVD,com)

        if typeof(com.abm.platform) <: CPU
            neig.neighborN_ = zeros(Int64,com.nMax_)
            neig.neighborList_ =  zeros(Int64,com.nMax_,neig.nMaxNeighbors)
            neig.posOld_ =  zeros(Float64,com.nMax_,com.abm.dims)
            neig.accumulatedDistance_ = zeros(Float64,com.nMax_)
            neig.nCells_ = ceil.(Int64,(com.simBox[:,2].-com.simBox[:,1])./neig.cellEdge .+2)
            neig.cellAssignedToAgent_ = zeros(Int64,com.nMax_)
            neig.cellNumAgents_ =  zeros(Int64,prod(neig.nCells_))
            neig.cellCumSum_ =  zeros(Int64,prod(neig.nCells_))
        else
            neig.neighborN_ = CUDA.zeros(Int,com.nMax_)
            neig.neighborList_ =  CUDA.zeros(Int,com.nMax_,neig.nMaxNeighbors)
            neig.posOld_ =  CUDA.zeros(com.nMax_,com.abm.dims)
            neig.accumulatedDistance_ = CUDA.zeros(com.nMax_)
            neig.cellEdge = cu(neig.cellEdge)
            neig.nCells_ = cu(ceil.(Int,(com.simBox[:,2].-com.simBox[:,1])./neig.cellEdge .+2))
            neig.cellAssignedToAgent_ = cu(zeros(Int,com.nMax_))
            neig.cellNumAgents_ =  cu(zeros(Int,prod(neig.nCells_)))
            neig.cellCumSum_ =  cu(zeros(Int,prod(neig.nCells_)))
        end
        neig.f_ = eval(Meta.parse("neighborsVerletDisplacement$(com.abm.dims)$(typeof(com.abm.platform))!"))

        return

    end

    function computeNeighbors!(neig::CLVD,com)

        neig.f_(com)

        return

    end

    """
        macro verletNeighborsCLVD(platform, args...)

    Macro to generate the code for the computation of Verlet lists going over CellLinked lists for different platforms and dimensions .

    Adds the following functions to the library:

        verletNeighborsCLVDCPU!(x)
        verletNeighborsCLVDCPU!(x,y)
        verletNeighborsCLVDCPU!(x,y,z)
        verletNeighborsCLVDGPU!(x)
        verletNeighborsCLVDGPU!(x,y)
        verletNeighborsCLVDGPU!(x,y,z)
    """
    macro verletNeighborsCLVD(platform, args...) #Macro to make the verletNeighbor loops

        base = agentArgsNeighbors(args,CLVD)

        args2 = []
        for i in args
            append!(args2,[:($i[i1_]),:($i[i2_])])
        end

        args3 = Any[:(pos_),:(i3_)]
        for i in 1:length(args)
            append!(args3,[:(nCells_[$i])])
        end

        args4 = Any[:(cellEdge[1])]
        for (i,j) in enumerate(POSITIONPARAMETERS[1:length(args)])
            append!(args4,[:($j[i1_]),:(simBox[$i,1]),:(simBox[$i,2]),:(nCells_[$i])])
        end

        name = Meta.parse("verletNeighborsCLVD$(length(args))$(platform)!")

        code = 0
        if platform == :CPU

            code = quote
                if i1_ != i2_
                    d = CBMMetrics.euclidean($(args2...))
                    if d < skin 
                        lock(lk) do
                            neighborN_[i1_] += 1
                            # neighborN_[i2_] += 1
                            neighborList_[i1_,neighborN_[i1_]] = i2_
                            # neighborList_[i2_,neighborN_[i2_]] = i1_
                        end
                    end
                end
            end

            code = quote
                pos_ = cellPos($(args4...))
                for i3_ in 1:1:$(3^length(args)) #Go over the posible neighbor cells
                    posNeigh_ = cellPosNeigh($(args3...)) #Obtain the position of the neighbor cell
                    if posNeigh_ != -1 #Ignore cells outside the boundaries
                        for i4_ in cellCumSum_[posNeigh_]-cellNumAgents_[posNeigh_]+1:1:cellCumSum_[posNeigh_] #Go over the cells of that neighbor cell
                            i2_ = cellAssignedToAgent_[i4_]
                            if i1_ != i2_
                                $code 
                            end
                        end
                    end
                end
            end

            code = :(
                function $name($(base...))
                    lk = ReentrantLock()
                    @inbounds Threads.@threads for i1_ in 1:1:N
                        $code
                    end
                end
            )
        elseif platform == :GPU

            code = quote
                if i1_ != i2_
                    d = CBMMetrics.euclidean($(args2...))
                    if d < skin
                        pos1 = CUDA.atomic_add!(CUDA.pointer(neighborN_,i1_),1) + 1
                        # pos2 = CUDA.atomic_add!(CUDA.pointer(neighborN_,i2_),1) + 1
                        neighborList_[i1_,pos1] = i2_
                        # neighborList_[i2_,pos2] = i1_
                    end
                end
            end

            code = quote
                pos_ = cellPos($(args4...))
                for i3_ in 1:1:$(3^length(args)) #Go over the posible neighbor cells
                    posNeigh_ = cellPosNeigh($(args3...)) #Obtain the position of the neighbor cell
                    if posNeigh_ != -1 #Ignore cells outside the boundaries
                        for i4_ in cellCumSum_[posNeigh_]-cellNumAgents_[posNeigh_]+1:1:cellCumSum_[posNeigh_] #Go over the cells of that neighbor cell
                            i2_ = cellAssignedToAgent_[i4_]
                            if i1_ != i2_
                                $code 
                            end
                        end
                    end
                end
            end

            code = :(
                function $name($(base...))
                    index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
                    stride = gridDim().x * blockDim().x
                    @inbounds for i1_ in index:stride:N
                        $code
                    end

                    return
                end
            )
        end

        return code

    end

    @verletNeighborsCLVD CPU x
    @verletNeighborsCLVD CPU x y
    @verletNeighborsCLVD CPU x y z
    # @verletNeighborsCLVD GPU x
    # @verletNeighborsCLVD GPU x y
    # @verletNeighborsCLVD GPU x y z

    """
        macro neighborsCLVD(platform, args...)

    Macro to generate the code to compute neighbors according to CellLinked-VerletDistance algorithms.

    Adds the following functions to the library:

        neighborsCLVD1CPU!(community)
        neighborsCLVD2CPU!(community)
        neighborsCLVD3CPU!(community)
        neighborsCLVD1GPU!(community)
        neighborsCLVD2GPU!(community)
        neighborsCLVD3GPU!(community)
    """
    macro neighborsCLVD(platform, args...)

        base = agentArgsNeighbors(args,CLVD,sym=:community)

        nameDisp = Meta.parse(string("verletDisplacement$(platform)!"))
        nameResDisp = Meta.parse(string("verletResetDisplacement$(platform)!"))

        namef = Meta.parse(string("assignCells$(length(args))$(platform)!"))
        namef2 = Meta.parse(string("sortAgentsInCells$(length(args))$(platform)!"))
        namef3 = Meta.parse(string("verletNeighborsCLVD$(length(args))$(platform)!"))

        name = Meta.parse(string("neighborsCLVD$(length(args))$(platform)!"))

        code = 0
        if platform == :CPU
            code = :(
                function $name(community)

                    $nameDisp($(base...),)
                    if community.flagRecomputeNeighbors_[1] == 1
                        #Stuff related with CellLink
                        community.abm.neighbors.cellNumAgents_ .= 0
                        $namef($(base...),)
                        community.abm.neighbors.cellCumSum_ .= cumsum(community.abm.neighbors.cellNumAgents_) .- community.abm.neighbors.cellNumAgents_
                        $namef2($(base...),)
                        #Stuff related with Verlet Displacement
                        @views community.abm.neighbors.neighborN_[1:community.N] .= 0
                        @views community.abm.neighbors.accumulatedDistance_[1:community.N] .= 0.
                        @views community.flagRecomputeNeighbors_ .= 0
                        $nameResDisp($(base...))
                        #Assign neighbors
                        $namef3($(base...),)
                    end

                    return 
                end
            )
        else
            code = :(
                function $name(community)

                    kernelDisp = @cuda launch=false $nameDisp($(base...),)
                    kernelResDisp = @cuda launch=false $nameResDisp($(base...),)
                    
                    CUDA.@sync kernelDisp($(base...);threads=community.abm.platform.agentThreads,blocks=community.abm.platform.agentBlocks)
                    if CUDA.@allowscalar community.flagRecomputeNeighbors_[1] == 1
                        #Stuff relateed with CellLinked
                        community.abm.neighbors.cellNumAgents_ .= 0
                        kernel = @cuda launch=false $namef($(base...),)
                        CUDA.@sync kernel($(base...);threads=community.abm.platform.agentThreads,blocks=community.abm.platform.agentBlocks)
                        community.abm.neighbors.cellCumSum_ .= cumsum(community.abm.neighbors.cellNumAgents_) .- community.abm.neighbors.cellNumAgents_
                        kernel2 = @cuda launch=false $namef2($(base...),)
                        CUDA.@sync kernel2($(base...);threads=community.abm.platform.agentThreads,blocks=community.abm.platform.agentBlocks)
                        #Stuff related with Verlet Displacement
                        CUDA.@sync community.abm.neighbors.neighborN_ .= 0
                        CUDA.@sync community.abm.neighbors.accumulatedDistance_ .= 0.
                        CUDA.@sync community.flagRecomputeNeighbors_ .= 0
                        CUDA.@sync kernelResDisp($(base...);threads=community.abm.platform.agentThreads,blocks=community.abm.platform.agentThreads)
                        #Assign neighbors
                        kernel3 = @cuda launch=false $namef3($(base...),)
                        CUDA.@sync kernel3($(base...);threads=community.abm.platform.agentThreads,blocks=community.abm.platform.agentThreads)
                    end

                    return 
                end
            )
        end

        return code
    end

    @neighborsCLVD CPU x
    @neighborsCLVD CPU x y
    @neighborsCLVD CPU x y z
    # @neighborsCLVD GPU x
    # @neighborsCLVD GPU x y
    # @neighborsCLVD GPU x y z

end