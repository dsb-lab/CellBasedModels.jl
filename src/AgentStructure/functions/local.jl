######################################################################################################
# add agent code
######################################################################################################
function addAgentCode(arguments,agent::Agent)

    code = quote end

    updateargs = [sym for (sym,prop) in pairs(agent.declaredSymbols) if prop[3] in [:UserUpdatable,:Position]]
    
    args = []
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

    #Add parameters to agent
    for i in updateargs
        if !(i in args) && i != :id
            push!(code.args,:($i.addCell=$i))
        end
    end

    #Add 
    if agent.platform == :CPU 
        code = quote
                i1New_ = N+Threads.atomic_add!(NV_,$(INT[agent.platform])(1)) + 1
                idNew_ = Threads.atomic_add!(idMax_,$(INT[agent.platform])(1)) + 1
                if nMax_ >= i1New_
                    id = idNew_
                    $code
                else
                    Threads.atomic_add!(NV_,$(INT[agent.platform])(-1))
                end
            end
    elseif agent.platform == :GPU
        code = quote
            i1New_ = N+CUDA.atomic_add!(CUDA.pointer(NV_,1),$(INT[agent.platform])(1)) + 1
            idNew_ = CUDA.atomic_add!(CUDA.pointer(idMax_,1),$(INT[agent.platform])(1)) + 1
            if nMax_ >= i1New_
                id = idNew_
                $code
            else
                CUDA.atomic_add!(CUDA.pointer(NV_,1),$(INT[agent.platform])(-1))
            end
        end
    end

    return code
end

function addEventAddAgent(code::Expr,agent::Agent)

    if inexpr(code,:addAgent)
        
        code = postwalk(x->@capture(x,addAgent(g__)) ? addAgentCode(g,agent) : x , code)

    end

    return code
end

######################################################################################################
# remove agent code
######################################################################################################
function reorganizeCells(agent::Agent)

    updateargs = [sym for (sym,prop) in pairs(agent.declaredSymbols) if prop[3] in [:UserUpdatable,:Position]]

    code = quote 
        iNew_ = remPos_[ic1_]
        iNew_ = remPos_[ic1_]
    end
    for sym in updateargs
        push!(code.args,:($sym.new[iNew_] = $sym.new[]))
    end

    if agent.platform == :CPU
        code = quote end

        if

    elseif agent.platform == :gpu
    
    end

end

function removeAgentCode(agent::Agent)

    code = quote end

    if agent.platform == :CPU 
        code = quote
                idNew_ = Threads.atomic_add!(NRem_,$(INT[agent.platform])(1)) + 1
                remPos_[idNew_] = ic1_ 
            end
    elseif agent.platform == :GPU
        code = quote
                i1New_ = CUDA.atomic_add!(CUDA.pointer(NRem_,1),$(INT[agent.platform])(1)) + 1
                remPos_[idNew_] = ic1_ 
            end
    end

    return code

end

function addEventRemoveAgent(code::Expr,agent::Agent)

    code = postwalk(x->@capture(x,removeAgent()) ? removeAgentCode(agent) : x , code)

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
        code = removeEventAgent(code,agent)
        #Vectorize
        code = vectorize(code,agent)
        #Put in loop
        code = makeSimpleLoop(code,agent)

        agent.declaredUpdatesCode[:UpdateLocal] = code
        agent.declaredUpdatesFunction[:UpdateLocal_] = Main.eval(:(($(args...),) -> $code))

        if agent.platform == :CPU
            agent.declaredUpdatesFunction[:UpdateLocal] = Main.eval(
                :(function (community)

                    community.agent.declaredUpdatesFunction[:UpdateLocal_]($(args2...))
                    community.N .+= community.NV_[]
                    community.NV_[] = 0
                    return 

                end)
            )
        elseif agent.platform == :GPU
            agent.declaredUpdatesFunction[:UpdateLocal] = Main.eval(
                :(function (community)

                    @cuda threads=community.platform.threads blocks=community.platform.blocks community.agent.declaredUpdatesFunction[:UpdateLocal_]($(args2...))
                    community.N .+= community.NV_
                    community.NV_ .= 0
                    return 

                end)
            )
        end
    else
        agent.declaredUpdatesFunction[:UpdateLocal] = Main.eval(:((community) -> nothing))
    end

end

function localStep!(community)

    community.agent.declaredUpdatesFunction[:UpdateLocal](community)

    return 

end