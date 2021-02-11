function integratorSDEEulerIto(agentModel::Model,inLoop::Expr,arg::Array{Symbol};platform::String="cpu",nChange_=false)
    
    varDeclare = []
    fdeclare = []
    execute = []
    begining = []
    
    if length(agentModel.declaredSymb["var"])>0
        
        comArgs = commonArguments(agentModel)
        
        #Declare auxiliar variables
        push!(varDeclare,
            platformAdapt(
                :(v1_=@ARRAY_zeros(nMax_,$(length(agentModel.declaredSymb["var"])))),
                platform=platform
            )
            )
        
        #Make the equations
        nEqs = []
        for eq in agentModel.equations
            eq = vectParams(agentModel,eq)
            lIn = [Meta.parse(string("d",i)) for i in agentModel.declaredSymb["var"]]
            lOut = [Meta.parse(string("v1_[ic1_,$j]")) for (j,i) in enumerate(agentModel.declaredSymb["var"])]
            for (i,j) in zip(lIn,lOut)
                subs(eq,i,j)
            end
            push!(nEqs,eq)
        end
        #Make the update
        update = [Meta.parse(string("v_[ic1_,$j]+=v1_[ic1_,$j]")) for (j,i) in enumerate(agentModel.declaredSymb["var"])]
        push!(fdeclare,
        platformAdapt(
        :(
        function integratorStep_($(comArgs...),v1_)
        @INFUNCTION_ for ic1_ in index_:stride_:N
            $(nEqs...)
            $(update...)
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
        @INFUNCTION_ for ic1_ in index_:stride_:N
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
        :(begin
        @OUTFUNCTION_ interUpdate_($(comArgs...),$(arg...))
        @OUTFUNCTION_ integratorStep_($(comArgs...),v1_)
        end
        ),platform=platform)
        )

        #Begining
        push!(begining,
        platformAdapt(
        :(
        @OUTFUNCTION_ interUpdate_($(comArgs...),$(arg...))
        ),platform=platform)
        )

    end        

    return varDeclare, fdeclare, execute, begining
end