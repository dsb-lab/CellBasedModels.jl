function addAgentCode(g,p,platform;rem=false)

    code = quote end
    
    # if rem #In case of removal, add new people to the list
    #     push!(code.args,:(keepList_[ic1New_] = ic1New_))
    # end

    args = []
    for i in g
        if i.head == :kw
            if !(i.args[1] in [:($i.new) for i in p.agent.declaredSymbols["Local"]] || i.args[1] in [:($i.new) for i in p.agent.declaredSymbols["Identity"]])
                error(i.args[1], "is not a Local or Identity parameter of the agent.")
            end
        else
            error(i, " is not a valid assignation of code when declaring addAgent. A Valid one should be of the form parameterOfAgent = value")
        end

        if i.args[1] in args
           error(i.args[1]," has been declared more than once.") 
        end

        if i.args[1] == :id
            error("id should not be declared when calling addAgent, it is assigned automatically.")
        end
        push!(code.args,:($(i.args[1])=$(i.args[2])))
        push!(args,i.args[1].args[1])
    end

    for i in p.agent.declaredSymbols["Local"]
        if !(i in args)
            error(i, " has not been assigned in new agent of addAgent.")
        end
    end

    for i in p.agent.declaredSymbols["Identity"]
        if !(i in args)  && (i != :id)
            error(i, " has not been assigned in new agent declared by addAgent in UpdateLocal.")
        end
    end

    if platform == "cpu" 
        code = quote
                ic1New_ = N+Threads.atomic_add!(NV,$INT(1)) + 1
                idNew_ = Threads.atomic_add!(agentIdMax,$INT(1)) + 1
                if nMax >= ic1New_
                    id = idNew_
                    $code
                else
                    Threads.atomic_add!(NV,$INT(-1))
                    limNMax_[] = 0
                end
            end
    else
        code = quote
            ic1New_ = N+CUDA.atomic_add!(CUDA.pointer(NV,1),$INTCUDA(1)) + 1
            idNew_ = CUDA.atomic_add!(CUDA.pointer(agentIdMax,1),$INTCUDA(1)) + 1
            if nMax >= ic1New_
                id = idNew_
                $code
            else
                Threads.atomic_add!(NV,$INT(-1))
                limNMax_[1] = 0
            end
        end
    end

    code = vectorize_(p.agent,code,p)

    code = postwalk(x->@capture(x,g0_[g1_,g2_] = g3_) && g1 == :ic1_ ? :($g0[ic1New_,$g2] = $g3) : x , code)

    return code
end

"""
    function addEventAddAgent_(code::Expr,p::Program_,platform::String)

Generate the functions for division events.
"""
function addEventAddAgent_(code::Expr,p::Program_,platform::String)

    if inexpr(code,:addAgent)
        
        if inexpr(code,:removeAgent) #In case of removal, add new people to the list
            code = postwalk(x->@capture(x,addAgent(g__)) ? addAgentCode(g,p,platform,rem=true) : x , code)
        else
            code = postwalk(x->@capture(x,addAgent(g__)) ? addAgentCode(g,p,platform) : x , code)
        end

        if platform == "cpu"

            push!(p.declareVar.args,:(NV = Threads.Atomic{$INT}(0)))
            push!(p.declareVar.args,:(agentIdMax = Threads.Atomic{$INT}(N)))

            push!(p.execInloop.args,:(N += NV[]; NV[] = 0))

        elseif platform == "gpu"

            push!(p.declareVar.args,:(NV = CUDA.zeros($INTCUDA,1)))
            push!(p.declareVar.args,:(agentIdMax = N .*CUDA.ones($INTCUDA,1)))

            push!(p.execInloop.args,:(N += Core.Array(NV)[1]; NV .= 0))

        end

        push!(p.args,:(NV),:(agentIdMax),:(limNMax_),:(nMax))

    end

    return code
end
