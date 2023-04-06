import ...CellBasedModels: rand, MultivariateNormal

"""
    function stochasticDescentAlgorithm(evalFunction::Function, 
        searchList::Dict{Symbol,<:Union{<:Tuple{<:Number,<:Number},Vector{<:Number}}}; 
        population::Int=1,
        jumpVarianceStart::Union{<:Number,Matrix{<:Number}} = .1, 
        nStatistics::Number = 10, 
        stopMaxGenerations::Number = 100, 
        initialisation::Union{Nothing,DataFrame} = nothing,
        returnAll::Bool=false,
        saveFileName::Union{Nothing,String} = nothing,
        args::Vector{<:Any} = Any[],
        verbose=false)

Optimization of the parameter space of a model that uses [Stochastic Gradient Descent](https://en.wikipedia.org/wiki/Stochastic_gradient_descent).

||Parameter|Description|
|:---|:---|:---|
|Args|evalFunction:: Function | Function that takes a DataFrame with parameters, generates the simulations and returns a score of the fit.|
||searchList::Dict{Symbol,<:Tuple{<:Number,<:Number}}} | Dictionary of parameters and the ranges of exloration the parameters (e.g. :x => (0,1)).|
|KwArgs|population::Int=100 | Size of the colony used at each generation for the optimization.|
||jumpVarianceStart::Union{<:Number,Matrix{<:Number}} = .1 | Initial variance of the multivariate normal used to compute the jump. This parameter is updates if the rejection ratio is very high.|
||stopMaxGenerations::Int = 10 | How many generations do before stopping the algorithm. |
||initialisation::Union{Nothing,DataFrame} = nothing | DataFrame defining the initial parameters of the population. If nothing, they are set randomly.|
||returnAll::Bool = false | If return the hole list of parameters explored or the just the most fit.|
||saveFileName::Union{Nothing,String} = nothing | If given a string, it saves the parameters explored in a file with the corresponding name.|
||args::Vector{<:Any} = Any[] | Additional arguments to give to `evalFunction`.|
||verbose=false | If `true`, show progress bar during optimization.|
"""
function stochasticDescentAlgorithm(evalFunction::Function, 
                        searchList::Dict{Symbol,<:Union{<:Tuple{<:Number,<:Number},Vector{<:Number}}}; 
                        population::Int=1,
                        jumpVarianceStart::Union{<:Number,Matrix{<:Number}} = .1, 
                        nStatistics::Number = 10, 
                        stopMaxGenerations::Number = 100, 
                        initialisation::Union{Nothing,DataFrame} = nothing,
                        returnAll::Bool=false,
                        saveFileName::Union{Nothing,String} = nothing,
                        args::Vector{<:Any} = Any[],
                        verbose=false)

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
    m[:,:_variance_] .= jumpVarianceStart
    m[:,:_rejection_] .= 0

    #Start simulation
    prog = nothing
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
        CSV.write(string(saveFileName,".csv"),m[line,:])
    end

    count = 2
    for k in 2:stopMaxGenerations
        
        mNew = DataFrame([i=>zeros(population) for i in keys(searchList)]...)
        mNew[:,:_score_] .= 0.
        mNew[:,:_generation_] .= count
        mNew[:,:_variance_] .= m[:,:_variance_]
        mNew[:,:_rejection_] .= m[:,:_rejection_]

        #New jumps
        if verbose
            prog = Progress(population,string("Generation ",k,"/",stopMaxGenerations))
        end
        Threads.@threads for i in 1:population
            #Make the distribution matrix
            if mNew[i,:_generation_] % nStatistics == 0
                if mNew[i,:_rejection_] > .6*nStatistics
                    mNew[i,:_variance_] = m[i,:_variance_]*.75
                else
                    mNew[i,:_variance_] = m[i,:_variance_]*1.5
                end
                mNew[i,:_rejection_] = 0
            end
            dist = rand(MultivariateNormal(zeros(length(keys(searchList))),mNew[i,:_variance_]))
            for param in keys(searchList)
                mNew[i,Symbol(param)] = m[i,Symbol(param)] + dist[i]
                if mNew[i,param] < searchList[Symbol(param)][1]
                    mNew[i,param] = searchList[Symbol(param)][1]
                elseif mNew[i,param] > searchList[Symbol(param)][2]
                    mNew[i,param] = searchList[Symbol(param)][2]
                end
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
            if m[i,:_score_] > mOld[i,:_score_]
                variance = m[i,:_variance_]
                rejection = m[i,:_rejection_]
                generation = m[i,:_generation_]
                m[i,:] = mOld[i,:]
                m[i,:_rejection_] = rejection + 1
                m[i,:_generation_] = generation
                m[i,:_variance_] = variance
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