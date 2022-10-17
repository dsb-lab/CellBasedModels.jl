function addAgentCode(g,p;rem=false)

    code = quote end
    
    # if rem #In case of removal, add new people to the list
    #     push!(code.args,:(keepList_[ic1New_] = ic1New_))
    # end

    args = []
    for i in g
        if i.head == :kw
            if !(i.args[1] in [:($i.new) for i in p.declaredSymbols[p.declaredSymbols[:,:scope].==:Local,:name]])
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

    for i in p.declaredSymbols[p.declaredSymbols[:,:scope].==:Local,:name]
        if !(i in args)
            push!(code.args,:($i.new=$i))
        end
    end

    if p.platform == :CPU 
        code = quote
                ic1New_ = N+Threads.atomic_add!(NV,$INT(1)) + 1
                Threads.atomic_add!(N,$INT(1))
                idNew_ = Threads.atomic_add!(agentIdMax,$INT(1)) + 1
                if nMax >= ic1New_
                    id = idNew_
                    $code
                else
                    Threads.atomic_add!(NV,$INT(-1))
                    Threads.atomic_add!(N,$INT(-1))
                    limNMax_[] = 0
                end
            end
    elseif p.platform == :GPU
        code = quote
            ic1New_ = N+CUDA.atomic_add!(CUDA.pointer(NV,1),$(INT["gpu"])(1)) + 1
            CUDA.atomic_add!(CUDA.pointer(N,1),$(INT["gpu"])(1))
            idNew_ = CUDA.atomic_add!(CUDA.pointer(agentIdMax,1),$(INT["gpu"])(1)) + 1
            if nMax >= ic1New_
                id = idNew_
                $code
            else
                CUDA.atomic_add!(CUDA.pointer(NV,1),$(INT["gpu"])(-1))
                CUDA.atomic_add!(CUDA.pointer(N,1),$(INT["gpu"])(-1))
                limNMax_[1] = 0
            end
        end
    end

    code = vectorize(code,p)

    code = postwalk(x->@capture(x,g0_[g1_] = g3_) && g1 == :ic1_ ? :($g0[ic1New_] = $g3) : x , code)

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
function addEventAddAgent(code::Expr,p::Agent)

    if inexpr(code,:addAgent)
        
        if inexpr(code,:removeAgent) #In case of removal, add new people to the list
            code = postwalk(x->@capture(x,addAgent(g__)) ? addAgentCode(g,p,rem=true) : x , code)
        else
            code = postwalk(x->@capture(x,addAgent(g__)) ? addAgentCode(g,p) : x , code)
        end

        push!(p.declaredSymbols,[:NV,:AtomicInt,:Atomic,:Int,false,:Inner])
        push!(p.declaredSymbols,[:agentIdMax,:AtomicInt,:Atomic,:Int,false,:Inner])

    end

    return code
end
