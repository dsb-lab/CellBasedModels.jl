function makeInLoop(agentModel::Model,platform,algorithm)
    
    inLoop, arg = neighborhoodLoop(agentModel)
    inLoop = Meta.parse(replace(string(inLoop),"ALGORITHMS_"=>algorithm))
    inLoop = NEIGHBORHOODADAPT[typeof(agentModel.neighborhood)](inLoop)   

    return inLoop, arg
end