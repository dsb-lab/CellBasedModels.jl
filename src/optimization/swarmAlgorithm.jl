import ...AgentBasedModels: rand

"""
    function swarmAlgorithm(evalFunction::Function,  
        searchList::Dict{Symbol,<:Union{<:Tuple{<:Number,<:Number},Vector{<:Number}}};
        population::Int=100,
        weightInertia::Number = .1,
        weightGlobalBest::Number = .1, 
        weightPopulationBest::Number = .1, 
        stopMaxGenerations::Int = 10,
        initialisation::Union{Nothing,DataFrame} = nothing,
        returnAll::Bool = false,
        saveFileName::Union{Nothing,String} = nothing,
        args::Vector{<:Any} = Any[])

Optimization of the parameter space of a model that uses the [Swarm Algorithm](https://en.wikipedia.org/wiki/Particle_swarm_optimization).

Args:
- **evalFunction:: Function** : Function that takes a DataFrame with parameters, generates the simulations and returns a score of the fit.
- **searchList::Dict{Symbol,<:Tuple{<:Number,<:Number}}}** : Dictionary of parameters and the ranges of exloration the parameters (e.g. :x => (0,1)).

kArgs:
 - **population::Int = 100** : Size of the colony used at each generation for the optimization.
 - **weightInertia::Number = .1** : Hyperparameter of the colony weighting the current velocity.
 - **weightGlobalBest::Number = .1** : Hyperparameter of the colony weighting the global best solution.
 - **weightPopulationBest::Number = .1** : Hyperparameter of the colony weighting the local best solution.
 - **stopMaxGenerations::Int = 10** : How many generations do before stopping the algorithm. 
 - **initialisation::Union{Nothing,DataFrame} = nothing** : DataFrame defining the initial parameters of the population. If nothing, they are set randomly.
 - **returnAll::Bool = false** : If return the hole list of parameters explored or the just the most fit.
 - **saveFileName::Union{Nothing,String} = nothing** : If given a string, it saves the parameters explored in a file with the corresponding name.
 - **args::Vector{<:Any} = Any[]** : Additional arguments to give to `evalFunction`.
"""
function swarmAlgorithm(evalFunction::Function,  
                        searchList::Dict{Symbol,<:Union{<:Tuple{<:Number,<:Number},Vector{<:Number}}};
                        population::Int=100,
                        weightInertia::Number = .1,
                        weightGlobalBest::Number = .1, 
                        weightPopulationBest::Number = .1, 
                        stopMaxGenerations::Int = 10,
                        initialisation::Union{Nothing,DataFrame} = nothing,
                        returnAll::Bool = false,
                        saveFileName::Union{Nothing,String} = nothing,
                        args::Vector{<:Any} = Any[])

    mTotal = DataFrame()

    #Creating the dataframe
    m = DataFrame([i=>zeros(population) for i in keys(searchList)]...)
    for param in keys(searchList)
        m[:,Meta.parse(string(param,"_velocity_"))] .= 0.
    end
    if initialisation === nothing
        for i in 1:population
            for param in keys(searchList)
                if typeof(searchList[Symbol(param)]) <: Tuple{<:Number,<:Number}
                    m[i,Symbol(param)] = rand(Uniform(searchList[Symbol(param)]...))
                else
                    error("beeColonyAlgorithm only works with continuous parameters.")
                end
                #Initialize velocity
                vel = Meta.parse(string(param,"_velocity_"))
                dif = searchList[Symbol(param)][2]-searchList[Symbol(param)][1]
                m[i,Symbol(vel)] = rand(Uniform(-dif,dif))
            end
        end
    else
        for i in 1:population
            for param in keys(searchList)
                m[i,Symbol(param)] = initialisation[i,Symbol(param)]
                #Initialize velocity
                vel = Meta.parse(string(param,"_velocity_"))
                dif = searchList[Symbol(param)][2]-searchList[Symbol(param)][1]
                m[i,Symbol(vel)] = rand(Uniform(-dif,dif))
            end
        end
    end
    m[:,:_score_] .= 0.
    m[:,:_generation_] .= 1

    #Start first simulations
    for i in 1:population
        m[i,:_score_] = evalFunction(m[i,:],args...)
    end
    mTotal = copy(m)
    mPBest = m[argmin(m._score_),:]
    mGBest = m[argmin(m._score_),:]

    if saveFileName !== nothing
        CSV.write(string(saveFileName,".csv"),mTotal)
    end

    count = 2
    while count <= stopMaxGenerations
        #Update rule
        mNew = DataFrame([i=>zeros(population) for i in keys(searchList)]...)
        for param in keys(searchList)
            mNew[:,Meta.parse(string(param,"_velocity_"))] .= 0.
        end
        #Updating the population
        for i in 1:population
            for param in keys(searchList)
                #Computing new velocities
                vel = Meta.parse(string(param,"_velocity_"))
                v =  weightInertia * m[i,vel] + weightGlobalBest * rand() * (mGBest[param] - m[i,param]) + weightPopulationBest * rand() * (mPBest[param] - m[i,param])
                #Updating parameters and cheking bounds of exploration
                mNew[i,param] = m[i,param] + v
                mNew[i,vel] = v
                if mNew[i,param] < searchList[Symbol(param)][1]
                    mNew[i,param] = searchList[Symbol(param)][1]
                elseif mNew[i,param] > searchList[Symbol(param)][2]
                    mNew[i,param] = searchList[Symbol(param)][2]
                end
            end
        end
        m = copy(mNew)
        m[:,:_score_] .= 0.
        m[:,:_generation_] .= count

        #Simulations
        for i in 1:population
            m[i,:_score_] = evalFunction(m[i,:],args...)
        end
        append!(mTotal,m)

        mPBest = m[argmin(m._score_),:]
        if mPBest._score_ < mGBest._score_
            mGBest = copy(mPBest)
        end

        if saveFileName !== nothing
            CSV.write(string(saveFileName,".csv"),m,append=true)
        end

        count += 1
    end

    if returnAll
        return mTotal
    else
        return mTotal[argmin(mTotal._score_),:]
    end
end