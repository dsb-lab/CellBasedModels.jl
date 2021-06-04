"""
    function agentCode_!(abm::Model,space::Space,p::Program,platform::String)

Generate all the code related with the agent properties.
"""
function agentCode_!(abm::Model,space::Space,p::Program,platform::String)

    varDeclarations = Expr[]
    fDeclarations = Expr[]
    execute = Expr[]
    begining = Expr[]
    
    #Parameter declare###########################################################################

        #Float
    if length(abm.declaredSymb["var"])>0
        push!(varDeclarations, 
            platformAdapt(:(v_ = @ARRAYEMPTY_(com.var)),platform=platform ) )
        push!(varDeclarations, 
            platformAdapt(
                :(v_ = [v_;@ARRAY_zeros(nMax-size(com.var)[1],$(length(abm.declaredSymb["var"])))]),platform=platform ) 
        )
    end
    if length(abm.declaredSymb["loc"])>0
        push!(varDeclarations, 
            platformAdapt(:(loc_ = @ARRAYEMPTY_(com.loc)),platform=platform ) )
        push!(varDeclarations, 
            platformAdapt(
                :(loc_ = [loc_;@ARRAY_zeros(nMax-size(com.loc)[1],$(length(abm.declaredSymb["loc"])))]),platform=platform )
            ) 
    end
    if length(abm.declaredSymb["inter"])>0
        push!(varDeclarations, 
            platformAdapt(
                :(inter_ = @ARRAY_zeros(nMax,$(length(abm.declaredSymb["inter"])))),platform=platform ) 
        )
    end
    if length(abm.declaredSymb["locInter"])>0
        push!(varDeclarations, 
            platformAdapt(
                :(locInter_ = @ARRAY_zeros(nMax,$(length(abm.declaredSymb["locInter"])))),platform=platform ) 
        )
    end
    if length(abm.declaredSymb["glob"])>0
        push!(varDeclarations, 
            platformAdapt(:(glob_ = @ARRAYEMPTY_(com.glob)),platform=platform ) )
    end
    if length(abm.declaredSymbArrays["glob"])>0
        for (j,i) in enumerate(abm.declaredSymbArrays["glob"])
            push!(varDeclarations, 
                platformAdapt(
                    :($(Meta.parse(string(i[1],"_"))) = @ARRAY_Array(com.globArray[$j]))
                ,platform=platform ) 
            )
        end
    end
        #Ids
    if length(abm.declaredIds)>0
        push!(varDeclarations, 
            platformAdapt(:(ids_ = @ARRAYEMPTYINT_(com.ids)),platform=platform ) )
        push!(varDeclarations, 
            platformAdapt(
                :(ids_ = [ids_;@ARRAY_zeros(Int,nMax-size(com.ids)[1],$(length(abm.declaredIds)))]),platform=platform )
            ) 
    end
        #Rand
    if length(abm.declaredRandSymb["loc"])>0
        for i in abm.declaredRandSymb["loc"]
            push!(varDeclarations, 
                platformAdapt(
                    :($(Meta.parse(string(i[1],"_"))) = @ARRAY_zeros(nMax))
                ,platform=platform ) 
            )
        end
    end
    if length(abm.declaredRandSymb["locInter"])>0
        for i in abm.declaredRandSymb["locInter"]
            push!(varDeclarations, 
                platformAdapt(
                    :($(Meta.parse(string(i[1],"_"))) = @ARRAY_zeros(nMax,nMax))
                ,platform=platform ) 
            )
        end
    end
    if length(abm.declaredRandSymb["glob"])>0
        for i in abm.declaredRandSymb["glob"]
            push!(varDeclarations, 
                platformAdapt(
                    :($(Meta.parse(string(i[1],"_"))) = @ARRAY_zeros(1))
                ,platform=platform ) 
            )
        end
    end
    if length(abm.declaredRandSymb["var"])>0
        for i in abm.declaredRandSymb["var"]
            push!(varDeclarations, 
                platformAdapt(
                    :($(Meta.parse(string(i[1],"_"))) = @ARRAY_zeros(nMax))
                ,platform=platform ) 
            )
        end
    end
    if length(abm.declaredRandSymb["ids"])>0
        for i in abm.declaredRandSymb["ids"]
            push!(varDeclarations, 
                platformAdapt(
                    :($(Meta.parse(string(i[1],"_"))) = @ARRAY_zeros(nMax))
                ,platform=platform ) 
            )
        end
    end
    if length(abm.declaredRandSymbArrays["glob"])>0
        for i in abm.declaredRandSymbArrays["glob"]
            push!(varDeclarations, 
                platformAdapt(
                    :($(Meta.parse(string(i[1][1],"_"))) = @ARRAY_zeros($(i[1][2]...)))
                ,platform=platform ) 
            )
        end
    end    
    #Function declare######################################################
    comArgs = commonArguments(abm)
    #Make the locInter
    if length(abm.locInter) > 0 
        locInter = [string(i,"\n") for i in vectParams(abm,deepcopy(abm.locInter))]
        inLoop = Meta.parse(replace(string(inLoop),"ALGORITHMS_"=>"$(locInter...)"))
        inLoop = NEIGHBORHOODADAPT[typeof(abm.neighborhood)](inLoop)   

        reset = []
        for i in 1:length(abm.declaredSymb["locInter"])
            push!(reset,:(locInter_[ic1_,$i]=0))
        end
        push!(fDeclarations,
        platformAdapt(
        :(
        function locInterStep_($(comArgs...),$(arg...))
            @INFUNCTION_ for ic1_ in index_:stride_:N
                #$(reset...)
                $inLoop    
            end
            return
        end
        ),platform=platform)
        )
    end
    
    #Make loc
    if length(abm.loc)>0
        loc = vectParams(abm,deepcopy(abm.loc))
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
    if length(abm.glob)>0
        glob = vectParams(abm,deepcopy(abm.glob))
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

    #Make ids
    if length(abm.ids)>0
        ids = vectParams(abm,deepcopy(abm.ids))
        push!(fDeclarations,
        platformAdapt(
        :(
        function idsStep_($(comArgs...))
        @INFUNCTION_ for ic1_ in index_:stride_:N
            $(ids...)
        end
        return
        end),platform=platform)
        )
    end
    
    #Execute##############################################
    
    #Add interLoc
    platformRandomAdapt!(execute,abm,"locInter",platform)
    if length(abm.locInter)>0
        push!(execute,
        platformAdapt(
        :(begin
            locInter_ .= 0.
            @OUTFUNCTION_ locInterStep_($(comArgs...),$(arg...))
        end)
        ,platform=platform)
        )
        push!(begining,
        platformAdapt(
        :(begin
            locInter_ .= 0.
            @OUTFUNCTION_ locInterStep_($(comArgs...),$(arg...))
        end)
        ,platform=platform)
        )
    end
    #Add loc
    platformRandomAdapt!(execute,abm,"loc",platform)
    if length(abm.loc)>0
        push!(execute,
        platformAdapt(
        :(@OUTFUNCTION_ locStep_($(comArgs...)))
        ,platform=platform)
        )
    end
    #Add glob
    platformRandomAdapt!(execute,abm,"glob",platform)
    if length(abm.glob)>0
        push!(execute,
        platformAdapt(
        :(@OUTFUNCTION_ globStep_($(comArgs...)))
        ,platform=platform)
        )
    end
    #Add ids
    platformRandomAdapt!(execute,abm,"ids",platform)
    if length(abm.ids)>0
        push!(execute,
        platformAdapt(
        :(@OUTFUNCTION_ idsStep_($(comArgs...)))
        ,platform=platform)
        )
    end

    return varDeclarations, fDeclarations, execute, begining
    
end