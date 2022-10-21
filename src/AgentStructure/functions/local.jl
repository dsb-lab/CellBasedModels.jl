######################################################################################################
# add agent code
######################################################################################################
function addAgentCode(arguments,agent::Agent;rem=true)

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
           error(string(i.args[1])[1:end-4]," has been declared more than once for the same agent.") 
        end

        if i.args[1] == :id
            error("id should not be declared when calling addAgent, it is assigned automatically.")
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
                i1New_ = N+Threads.atomic_add!(NV,$INT(1)) + 1
                Threads.atomic_add!(N,$INT(1))
                idNew_ = Threads.atomic_add!(agentIdMax,$INT(1)) + 1
                if nMax >= i1New_
                    id = idNew_
                    $code
                else
                    Threads.atomic_add!(NV,$INT(-1))
                    Threads.atomic_add!(N,$INT(-1))
                    limNMax_[] = 0
                end
            end
    elseif agent.platform == :GPU
        code = quote
            i1New_ = N+CUDA.atomic_add!(CUDA.pointer(NV,1),$(INT["gpu"])(1)) + 1
            CUDA.atomic_add!(CUDA.pointer(N,1),$(INT["gpu"])(1))
            idNew_ = CUDA.atomic_add!(CUDA.pointer(agentIdMax,1),$(INT["gpu"])(1)) + 1
            if nMax >= i1New_
                id = idNew_
                $code
            else
                CUDA.atomic_add!(CUDA.pointer(NV,1),$(INT["gpu"])(-1))
                CUDA.atomic_add!(CUDA.pointer(N,1),$(INT["gpu"])(-1))
                limNMax_[1] = 0
            end
        end
    end

    return code
end

"""
    function addEventAddAgent(code::Expr,p::Agent)

Substitute a declaration of `addAgent` by the corresponding code.

# Args
 - **code::Expr**:  Code to be changed by agents.
 - **p::Agent**:  Agent structure containing all the created code when compiling.

# Returns
 - `Expr` with the modified code.
"""
function addEventAddAgent(code::Expr,agent::Agent)

    if inexpr(code,:addAgent)
        
        if inexpr(code,:removeAgent) #In case of removal, add new people to the list
            code = postwalk(x->@capture(x,addAgent(g__)) ? addAgentCode(g,agent,rem=true) : x , code)
        else
            code = postwalk(x->@capture(x,addAgent(g__)) ? addAgentCode(g,agent) : x , code)
        end

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
        # code = remAgentCode(code,agent)
        #Vectorize
        code = vectorize(code,agent)
        println(prettify(code))
        #Put in loop
        code = makeSimpleLoop(code,agent)

        agent.declaredUpdatesCode[:UpdateLocal] = code
        agent.declaredUpdatesFunction[:UpdateLocal_] = Main.eval(:(($(args...),) -> $code))
        agent.declaredUpdatesFunction[:UpdateLocal] = Main.eval(:((community,agent) -> agent.declaredUpdatesFunction[:UpdateLocal_]($(args2...))))
    else
        agent.declaredUpdatesFunction[:UpdateLocal] = Main.eval(:((community,agent) -> nothing))
    end

end

function localStep!(community,agent)

    agent.declaredUpdatesFunction[:UpdateLocal](community,agent)

    return 

end