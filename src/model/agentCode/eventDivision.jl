"""
    function addEventDivision_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions for division events.
"""
function addEventDivision_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if "EventDivision" in keys(abm.declaredUpdates)

        code = abm.declaredUpdates["EventDivision"]

        if !@capture(code,if v_ g__ end)
            error("Erroneos structure of division events. Should be if something update end")
        end

        code = vectorize_(abm,code,p)
        subcode = postwalk(x->@capture(x,if v_ g__ end) ? quote $(g...) end : x, code)
        subcode = unblock(subcode)
        condition = postwalk(x->@capture(x,if v_ g__ end) ? v : x, code)
        condition = unblock(condition)

        #Add atomic_add
        if platform == "cpu"
            pushfirst!(subcode.args, :(ic1New_ = Threads.atomic_add!(NV,Int(1)) + 1))
            pushfirst!(subcode.args, :(idNew_ = Threads.atomic_add!(agentIdMax,Int(2)) + 1))
        elseif platform == "gpu"
            pushfirst!(subcode.args, :(ic1New_ = CUDA.atomic_add!(CUDA.pointer(NV,1),Int32(1)) + 1))
            pushfirst!(subcode.args, :(idNew_ = CUDA.atomic_add!(CUDA.pointer(agentIdMax,1),Int32(2)) + 1))
        end
        for k in ["Local","Identity"]
            vec = Meta.parse(string(lowercase(k),"V"))
            vecCopy = Meta.parse(string(lowercase(k),"VCopy"))
            for (i,j) in enumerate(abm.declaredSymbols[k])
                if j in keys(p.update["EventDivision"])
                    ii = p.update[k][j]
                    #Parse content
                    s = Meta.parse(string(j,"_1"))
                    subcode = postwalk(x -> @capture(x,g_=v__) && g == s ? :($vecCopy[ic1_,$ii] = $(v...)) : x, subcode)
                    s = Meta.parse(string(j,"_2"))
                    subcode = postwalk(x -> @capture(x,g_=v__) && g == s ? :($vecCopy[ic1New_,$ii] = $(v...)) : x, subcode)
                end
            end          
        end
        for k in ["Local","Identity"]  #Add other updates of non changed variables
            vec = Meta.parse(string(lowercase(k),"V"))
            vecCopy = Meta.parse(string(lowercase(k),"VCopy"))  
            for (i,j) in enumerate(abm.declaredSymbols[k])
                #Add update if doesn't exist
                if !(j in keys(p.update["EventDivision"])) && j != :agentId
                    push!(subcode.args,:($vec[ic1New_,$i] = $vec[ic1_,$i]))
                elseif j != :agentId
                    ii = p.update[k][j]
                    push!(subcode.args,:($vec[ic1_,$i] = $vecCopy[ic1_,$ii]))
                    push!(subcode.args,:($vec[ic1New_,$i] = $vecCopy[ic1New_,$ii]))                
                else
                    ii = findfirst(abm.declaredSymbols["Identity"] .== j)
                    push!(subcode.args,:($vec[ic1_,$ii] = idNew_))
                    push!(subcode.args,:($vec[ic1New_,$ii] = idNew_ + 1))                                    
                end
            end        
        end
        code = quote
            if $condition
                $subcode
            end
        end

        code = simpleFirstLoopWrapInFunction_(platform,:division_!,code)

        push!(p.declareF.args,code)
        push!(p.args,:(NV))
        if platform == "cpu"
            push!(p.declareVar.args,:(NV = Threads.Atomic{Int}(N)))
            push!(p.declareVar.args,:(agentIdMax = Threads.Atomic{Int}(N)))

            push!(p.execInloop.args,
                    :(begin
                        @platformAdapt division_!(ARGS_)
                        N = NV[]
                    end)
                )
        elseif platform == "gpu"
            push!(p.declareVar.args,:(NV = N .*CUDA.ones(Int,1)))
            push!(p.declareVar.args,:(agentIdMax = N .*CUDA.ones(Int,1)))

            push!(p.execInloop.args,
                    :(begin
                        @platformAdapt division_!(ARGS_)
                        N = Core.Array(NV)[1]
                    end)
                )
        end

    end

    return nothing
end
