function platformAdapt(text::String;platform)
    if platform == "cpu"
        text = replace(text,"@INFUNCTION_"=>CPUINFUNCTION)
        text = replace(text,"index_"=>"1")
        text = replace(text,"stride_"=>"1")
        text = replace(text,"@OUTFUNCTION_"=>CPUOUTFUNCTION)
        text = replace(text,"@ARRAY_"=>CPUARRAY)
        text = replace(text,"@ARRAYEMPTY_"=>CPUARRAYEMPTY)
    elseif platform == "gpu"
        text = replace(text,"@INFUNCTION_"=>GPUINFUNCTION)
        text = replace(text,"@OUTFUNCTION_"=>GPUOUTFUNCTION)
        text = replace(text,"@ARRAY_"=>GPUARRAY)
        text = replace(text,"@ARRAYEMPTY_"=>GPUARRAYEMPTY)
    else
        error("""Platform has to be "cpu" of "gpu" """)
    end
    
    a = Meta.parse(text)
    
    if platform == "gpu"
        subs(a,:^,:(CUDA.pow))
    end
    
    return string(a)
end

function platformAdapt(text::Expr;platform="cpu")
    text = string(text)
    text = platformAdapt(text,platform=platform)
        
    return Meta.parse(text)
end

function platformAdapt(text::Array{String};platform="cpu")

    for i in 1:length(text)
        text[i] = platformAdapt(text[i],platform=platform)
    end
    
    return text
end

function platformAdapt(text::Array{Expr};platform="cpu")

    for i in 1:length(text)
        text[i] = platformAdapt(text[i],platform=platform)
    end
    
    return text
end