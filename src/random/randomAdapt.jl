function platformRandomAdapt!(execute::Array{Expr}, agentModel::Model, randVars::String , platform="cpu", nChange_=false)

    comArgs = commonArguments(agentModel,random=false)    
    
    if length(agentModel.declaredRandSymb[randVars])>0

        if platform == "cpu" && nChange_ == false 
            
            push!(execute,
                platformAdapt(
                :(rand!($(Meta.parse(string(randVars,"_")))))
                ,platform=platform)
            )
            
            if randVars == "locRand"
                for (pos,pdf) in enumerate(values(agentModel.declaredRandSymb[randVars]))
                    push!(execute,
                        platformAdapt(
                            :($(Meta.parse(string(pdf[2],"2_!")))($(Meta.parse(string(randVars,"_"))), $(pdf[3:end]...),$pos,N_))
                        ,platform=platform)
                    )
                end        
            elseif randVars == "locInterRand"
                for (pos,pdf) in enumerate(values(agentModel.declaredRandSymb[randVars]))
                    push!(execute,
                        platformAdapt(
                            :($(Meta.parse(string(pdf[2],"3_!")))($(Meta.parse(string(randVars,"_"))), $(pdf[3:end]...),$pos,N_,nnMax_))
                        ,platform=platform)
                    )
                end        
            elseif randVars == "globRand"
                for (pos,pdf) in enumerate(values(agentModel.declaredRandSymb[randVars]))
                    push!(execute,
                        platformAdapt(
                            :($(Meta.parse(string(pdf[2],"1_!")))($(Meta.parse(string(randVars,"_"))), $(pdf[3:end]...),$pos))
                        ,platform=platform)
                    )
                end        
            end

        elseif platform == "cpu" && nChange_ == true

            if randVars == "locRand"
                push!(execute,
                    platformAdapt(
                    :(rand!(view(locRand_,N_,:)))
                    ,platform=platform)
                )
                for (pos,pdf) in enumerate(values(agentModel.declaredRandSymb[randVars]))
                    push!(execute,
                        platformAdapt(
                            :($(Meta.parse(string(pdf[2],"2_!")))($(Meta.parse(string(randVars,"_"))), $(pdf[3:end]...),$pos,N_))
                        ,platform=platform)
                    )
                end        
            elseif randVars == "locInterRand"
                push!(execute,
                    platformAdapt(
                    :(rand!(view(locInterRand_,N_,:,:)))
                    ,platform=platform)
                )
                for (pos,pdf) in enumerate(values(agentModel.declaredRandSymb[randVars]))
                    push!(execute,
                        platformAdapt(
                            :($(Meta.parse(string(pdf[2],"3_!")))($(Meta.parse(string(randVars,"_"))), $(pdf[3:end]...),$pos,N_,nnMax_))
                        ,platform=platform)
                    )
                end        
            elseif randVars == "globRand"
                push!(execute,
                    platformAdapt(
                    :(rand!(glob_))
                    ,platform=platform)
                )
                for (pos,pdf) in enumerate(values(agentModel.declaredRandSymb[randVars]))
                    push!(execute,
                        platformAdapt(
                            :($(Meta.parse(string(pdf[2],"1_!")))($(Meta.parse(string(randVars,"_"))), $(pdf[3:end]...),$pos))
                        ,platform=platform)
                    )
                end        
            end

        elseif platform == "gpu"
            
            push!(execute,
                platformAdapt(
                :(rand!($(Meta.parse(string(randVars,"_")))))
                ,platform=platform)
            )
            
            if randVars == "locRand"
                for (pos,pdf) in enumerate(values(agentModel.declaredRandSymb[randVars]))
                    push!(execute,
                        platformAdapt(
                            :(CUDA.@cuda threads = threads_ blocks = nBlocks_ $(Meta.parse(string(pdf[2],"2CUDA_!")))($(Meta.parse(string(randVars,"_"))), $(pdf[3:end]...),$pos,N_))
                        ,platform=platform)
                    )
                end        
            elseif randVars == "locInterRand"
                for (pos,pdf) in enumerate(values(agentModel.declaredRandSymb[randVars]))
                    push!(execute,
                        platformAdapt(
                            :(CUDA.@cuda threads = threads_ blocks = nBlocks_ $(Meta.parse(string(pdf[2],"3CUDA_!")))($(Meta.parse(string(randVars,"_"))), $(pdf[3:end]...),$pos,N_,nnMax_))
                        ,platform=platform)
                    )
                end        
            elseif randVars == "globRand"
                for (pos,pdf) in enumerate(values(agentModel.declaredRandSymb[randVars]))
                    push!(execute,
                        platformAdapt(
                            :(CUDA.@cuda threads = threads_ blocks = nBlocks_ $(Meta.parse(string(pdf[2],"1CUDA_!")))($(Meta.parse(string(randVars,"_"))), $(pdf[3:end]...),$pos))
                        ,platform=platform)
                    )
                end        
            end

        else
            error("Not a valid platform.")
        end
    end
    
    return
end