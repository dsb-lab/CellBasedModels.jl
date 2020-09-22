module CellCommunity

    push!(LOAD_PATH,"./")
    import CellStruct
    import Distributions

    mutable struct cellCommunity
        cells::Array{CellStruct.cell}
        nCells::Int
        neighbours::Array{Float32,2}
        dSpace::Int
        function cellCommunity(dspace::Int,dstate::Int,dparameters::Int,ncells::Int=1)
            c = Array{CellStruct.cell}(undef, ncells)
            for i in 1:ncells
                c[i]  = CellStruct.cell(dspace,dstate,dparameters)
            end
            new(c,ncells,Dspace)
        end
    end

    function updateNeighbours(com::cellCommunity, metric = euclideMetric, cutoff::Float32 = 0.1)
        for i in 1:com.nCells
            for j in 1:com.nCells

    end

    function evolveCells(com::cellCommunity, stopCriterion::string = "time", integrator = rungeKutta2, potential = normal, precission::Float32 = 0.1f0)

    end

    function cellDivision(com::cellCommunity, cellId::Int32, splitMethod::string = "randomEvenHalves", customSplit = nothing)

        if splitMethod == "randomEvenHalves"
            #Choose axis 
            ax = Array{Float32}(undef,com.dSpace)
            total::Float32 = 0
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
            com.cellCommunity.cells[cellId].pos += ax/2
            cop.pos -= ax/2
        
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
        evolveCells(com, stopCriterion = "relaxation", precission = 0.1)

    end

end