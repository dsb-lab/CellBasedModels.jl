import ...AgentBasedModels: rand, Categorical, Uniform

"""
    function beeColonyAlgorithm(communityInitial::Community, 
        model::Model, 
        loosFunction:: Function, 
        searchList::Dict{Symbol,<:Union{<:Tuple{<:Number,<:Number},Vector{<:Number}}}, 
        evalParams::Dict{Symbol,<:Number};
        population::Int=100,
        limitCycles::Int = 10,
        stopMaxGenerations::Int = 100,
        initialisation::Union{Nothing,DataFrame} = nothing,
        initialisationF::Union{Nothing,Function} = nothing,
        returnAll::Bool = false,
        saveFileName::Union{Nothing,String} = nothing)

Optimization of the parameter space of a model that uses the [Bee Colony Algorithm](https://en.wikipedia.org/wiki/Artificial_bee_colony_algorithm).

Args:
 - **communityInitial::Community** : Community to use as a base to start the optimization.
 - **model::Model** : Model to be optimized to evolve the communityInitial.
 - **loosFunction:: Function** : Cost function over which optimize the parameter.
 - **searchList::Dict{Symbol,<:Tuple{<:Number,<:Number}}}** : Dictionary of parameters and the ranges of exloration the parameters (e.g. :x => (0,1)).
 - **evalParams::Dict{Symbol,<:Number}** : Dictionary of parameters and the ranges of exloration the parameters (e.g. :tMax => 10).

kArgs:
 - **population::Int=100** : Size of the colony used at each generation for the optimization.
 - **limitCycles::Int = 10** : Hyperparameter of the algorithm that says how many generations without update are waited until jump to other position.
 - **stopMaxGenerations::Int = 100** : How many generations do before stopping the algorithm. 
 - **initialisation::Union{Nothing,DataFrame} = nothing** : DataFrame defining the initial parameters of the population. If nothing, they are set randomly.
 - **initialisationF::Union{Nothing,Function} = nothing** : Function that takes communityInitial as an argument and searchList parameters as kargs and modifies the communityInitial.
 - **returnAll::Bool = false** : If return the hole list of parameters explored or the just the most fit.
 - **saveFileName::Union{Nothing,String} = nothing** : If given a string, it saves the parameters explored in a file with the corresponding name.
"""
function beeColonyAlgorithm(communityInitial::Community, 
                        model::Model, 
                        loosFunction:: Function, 
                        searchList::Dict{Symbol,<:Tuple{<:Number,<:Number}}, 
                        evalParams::Dict{Symbol,<:Number};
                        population::Int=100,
                        limitCycles::Int = 10,
                        stopMaxGenerations::Int = 100,
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
                    error("beeColonyAlgorithm only works with continuous parameters.")
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
    m[:,:_cycles_] .= 0

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
        #Update rule
        mNew = DataFrame([i=>zeros(population) for i in keys(searchList)]...)
        mNew[:,:_score_] .= 0.
        mNew[:,:_generation_] .= count
        mNew[:,:_cycles_] .= m[:,:_cycles_]
        #Updating the population
        p = 1 .-(m[:,:_score_] .-minimum(m[:,:_score_]))./(maximum(m[:,:_score_])-minimum(m[:,:_score_]))
        if maximum(m[:,:_score_]) != minimum(m[:,:_score_])
            p = p./sum(p)
        else
            p .= 1/population
        end
        for i in 1:population
            candidate = rand(Categorical(p))
            for param in keys(searchList)
                #Computing new positions
                if m[i,:_cycles_] < limitCycles
                    mNew[i,param] = m[i,param] + rand(Uniform(-1,1))*(m[candidate,param]-m[i,param])
                    if mNew[i,param] < searchList[Symbol(param)][1]
                        mNew[i,param] = searchList[Symbol(param)][1]
                    elseif mNew[i,param] > searchList[Symbol(param)][2]
                        mNew[i,param] = searchList[Symbol(param)][2]
                    end
                else
                    mNew[i,Symbol(param)] = rand(Uniform(searchList[Symbol(param)]...))
                end
            end
            if m[i,:_cycles_] < limitCycles
                mNew[i,:_cycles_] = 0
            end
        end
        mOld = copy(m)
        m = copy(mNew)

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

            #Check if keep old update
            if m[i,:_score_] > mOld[i,:_score_]
                generation = m[i,:_generation_]
                m[i,:] = mOld[i,:]
                m[i,:_cycles_] += 1
                m[i,:_generation_] = generation
            end
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