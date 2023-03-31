######################################################################################################
# add agent code
######################################################################################################
"""
    function addAgentCode(arguments,abm::ABM)

Functions that returns the special code based on the arguments provided to `addAgent`.
"""
function addAgentCode(arguments,abm::ABM)

    #List parameters that can be updated by the user
    updateargs = [sym for (sym,prop) in pairs(abm.parameters) if prop.scope == :agent]
    #Checks that the correct parameters has been declared and not others
    args = []
    addCell = BASESYMBOLS[:AddCell].symbol
    code = quote end
    for i in arguments
        found = @capture(i,g_ = f_)
        if found
            if !(g in updateargs)
                error(g, " is not an agent parameter.")
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

        push!(code.args,:($g[i1New_]=$f))
        push!(args,i.args[1])

    end

    #Add parameters to agent that have not been user defined
    for i in updateargs
        if !(i in args)
            push!(code.args,:($i[i1New_]=$i))
        end
    end

    #Make code
    dtype = DTYPE[:Int][abm.platform]
    code = quote
            i1New_ = N+Threads.atomic_add!(NAdd_,$(dtype)(1)) + 1
            idNew_ = Threads.atomic_add!(idMax_,$(dtype)(1)) + 1
            if nMax_ >= i1New_
                flagNeighbors_[i1New_] = 1
                id[i1New_] = idNew_
                flagRecomputeNeighbors_ = 1
                flagNeighbors_[i1New_] = 1
                flagSurvive_[i1New_] = 1
                $code
            else
                Threads.atomic_add!(NAdd_,$(dtype)(-1))
            end
        end

    #Adapt code to platform
    code = cudaAdapt(code,abm)

    return code
end

"""
    function addEventAddAgent(code::Expr,com)

Functions that goes over all the calls to `addAgent` and inserts the compiled code provided by `addGlobalAgentCode`.
"""
function addEventAddAgent(code::Expr,com)

    if inexpr(code,:addAgent)
        
        #Substitute code
        code = postwalk(x->@capture(x,addAgent(g__)) ? addAgentCode(g,com.abm) : x , code)

        return code

    end

    return code
end

"""
    macro addAgentCode(arguments)

Macro that returns the special code based on the arguments provided to `addAgent`.
"""
macro addAgent(arguments...)

    abm = AGENT
    #List parameters that can be updated by the user
    updateargs = [sym for (sym,prop) in pairs(abm.parameters) if prop.scope == :agent]
    updateargs2 = [new(sym) for (sym,prop) in pairs(abm.parameters) if prop.scope == :agent]
    append!(updateargs2,updateargs)
    #Checks that the correct parameters has been declared and not others
    args = []
    code = quote end
    for i in arguments
        found = @capture(i,g_[h_] = f_)
        if found
            if !(g in updateargs2)
                error(g, " is not an agent parameter.")
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

        if abm.parameters[old(g)].update
            push!(code.args,:($(new(old(g)))[i1New_]=$f))
        else
            push!(code.args,:($(old(g))[i1New_]=$f))
        end
        push!(args,g)

    end

    #Add parameters to agent that have not been user defined
    for i in updateargs
        if !(i in args) && !(new(i) in args)
            if abm.parameters[i].update
                push!(code.args,:($(new(i))[i1New_]=$i[i1_]))
            else
                push!(code.args,:($i[i1New_]=$i[i1_]))
            end
        end
    end

    #Make code
    code = quote
            i1New_ = N+Threads.atomic_add!(NAdd_,1) + 1
            idNew_ = Threads.atomic_add!(idMax_,1) + 1
            if nMax_ >= i1New_
                # flagNeighbors_[i1New_] = 1
                id[i1New_] = idNew_
                flagRecomputeNeighbors_ = 1
                # flagNeighbors_[i1New_] = 1
                flagSurvive_[i1New_] = 1
                $code
            else
                Threads.atomic_add!(NAdd_,-1)
            end
        end

    #Adapt code to platform
    code = cudaAdapt(code,abm)

    code = vectorize(code)

    return esc(code)
end

######################################################################################################
# remove agent code
######################################################################################################
"""
    function removeAgentCode(abm::ABM)

Functions that returns the special code based on the arguments provided to `removeAgent()`.
"""
function removeAgentCode(abm::ABM)

    code = quote end

    #Add 1 to the number of removed
    #Add the cell position to the list of removed
    #Set survived to 0
    dtype = DTYPE[:Int][abm.platform]
    code = quote
            idNew_ = Threads.atomic_add!(NRemove_,$(dtype)(1)) + 1
            holeFromRemoveAt_[idNew_] = i1_ 
            flagSurvive_[i1_] = 0
            flagRecomputeNeighbors_ = 1
            flagNeighbors_[i1_] = 1
        end

    #Adapt to platform
    code = cudaAdapt(code,abm)

    return code

end

"""
    function addEventRemoveAgent(code::Expr,com)

Functions that goes over all the calls to `removeAgent` and inserts the compiled code provided by `addGlobalAgentCode`.
"""
function addEventRemoveAgent(code::Expr,com)

    if inexpr(code,:removeAgent)

        #Make true indicator of survival at the beginning of the code
        pushfirst!(code.args,:(flagSurvive_[i1_] = 1))
        #Transform code removeAgent
        code = postwalk(x->@capture(x,removeAgent()) ? removeAgentCode(com.abm) : x , code)

    end

    return code

end

"""
    macro removeAgent()

Macro that returns the special code based on the arguments provided to `removeAgent()`.
"""
macro removeAgent()

    com = COMUNITY
    code = quote end

    #Add 1 to the number of removed
    #Add the cell position to the list of removed
    #Set survived to 0
    code = quote
            idNew_ = Threads.atomic_add!(NRemove_,1) + 1
            holeFromRemoveAt_[idNew_] = i1_ 
            flagSurvive_[i1_] = 0
            flagRecomputeNeighbors_ = 1
            # flagNeighbors_[i1_] = 1
        end

    code = vectorize(code)

    #Adapt to platform
    code = cudaAdapt(code,com.platform)

    return esc(code)

end

######################################################################################################
# local function
######################################################################################################
"""
    function localFunction(abm)

Creates the final code provided to ABM in `agentRule` as a function and adds it to the ABM.
"""
function functionRule(com,scope)

    ref = addSymbol(scope,"Rule")

    abm = com.abm
    if !isemptyupdaterule(abm,ref)
        code = abm.declaredUpdates[ref]

        #Custom functions
        code = addEventAddAgent(code,com)
        code = addEventRemoveAgent(code,com)
        #Vectorize
        code = vectorize(code,com)
        code = vectorizeMediumInAgents(code,com)
        #Put in loop
        if ! contains(string(code),"@loopOverAgents")
            code = makeSimpleLoop(code,com)
        end

        func = :(rule_($(agentArgs(com)...),) = $code)
        # abm.declaredUpdatesFunction[:AgentRule_] = Main.eval(:($(abm.declaredUpdatesCode[:AgentRule_])))
        aux = addCuda(:(rule_($(agentArgs(com,sym=:community)...))),scope,com) #Add code to execute kernel in cuda if GPU
        abm.declaredUpdatesCode[ref] = :(function (community)
                                                        $func
                                                        $aux
                                                        return 
                                                    end)
        abm.declaredUpdatesFunction[ref] = Main.eval(
            :($(abm.declaredUpdatesCode[ref]))
        )
    else
        abm.declaredUpdatesFunction[ref] = Main.eval(:((community) -> nothing))
    end

end

"""
    function agentStepRule!(community)

Function that computes a local step of the community a time step `dt`.
"""
function agentStepRule!(community)

    checkLoaded(community)

    community.abm.declaredUpdatesFunction[:agentRule](community)

    return 

end

"""
    function agentStepRule!(community)

Function that computes a local step of the community a time step `dt`.
"""
function modelStepRule!(community)

    checkLoaded(community)

    community.abm.declaredUpdatesFunction[:modelRule](community)

    return 

end

"""
    function agentStepRule!(community)

Function that computes a local step of the community a time step `dt`.
"""
function mediumStepRule!(community)

    checkLoaded(community)

    community.abm.declaredUpdatesFunction[:mediumRule](community)

    return 

end