function createFunction(code::Expr,p::AgentCompiled;orderInteraction::Int=0,integrator=Euler,integrationStep=1,variablesUpdated=All)
    
    #Add medium coupling
    codeFull = addMediumCode(p)

    #Add medium code
    push!(codeFull.args,code)

    #Adapt special symbols and operators

        #dW
    codeFull = postwalk(x -> @capture(x,dW) ? :(Normal(0.,sqrt(dt))) : x, codeFull)

        #addAgent()
    codeFull = addEventAddAgent(codeFull,p)

        #removeAgent()
    codeFull = addEventRemoveAgent(codeFull,p)

        #Probability distributions
    codeFull = randomAdapt(codeFull,p)

    #Vectorize
    codeFull = vectorize(codeFull,p,integrator=Euler,integrationStep=integrationStep)

    #Put in function
    if orderInteraction == 0
        f = wrapInFunction(codeFull,ARGS)
    elseif orderInteraction == 1
        f = simpleFirstLoopWrapInFunction(codeFull,p.platform,ARGS)
    elseif orderInteraction == 2
        codeFull = NEIGHBORSLOOP[p.neighbors](codeFull,p)
        f = wrapInFunction(codeFull,[ARGS;NEIGHBORSARGUMENTS[p.neighbors]])
    end

    return f
end