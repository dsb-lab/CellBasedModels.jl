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
                    varCopy_ = Array([com.var;zeros(nMax-size(com.var)[1],$(length(abm.declaredSymbols["Variable"])))])
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
                    locCopy_ = Array([com.var;zeros(nMax-size(com.var)[1],$(length(abm.declaredSymbols["Local"])))])
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
                    idCopy_ = Array([com.var;zeros(nMax-size(com.var)[1],$(length(abm.declaredSymbols["Identity"])))])
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

        #Check updated in the wrong place
        updated = updatedParameters_(abm.declaredUpdates["UpdateGlobal"])
        for i in updated
            place = whereDeclared_(abm,i)
            if place == "Global" || place == "GlobalArray" || place === nothing
                nothing
            else
                error(i, " has been updated in Global but was declared as ", place, " in code:\n", abm.declaredUpdates["UpdateGlobal"])
            end
        end

        #Create function
        f = simpleFirstLoopWrapInFunction_(platform,:globStep_,abm.declaredUpdates["UpdateGlobal"])
        f = vectorize_(abm,f,update="Copy")

        push!(p.declareF.args,
            f)

        push!(p.execInloop.args,
                :(globStep_(ARGS_)) 
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
        f = simpleFirstLoopWrapInFunction_(platform,:locStep_,abm.declaredUpdates["UpdateLocal"])
        f = vectorize_(abm,f,update="Copy")

        push!(p.declareF.args,
            f)

        push!(p.execInloop.args,
                :(locStep_(ARGS_)) 
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
        f = loop_(abm,space,abm.declaredUpdates["UpdateLocalInteraction"],platform)
        f = vectorize_(abm,f)
        f = wrapInFunction_(:locInterStep_,f)

        push!(p.declareF.args,
            f)

        push!(p.execInloop.args,
                :(locInterStep_(ARGS_))
            )
    end

    return nothing
end

"""
    function addUpdateLocalInteraction_!(abm::Agent,space::SimulationSpace,p::Program_,platform::String)

Generate the functions related with Local Interaction Updates.
"""
function addUpdateInteraction_!(abm::Agent,space::SimulationSpace,p::Program_,platform::String)

    if !emptyquote_(abm.declaredUpdates["UpdateInteraction"])
        f = loop_(abm,space,abm.declaredUpdates["UpdateInteraction"],platform)
        f = vectorize_(abm,f)
        f = wrapInFunction_(:locInterStep_,f)

        push!(p.declareF.args,
            f)

    end

    return nothing
end

