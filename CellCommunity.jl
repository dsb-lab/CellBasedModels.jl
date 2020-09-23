using CUDA

mutable struct cellCommunity

    #Global properties
    chemicalParametersGlobal::CUDA.Array{Float32}
    shapeParametersGlobal::CUDA.Array{Float32}

    distanceMatrix::CUDA.Array{Float32}
    nearestNeighbours::CUDA.Array{Float32}
    nCells::Integer
    dSpace::Integer
    dChemicals::Integer
    t::Float64

    #Local properties
    chemicalDynamicsLocal::CUDA.Array{Float32}
    chemicalParametersLocal::CUDA.Array{Float32}

    shapeDynamicsLocal::CUDA.Array{Float32}
    shapeParametersLocal::CUDA.Array{Float32}

    innerTime::CUDA.Array{Float32}

    function cellCommunity(dspace::Int,dstate::Int,dparameters::Int,ncells::Int)

        c = Array{CellStruct.cell}(undef, ncells)
        for i in 1:ncells
            c[i]  = CellStruct.cell(dspace,dstate,dparameters)
        end

        n = zeros(ncells,ncells)

        f = Array{Array{Float64}}(undef,ncells)
        for i in 1:ncells
            f[i]  = zeros(dspace)
        end
        new(c,ncells,Dspace,n,f,0)

        new(c,ncells,Dspace,n)
    end

end

"""function updateNeighbours(com::cellCommunity, metric = Metrics.nearestNeighbours)
    for i in 1:com.nCells
        for j in 1:com.nCells
            com.neighbours[i,j] = metric(com.cells[i],com.cells[j])

end

function step(com::cellCommunity, integrator, forceFunction, potential, dt)
    for i in 1:com.nCells
        com.state = integrator(com.state,com.forces[i],com.t,dt,forceFunction)
    end

end

    function computeForces(com::cellCommunity, potential)

        for i in 1:com.nCells
            for j in 1:com.nCells
                com.forces[i] += potential(com.cells[i], com.cells[j])
            end
        end

    end

    function evolveCells(com::cellCommunity, integrator = Integrators.rungeKutta4, forceFunction = SpatialDynamics.freeInertialMovement, potential = Potentials.normal)

        computeForces(com,potential)
        #Perform step
        step(com, integrator, forceFunction, potential, dt)
        com.t += dt

    end

    function cellDivision(com::cellCommunity, cellId::Int32, splitMethod::string = "randomEvenHalves", customSplit = nothing)

        if splitMethod == "randomEvenHalves"
            #Choose axis 
            ax = Array{Float64}(undef,com.dSpace)
            total::Float64 = 0
            for i in 1:com.dSpace
                ax[i] = Distributions.Normal(0,1)
                total += ax[i]^2
            end
            #Normalise
            total = sqrt(total)
            ax /= total
            #Create new cell
            cop = deepcopy(com.cellCommunity.cells[cellId])
            #Create new center of the cells
            com.cellCommunity.cells[cellId].pos += ax*cop.radius/2
            cop.pos -= ax*cop.radius/2
        
        end

        #Reduce the volume by half
        com.cellCommunity.cells[cellId].radius /= 2^(1/3)
        cop.radius /= 2^(1/3)
        #Add new cell to the list
        append!(com.cells,cop)
        com.nCells += 1
        #Update neighbours
        updateNeighbours(com)

    end

    function growCluster(com::cellCommunity)

        c = rand(1:length(com.cells))
        #Store original radius
        r = com.cells[c].radius
        #Make division
        cellDivision(com, c)
        #Return the original radius
        com.cells[c].radius = r        
        com.cells[com.nCells] = r

        #Evolve the model for a few steps
        evolveCells(com)

    end"""
