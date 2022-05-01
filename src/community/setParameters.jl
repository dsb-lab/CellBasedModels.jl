"""
    function setParameters!(community::Community,parameters::Dict{Symbol,<:Any})

Function that assigns the parameters of a list to the community. Handful to automatize initializations.

# Args
 - **community::Community**: Community where to assign the parameters.
 - **parameters::Dict{Symbol,<:Any}**: Dictionary of symbols and values to assign to the community.
"""
function setParameters!(community::Community,parameters::Dict{Symbol,<:Any})
    for i in keys(parameters)
        if i in community.declaredSymbols_["Global"]
            setproperty!(community,i,parameters[i])
        elseif i in community.declaredSymbols_["GlobalArray"]
            setproperty!(community,i,parameters[i])
        else 
            getproperty(community,i) .= parameters[i]
        end
    end
end