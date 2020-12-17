function integratorSDEEulerIto(agentModel::Model;platform::String="cpu",neighborhood="full",nChange_=false)
    
    varDeclare = []
    fdeclare = []
    execute = []
    
    if length(agentModel.declaredSymb["var"])>0
        
        comArgs = commonArguments(agentModel)
        
        #Number of random variables that we require
        count = 1
        nEqs = []
        for eq in agentModel.equations
            eqs = split(string(eq),"ξ_")
            eq = eqs[1]
            for i in eqs[2:end]
                eq = string(eq,"ξ_[ic1_,$count]/dt_^0.5",i)
                count += 1
            end
            push!(nEqs,Meta.parse(eq))
        end

        #Declare auxiliar variables
        varDeclare = Expr[]
        push!(varDeclare,
        platformAdapt(:(ξ_ = @ARRAY_zeros(nMax_,$(count-1))),
            platform=platform)
        )
        
        #Make the equations
        nEqs2 = []
        for eq in nEqs
            v = string(eq.args[1])[2:end-2]
            arg = string(eq.args[2])
            push!(nEqs2,string("$v += ($arg)*dt_"))
        end
        eqs = vectParams(agentModel,nEqs2)
        push!(fdeclare,
        platformAdapt(
        :(
        function integratorStep_($(comArgs...),ξ_)
        @INFUNCTION_ for ic1_ in index_:stride_:N_
            $(eqs...)
        end
        return
        end),platform=platform)
        )

        #Make the update
        inter = vectParams(agentModel,agentModel.inter)
        if neighborhood == "full"
            count = :N_
            inter = subs(inter,[:nnic2_],[:N_])
        elseif neighborhood == "nn"
            count = Meta.parse("nnN_[i1_]")
            inter = subs(inter,[:nnic2_],[:(nnList_[ic1_,ic2_])])
        end
        inLoop = 
        :(
        for ic2_ in 1:$count
            $(inter...)
        end    
        )
    
        #Make the functions
        if neighborhood == "full"
            count = []
        elseif neighborhood == "nn"
            count = [Meta.parse("nnN_"),Meta.parse("nnList_")]
        end
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
    
        #Random initialisation depending on platform
        if platform == "cpu" && nChange_ == false
            init = :(randn!(ξ_))
        elseif platform == "gpu"
            init = :(CUDA.randn!(ξ_))
        else
            error("Platform incorrect")
        end
        #Make the declarations for the inside loop
        push!(execute,
        platformAdapt(
        :(begin
        $init
        @OUTFUNCTION_ integratorStep_($(comArgs...),ξ_)
        @OUTFUNCTION_ interUpdate_($(comArgs...),$(count...))
        end
        ),platform=platform)
        )
        append!(execute,agentModel.additionalInteractions)

    end
        
    return varDeclare, fdeclare, execute
end