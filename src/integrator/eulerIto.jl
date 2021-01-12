function integratorSDEEulerIto(agentModel::Model,inLoop::Expr,arg::Array{Symbol};platform::String="cpu",nChange_=false)
    
    varDeclare = []
    fdeclare = []
    execute = []
    
    if length(agentModel.declaredSymb["var"])>0
        
        comArgs = commonArguments(agentModel)
        
        #Number of random variables that we require
        count = 1
        nEqs = []
        for eq in deepcopy(agentModel.equations)
            eqs = split(string(eq),"ξ_")
            eq = eqs[1]
            for i in eqs[2:end]
                eq = string(eq,"ξ_[ic1_,$count]/dt_^0.5",i)
                count += 1
            end
            push!(nEqs,Meta.parse(eq))
        end

        #Error if there are not random variables
        if count <= 1
            error("Dynamical system is not stochastical, use a ODE integrator.")
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
            args = string(eq.args[2])
            push!(nEqs2,string("$v += ($args)*dt_"))
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

        #Make the functions
        inter = vectParams(agentModel,deepcopy(agentModel.inter))
        inter = NEIGHBORHOODADAPT[typeof(agentModel.neighborhood)](inter)
        inLoop = Meta.parse(replace(string(inLoop),"ALGORITHMS_"=>"$(inter...)"))

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
        @OUTFUNCTION_ interUpdate_($(comArgs...),$(arg...))
        @OUTFUNCTION_ integratorStep_($(comArgs...),ξ_)
        end
        ),platform=platform)
        )

    end
        
    return varDeclare, fdeclare, execute
end