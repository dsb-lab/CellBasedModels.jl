function integratorSDEEulerIto(agentModel::Model,inLoop::Expr,arg::Array{Symbol};platform::String="cpu",nChange_=false)
    
    varDeclare = []
    fdeclare = []
    execute = []
    begining = []
    
    if length(agentModel.declaredSymb["var"])>0
        
        comArgs = commonArguments(agentModel)
        
        #Number of random variables that we require
        count = 1
        nEqs = []
        for eq in deepcopy(agentModel.equations)
            eqs = split(string(eq),"ξ_")
            eq = eqs[1]
            for i in eqs[2:end]
                eq = string(eq,"ξ_[ic1_,$count]/dt^0.5",i)
                count += 1
            end
            push!(nEqs,Meta.parse(eq))
        end

        #Declare auxiliar variables
        #Declare random array if there are random variables
        if count > 1
            varDeclare = Expr[]
            push!(varDeclare,
            platformAdapt(:(ξ_ = @ARRAY_zeros(nMax_,$(count-1))),
                platform=platform)
            )
            addArgs = [:ξ_] 
        else
            addArgs = []
        end
        
        #Make the equations
        nEqs2 = []
        for eq in nEqs
            v = string(eq.args[1])[2:end-2]
            args = string(eq.args[2])
            push!(nEqs2,string("$v += ($args)*dt"))
        end
        eqs = vectParams(agentModel,nEqs2)
        push!(fdeclare,
        platformAdapt(
        :(
        function integratorStep_($(comArgs...),$(addArgs...))
        @INFUNCTION_ for ic1_ in index_:stride_:N
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
        @INFUNCTION_ for ic1_ in index_:stride_:N
            $(reset...)
            $inLoop
        end
        return
        end
        ),platform=platform)
        )
    
        #Random initialisation depending on platform
        init = :()
        if count > 1
            if platform == "cpu" && nChange_ == false
                init = :(randn!(ξ_))
            elseif platform == "gpu"
                init = :(CUDA.randn!(ξ_))
            else
                error("Platform incorrect")
            end
        end
        #Make the declarations for the inside loop
        push!(execute,
        platformAdapt(
        :(begin
        $init
        @OUTFUNCTION_ interUpdate_($(comArgs...),$(arg...))
        @OUTFUNCTION_ integratorStep_($(comArgs...),$(addArgs...))
        end
        ),platform=platform)
        )

    end
        
    #Begining
    push!(begining,
    platformAdapt(
    :(
    @OUTFUNCTION_ interUpdate_($(comArgs...),$(arg...))
    ),platform=platform)
    )

    return varDeclare, fdeclare, execute, begining
end