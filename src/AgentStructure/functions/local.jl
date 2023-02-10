######################################################################################################
# add agent code
######################################################################################################
"""
    function addAgentCode(arguments,agent::Agent)

Functions that returns the special code based on the arguments provided to `addAgent`.
"""
function addAgentCode(arguments,agent::Agent)

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
            push!(code.args,:($i.$addCell=$i))
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

"""
    function addEventAddAgent(code::Expr,agent::Agent)

Functions that goes over all the calls to `addAgent` and inserts the compiled code provided by `addGlobalAgentCode`.
"""
function addEventAddAgent(code::Expr,agent::Agent)

    if inexpr(code,:addAgent)
        
        #Substitute code
        code = postwalk(x->@capture(x,addAgent(g__)) ? addAgentCode(g,agent) : x , code)

        return code

    end

    return code
end

######################################################################################################
# remove agent code
######################################################################################################
"""
    function removeAgentCode(agent::Agent)

Functions that returns the special code based on the arguments provided to `removeAgent()`.
"""
function removeAgentCode(agent::Agent)

    code = quote end

    #Add 1 to the number of removed
    #Add the cell position to the list of removed
    #Set survived to 0
    dtype = DTYPE[:Int][agent.platform]
    code = quote
            idNew_ = Threads.atomic_add!(NRemove_,$(dtype)(1)) + 1
            holeFromRemoveAt_[idNew_] = i1_ 
            flagSurvive_[i1_] = 0
            flagRecomputeNeighbors_ = 1
            flagNeighbors_[i1_] = 1
        end

    #Adapt to platform
    code = cudaAdapt(code,agent)

    return code

end

"""
    function addEventRemoveAgent(code::Expr,agent::Agent)

Functions that goes over all the calls to `removeAgent` and inserts the compiled code provided by `addGlobalAgentCode`.
"""
function addEventRemoveAgent(code::Expr,agent::Agent)

    if inexpr(code,:removeAgent)

        #Make true indicator of survival at the beginning of the code
        pushfirst!(code.args,:(flagSurvive_[i1_] = 1))
        #Transform code removeAgent
        code = postwalk(x->@capture(x,removeAgent()) ? removeAgentCode(agent) : x , code)

    end

    return code

end

######################################################################################################
# local function
######################################################################################################
"""
    function localFunction(agent)

Creates the final code provided to Agent in `updateLocal` as a function and adds it to the Agent.
"""
function localFunction(agent)

    if !all([typeof(i) == LineNumberNode for i in agent.declaredUpdates[:UpdateLocal].args])
        code = agent.declaredUpdates[:UpdateLocal]

        #Custom functions
        code = addEventAddAgent(code,agent)
        code = addEventRemoveAgent(code,agent)
        #Vectorize
        code = vectorize(code,agent)
        #Put in loop
        code = makeSimpleLoop(code,agent)

        agent.declaredUpdatesCode[:UpdateLocal_] = :(($(agentArgs()...),) -> $code)
        agent.declaredUpdatesFunction[:UpdateLocal_] = Main.eval(:($(agent.declaredUpdatesCode[:UpdateLocal_])))
        aux = addCuda(:(community.agent.declaredUpdatesFunction[:UpdateLocal_]($(agentArgs(:community)...))),agent) #Add code to execute kernel in cuda if GPU
        agent.declaredUpdatesCode[:UpdateLocal] = :(function (community)
                                                        $aux
                                                        return 
                                                    end)
        agent.declaredUpdatesFunction[:UpdateLocal] = Main.eval(
            :($(agent.declaredUpdatesCode[:UpdateLocal]))
        )
    else
        agent.declaredUpdatesFunction[:UpdateLocal] = Main.eval(:((community) -> nothing))
    end

end

"""
    function localStep!(community)

Function that computes a local step of the community a time step `dt`.
"""
function localStep!(community)

    checkLoaded(community)

    community.agent.declaredUpdatesFunction[:UpdateLocal](community)

    return 

end