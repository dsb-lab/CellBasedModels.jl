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

    if !emptyquote_(abm.declaredUpdates["UpdateGlobal"])

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

    if !emptyquote_(abm.declaredUpdates["UpdateLocal"])

        #Check updated
        up = symbols_(abm,abm.declaredUpdates["UpdateLocal"])
        up = up[Bool.((up[:,"placeDeclaration"].==:Model) .* Bool.((up[:,"assigned"].==true) .+ (up[:,"updated"].==true))),:]

        #Construct functions
        f = simpleFirstLoopWrapInFunction_(platform,:locStep_!,abm.declaredUpdates["UpdateLocal"])
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
    function addCleanInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with Cleaning Interaction Updates.
"""
function addCleanInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if !emptyquote_(abm.declaredUpdates["UpdateLocalInteraction"]) || !emptyquote_(abm.declaredUpdates["UpdateInteraction"])

        #Construct cleanup function
        s = []
        for i in ["UpdateLocalInteraction","UpdateInteraction"]
            syms = symbols_(abm,abm.declaredUpdates[i])
            syms = syms[Bool.((syms[:,"placeDeclaration"] .== :Model) .* syms[:,"updated"]),"Symbol"]
            append!(s,syms)
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
    function addUpdateLocalInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions related with Local Interaction Updates.
"""
function addUpdateLocalInteraction_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    if !emptyquote_(abm.declaredUpdates["UpdateLocalInteraction"])

        #Construct update computation function
        fcompute = loop_(p,abm,space,abm.declaredUpdates["UpdateLocalInteraction"],platform)
        fcompute = vectorize_(abm,fcompute,p)
        fcompute = wrapInFunction_(:locInterCompute_!,fcompute)
        push!(p.declareF.args,fcompute)

        #Wrap both functions in a clean step function
        f = push!(p.declareF.args,
            :(
                function locInterStep_!(ARGS_)
                    @platformAdapt cleanInteraction_!(ARGS_)
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
    function addDivision_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the functions for division events.
"""
function addEventDivision_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

    code = abm.declaredUpdates["EventDivision"]

    if !emptyquote_(code)

        #Add atomic_add
        code = vectorize_(abm,code,p)
        subcode = code.args[end].args[end]
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
                    s = Meta.parse(string(j,"_₁"))
                    subcode = postwalk(x -> @capture(x,$s=v__) ? :($vecCopy[ic1_,$ii] = $(v...)) : x, subcode)
                    s = Meta.parse(string(j,"_₂"))
                    subcode = postwalk(x -> @capture(x,$s=v__) ? :($vecCopy[ic1New_,$ii] = $(v...)) : x, subcode)
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
        code.args[end].args[end] = subcode

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
