function platformRandomAdapt!(execute::Array{Expr}, agentModel::Model, randVars::String , platform="cpu")

    comArgs = commonArguments(agentModel,random=false)    
    
    if length(agentModel.declaredRandSymb[randVars])>0

        if platform == "cpu"
                        
            for pdf in values(agentModel.declaredRandSymb[randVars])
                push!(execute,
                    platformAdapt(
                        :(rand!($(pdf[2]),$(Meta.parse(string(pdf[1],"_")))))
                    ,platform=platform)
                )
            end        

        elseif platform == "gpu"
            
            for (name,pdf) in values(agentModel.declaredRandSymb[randVars])
                dist = gpuDist(name,pdf)
                push!(execute,
                    platformAdapt(
                        dist
                    ,platform=platform)
                )
            end        

        else
            error("Not a valid platform.")
        end
    end

    if randVars == "glob"
        if length(agentModel.declaredRandSymbArrays[randVars])>0

            if platform == "cpu"
                            
                for pdf in values(agentModel.declaredRandSymbArrays[randVars])
                    push!(execute,
                        platformAdapt(
                            :(rand!($(pdf[2]),$(Meta.parse(string(pdf[1][1],"_")))))
                        ,platform=platform)
                    )
                end        

            elseif platform == "gpu"
                
                for (name,pdf) in values(agentModel.declaredRandSymbArrays[randVars])
                    dist = gpuDist(name[1],pdf)
                    push!(execute,
                        platformAdapt(
                            dist
                        ,platform=platform)
                    )
                end        

            else
                error("Not a valid platform.")
            end
        end
    end
    
    return
end

function gpuDist(pos,pdf)

    pdf = eval(pdf)
    type = typeof(pdf)
    pos = Meta.parse(string(pos,"_"))

    if type <: Uniform
        return :($pos = $(pdf.b-pdf.a) .*CUDA.rand!($pos) .+ $(pdf.a))
    elseif type <: Normal
        return :($pos = CUDA.randn!($pos).*$(pdf.σ) .+ $(pdf.μ))
    else
        error("Distribution ",type," has not been implemented (yet) for gpu.")
    end
end