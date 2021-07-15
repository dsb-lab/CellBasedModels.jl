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
                $(Meta.parse(string(i))) = Array(copy(com.globalArray_[$j]))
            end).args 
            )
           
            push!(p.args,Meta.parse(string(i)))
        end
        if !isempty(p.update["GlobalArray"])
            for (j,i) in enumerate(keys(p.update["GlobalArray"]))
                append!(p.declareVar.args, 
                (quote
                    $(Meta.parse(string(i,GLOBALARRAYCOPY))) = Array(copy(com.globalArray_[$j]))
                end).args 
                )
    
                push!(p.args,Meta.parse(string(i,GLOBALARRAYCOPY)))
            end
        end
    end

    if length(abm.declaredSymbols["Medium"])>0
        append!(p.declareVar.args, 
            (quote
                mediumV = Array(Float64.(com.medium_))
            end).args
        )

        push!(p.args,:globalV)
        if !isempty(p.update["Medium"]) && !isempty([ v for v in keys(p.update["Medium"]) if v in abm.declaredSymbols["Medium"] ])
            append!(p.declareVar.args, 
                (quote
                    mediumVCopy = zeros(Float64,com.mediumGrid_...,$(length(p.update["Medium"])))
                end).args
            )
    
            push!(p.args,:globalVCopy)
        end    
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
                    n = Meta.parse(string(j,GLOBALARRAYCOPY)) 
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
                    n = Meta.parse(string(j,GLOBALARRAYCOPY)) 
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