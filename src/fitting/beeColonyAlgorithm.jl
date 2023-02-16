import ...AgentBasedModels: rand, Categorical, Uniform

"""
    function beeColonyAlgorithm(
        evalFunction::Function, 
        searchList::Dict{Symbol,<:Tuple{<:Number,<:Number}}; 
        population::Int=100,
        limitCycles::Int = 10,
        stopMaxGenerations::Int = 100,
        returnAll::Bool = false,
        initialisation::Union{Nothing,DataFrame} = nothing,
        saveFileName::Union{Nothing,String} = nothing,
        args::Vector{<:Any} = Any[],
        verbose=false)

Optimization of the parameter space of a model that uses the [Bee Colony Algorithm](https://en.wikipedia.org/wiki/Artificial_bee_colony_algorithm).

||Parameter|Description|
|:---|:---|:---|
|Args|evalFunction:: Function | Function that takes a DataFrame with parameters, generates the simulations and returns a score of the fit.|
||searchList::Dict{Symbol,<:Tuple{<:Number,<:Number}}} | Dictionary of parameters and the ranges of exloration the parameters (e.g. :x => (0,1)).|
|KwArgs|population::Int=100 | Size of the colony used at each generation for the optimization.|
||limitCycles::Int = 10 | Hyperparameter of the algorithm that says how many generations without update are waited until jump to other position.|
||stopMaxGenerations::Int = 100 | How many generations do before stopping the algorithm. |
||returnAll::Bool = false | If return the hole list of parameters explored or the just the most fit.|
||initialisation::Union{Nothing,DataFrame} = nothing | DataFrame defining the initial parameters of the population. If nothing, they are set randomly.|
||saveFileName::Union{Nothing,String} = nothing | If given a string, it saves the parameters explored in a file with the corresponding name.|
||args::Vector{<:Any} = Any[] | Additional arguments to give to `evalFunction`.|
||verbose=false | If `true`, show progress bar during optimization.|
"""
function beeColonyAlgorithm(
                        evalFunction::Function, 
                        searchList::Dict{Symbol,<:Tuple{<:Number,<:Number}}; 
                        population::Int=100,
                        limitCycles::Int = 10,
                        stopMaxGenerations::Int = 100,
                        returnAll::Bool = false,
                        initialisation::Union{Nothing,DataFrame} = nothing,
                        saveFileName::Union{Nothing,String} = nothing,
                        args::Vector{<:Any} = Any[],
                        verbose=false)

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
    if verbose
        prog = Progress(population,string("Generation ",1,"/",stopMaxGenerations))
    end
    Threads.@threads for i in 1:population
        m[i,:_score_] = evalFunction(m[i,:],args...)
        if verbose
            next!(prog)
        end
    end
    mTotal = copy(m)

    if saveFileName !== nothing
        CSV.write(string(saveFileName,".csv"),mTotal)
    end

    count = 2
    for k in 2:stopMaxGenerations
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
        if verbose
            prog = Progress(population,string("Generation ",k,"/",stopMaxGenerations))
        end
        Threads.@threads for i in 1:population
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
            if verbose
                next!(prog)
            end
        end
        mOld = copy(m)
        m = copy(mNew)

        #Simulations
        for i in 1:population
            m[i,:_score_] = evalFunction(m[i,:],args...)

            #Check if keep old update
            if m[i,:_score_] > mOld[i,:_score_]
                generation = m[i,:_generation_]
                m[i,:] = mOld[i,:]
                m[i,:_cycles_] += 1
                m[i,:_generation_] = generation
                if verbose
                    next!(prog)
                end
            end
        end
        append!(mTotal,m)

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