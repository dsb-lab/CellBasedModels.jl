import ...AgentBasedModels: rand, Categorical, Uniform

"""
    function geneticAlgorithm(communityInitial::Community, 
        model::Model, 
        loosFunction:: Function, 
        searchList::Dict{Symbol,<:Union{<:Tuple{<:Number,<:Number},Vector{<:Number}}}, 
        evalParams::Dict{Symbol,<:Number};
        population::Int=100,
        parentSelectionAlg::String = "weighted", #weighted or random
        parentSelectionP::Number = .1, 
        mutationRate::Number = .1, 
        stopMaxGenerations::Int = 10,
        initialisation::Union{Nothing,DataFrame} = nothing,
        initialisationF::Union{Nothing,Function} = nothing,
        returnAll::Bool = false,
        saveFileName::Union{Nothing,String} = nothing)

Optimization of the parameter space of a model that uses the [Particle Swarm Algorithm](https://en.wikipedia.org/wiki/Particle_swarm_optimization).

Args:
communityInitial::Community : Community to use as a base to start the optimization.
model::Model : Model to be optimized to evolve the communityInitial.
loosFunction:: Function : Cost function over which optimize the parameter.
searchList::Dict{Symbol,<:Tuple{<:Number,<:Number}}} : Dictionary of parameters and the ranges of exloration the parameters (e.g. :x => (0,1)).
evalParams::Dict{Symbol,<:Number} : Dictionary of parameters and the ranges of exloration the parameters (e.g. :tMax => 10).

kArgs:
population::Int=100 : Size of the colony used at each generation for the optimization.
parentSelectionAlg::String = "weighted" : Weigthing method of the population ot chose descendants. 
parentSelectionP::Number = .1 : Hyperparameter of the algorithm indicating the proportion of parameters exchanged between parents.
mutationRate::Number = .1 : Hyperparameter of the algorithm indicating the probability of resampling the parameter with a uniform.
stopMaxGenerations::Int = 10 : How many generations do before stopping the algorithm. 
initialisation::Union{Nothing,DataFrame} = nothing : DataFrame defining the initial parameters of the population. If nothing, they are set randomly.
initialisationF::Union{Nothing,Function} = nothing : Function that takes communityInitial as an argument and searchList parameters as kargs and modifies the communityInitial.
returnAll::Bool = false : If return the hole list of parameters explored or the just the most fit.
saveFileName::Union{Nothing,String} = nothing : If given a string, it saves the parameters explored in a file with the corresponding name.
"""
function geneticAlgorithm(communityInitial::Community, 
                        model::Model, 
                        loosFunction:: Function, 
                        searchList::Dict{Symbol,<:Union{<:Tuple{<:Number,<:Number},Vector{<:Number}}}, 
                        evalParams::Dict{Symbol,<:Number};
                        population::Int=100,
                        parentSelectionAlg::String = "weighted", #weighted or random
                        parentSelectionP::Number = .1, 
                        mutationRate::Number = .1, 
                        stopMaxGenerations::Int = 10,
                        initialisation::Union{Nothing,DataFrame} = nothing,
                        initialisationF::Union{Nothing,Function} = nothing,
                        returnAll::Bool = false,
                        saveFileName::Union{Nothing,String} = nothing)

    mTotal = DataFrame()

    #Creating the dataframe
    m = DataFrame([i=>zeros(population) for i in keys(searchList)]...)
    if initialisation === nothing
        for i in 1:population
            for param in keys(searchList)
                if typeof(searchList[Symbol(param)]) <: Tuple{<:Number,<:Number}
                    m[i,Symbol(param)] = rand(Uniform(searchList[Symbol(param)]...))
                else
                    m[i,Symbol(param)] = rand(searchList[Symbol(param)])
                end
            end
        end
    else
        for i in 1:population
            for param in keys(searchList)
                m[i,Symbol(param)] = initialisation[i,Symbol(param)]
            end
        end
    end
    m[:,:_score_] .= 0.
    m[:,:_generation_] .= 1

    #Start first simulations
    for i in 1:population
        com = deepcopy(communityInitial)
        #Set parameters
        if initialisationF === nothing
            for param in keys(searchList)
                com[Symbol(param)] = m[i,param]
            end
        else
            initialisationF(com;[Symbol(param)=>m[i,param] for param in keys(searchList)]...)
        end
        #Run simulation
        comt = model.evolve(com;evalParams...)
        #Run loos function
        m[i,:_score_] = loosFunction(comt)
    end
    mTotal = copy(m)

    if saveFileName !== nothing
        CSV.write(saveFileName,m[line,:])
    end

    count = 2
    while count <= stopMaxGenerations
        #Selective Breading and mutation
        mNew = DataFrame([i=>zeros(population) for i in keys(searchList)]...)
        #Weighted probability
        p = 1 .-(m[:,:_score_] .-minimum(m[:,:_score_]))./(maximum(m[:,:_score_])-minimum(m[:,:_score_]))
        if maximum(m[:,:_score_]) != minimum(m[:,:_score_])
            p = p./sum(p)
        else
            p .= 1/population
        end
        for i in 1:2:population
            parents = rand(Categorical(p),2)
            for param in keys(searchList)
                #Crossing
                if parentSelectionP < rand()
                    mNew[i,Symbol(param)] = m[parents[1],param]
                    mNew[i+1,Symbol(param)] = m[parents[2],param]
                else
                    mNew[i,Symbol(param)] = m[parents[2],param]
                    mNew[i+1,Symbol(param)] = m[parents[1],param]
                end
                #Mutation
                if mutationRate > rand()
                    if typeof(searchList[Symbol(param)]) <: Tuple{<:Number,<:Number}
                        mNew[i,Symbol(param)] = rand(Uniform(searchList[Symbol(param)]...))
                    else
                        mNew[i,Symbol(param)] = rand(searchList[Symbol(param)])
                    end
                end
                if mutationRate > rand()
                    if typeof(searchList[Symbol(param)]) <: Tuple{<:Number,<:Number}
                        mNew[i+1,Symbol(param)] = rand(Uniform(searchList[Symbol(param)]...))
                    else
                        mNew[i+1,Symbol(param)] = rand(searchList[Symbol(param)])
                    end
                end
            end
        end
        m = copy(mNew)
        m[:,:_score_] .= 0.
        m[:,:_generation_] .= count

        #Simulations
        for i in 1:population
            com = deepcopy(communityInitial)
            #Set parameters
            if initialisationF === nothing
                for param in keys(searchList)
                    com[Symbol(param)] = m[i,param]
                end
            else
                initialisationF(com;[Symbol(param)=>m[i,param] for param in keys(searchList)]...)
            end
            #Run simulation
            comt = model.evolve(com;evalParams...)
            #Run loos function
            m[i,:_score_] = loosFunction(comt)
        end
        append!(mTotal,m)

        if saveFileName !== nothing
            CSV.write(saveFileName,m[line,:],append=true)
        end

        count += 1
    end

    if returnAll
        return mTotal
    else
        return mTotal[argmin(mTotal._score_),:]
    end
end