function integratorHeun(agentModel::Model,inLoop::Expr,arg::Array{Symbol};platform::String="cpu")
    
    varDeclare = []
    fdeclare = []
    execute = []
    begining = []
    
    if length(agentModel.declaredSymb["var"])>0
        
        comArgs = commonArguments(agentModel)
        eq = copy(agentModel.equations)
        eq, nRand = splitEqs(eq)
        eq2 = copy(eq)

        #Declare auxiliar variables
        if nRand != []
            push!(varDeclare,
                platformAdapt(
                    :(begin
                        v1_=@ARRAY_zeros(nMax_,$(length(agentModel.declaredSymb["var"])))
                        v2_=@ARRAY_zeros(nMax_,$(length(agentModel.declaredSymb["var"])))
                        W_=@ARRAY_zeros(nMax_,$(length(nRand)))
                        S_=@ARRAY_zeros(nMax_,$(length(nRand)))
                        end
                            ),platform=platform
                    )
                    )      
            kargs = [:v1_,:v2_,:W_,:S_]
        else
            push!(varDeclare,
                platformAdapt(
                    :(begin
                        v1_=@ARRAY_zeros(nMax_,$(length(agentModel.declaredSymb["var"])))
                        v2_=@ARRAY_zeros(nMax_,$(length(agentModel.declaredSymb["var"])))
                        end
                            ),platform=platform
                    )
                    )      
            kargs = [:v1_,:v2_]
        end
        
        #Make the equations 1
        eq = vectParams(agentModel,eq)
        lIn = [Meta.parse(string("d",i)) for i in agentModel.declaredSymb["var"]]
        lOut = [Meta.parse(string("v1_[ic1_,$j]")) for (j,i) in enumerate(agentModel.declaredSymb["var"])]
        for (i,j) in zip(lIn,lOut)
            subs(eq,i,j)
        end
        counter = 1
        for i in nRand
            subs(eq.args[i],:(dW),:(W_[ic1_,$counter]-S_[ic1_,$counter])) 
            counter += 1
        end

        #Make the equations 2
        eq2 = vectParams(agentModel,eq2)
        subs(eq2,:v_,:v1_)
        subs(eq2,:t,:((t+dt)))
        lIn = [Meta.parse(string("d",i)) for i in agentModel.declaredSymb["var"]]
        lOut = [Meta.parse(string("v2_[ic1_,$j]")) for (j,i) in enumerate(agentModel.declaredSymb["var"])]
        for (i,j) in zip(lIn,lOut)
            subs(eq2,i,j)
        end
        counter = 1
        for i in nRand
            subs(eq2.args[i],:(dW),:(W_[ic1_,$counter]+S_[ic1_,$counter])) 
            counter += 1
        end

        
        #Make the update
        update = [Meta.parse(string("v_[ic1_,$j]+=(v1_[ic1_,$j]+v2_[ic1_,$j])/2")) for (j,i) in enumerate(agentModel.declaredSymb["var"])]
        push!(fdeclare,
        platformAdapt(
        :(
        function integratorStep_($(comArgs...),$(kargs...))
        @INFUNCTION_ for ic1_ in index_:stride_:N
            $eq
        end
        return
        end),platform=platform)
        )
        push!(fdeclare,
        platformAdapt(
        :(
        function integratorStep2_($(comArgs...),$(kargs...))
        @INFUNCTION_ for ic1_ in index_:stride_:N
            $eq2
            $(update...)
        end
        return
        end),platform=platform)
        )

        #Make the functions
        inter = [string(i,"\n") for i in vectParams(agentModel,deepcopy(agentModel.inter))]
        inLoop = Meta.parse(replace(string(inLoop),"ALGORITHMS_"=>"$(inter...)"))
        inLoop = AgentModel.NEIGHBORHOODADAPT[typeof(agentModel.neighborhood)](inLoop)
    
        reset = []
        for i in 1:length(agentModel.declaredSymb["inter"])
            push!(reset,:(inter_[ic1_,$i]=0.))
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
        inexecute = []
        if nRand != []
            inexecute =
            [:(W_ = sqrt(dt).* randn!(W_)),
            :(S_ = sqrt(dt).* round.(rand!(S_)))]
        end
        
        push!(execute,
        platformAdapt(
        :(begin
        $(inexecute...)
        @OUTFUNCTION_ interUpdate_($(comArgs...),$(arg...))
        @OUTFUNCTION_ integratorStep_($(comArgs...),$(kargs...))
        @OUTFUNCTION_ interUpdate_($(comArgs...),$(arg...))
        @OUTFUNCTION_ integratorStep2_($(comArgs...),$(kargs...))
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