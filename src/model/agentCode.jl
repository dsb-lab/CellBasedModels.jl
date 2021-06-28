"""
    function addParameters_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the variables of the model and declare them.
"""
function addParameters_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)
    
    #Parameter declare###########################################################################

    if length(abm.declaredSymbols["Local"])>0
        append!(p.declareVar.args, 
            (quote
                localV = Array(Float64.([com.local_;Base.zeros(nMax-N,$(length(abm.declaredSymbols["Local"])))]))
            end).args
        )

        push!(p.args,:localV)

        if !isempty(p.update["Local"])
            append!(p.declareVar.args, 
                (quote
                    localVCopy = zeros(Float64,size(localV)[1],$(length(keys(p.update["Local"]))))
                end).args
            )
    
            push!(p.args,:localVCopy)
        end
    end
    if length(abm.declaredSymbols["Identity"])>0
        append!(p.declareVar.args, 
            (quote
                identityV = Array([Int.(com.identity_);Base.zeros(Int,nMax-N,$(length(abm.declaredSymbols["Identity"])))])
            end).args 
        ) 

        push!(p.args,:identityV)

        if !isempty(p.update["Identity"])
            append!(p.declareVar.args, 
                (quote
                    identityVCopy = zeros(Int,size(identityV)[1],$(length(keys(p.update["Identity"]))))
                end).args
            )
    
            push!(p.args,:identityVCopy)
        end
    end

    if length(abm.declaredSymbols["Global"])>0
        append!(p.declareVar.args, 
            (quote
                globalV = Array(Float64.(com.global_))
            end).args
        )

        push!(p.args,:globalV)
        if !isempty(p.update["Global"]) && !isempty([ v for v in keys(p.update["Global"]) if v in abm.declaredSymbols["Global"] ])
            append!(p.declareVar.args, 
                (quote
                    globalVCopy = zeros(Float64,$(length(p.update["Global"])))
                end).args
            )
    
            push!(p.args,:globalVCopy)
        end    
    end
    
    if length(abm.declaredSymbols["GlobalArray"])>0
        for (j,i) in enumerate(abm.declaredSymbols["GlobalArray"])
            append!(p.declareVar.args, 
            (quote
                $(Meta.parse(string(i))) = Array(com.globArray[$j])
            end).args 
            )
           
            push!(p.args,Meta.parse(string(i)))
        end
        if !isempty(p.update["Global"])
            for (j,i) in enumerate(abm.declaredSymbols["GlobalArray"])
                append!(p.declareVar.args, 
                (quote
                    $(Meta.parse(string(i,"Copy"))) = Array(com.globArray[$j])
                end).args 
                )
    
                push!(p.args,Meta.parse(string(i,"Copy")))
            end
        end
    end

    return nothing
end

"""
    function addUpdateLocal_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with Global Updates.
"""
function addUpdateGlobal_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if "UpdateGlobal" in keys(abm.declaredUpdates)

        #Check updated
        up = symbols_(abm,abm.declaredUpdates["UpdateGlobal"])
        up = up[Bool.((up[:,"placeDeclaration"].==:Model) .* Bool.((up[:,"assigned"].==true) .+ (up[:,"updated"].==true))),:]

        #Construct functions
        f = simpleFirstLoopWrapInFunction_(platform,:globStep_!,
                        :(begin        
                            if ic1_ == 1
                                $(abm.declaredUpdates["UpdateGlobal"])
                            end
                        end)
                        )
        f = vectorize_(abm,f,p)

        push!(p.declareF.args,
            f)

        push!(p.execInloop.args,
                :(@platformAdapt globStep_!(ARGS_)) 
            )
    end

    return nothing
end

"""
    function addUpdateLocal_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with Local Updates.
"""
function addUpdateLocal_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if "UpdateLocal" in keys(abm.declaredUpdates)

        code = abm.declaredUpdates["UpdateLocal"]

        #Construct functions
        f = simpleFirstLoopWrapInFunction_(platform,:locStep_!,code)
        f = vectorize_(abm,f,p)

        push!(p.declareF.args,
            f)

        push!(p.execInloop.args,
                :(@platformAdapt locStep_!(ARGS_)) 
            )

    end

    return nothing
end

"""
    function addCheckBounds_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with boundary checking.
"""
function addCheckBounds_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if !isempty([i for i in keys(p.update["Local"])])
        ##Add bound code if bound symbols update
        code = returnBound_(space.box,p)

        if !emptyquote_(code)

            #Construct functions
            f = simpleFirstLoopWrapInFunction_(platform,:boundsCheck_!,code)
            f = vectorize_(abm,f,p)

            push!(p.declareF.args,
                f)

            push!(p.execInloop.args,
                    :(@platformAdapt boundsCheck_!(ARGS_)) 
                )

        end

    end

    return nothing
end

"""
    function addCleanInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with Cleaning Interaction Updates.
"""
function addCleanInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if "UpdateLocalInteraction" in keys(abm.declaredUpdates) || "UpdateInteraction" in keys(abm.declaredUpdates)

        #Construct cleanup function
        s = []
        for i in ["UpdateInteraction"]
            if i in keys(abm.declaredUpdates)
                syms = symbols_(abm,abm.declaredUpdates[i])
                syms = syms[Bool.((syms[:,"placeDeclaration"] .== :Model) .* syms[:,"updated"]),"Symbol"]
                append!(s,syms)
            end
        end
        unique!(s)
        up = quote end
        for i in s
            pos = findfirst(abm.declaredSymbols["Local"] .== i)
            push!(up.args,:(localV[ic1_,$pos]=0))
        end
        fclean = simpleFirstLoopWrapInFunction_(platform,:cleanInteraction_!,up)
        push!(p.declareF.args,fclean)
    end

    return nothing
end

"""
    function addCleanInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with Cleaning Interaction Updates.
"""
function addCleanLocalInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if "UpdateLocalInteraction" in keys(abm.declaredUpdates) || "UpdateInteraction" in keys(abm.declaredUpdates)

        #Construct cleanup function
        s = []
        for i in ["UpdateLocalInteraction"]
            if i in keys(abm.declaredUpdates)
                syms = symbols_(abm,abm.declaredUpdates[i])
                syms = syms[Bool.((syms[:,"placeDeclaration"] .== :Model) .* syms[:,"updated"]),"Symbol"]
                append!(s,syms)
            end
        end
        unique!(s)
        up = quote end
        for i in s
            pos = findfirst(abm.declaredSymbols["Local"] .== i)
            push!(up.args,:(localV[ic1_,$pos]=0))
        end
        fclean = simpleFirstLoopWrapInFunction_(platform,:cleanLocalInteraction_!,up)
        push!(p.declareF.args,fclean)
    end

    return nothing
end

"""
    function addUpdateLocalInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with Local Interaction Updates.
"""
function addUpdateLocalInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if "UpdateLocalInteraction" in keys(abm.declaredUpdates)

        #Construct update computation function
        fcompute = loop_(p,abm,space,abm.declaredUpdates["UpdateLocalInteraction"],platform)
        fcompute = vectorize_(abm,fcompute,p)
        fcompute = wrapInFunction_(:locInterCompute_!,fcompute)
        push!(p.declareF.args,fcompute)

        #Wrap both functions in a clean step function
        f = push!(p.declareF.args,
            :(
                function locInterStep_!(ARGS_)
                    @platformAdapt cleanLocalInteraction_!(ARGS_)
                    @platformAdapt locInterCompute_!(ARGS_)
                    return
                end
            )
            )

        push!(p.execInit.args,
                :(locInterStep_!(ARGS_))
            )
        push!(p.execInloop.args,
            :(locInterStep_!(ARGS_))
        )
        push!(p.execAfter.args,
                :(locInterStep_!(ARGS_))
            )
        
end

    return nothing
end

"""
    function addUpdate_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions to update all the modified values.
"""
function addUpdate_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    create = false

    for i in keys(abm.declaredUpdates)
        if !(i in ["UpdateLocalInteraction","UpdateInteraction","EventDivision"]) && !emptyquote_(abm.declaredUpdates[i])
            create = true
        end
    end 

    if create
        gen = quote end #General update
        up = quote end
        for i in keys(abm.declaredSymbols)
            if  i == "GlobalArray"
                for j in keys(p.update[i]) 
                    n = Meta.parse(string(j,"Copy_")) 
                    push!(gen.args,:($j.=$n))
                end
            elseif i in ["Local","Identity"]
                var = Meta.parse(string(lowercase(i),"V"))
                varCopy = Meta.parse(string(lowercase(i),"VCopy"))
                for j in keys(p.update[i])
                    pos = findfirst(abm.declaredSymbols[i] .== j)
                    posCopy = p.update[i][j]
                    push!(up.args,:($var[ic1_,$pos]=$varCopy[ic1_,$posCopy]))
                end
            elseif i == "Global"
                var = Meta.parse(string(lowercase(i),"V"))
                varCopy = Meta.parse(string(lowercase(i),"VCopy"))
                
                upb = quote end #Assign updates of the global to the first thread
                for j in keys(p.update[i])
                    pos = findfirst(abm.declaredSymbols[i] .== j)
                    posCopy = p.update[i][j]
                    push!(upb.args,:($var[$pos]=$varCopy[$posCopy]))
                end

                push!(up.args,
                    :(begin
                        if ic1_ == 1
                            $(upb)
                        end
                    end))
            end

        end
        
        #Construct global and local update function
        f = simpleFirstLoopWrapInFunction_(platform,:updateLocGlob_!,up)
        push!(p.declareF.args,f)
        #Construct general update function
        push!(p.declareF.args,
            :(begin 
                function update_!(ARGS_)
                    $gen
                    @platformAdapt updateLocGlob_!(ARGS_)
                    return
                end
            end)
            )

        #Add to execution cue
        push!(p.execInloop.args,:(update_!(ARGS_)))
    end

    return nothing
end

"""
    function addCopyInitialisation_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions to update all the modified values.
"""
function addCopyInitialisation_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    create = false

    for i in keys(abm.declaredUpdates)
        if !(i in ["UpdateLocalInteraction","UpdateInteraction","EventDivision"]) && !emptyquote_(abm.declaredUpdates[i])
            create = true
        end
    end 

    if create
        gen = quote end #General update
        up = quote end
        for i in keys(abm.declaredSymbols)
            if  i == "GlobalArray"
                for j in keys(p.update[i]) 
                    n = Meta.parse(string(j,"Copy_")) 
                    push!(gen.args,:($n.=$j))
                end
            elseif i in ["Local","Identity"]
                var = Meta.parse(string(lowercase(i),"V"))
                varCopy = Meta.parse(string(lowercase(i),"VCopy"))
                for j in keys(p.update[i])
                    pos = findfirst(abm.declaredSymbols[i] .== j)
                    posCopy = p.update[i][j]
                    push!(up.args,:($varCopy[ic1_,$posCopy]=$var[ic1_,$pos]))
                end
            elseif i == "Global"
                var = Meta.parse(string(lowercase(i),"V"))
                varCopy = Meta.parse(string(lowercase(i),"VCopy"))
                
                upb = quote end #Assign updates of the global to the first thread
                for j in keys(p.update[i])
                    pos = findfirst(abm.declaredSymbols[i] .== j)
                    posCopy = p.update[i][j]
                    push!(upb.args,:($varCopy[$posCopy]=$var[$pos]))
                end

                push!(up.args,
                    :(begin
                        if ic1_ == 1
                            $(upb)
                        end
                    end))
            end

        end
        
        #Construct global and local update function
        f = simpleFirstLoopWrapInFunction_(platform,:initialiseLocGlobCopy_!,up)
        push!(p.declareF.args,f)
        #Construct general update function
        push!(p.declareF.args,
            :(begin 
                function initialiseCopy_!(ARGS_)
                    $gen
                    @platformAdapt initialiseLocGlobCopy_!(ARGS_)
                    return
                end
            end)
            )

        #Add to execution cue
        push!(p.execInit.args,:(initialiseCopy_!(ARGS_)))
    end

    return nothing
end

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


"""
    function addEventDeath_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions for division events.
"""
function addEventDeath_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if "EventDeath" in keys(abm.declaredUpdates)

        condition = abm.declaredUpdates["EventDeath"].args[end]

        #Create function to check dead elements
        if platform == "cpu"
            up= :(removeList_Pos_ = Threads.atomic_add!(remV_,1) + 1)
        elseif platform == "gpu"
            up= :(removeList_Pos_ = CUDA.atomic_add!(pointer(remV_,1),Int(1)) + 1)
        end

        code = quote
            if $condition
                keepList_[ic1_] = 0
                $up
                removeList_[removeList_Pos_] = ic1_
            else
                keepList_[ic1_] = ic1_
            end
        end

        code = vectorize_(abm,code,p)

        f1 = simpleFirstLoopWrapInFunction_(platform,:checkDyingAgents_!,code)

        #Create function to put agents in their new position
        code = quote
            oldPos_ = keepList_[ic1_]
            newPos_ = removeList_[ic1_]
        end
        if !isempty(abm.declaredSymbols["Local"])
            push!(code.args,
                :(begin 
                    if oldPos_ > 0
                        for ic2_ in 1:$(length(abm.declaredSymbols["Local"]))
                            localV[newPos_, ic2_] = localV[oldPos_, ic2_] 
                        end
                    end
                end)
            )
        end
        if !isempty(abm.declaredSymbols["Identity"])
            push!(code.args,
                :(begin 
                    if oldPos_ > 0
                        for ic2_ in 1:$(length(abm.declaredSymbols["Identity"]))
                            identityV[newPos_, ic2_] = identityV[oldPos_, ic2_] 
                        end
                    end
                end)
            )
        end
        if !isempty(p.update["Local"])
            push!(code.args,
                :(begin 
                    if oldPos_ > 0
                        for ic2_ in 1:$(length(p.update["Local"]))
                            localVCopy[newPos_, ic2_] = localVCopy[oldPos_, ic2_] 
                        end
                    end
                end)
            )
        end
        if !isempty(p.update["Identity"])
            push!(code.args,
                :(begin 
                    if oldPos_ > 0
                        for ic2_ in 1:$(length(p.update["Identity"]))
                            identityVCopy[newPos_, ic2_] = identityVCopy[oldPos_, ic2_] 
                        end
                    end
                end)
            )
        end

        f2 = simpleFirstLoopWrapInFunction_(platform,:assignDeadAgentsSpaces_!,code)  
        if platform == "cpu"
            f2 = postwalk(x->@capture(x,N) ? :(remV_[]) : x, f2)      
        elseif platform == "gpu"
            f2 = postwalk(x->@capture(x,N) ? :(remV_[1]) : x, f2)      
        end


        #Make wrap function of the algorithm
        if platform == "cpu"
            code = quote
                remV_[] = 0
                if N > 0
                    @platformAdapt checkDyingAgents_!(ARGS_)
                    sort!(keepList_,rev=true)
                    @platformAdapt assignDeadAgentsSpaces_!(ARGS_)
                end
            end
        elseif platform == "gpu"
            code = quote
                remV_ .= 0
                if N > 0
                    @platformAdapt checkDyingAgents_!(ARGS_)
                    sort!(keepList_,rev=true)
                    @platformAdapt assignDeadAgentsSpaces_!(ARGS_)
                end
            end        
        end
        
        f3 = wrapInFunction_(:removeDeadAgents_!,code)   

        # Add to program
        if platform == "cpu"
            push!(p.declareVar.args,
                :(begin 
                    remV_ = Threads.Atomic{Int}()
                    keepList_ = zeros(Int,nMax)
                    removeList_ = zeros(Int,nMax)
                end)
            )
        elseif platform == "gpu"
            push!(p.declareVar.args,
                :(begin 
                    remV_ = CUDA.zeros(Int,1)
                    keepList_ = zeros(Int,nMax)
                    removeList_ = zeros(Int,nMax)
                end)
            )
        end

        push!(p.args,:remV_,:keepList_,:removeList_)

        push!(p.declareF.args,f1,f2,f3)

        if platform == "cpu"
            push!(p.execInloop.args,:(removeDeadAgents_!(ARGS_); N -= remV_[]))
        else
            push!(p.execInloop.args,:(removeDeadAgents_!(ARGS_); N -= Core.Array(remV_)[1]))
        end
    end

    return nothing
end
