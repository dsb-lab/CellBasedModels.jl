function integratorEuler(agentModel::Model;platform::String="cpu",neighborhood="full",nChange_=false,radius=0.,boxSize=[])
    
    varDeclare = []
    fdeclare = []
    execute = []
    
    if length(agentModel.declaredSymb["var"])>0
        
        comArgs = commonArguments(agentModel)

        #Declare auxiliar variables
        nothing
        
        #Make the equations
        nEqs = []
        for eq in agentModel.equations
            v = string(eq.args[1])[2:end-2]
            arg = string(eq.args[2])
            push!(nEqs,string("$v += ($arg)*dt_"))
        end
        eqs = vectParams(agentModel,nEqs)
        push!(fdeclare,
        platformAdapt(
        :(
        function integratorStep_($(comArgs...))
        @INFUNCTION_ for ic1_ in index_:stride_:N_
            $(eqs...)
        end
        return
        end),platform=platform)
        )

        #Make the functions
        inter = vectParams(agentModel,agentModel.inter)
        inLoop, arg = neighboursAdapt(inter,neighborhood=neighborhood,radius=radius,boxSize=boxSize)
    
        push!(fdeclare,
        platformAdapt(
        :(
        function interUpdate_($(comArgs...),$(count...))
        @INFUNCTION_ for ic1_ in index_:stride_:N_
            $inLoop
        end
        return
        end
        ),platform=platform)
        )
    
        #Make the declarations for the inside loop
        push!(execute,
        platformAdapt(
        :(
        @OUTFUNCTION_ integratorStep_($(comArgs...))
        ),platform=platform)
        )
        push!(execute,
        platformAdapt(
        :(
        @OUTFUNCTION_ interUpdate_($(comArgs...),$(count...))
        ),platform=platform)
        )
        append!(execute,agentModel.additionalInteractions)

    end
        
    return varDeclare, fdeclare, execute
end