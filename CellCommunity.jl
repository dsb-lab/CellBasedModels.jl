using CUDA

mutable struct cellCommunity

    spatialParametersNames::SpatialDynamics
    spatialParametersGlobal::AbstractArray
    spatialDynamicsLocal::AbstractArray
    spatialParametersLocal::AbstractArray

    chemicalParametersNames::ChemicalDynamics
    chemicalParametersGlobal::AbstractArray
    chemicalDynamicsLocal::AbstractArray
    chemicalParametersLocal::AbstractArray
    
    growParametersNames::GrowDynamics
    shapeParametersLocal::AbstractArray

    nCells::Integer
    t::Real

    function cellCommunity(sd::SpatialDynamics, cd::ChemicalDynamics, gd::GrowDynamics)

        new(sd, [], [], [], cd, [], [], [], gd, [])

    end

end
#Pretty printing of the noMovement structure
Base.show(io::IO, z::cellCommunity) = print(io, "Spatial parameters: ", typeof(z.spatialParametersNames), "\n",z.spatialParametersNames,"\n",
                                                "Chemical parameters: ", typeof(z.chemicalParametersNames), "\n",z.chemicalParametersNames,"\n",
                                                "Grow parameters parameters: ", typeof(z.growParametersNames), "\n",z.growParametersNames,"\n")

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
