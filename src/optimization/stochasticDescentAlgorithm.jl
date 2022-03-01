import ...AgentBasedModels: rand, MultivariateNormal

"""
    function stochasticDescentAlgorithm(communityInitial::Community, 
        model::Model, 
        loosFunction:: Function, 
        searchList::Dict{Symbol,<:Union{<:Tuple{<:Number,<:Number},Vector{<:Number}}}, 
        evalParams::Dict{Symbol,<:Number}; 
        population::Int=1,
        jumpVarianceStart::Union{<:Number,Matrix{<:Number}} = .1, 
        nStatistics::Number = 10, 
        stopMaxGenerations::Number = 100, 
        initialisation::Union{Nothing,DataFrame} = nothing,
        initialisationF::Union{Nothing,Function} = nothing,
        returnAll::Bool=false,
        saveFileName::Union{Nothing,String} = nothing)

Optimization of the parameter space of a model that uses [Stochastic Gradient Descent](https://en.wikipedia.org/wiki/Stochastic_gradient_descent).

Args:
 - **communityInitial::Community** : Community to use as a base to start the optimization.
 - **model::Model** : Model to be optimized to evolve the communityInitial.
 - **loosFunction:: Function **: Cost function over which optimize the parameter.
 - **searchList::Dict{Symbol,<:Tuple{<:Number,<:Number}}}** : Dictionary of parameters and the ranges of exloration the parameters (e.g. :x => (0,1)).
 - **evalParams::Dict{Symbol,<:Number}** : Dictionary of parameters and the ranges of exloration the parameters (e.g. :tMax => 10).

kArgs:
 - **population::Int=100** : Size of the colony used at each generation for the optimization.
 - **jumpVarianceStart::Union{<:Number,Matrix{<:Number}} = .1** : Initial variance of the multivariate normal used to compute the jump. This parameter is updates if the rejection ratio is very high.
 - **stopMaxGenerations::Int = 10** : How many generations do before stopping the algorithm. 
 - **initialisation::Union{Nothing,DataFrame} = nothing** : DataFrame defining the initial parameters of the population. If nothing, they are set randomly.
 - **initialisationF::Union{Nothing,Function} = nothing** : Function that takes communityInitial as an argument and searchList parameters as kargs and modifies the communityInitial.
 - **returnAll::Bool = false** : If return the hole list of parameters explored or the just the most fit.
 - **saveFileName::Union{Nothing,String} = nothing** : If given a string, it saves the parameters explored in a file with the corresponding name.
"""
function stochasticDescentAlgorithm(communityInitial::Community, 
                        model::Model, 
                        loosFunction:: Function, 
                        searchList::Dict{Symbol,<:Union{<:Tuple{<:Number,<:Number},Vector{<:Number}}}, 
                        evalParams::Dict{Symbol,<:Number}; 
                        population::Int=1,
                        jumpVarianceStart::Union{<:Number,Matrix{<:Number}} = .1, 
                        nStatistics::Number = 10, 
                        stopMaxGenerations::Number = 100, 
                        initialisation::Union{Nothing,DataFrame} = nothing,
                        initialisationF::Union{Nothing,Function} = nothing,
                        returnAll::Bool=false,
                        saveFileName::Union{Nothing,String} = nothing)

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
        
        mNew = DataFrame([i=>zeros(population) for i in keys(searchList)]...)
        mNew[:,:_score_] .= 0.
        mNew[:,:_generation_] .= count
        mNew[:,:_variance_] .= m[:,:_variance_]
        mNew[:,:_rejection_] .= m[:,:_rejection_]

        #New jumps
        for i in 1:population
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
            #Compute loos function
            m[i,:_score_] = loosFunction(comt)
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