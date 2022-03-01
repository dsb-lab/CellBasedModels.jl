"""
    function gridSearch(communityInitial::Community, 
        model::Model, 
        loosFunction:: Function, 
        searchList::Dict{Symbol,<:Vector{<:Number}}, 
        evalParams::Dict{Symbol,<:Number}; 
        repetitions::Int=1,
        returnAll::Bool=false,
        saveFileName::Union{Nothing,String} = nothing)

Function that evaluates a grid of parameter configurations for a model.

Args:
 - **communityInitial::Community** : Community to use as a base to start the optimization.
 - **model::Model** : Model to be optimized to evolve the communityInitial.
 - **loosFunction:: Function** : Cost function over which optimize the parameter.
 - **searchList::Dict{Symbol,<:Vector{<:Number}}** : Dictionary of parameters and the ranges of exloration the parameters (e.g. :x => [1,2,3]).
 - **evalParams::Dict{Symbol,<:Number}** : Dictionary of parameters and the ranges of exloration the parameters (e.g. :tMax => 10).

kArgs:
 - **repetitions::Int=1** : How many repetitions to perform per set of parameters. The simulations are promediated to obtain the actual cost of that parameter configuration.
 - **returnAll::Bool = false** : If return the hole list of parameters explored or the just the most fit.
 - **saveFileName::Union{Nothing,String} = nothing** : If given a string, it saves the parameters explored in a file with the corresponding name.
"""
function gridSearch(communityInitial::Community, 
                    model::Model, 
                    loosFunction:: Function, 
                    searchList::Dict{Symbol,<:Vector{<:Number}}, 
                    evalParams::Dict{Symbol,<:Number}; 
                    repetitions::Int=1,
                    returnAll::Bool=false,
                    saveFileName::Union{Nothing,String} = nothing)

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

        if saveFileName !== nothing
            if line == 1
                CSV.write(saveFileName,m[line,:])
            else
                CSV.write(saveFileName,m[line,:],append=true)
            end
        end
    end

    if returnAll
        return m
    else
        return m[argmin(m._score_),:]
    end
end