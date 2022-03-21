"""
    function gridSearch(evalFunction::Function,  
        searchList::Dict{Symbol,<:Vector{<:Number}}; 
        returnAll::Bool=false,
        saveFileName::Union{Nothing,String} = nothing,
        args::Vector{<:Any} = Any[])

Function that evaluates a grid of parameter configurations for a model.

Args:
- **evalFunction:: Function** : Function that takes a DataFrame with parameters, generates the simulations and returns a score of the fit.
- **searchList::Dict{Symbol,<:Tuple{<:Number,<:Number}}}** : Dictionary of parameters and the ranges of exloration the parameters (e.g. :x => (0,1)).

kArgs:
 - **returnAll::Bool = false** : If return the hole list of parameters explored or the just the most fit.
 - **saveFileName::Union{Nothing,String} = nothing** : If given a string, it saves the parameters explored in a file with the corresponding name.
 - **args::Vector{<:Any} = Any[]** : Additional arguments to give to `evalFunction`.
"""
function gridSearch(evalFunction::Function,  
                    searchList::Dict{Symbol,<:Vector{<:Number}}; 
                    returnAll::Bool=false,
                    saveFileName::Union{Nothing,String} = nothing,
                    args::Vector{<:Any} = Any[])

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
        m[line,:_score_] = evalFunction(m[line,:],args...)

        if saveFileName !== nothing
            if line == 1
                CSV.write(string(saveFileName,".csv"),m[line,:])
            else
                CSV.write(string(saveFileName,".csv"),m[line,:],append=true)
            end
        end
    end

    if returnAll
        return m
    else
        return m[argmin(m._score_),:]
    end
end