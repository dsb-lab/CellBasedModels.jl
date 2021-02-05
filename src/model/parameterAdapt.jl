"""
    function parameterAdapt(agentModel::Model,inLoop,arg;platform::String="cpu",nChange_=false)

Function that returns the pieces of the final compiling code for the parameters adapted to the corresponding platform:  

  * arrays to declare containg the parameters declared
  * functions for parameter updates
  * execution lines

Parameters:

  * *agentModel* : Model structure
  * *inLoop* : Code of the interaction local to be adapted depending on the neighbborhood
  * *arg* : Additional arguments required by the functions
  * *platform* : Platform to be adapted ("cpu" or "gpu")
  * *nChange_* : FILL THE GAP
"""
function parameterAdapt(agentModel::Model,inLoop,arg;platform::String="cpu",nChange_=false)

    varDeclarations = Expr[]
    fDeclarations = Expr[]
    execute = Expr[]
    begining = Expr[]
    
    #Parameter declare
    if length(agentModel.declaredSymb["var"])>0
        push!(varDeclarations, 
            platformAdapt(:(v_ = @ARRAYEMPTY_(com.var)),platform=platform ) )
        push!(varDeclarations, 
            platformAdapt(
                :(v_ = [v_;@ARRAY_zeros(nMax_-size(com.var)[1],$(length(agentModel.declaredSymb["var"])))]),platform=platform ) 
        )
    end
    if length(agentModel.declaredSymb["loc"])>0
        push!(varDeclarations, 
            platformAdapt(:(loc_ = @ARRAYEMPTY_(com.loc)),platform=platform ) )
        push!(varDeclarations, 
            platformAdapt(
                :(loc_ = [loc_;@ARRAY_zeros(nMax_-size(com.loc)[1],$(length(agentModel.declaredSymb["loc"])))]),platform=platform )
            ) 
    end
    if length(agentModel.declaredSymb["inter"])>0
        push!(varDeclarations, 
            platformAdapt(
                :(inter_ = @ARRAY_zeros(nMax_,$(length(agentModel.declaredSymb["inter"])))),platform=platform ) 
        )
    end
    if length(agentModel.declaredSymb["locInter"])>0
        push!(varDeclarations, 
            platformAdapt(
                :(locInter_ = @ARRAY_zeros(nMax_,$(length(agentModel.declaredSymb["locInter"])))),platform=platform ) 
        )
    end
    if length(agentModel.declaredSymb["glob"])>0
        push!(varDeclarations, 
            platformAdapt(:(glob_ = @ARRAYEMPTY_(com.glob)),platform=platform ) )
    end
    if length(agentModel.declaredRandSymb["locRand"])>0
        for i in agentModel.declaredRandSymb["locRand"]
            push!(varDeclarations, 
                platformAdapt(
                    :($(Meta.parse(string(i[1],"_"))) = @ARRAY_zeros(nMax_))
                ,platform=platform ) 
            )
        end
    end
    if length(agentModel.declaredRandSymb["locInterRand"])>0
        for i in agentModel.declaredRandSymb["locInterRand"]
            push!(varDeclarations, 
                platformAdapt(
                    :($(Meta.parse(string(i[1],"_"))) = @ARRAY_zeros(nMax_,nMax_))
                ,platform=platform ) 
            )
        end
    end
    if length(agentModel.declaredRandSymb["globRand"])>0
        for i in agentModel.declaredRandSymb["globRand"]
            push!(varDeclarations, 
                platformAdapt(
                    :($(Meta.parse(string(i[1],"_"))) = @ARRAY_zeros(1))
                ,platform=platform ) 
            )
        end
    end
    if length(agentModel.declaredRandSymb["varRand"])>0
        for i in agentModel.declaredRandSymb["varRand"]
            push!(varDeclarations, 
                platformAdapt(
                    :($(Meta.parse(string(i[1],"_"))) = @ARRAY_zeros(nMax_))
                ,platform=platform ) 
            )
        end
    end
    if length(agentModel.declaredIds)>0
        push!(varDeclarations, 
            platformAdapt(:(ids_ = @ARRAYEMPTYINT_(com.ids)),platform=platform ) )
        push!(varDeclarations, 
            platformAdapt(
                :(ids_ = [ids_;@ARRAY_zeros(Int,nMax_-size(com.ids)[1],$(length(agentModel.declaredIds)))]),platform=platform )
            ) 
    end
    
    #Function declare######################################################
    comArgs = commonArguments(agentModel)
    #Make the locInter
    if length(agentModel.locInter) > 0 
        locInter = [string(i,"\n") for i in vectParams(agentModel,deepcopy(agentModel.locInter))]
        inLoop = Meta.parse(replace(string(inLoop),"ALGORITHMS_"=>"$(locInter...)"))
        inLoop = NEIGHBORHOODADAPT[typeof(agentModel.neighborhood)](inLoop)   

        reset = []
        for i in 1:length(agentModel.declaredSymb["locInter"])
            push!(reset,:(locInter_[ic1_,$i]=0))
        end
        push!(fDeclarations,
        platformAdapt(
        :(
        function locInterStep_($(comArgs...),$(arg...))
            @INFUNCTION_ for ic1_ in index_:stride_:N
                $(reset...)
                $inLoop    
            end
            return
        end
        ),platform=platform)
        )
    end
    
    #Make loc
    if length(agentModel.loc)>0
        loc = vectParams(agentModel,deepcopy(agentModel.loc))
        push!(fDeclarations,
        platformAdapt(
        :(
        function locStep_($(comArgs...))
        @INFUNCTION_ for ic1_ in index_:stride_:N
            $(loc...)
        end
        return
        end),platform=platform)
        )
    end

    #Make glob
    if length(agentModel.glob)>0
        glob = vectParams(agentModel,deepcopy(agentModel.glob))
        push!(fDeclarations,
        platformAdapt(
        :(
        function globStep_($(comArgs...))
        @INFUNCTION_ for ic1_ in index_:stride_:1
            $(glob...)
        end
        return
        end),platform=platform)
        )
    end
    
    #Execute##############################################
    
    #Add interLoc
    platformRandomAdapt!(execute,agentModel,"locInterRand",platform,nChange_)
    if length(agentModel.locInter)>0
        push!(execute,
        platformAdapt(
        :(@OUTFUNCTION_ locInterStep_($(comArgs...),$(arg...)))
        ,platform=platform)
        )
        push!(begining,
        platformAdapt(
        :(@OUTFUNCTION_ locInterStep_($(comArgs...),$(arg...)))
        ,platform=platform)
        )
    end
    #Add loc
    platformRandomAdapt!(execute,agentModel,"locRand",platform,nChange_)
    if length(agentModel.loc)>0
        push!(execute,
        platformAdapt(
        :(@OUTFUNCTION_ locStep_($(comArgs...)))
        ,platform=platform)
        )
    end
    #Add glob
    platformRandomAdapt!(execute,agentModel,"globRand",platform,nChange_)
    if length(agentModel.glob)>0
        push!(execute,
        platformAdapt(
        :(@OUTFUNCTION_ globStep_($(comArgs...)))
        ,platform=platform)
        )
    end
    
    return varDeclarations, fDeclarations, execute, begining
    
end