function integratorEuler(agentModel::Model,inLoop::Expr,arg::Array{Symbol};platform::String="cpu")
    
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
            args = string(eq.args[2])
            push!(nEqs,string("$v += ($args)*dt_"))
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
        inter = vectParams(agentModel,deepcopy(agentModel.inter))
        inter = NEIGHBORHOODADAPT[typeof(agentModel.neighborhood)](inter)
        inLoop = Meta.parse(replace(string(inLoop),"ALGORITHMS_"=>"$(inter...)"))
    
        push!(fdeclare,
        platformAdapt(
        :(
        function interUpdate_($(comArgs...),$(arg...))
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
        @OUTFUNCTION_ interUpdate_($(comArgs...),$(arg...))
        ),platform=platform)
        )

    end
        
    return varDeclare, fdeclare, execute
end