######################################################################################################
# add agent code
######################################################################################################
function addGlobalAgentCode(arguments,agent::Agent)

    #List parameters that can be updated by the user
    updateargs = [sym for (sym,prop) in pairs(agent.declaredSymbols) if !(prop.reset) && prop.scope == :Local]
    updateargs = [updateargs...,POSITIONPARAMETERS[1:agent.dims]...]
    #Checks that the correct parameters has been declared and not others
    args = []
    addCell = BASESYMBOLS[:AddCell].symbol
    code = quote end
    for i in arguments
        found = @capture(i,g_ = f_)
        if found
            if !(g in updateargs)
                error(g, " is not a local parameter of the agent.")
            end
        else
            error(i, " is not a valid assignation of code when declaring addAgent. A Valid one should be of the form parameterOfAgent = value")
        end

        if g in args
           error(g," has been declared more than once in addAgent.") 
        end

        if i.args[1] == :id
            error("id must not be declared when calling addAgent. It is assigned automatically.")
        end

        push!(code.args,:($(i.args[1]).$addCell=$(i.args[2])))
        push!(args,i.args[1])

    end

    #Add parameters to agent that have not been user defined
    for i in updateargs
        if !(i in args)
            error(i, " should have been assigned when declaring addAgent in UpdateGlobal. Please specify a declaration of the form $i = value")
        end
    end

    #Make code
    dtype = DTYPE[:Int][agent.platform]
    code = quote
            i1New_ = N+Threads.atomic_add!(NAdd_,$(dtype)(1)) + 1
            idNew_ = Threads.atomic_add!(idMax_,$(dtype)(1)) + 1
            if nMax_ >= i1New_
                flagNeighbors_[i1New_] = 1
                id[i1New_] = idNew_
                flagRecomputeNeighbors_ = 1
                flagNeighbors_[i1New_] = 1
                $code
            else
                Threads.atomic_add!(NAdd_,$(dtype)(-1))
            end
        end

    #Adapt code to platform
    code = cudaAdapt(code,agent)

    return code
end

function addEventGlobalAddAgent(code::Expr,agent::Agent)

    if inexpr(code,:addAgent)
        
        #Substitute code
        code = postwalk(x->@capture(x,addAgent(g__)) ? addGlobalAgentCode(g,agent) : x , code)

        return code

    end

    return code
end

######################################################################################################
# global function
######################################################################################################
function globalFunction(agent)

    if !all([typeof(i) == LineNumberNode for i in agent.declaredUpdates[:UpdateGlobal].args])
        code = agent.declaredUpdates[:UpdateGlobal]

        #Custom functions
        code = addEventGlobalAddAgent(code,agent)
        #Vectorize
        code = vectorize(code,agent)
        # #Put in loop
        # code = makeSimpleLoop(code,agent)

        agent.declaredUpdatesCode[:UpdateGlobal] = code

        agent.declaredUpdatesFunction[:UpdateGlobal_] = Main.eval(:(($(agentArgs()...),) -> $(quote $code; nothing end)))
        aux = addCuda(:(community.agent.declaredUpdatesFunction[:UpdateGlobal_]($(agentArgs(:community)...))),agent,oneThread=true) #Add code to execute kernel in cuda if GPU
        agent.declaredUpdatesFunction[:UpdateGlobal] = Main.eval(
            :(function (community)
                $aux
                return 
            end)
        )
    else
        agent.declaredUpdatesFunction[:UpdateGlobal] = Main.eval(:((community) -> nothing))
    end

end

function globalStep!(community)

    checkLoaded(community)

    community.agent.declaredUpdatesFunction[:UpdateGlobal](community)

    return 

end