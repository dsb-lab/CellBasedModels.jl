using CUDA

mutable struct cellCommunitySCG

    spatialModel::interpretedData
    chemicalModel::interpretedData
    growthModel::interpretedData

    spatialParametersGlobal::AbstractArray
    spatialVariables::AbstractArray
    spatialParametersLocal::AbstractArray

    chemicalParametersGlobal::AbstractArray
    chemicalVariables::AbstractArray
    chemicalParametersLocal::AbstractArray
    
    growthParametersGlobal::AbstractArray
    growthVariables::AbstractArray
    growthParametersLocal::AbstractArray

    nCells::Integer
    t::Real

    function cellCommunity(spModel::String, chModel::String, grModel::String)

        #Extract spatial model
        spatialModel = extractModel(spModel)
        #Check there are spatial variables 
        if length(spatialModel.names["SpatialVariables:"]) == 0
            error("Spatial model should have at least one variable. Maybe you prefer a model without spatial dynamics?")
        #Check there are as many variables as diff. eq.
        for i in spatialModel.names["SpatialVariables:"]
            found = false
            for j in spatialModel.dynamics["Dynamics:"]
                if findfirst(i,j) !== nothing
                    found = true
                end
            end
            if found == false
                error("No differential equation has been defined for variable ", i, " in the spatial model.")
            end
        end

        #Extract chemical model
        chemicalModel = extractModel(chModel)
        #Check there are spatial variables 
        if length(chemicalModel.names["SpatialVariables:"]) == 0
            error("Chemical model should have at least one variable. Maybe you prefer a model without chemical dynamics?")
        #Check there are as many variables as diff. eq.
        for i in chemicalModel.names["ChemicalVariables:"]
            found = false
            for j in chemicalModel.dynamics["Dynamics:"]
                if findfirst(i,j) !== nothing
                    found = true
                end
            end
            if found == false
                error("No differential equation has been defined for variable ", i, " in the chemical model.")
            end
        end

        #Extract growth model
        growthModel = extractModel(grModel)
        #Check there are spatial variables 
        if length(growthModel.names["SpatialVariables:"]) == 0
            error("Growth model should have at least one variable. Maybe you prefer a model without growth dynamics?")
        #Check there are as many variables as diff. eq.
        for i in growthModel.names["GrowthVariables:"]
            found = false
            for j in growthModel.dynamics["Dynamics:"]
                if findfirst(i,j) !== nothing
                    found = true
                end
            end
            if found == false
                error("No differential equation has been defined for variable ", i, " in the growth model.")
            end
        end
        #Check there is a splitting process defined 
        if length(growthModel.names["SplitProcess:"]) == 0
            print("Model with growing cells has not a defined splitting method. Maybe you should include one or they will grow forever.")

        listVariablesSp = [[],[],[]]
        listVariablesCh = [[],[],[]]
        listVariablesGr = [[],[],[]]
        for i in SpatialHeadersParams
            for j in spatialModel.names[i]
                push!(listVariablesSp[1],j)
            end
            for j in chemicalModel.names[i]
                push!(listVariablesCh[1],j)
            end
            for j in growthModel.names[i]
                push!(listVariablesGr[1],j)
            end
        end
        for i in ChemicalHeadersParams
            for j in spatialModel.names[i]
                push!(listVariablesSp[2],j)
            end
            for j in chemicalModel.names[i]
                push!(listVariablesCh[2],j)
            end
            for j in growthModel.names[i]
                push!(listVariablesGr[2],j)
            end
        end
        for i in GrawthHeadersParams
            for j in spatialModel.names[i]
                push!(listVariablesSp[3],j)
            end
            for j in chemicalModel.names[i]
                push!(listVariablesCh[3],j)
            end
            for j in growthModel.names[i]
                push!(listVariablesGr[3],j)
            end
        end
        
        #Check repetition of variables
        for i in listVariablesSp[1]
            if findall(x->x=i,listVariablesCh[2]) !== nothing
                error("Repetition of parameter/variable ",i, " declared in the Spatial and Chemical models. Redefine one.")
            end
        end
        for i in listVariablesSp[1]
            if findall(x->x=i,listVariablesGr[3]) !== nothing
                error("Repetition of parameter/variable ",i, " declared in the Spatial and Growth models. Redefine one.")
            end
        end
        for i in listVariablesCh[1]
            if findall(x->x=i,listVariablesGr[2]) !== nothing
                error("Repetition of parameter/variable ",i, " declared in the Chemical and Chemical models. Redefine one.")
            end
        end

        #Check external variables not defined in the other model        
        for i in listVariablesSp[2]
            if findall(x->x=i,listVariablesCh[2]) === nothing
                error("Chemical parameter/variable ",i, " declared in the Spatial model and not defined in Chemical model.")
            end
        end
        for i in listVariablesSp[3]
            if findall(x->x=i,listVariablesGr[3]) === nothing
                error("Growth parameter/variable ",i, " declared in the Spatial model and not defined in Growth model.")
            end
        end
        for i in listVariablesCh[1]
            if findall(x->x=i,listVariablesSp[1]) === nothing
                error("Spatial parameter/variable ",i, " declared in the Chemical model and not defined in Spatial model.")
            end
        end
        for i in listVariablesCh[3]
            if findall(x->x=i,listVariablesGr[3]) === nothing
                error("Growth parameter/variable ",i, " declared in the Chemical model and not defined in Growth model.")
            end
        end
        for i in listVariablesGr[1]
            if findall(x->x=i,listVariablesSp[1]) === nothing
                error("Spatial parameter/variable ",i, " declared in the Growth model and not defined in Spatial model.")
            end
        end
        for i in listVariablesGr[2]
            if findall(x->x=i,listVariablesCh[2]) === nothing
                error("Chemical parameter/variable ",i, " declared in the Growth model and not defined in Chemical model.")
            end
        end

        #To be done
        new(spatialModel, chemicalModel, growthModel, AbstractArray([spatialModel.]), [], cd, [], [], [], gd, [])

    end

end
#Pretty printing of the noMovement structure
Base.show(io::IO, z::cellCommunity) = print(io, "Spatial parameters: ", typeof(z.spatialParametersNames), "\n",z.spatialParametersNames,"\n",
                                                "Chemical parameters: ", typeof(z.chemicalParametersNames), "\n",z.chemicalParametersNames,"\n",
                                                "Grow parameters parameters: ", typeof(z.growParametersNames), "\n",z.growParametersNames,"\n")


                                                spatialParametersGlobal::AbstractArray
                                                spatialVariables::AbstractArray
                                                spatialParametersLocal::AbstractArray
                                            
                                                chemicalParametersGlobal::AbstractArray
                                                chemicalVariables::AbstractArray
                                                chemicalParametersLocal::AbstractArray
                                                
                                                growthParametersGlobal::AbstractArray
                                                growthVariables::AbstractArray
                                                growthParametersLocal::AbstractArray
                                            
                                                nCells::Integer
                                                t::Real

                                                
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
