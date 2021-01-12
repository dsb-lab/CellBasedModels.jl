"""
    struct NeighboursFull <: Neighbours
"""
struct NeighboursFull <: Neighbours

end

"""
    function setNeighborhoodFull!(agentModel::Model)

Function that sets the neighborhoodof the model to fully connected. It is the neighborhood by default if no other neighborhood is defined.
"""
function setNeighborhoodFull!(agentModel::Model)

    agentModel.evolve = needCompilation
    
    agentModel.neighborhood = NeighboursFull() 
    
    return
end

"""
    function neighboursFull(agentModel::Model;platform="cpu")
"""
function neighboursFull(agentModel::Model;platform="cpu")

    #Add declaring variables
    varDeclare = Expr[]
    #Add declared functions
    fDeclare = Expr[]
    #Add execution time functions
    execute = Expr[]
    #Arguments for the calling function
    arg = Symbol[]
    #In loop call
    inLoop = 
    :(
    for ic2_ in 1:N_
        ALGORITHMS_
    end    
    )

    return varDeclare, fDeclare, execute, inLoop, arg

end

"""
    function neighboursFullAdapt(entry)
"""
function neighboursFullAdapt(entry)

    entry = subs(entry,:nnic2_,:ic2_)

    return entry

end