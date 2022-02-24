import ...AgentBasedModels: rand, MultivariateNormal

function stochasticDescent(communityInitial::Community, 
                        model::Model, 
                        loosFunction:: Function, 
                        searchList::Vector{Symbol}, 
                        evalParams::Dict{Symbol,<:Number}; 
                        jumpVarianceStart::Union{<:Number,Matrix{<:Number}} = .1, 
                        maxSteps::Number = 100, 
                        nStatistics::Number = 10, 
                        repetitions::Int=1,
                        returnAll::Bool=false)

    #Creating the dataframe
    m = DataFrame()
    for param in searchList
        if param != "_score_"
            m[!,Symbol(param)] = [communityInitial[Symbol(param)]]
        end
    end
    m[!,:_score_] = [0.]

    #Start simulation
    com = deepcopy(communityInitial)
    for rep in 1:repetitions
        #Run simulation
        comt = model.evolve(com;evalParams...)
        #Run loos function
        m[1,:_score_] += loosFunction(comt)/repetitions
    end

    #Make the distribution matrix
    dist = MultivariateNormal(zeros(length(keys(searchList))),jumpVarianceStart)
    rejection = 0

    count = 0
    countVariance = 1
    lastMin = 1
    while count < maxSteps
        com = deepcopy(communityInitial)
        #Set parameters
        update = [:_score_=>0.]
        sample = rand(dist)
        for (i,param) in enumerate(names(m))
            if param != "_score_"
                com[Symbol(param)] = m[lastMin,param] + sample[i]
                append!(update,[Symbol(param)=>m[lastMin,param] + sample[i]])
            end
        end
        append!(m,update)
        for rep in 1:repetitions
            #Run simulation
            comt = model.evolve(com;evalParams...)
            #Run loos function
            m[count+2,:_score_] += loosFunction(comt)/repetitions
        end

        if m[count+2,:_score_] < m[lastMin,:_score_]
            lastMin = count+2
        else
            rejection += 1
        end

        count += 1

        #Update jump
        if countVariance > nStatistics
            if rejection > .6*countVariance
                jumpVarianceStart = jumpVarianceStart .* rejection/countVariance*0.5
                dist = MultivariateNormal(zeros(length(keys(searchList))),jumpVarianceStart)
            else
                jumpVarianceStart .*= rejection/countVariance*1.5
            end

            rejection = 0
            countVariance = 0
        end

        countVariance += 1
    end

    if returnAll
        return m
    else
        return sort(m,:_score_,rev=false)[1,:]
    end
end