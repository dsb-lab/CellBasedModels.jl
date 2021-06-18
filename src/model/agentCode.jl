"""
    function addParameters_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)

Generate the variables of the model and declare them.
"""
function addParameters_!(p::Program_,abm::Agent,space::SimulationSpace,platform::String)
    
    #Parameter declare###########################################################################

    if length(abm.declaredSymbols["Local"])>0
        append!(p.declareVar.args, 
            (quote
                local_ = Array([com.local_;zeros(nMax-size(com.N)[1],$(length(abm.declaredSymbols["Local"])))])
            end).args
        )

        push!(p.args,:local_)

        if !emptyquote_(abm.declaredUpdates["UpdateLocal"]) || !emptyquote_(abm.declaredUpdates["Equation"])
            append!(p.declareVar.args, 
                (quote
                    localCopy_ = zeros(nMax-size(com.N)[1],$(length(keys(p.update["Local"]))))
                end).args
            )
    
            push!(p.args,:localCopy_)
        end
    end
    if length(abm.declaredSymbols["Identity"])>0
        append!(p.declareVar.args, 
            (quote
                identity_ = Array(Int,[com.identity_;zeros(Int,nMax-size(com.N)[1],$(length(abm.declaredSymbols["Identity"])))])
            end).args 
        ) 

        push!(p.args,:identity_)

        if !emptyquote_(abm.declaredUpdates["UpdateLocal"])
            append!(p.declareVar.args, 
                (quote
                    identityCopy_ = zeros(nMax-size(com.N)[1],$(length(keys(p.update["Identity"]))))
                end).args
            )
    
            push!(p.args,:identityCopy_)
        end
    end

    if length(abm.declaredSymbols["Global"])>0
        append!(p.declareVar.args, 
            (quote
                global_ = Array(com.global_)
            end).args
        )

        push!(p.args,:glob_)
        if !emptyquote_(abm.declaredUpdates["UpdateGlobal"])
            append!(p.declareVar.args, 
                (quote
                    globalCopy_ = Array(com.glob)
                end).args
            )
    
            push!(p.args,:globalCopy_)
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
        if !emptyquote_(abm.declaredUpdates["UpdateGlobal"])
            for (j,i) in enumerate(abm.declaredSymbols["GlobalArray"])
                append!(p.declareVar.args, 
                (quote
                    $(Meta.parse(string(i,"Copy__"))) = Array(com.globArray[$j])
                end).args 
                )
    
                push!(p.args,Meta.parse(string(i,"Copy__")))
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
        f = simpleFirstLoopWrapInFunction_(platform,:globStep_!,abm.declaredUpdates["UpdateGlobal"])
        f = vectorize_(abm,f,update="Copy")

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
        f = vectorize_(abm,f,update="Copy")

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
            push!(up.args,:(local_[ic1_,$pos]=0))
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
        fcompute = loop_(abm,space,abm.declaredUpdates["UpdateLocalInteraction"],platform)
        fcompute = vectorize_(abm,fcompute)
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


        push!(p.execInloop.args,
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

    gen = quote end #General update
    up = quote end
    for i in keys(abm.declaredSymbols)
        if  i == "GlobalArray"
            for j in keys(p.update[i]) 
                n = Meta.parse(string(j,"Copy_")) 
                push!(gen.args,:($j.=$n))
            end
        elseif i in ["Local","Identity"]
            var = Meta.parse(lowercase(string(i,"_")))
            varCopy = Meta.parse(string(lowercase(i),"Copy_"))
            for j in keys(p.update[i])
                pos = findfirst(abm.declaredSymbols[i] .== j)
                posCopy = p.update[i][j]
                push!(up.args,:($var[ic1_,$pos]=$varCopy[ic1_,$posCopy]))
            end
        elseif i == "Global"
            var = Meta.parse(lowercase(string(i,"_")))
            varCopy = Meta.parse(string(lowercase(i),"Copy_"))
            
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

    return nothing
end
