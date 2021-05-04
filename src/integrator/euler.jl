"""
Adaptation to the Euler integrator in Îto prescription.

```math
x(t+Δt) = x(t) + f(x(t),t)*Δt + g(x(t),t)ΔW
```
where ``ΔW`` is a Wiener process with step proportional to ``Δt^{1/2}``.

# Arguments 
 - **agentModel** (Model) Agent Model
 - **inLoop** (Expr) Block of code that will be included in the integration step.
 - **arg** (Array{Symbol} Additional arguments to include from the neighborhood.

# Optatiove keywork arguments 
 - **platform** (String) Platform to be adapted the algorithm. "cpu" by default
"""
function integratorEuler(agentModel::Model,inLoop::Expr,arg::Array{Symbol};platform::String="cpu")
    
    varDeclare = []
    fdeclare = []
    execute = []
    begining = []
    
    if length(agentModel.declaredSymb["var"])>0
        
        comArgs = commonArguments(agentModel)
        eq = copy(agentModel.equations)
        eq, nRand = splitEqs(eq)

        #Declare auxiliar variables
        push!(varDeclare,
            platformAdapt(
                :(v1_=@ARRAY_zeros(nMax_,$(length(agentModel.declaredSymb["var"])))),
                platform=platform
            )
            )
        kargs = [:(v1_)]
        if nRand != []
            push!(varDeclare,
                platformAdapt(
                    :(W_=@ARRAY_zeros(nMax_,$(length(nRand)))),
                    platform=platform
                )
                )      
            push!(kargs,:(W_))
        end
        #Make the equations
        eq = vectParams(agentModel,eq)
        lIn = [Meta.parse(string("d",i)) for i in agentModel.declaredSymb["var"]]
        lOut = [Meta.parse(string("v1_[ic1_,$j]")) for (j,i) in enumerate(agentModel.declaredSymb["var"])]
        for (i,j) in zip(lIn,lOut)
            subs(eq,i,j)
        end
        counter = 1
        for i in nRand
            subs(eq.args[i],:(dW),:(W_[ic1_,$counter])) 
            counter += 1
        end

        #Make the update
        update = [Meta.parse(string("v_[ic1_,$j]+=v1_[ic1_,$j]")) for (j,i) in enumerate(agentModel.declaredSymb["var"])]
        push!(fdeclare,
        platformAdapt(
        :(
        function integratorStep_($(comArgs...),$(kargs...))
        @INFUNCTION_ for ic1_ in index_:stride_:N
            $eq
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
        for i in 1:length(agentModel.declaredSymb["inter"])
            push!(reset,:(inter_[ic1_,$i]=0.))
        end
        push!(fdeclare,
        platformAdapt(
        :(
        function interUpdate_($(comArgs...),$(arg...))
        @INFUNCTION_ for ic1_ in index_:stride_:N
            #$(reset...)
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
        begin
            inter_ .= 0.
            @OUTFUNCTION_ interUpdate_($(comArgs...),$(arg...))
        end)
        ,platform=platform)
        )
        if nRand != []
            push!(execute,
            platformAdapt(
            :(
            W_ = sqrt(dt).*randn!(W_)
            ),platform=platform)
            )
        end
        push!(execute,
        platformAdapt(
        :(
        @OUTFUNCTION_ integratorStep_($(comArgs...),$(kargs...))
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