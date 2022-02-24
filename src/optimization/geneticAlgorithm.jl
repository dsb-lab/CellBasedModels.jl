import ...AgentBasedModels: rand, Categorical, Uniform

function geneticAlgorithm(communityInitial::Community, 
                        model::Model, 
                        loosFunction:: Function, 
                        searchList::Dict{Symbol,<:Union{<:Tuple{<:Number,<:Number},Vector{<:Number}}}, 
                        evalParams::Dict{Symbol,<:Number};
                        population::Int=100,
                        parentSelectionAlg::String = "weighted", #weighted or random
                        parentSelectionP::Number = .1, 
                        mutationRate::Number = .1, 
                        maxGenerations::Number = 10,
                        returnAll::Bool = false)

    mTotal = DataFrame()

    #Creating the dataframe
    m = DataFrame([i=>zeros(population) for i in keys(searchList)]...)
    for i in 1:population
        for param in keys(searchList)
            if !(param in ["_score_","_generation_"])
                if typeof(searchList[Symbol(param)]) <: Tuple{<:Number,<:Number}
                    m[i,Symbol(param)] = rand(Uniform(searchList[Symbol(param)]...))
                else
                    m[i,Symbol(param)] = rand(searchList[Symbol(param)])
                end
            end
        end
    end
    m[:,:_score_] .= 0.
    m[:,:_generation_] .= 1

    #Start first simulations
    for i in 1:population
        com = deepcopy(communityInitial)
        #Set parameters
        for param in names(m)
            if !(param in ["_score_","_generation_"])
                com[Symbol(param)] = m[i,param]
            end
        end
        #Run simulation
        comt = model.evolve(com;evalParams...)
        #Run loos function
        m[i,:_score_] = loosFunction(comt)
    end
    mTotal = copy(m)

    count = 2
    while count <= maxGenerations
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
                if !(param in ["_score_","_generation_"])
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
                            m[i,Symbol(param)] = rand(Uniform(searchList[Symbol(param)]...))
                        else
                            m[i,Symbol(param)] = rand(searchList[Symbol(param)])
                        end
                    end
                    if mutationRate > rand()
                        if typeof(searchList[Symbol(param)]) <: Tuple{<:Number,<:Number}
                            m[i+1,Symbol(param)] = rand(Uniform(searchList[Symbol(param)]...))
                        else
                            m[i+1,Symbol(param)] = rand(searchList[Symbol(param)])
                        end
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
            for param in names(m)
                if !(param in ["_score_","_generation_"])
                    com[Symbol(param)] = m[i,param]
                end
            end
            #Run simulation
            comt = model.evolve(com;evalParams...)
            #Run loos function
            m[i,:_score_] = loosFunction(comt)
        end
        append!(mTotal,m)

        count += 1
    end

    if returnAll
        return mTotal
    else
        return sort(mTotal,:_score_,rev=false)[1,:]
    end
end