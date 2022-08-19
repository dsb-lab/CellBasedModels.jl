"""
    function addParameters_!(p::AgentCompiled,platform::String)

Generate the arrays to be declared containing the parameters of all the agents and adds the code generated to `AgentCompiled`.

# Args
 - **p::AgentCompiled**:  AgentCompiled structure containing all the created code when compiling.
 - **platform::String**: Platform to adapt the code.

# Returns
 -  Nothing
"""
function addParameters_!(p::AgentCompiled,platform::String)
    
    #Parameter declare###########################################################################

    append!(p.declareVar.args, 
        (quote
            simulationBox = Array(com.simulationBox)
        end).args
    )

    if length(p.agent.declaredSymbols["Local"])>0
        append!(p.declareVar.args, 
            (quote
                localV = Array($FLOAT.([com.local_;Base.zeros(nMax-N,$(length(p.agent.declaredSymbols["Local"])))]))
            end).args
        )

        push!(p.args,:localV)

        if !isempty(p.update["Local"])
            append!(p.declareVar.args, 
                (quote
                    localVCopy = zeros($FLOAT,size(localV)[1],$(length(keys(p.update["Local"]))))
                end).args
            )
    
            push!(p.args,:localVCopy)
        end
    end

    if length(p.agent.declaredSymbols["LocalInteraction"])>0
        append!(p.declareVar.args, 
            (quote
                localInteractionV = Array($FLOAT.([com.localInteraction_;Base.zeros(nMax-N,$(length(p.agent.declaredSymbols["LocalInteraction"])))]))
            end).args
        )

        push!(p.args,:localInteractionV)
    end

    if length(p.agent.declaredSymbols["Identity"])>0
        append!(p.declareVar.args, 
            (quote
                identityV = Array($INT.([com.identity_;Base.zeros(Int,nMax-N,$(length(p.agent.declaredSymbols["Identity"])))]))
            end).args 
        ) 

        push!(p.args,:identityV)

        if !isempty(p.update["Identity"])
            append!(p.declareVar.args, 
                (quote
                    identityVCopy = zeros($INT,size(identityV)[1],$(length(keys(p.update["Identity"]))))
                end).args
            )
    
            push!(p.args,:identityVCopy)
        end
    end

    if length(p.agent.declaredSymbols["IdentityInteraction"])>0
        append!(p.declareVar.args, 
            (quote
                identityInteractionV = Array($INT.([com.identityInteraction_;Base.zeros(nMax-N,$(length(p.agent.declaredSymbols["IdentityInteraction"])))]))
            end).args
        )

        push!(p.args,:identityInteractionV)
    end

    if length(p.agent.declaredSymbols["Global"])>0
        append!(p.declareVar.args, 
            (quote
                globalV = Array($FLOAT.(com.global_))
            end).args
        )

        push!(p.args,:globalV)
        if !isempty(p.update["Global"]) && !isempty([ v for v in keys(p.update["Global"]) if v in p.agent.declaredSymbols["Global"] ])
            append!(p.declareVar.args, 
                (quote
                    globalVCopy = zeros($FLOAT,$(length(p.update["Global"])))
                end).args
            )
    
            push!(p.args,:globalVCopy)
        end    
    end

    if length(p.agent.declaredSymbols["GlobalInteraction"])>0
        append!(p.declareVar.args, 
            (quote
                globalInteractionV = Array($FLOAT.(com.globalInteraction_))
            end).args
        )

    end

    if length(p.agent.declaredSymbols["Medium"])>0
        if p.agent.dims >= 1
            push!(p.declareVar.args, :(Nx_ = com.mediumN[1]))
            push!(p.declareVar.args, :(dxₘ_ = (com.simulationBox[1,2]-com.simulationBox[1,1])/(Nx_)))

            push!(p.args,:Nx_)
            push!(p.args,:dxₘ_)
        end
        if p.agent.dims >= 2
            push!(p.declareVar.args, :(Ny_ = com.mediumN[2]))
            push!(p.declareVar.args, :(dyₘ_ = (com.simulationBox[2,2]-com.simulationBox[2,1])/(Ny_)))

            push!(p.args,:Ny_)
            push!(p.args,:dyₘ_)
        end
        if p.agent.dims >= 3
            push!(p.declareVar.args, :(Nz_ = com.mediumN[3]))
            push!(p.declareVar.args, :(dzₘ_ = (com.simulationBox[3,2]-com.simulationBox[3,1])/(Nz_)))

            push!(p.args,:Nz_)
            push!(p.args,:dzₘ_)
        end
        if p.agent.dims == 1
            push!(p.declareVar.args, :(mediumV = Base.zeros($FLOAT,size(com.medium_))))
            push!(p.declareVar.args, :(mediumV = com.medium_))
        elseif p.agent.dims == 2
            push!(p.declareVar.args, :(mediumV = Base.zeros($FLOAT,size(com.medium_))))
            push!(p.declareVar.args, :(mediumV = com.medium_))
        elseif p.agent.dims == 3
            push!(p.declareVar.args, :(mediumV = Base.zeros($FLOAT,size(com.medium_))))
            push!(p.declareVar.args, :(mediumV = com.medium_))
        end
        push!(p.declareVar.args, :(mediumV = Array(mediumV)))

        push!(p.args,:mediumV)

        if "UpdateMedium" in keys(p.agent.declaredUpdates)
            push!(p.declareVar.args, :(mediumVCopy = copy(mediumV)))
            push!(p.args,:mediumVCopy)
        end

    end

    return nothing
end

"""
    function addUpdate_!(p::AgentCompiled,platform::String)

Generate the functions to update the parameters at each step and adds the code generated to `AgentCompiled`.

# Args
 - **p::AgentCompiled**:  AgentCompiled structure containing all the created code when compiling.
 - **platform::String**: Platform to adapt the code.

# Returns
 -  Nothing
"""
function addUpdate_!(p::AgentCompiled,platform::String)

    create = false

    #Check if there is something to update
    for i in UPDATINGTYPES
        if !isempty(p.update[i])
            create = true
        end
    end

    if create
        gen = quote end #General update
        up = quote end
        for i in keys(p.agent.declaredSymbols)
            if i in ["Local","Identity"]
                var = Meta.parse(string(lowercase(i),"V"))
                varCopy = Meta.parse(string(lowercase(i),"VCopy"))
                for j in keys(p.update[i])
                    pos = findfirst(p.agent.declaredSymbols[i] .== j)
                    posCopy = p.update[i][j]
                    push!(up.args,:($var[ic1_,$pos]=$varCopy[ic1_,$posCopy]))
                end
            elseif i == "Global"
                var = Meta.parse(string(lowercase(i),"V"))
                varCopy = Meta.parse(string(lowercase(i),"VCopy"))
                
                upb = quote end #Assign updates of the global to the first thread
                for j in keys(p.update[i])
                    pos = findfirst(p.agent.declaredSymbols[i] .== j)
                    posCopy = p.update[i][j]
                    push!(upb.args,:($var[$pos]=$varCopy[$posCopy]))
                end

                if length([i for i in upb.args if typeof(i) != LineNumberNode]) > 0
                    push!(up.args,
                        :(begin
                            if ic1_ == 1
                                $(upb)
                            end
                        end))
                end
            elseif i == "Medium"
                if "UpdateMedium" in keys(p.agent.declaredUpdates)
                    push!(gen.args,:(mediumV.=mediumVCopy))
                end
            end

        end
        
        #Construct global and local update function
        add = nothing
        if length([i for i in up.args if typeof(i) != LineNumberNode]) > 0
            f = simpleFirstLoopWrapInFunction_(platform,:updateLocGlob_!,up)
            push!(p.declareF.args,f)
            add = :(@platformAdapt updateLocGlob_!(ARGS_))
        else
            add = :nothing
        end
        #Construct general update function
        push!(p.declareF.args,
            :(begin 
                function update_!(ARGS_)
                    $gen
                    $add
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
    function addCopyInitialisation_!(p::AgentCompiled)

Generate the functions to update all the modified values.
"""
function addCopyInitialisation_!(p::AgentCompiled)

    create = false

    #Check is there is something to update
    for i in UPDATINGTYPES
        if !isempty(p.update[i])
            create = true
        end
    end

    if create
        gen = quote end #General update
        up = quote end
        for i in keys(p.agent.declaredSymbols)
            if i in ["Local","Identity"]
                var = Meta.parse(string(lowercase(i),"V"))
                varCopy = Meta.parse(string(lowercase(i),"VCopy"))
                for j in keys(p.update[i])
                    pos = findfirst(p.agent.declaredSymbols[i] .== j)
                    posCopy = p.update[i][j]
                    push!(up.args,:($varCopy[ic1_,$posCopy]=$var[ic1_,$pos]))
                end
            elseif i == "Global"
                var = Meta.parse(string(lowercase(i),"V"))
                varCopy = Meta.parse(string(lowercase(i),"VCopy"))
                
                upb = quote end #Assign updates of the global to the first thread
                for j in keys(p.update[i])
                    pos = findfirst(p.agent.declaredSymbols[i] .== j)
                    posCopy = p.update[i][j]
                    push!(upb.args,:($varCopy[$posCopy]=$var[$pos]))
                end

                if length([i for i in upb.args if typeof(i) != LineNumberNode]) > 0
                    push!(up.args,
                        :(begin
                            if ic1_ == 1
                                $(upb)
                            end
                        end))
                end
            elseif i == "Medium"
                if "UpdateMedium" in keys(p.agent.declaredUpdates)
                    push!(gen.args,:(mediumVCopy .= mediumV))
                end
            end

        end
        
        #Construct global and local update function
        add = nothing
        if length([i for i in up.args if typeof(i) != LineNumberNode]) > 0
            f = simpleFirstLoopWrapInFunction_(p.platform,:updateLocGlobInitialisation_!,ARGS,up)
            if p.platform == "cpu"
                add = :(updateLocGlobInitialisation_!($(COMARGS...)))
            elseif p.platform == "gpu"
                add = :(CUDA.@cuda threads=threads_ blocks=nBlocks_ updateLocGlobInitialisation_!($(COMARGS...)))
            end
        else
            add = :nothing
        end

        #Construct general update function
        p.AgentCompiledinitialise = 
                :(begin 
                    function f(com)
                        $f
                        $gen
                        $add
                        return
                    end
                end)

        p.f_initialise = Main.eval(p.AgentCompiledinitialise)
    end

    return nothing
end