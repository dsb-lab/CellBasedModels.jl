function gridSearch(communityInitial::Community, 
                    model::Model, 
                    loosFunction:: Function, 
                    searchList::Dict{Symbol,<:Vector{<:Number}}, 
                    evalParams::Dict{Symbol,<:Number}; 
                    repetitions::Int=1,
                    returnAll::Bool=false)

    #Creating the dataframe
    dims = [size(searchList[par])[1] for par in keys(searchList)]
    m = DataFrame()
    for (i,key) in enumerate(keys(searchList))
        before = [1 for j in 1:1:i-1]
        after = [1 for j in i+1:1:length(dims)]
        flat = reshape(searchList[key],before...,dims[i],after...).*ones(dims...)
        flat = reshape(flat,prod(dims))
        m[!,key] = flat
    end

    m[!,:_score_] .= -Inf

    for line in 1:size(m)[1]
        com = deepcopy(communityInitial)
        #Set parameters
        for param in names(m)
            if param != "_score_"
                com[Symbol(param)] = m[line,param]
            end
        end
        m[line,:_score_] = 0
        for rep in 1:repetitions
            #Run simulation
            comt = model.evolve(com;evalParams...)
            #Run loos function
            m[line,:_score_] += loosFunction(comt)/repetitions
        end
    end

    if returnAll
        return m
    else
        return sort(m,:_score_,rev=false)[1,:]
    end
end