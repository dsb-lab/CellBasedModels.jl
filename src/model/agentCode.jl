"""
    function addParameters_!(abm::Agent,space::SimulationSpace,p::Program_,platform::String)

Generate the variables of the model and declare them.
"""
function addParameters_!(abm::Agent,space::SimulationSpace,p::Program_,platform::String)
    
    #Parameter declare###########################################################################

    if length(abm.declaredSymbols["Variable"])>0
        append!(p.declareVar.args, 
            (quote
                var_ = Array([com.var;zeros(nMax-size(com.var)[1],$(length(abm.declaredSymbols["Variable"])))])
            end).args
        )

        push!(p.args,:var_)

        if !emptyquote_(abm.declaredUpdates["Equation"])
            append!(p.declareVar.args, 
                (quote
                    varCopy_ = copy(var_)
                end).args
            )
    
            push!(p.args,:varCopy_)
        end    
    end
    if length(abm.declaredSymbols["Local"])>0
        append!(p.declareVar.args, 
            (quote
                loc_ = Array([com.loc;zeros(nMax-size(com.loc)[1],$(length(abm.declaredSymbols["Local"])))])
            end).args
        )

        push!(p.args,:loc_)

        if !emptyquote_(abm.declaredUpdates["UpdateLocal"])
            append!(p.declareVar.args, 
                (quote
                    locCopy_ = copy(loc_)
                end).args
            )
    
            push!(p.args,:locCopy_)
        end
    end
    if length(abm.declaredSymbols["Identity"])>0
        append!(p.declareVar.args, 
            (quote
                id_ = Array(Int,[com.ids;zeros(Int,nMax-size(com.ids)[1],$(length(abm.declaredSymbols["Identity"])))])
            end).args 
        ) 

        push!(p.args,:id_)

        if !emptyquote_(abm.declaredUpdates["UpdateLocal"])
            append!(p.declareVar.args, 
                (quote
                    idCopy_ = copy(id_)
                end).args
            )
    
            push!(p.args,:idCopy_)
        end
    end

    if length(abm.declaredSymbols["Interaction"])>0
        append!(p.declareVar.args, 
            (quote
                inter_ = zeros(nMax,$(length(abm.declaredSymbols["Interaction"])))
            end).args
        )

        push!(p.args,:inter_)
    end
    if length(abm.declaredSymbols["Global"])>0
        append!(p.declareVar.args, 
            (quote
                glob_ = Array(com.glob)
            end).args
        )

        push!(p.args,:glob_)
        if !emptyquote_(abm.declaredUpdates["UpdateGlobal"])
            append!(p.declareVar.args, 
                (quote
                    globCopy_ = Array(com.glob)
                end).args
            )
    
            push!(p.args,:globCopy_)
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
                    $(Meta.parse(string(i,"Copy_"))) = Array(com.globArray[$j])
                end).args 
                )
    
                push!(p.args,Meta.parse(string(i,"Copy_")))
            end
        end
    end

    return nothing
end

"""
    function addUpdateLocal_!(abm::Agent,space::SimulationSpace,p::Program_,platform::String)

Generate the functions related with Global Updates.
"""
function addUpdateGlobal_!(abm::Agent,space::SimulationSpace,p::Program_,platform::String)

    if !emptyquote_(abm.declaredUpdates["UpdateGlobal"])

        #Check updated
        up = symbols_(abm,abm.declaredUpdates["UpdateGlobal"])
        up = up[Bool.((up[:,"placeDeclaration"].==:Model) .* Bool.((up[:,"assigned"].==true) .+ (up[:,"updated"].==true))),:]
        append!(p.update,up.Symbol)

        #Construct functions
        f = simpleFirstLoopWrapInFunction_(platform,:globStep_!,abm.declaredUpdates["UpdateGlobal"])
        f = vectorize_(abm,f,update="Copy")

        push!(p.declareF.args,
            f)

        push!(p.execInloop.args,
                :(globStep_!(ARGS_)) 
            )
    end

    return nothing
end

"""
    function addUpdateLocal_!(abm::Agent,space::SimulationSpace,p::Program_,platform::String)

Generate the functions related with Local Updates.
"""
function addUpdateLocal_!(abm::Agent,space::SimulationSpace,p::Program_,platform::String)

    if !emptyquote_(abm.declaredUpdates["UpdateLocal"])

        #Check updated
        up = symbols_(abm,abm.declaredUpdates["UpdateLocal"])
        up = up[Bool.((up[:,"placeDeclaration"].==:Model) .* Bool.((up[:,"assigned"].==true) .+ (up[:,"updated"].==true))),:]
        append!(p.update,up.Symbol)

        #Construct functions
        f = simpleFirstLoopWrapInFunction_(platform,:locStep_!,abm.declaredUpdates["UpdateLocal"])
        f = vectorize_(abm,f,update="Copy")

        push!(p.declareF.args,
            f)

        push!(p.execInloop.args,
                :(locStep_!(ARGS_)) 
            )

    end

    return nothing
end

"""
    function addUpdateLocalInteraction_!(abm::Agent,space::SimulationSpace,p::Program_,platform::String)

Generate the functions related with Local Interaction Updates.
"""
function addUpdateLocalInteraction_!(abm::Agent,space::SimulationSpace,p::Program_,platform::String)

    if !emptyquote_(abm.declaredUpdates["UpdateLocalInteraction"])

        #Construct functions
        f = loop_(abm,space,abm.declaredUpdates["UpdateLocalInteraction"],platform)
        f = vectorize_(abm,f)
        f = wrapInFunction_(:locInterStep_!,f)

        push!(p.declareF.args,
            f)

        push!(p.execInloop.args,
                :(locInterStep_!(ARGS_))
            )

    end

    return nothing
end

"""
    function addUpdate_!(abm::Agent,space::SimulationSpace,p::Program_,platform::String)

Generate the functions to update all the modified values.
"""
function addUpdate_!(abm::Agent,space::SimulationSpace,p::Program_,platform::String)

    unique!(p.update)

    up = quote end
    for i in p.update
        dec = whereDeclared_(abm,i)[2]
        if  !(dec in [:GlobalArray,:Interaction])
            push!(up.args,:($i=$i))
        end
    end
    
    #Construct functions
    f = simpleFirstLoopWrapInFunction_(platform,:update_!,up)
    f = vectorize_(abm,f,base="Copy")

    push!(p.declareF.args,f)
    push!(p.execInloop.args,:(update_!(ARGS_)))

    return nothing
end
