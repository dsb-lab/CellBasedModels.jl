######################################################################################################
# add agent code
######################################################################################################
function addAgentCode(arguments,agent::Agent)

    #List parameters that can be updated by the user
    updateargs = [sym for (sym,prop) in pairs(agent.declaredSymbols) if (prop[3] in [:UserUpdatable,:Position]) && (prop[2] in [:Local])]
    
    #Checks that the correct parameters has been declared and not others
    args = []
    code = quote end
    for i in arguments
        found = @capture(i,g_.h_ = f_)
        if found
            if !(g in [sym for (sym,prop) in pairs(agent.declaredSymbols) if sym in updateargs])
                error(g, " is not a local parameter of the agent.")
            end
        else
            error(i, " is not a valid assignation of code when declaring addAgent. A Valid one should be of the form parameterOfAgent = value")
        end

        if g in args
           error(string(i.args[1])[1:end-4]," has been declared more than once in addAgent.") 
        end

        if i.args[1] == :id
            error("id must not be declared when calling addAgent. It is assigned automatically.")
        end

        push!(code.args,:($(i.args[1]).addCell=$(i.args[2])))
        push!(args,i.args[1].args[1])

    end

    #Add parameters to agent that have not been user defined
    for i in updateargs
        if !(i in args) && i != :id
            push!(code.args,:($i.addCell=$i))
        end
    end

    #Make code
    code = quote
            i1New_ = N+Threads.atomic_add!(NAdd_,$(INT[agent.platform])(1)) + 1
            idNew_ = Threads.atomic_add!(idMax_,$(INT[agent.platform])(1)) + 1
            if nMax_ >= i1New_
                flagNeighbors_[i1New_] = 1
                id[i1New_] = idNew_
                flagRecomputeNeighbors_[] = 1
                $code
            else
                Threads.atomic_add!(NAdd_,$(INT[agent.platform])(-1))
            end
        end

    #Adapt code to platform
    code = cudaAdapt(code,agent)

    return code
end

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
function removeAgentCode(agent::Agent)

    code = quote end

    #Add 1 to the number of removed
    #Add the cell position to the list of removed
    #Set survived to 0
    code = quote
            idNew_ = Threads.atomic_add!(NRemove_,$(INT[agent.platform])(1)) + 1
            holeFromRemoveAt_[idNew_] = i1_ 
            flagSurvive_[i1_] = 0
            flagRecomputeNeighbors_[] = 1
        end

    #Adapt to platform
    code = cudaAdapt(code,agent)

    return code

end

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
function localFunction(agent)

    args = []
    for i in keys(agent.declaredSymbols)
        push!(args,:($i))        
    end

    args2 = [:(community.$i) for i in args]

    if !all([typeof(i) == LineNumberNode for i in agent.declaredUpdates[:UpdateLocal].args])
        code = agent.declaredUpdates[:UpdateLocal]

        #Custom functions
        code = addEventAddAgent(code,agent)
        code = addEventRemoveAgent(code,agent)
        #Vectorize
        code = vectorize(code,agent)
        #Put in loop
        code = makeSimpleLoop(code,agent)

        agent.declaredUpdatesCode[:UpdateLocal] = code
        agent.declaredUpdatesFunction[:UpdateLocal_] = Main.eval(:(($(args...),) -> $code))

        aux = addCuda(:(community.agent.declaredUpdatesFunction[:UpdateLocal_]($(args2...))),agent) #Add code to execute kernel in cuda if GPU
        agent.declaredUpdatesFunction[:UpdateLocal] = Main.eval(
            :(function (community)
                $aux
                return 
            end)
        )

    else
        agent.declaredUpdatesFunction[:UpdateLocal] = Main.eval(:((community) -> nothing))
    end

end

function localStep!(community)

    checkLoaded(community)

    community.agent.declaredUpdatesFunction[:UpdateLocal](community)

    return 

end