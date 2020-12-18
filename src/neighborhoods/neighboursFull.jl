struct NeighboursFull <: Neighbours

end

function setNeighborhoodFull!(agentModel::Model)
    
    agentModel.neighborhood = NeighboursFull() 
    
    return
end

function neighboursFull(agentModel::Model;platform="cpu")

    #Add declaring variables
    varDeclare = Expr[]
    #Add declared functions
    fDeclare = Expr[]
    #Add execution time functions
    execute = Expr[]

    count = Meta.parse("nnN_[ic1_]")
    locInter = subs(algorithms,[:nnic2_],[:(N_)])
    arg = []
    inLoop = 
    :(
    for ic2_ in 1:N_
        ALGORITHMS_
    end    
    )

    return varDeclare, fDeclare, execute, inLoop, arg

end