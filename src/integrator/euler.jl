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
        inter = [string(i,"\n") for i in vectParams(agentModel,deepcopy(agentModel.inter))]
        inLoop = Meta.parse(replace(string(inLoop),"ALGORITHMS_"=>"$(inter...)"))
        inLoop = NEIGHBORHOODADAPT[typeof(agentModel.neighborhood)](inLoop)
    
        reset = []
        for i in 1:length(inter)
            push!(reset,:(inter_[ic1_,$i]=0))
        end
        push!(fdeclare,
        platformAdapt(
        :(
        function interUpdate_($(comArgs...),$(arg...))
        @INFUNCTION_ for ic1_ in index_:stride_:N_
            $(reset...)
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
        @OUTFUNCTION_ interUpdate_($(comArgs...),$(arg...))
        ),platform=platform)
        )
        push!(execute,
        platformAdapt(
        :(
        @OUTFUNCTION_ integratorStep_($(comArgs...))
        ),platform=platform)
        )

    end
        
    return varDeclare, fdeclare, execute
end