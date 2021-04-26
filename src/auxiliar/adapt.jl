"""
Function to adapt block of code into the CPU of GPU platforms.

# Arguments

 - **text** (String, Expr, Array{String}, Array{Expr}) Block of code to adapt.

# Optional keyword arguments

 - **platform** (String) Platform to be adapted. Options are "cpu" (default) or "gpu".

# Returns 

Expr or Array{Expr}
"""
function platformAdapt(text::String;platform="cpu")
    if platform == "cpu"
        text = replace(text,"@INFUNCTION_"=>CPUINFUNCTION)
        text = replace(text,"index_"=>"1")
        text = replace(text,"stride_"=>"1")
        text = replace(text,"@OUTFUNCTION_"=>CPUOUTFUNCTION)
        text = replace(text,"@ARRAY_"=>CPUARRAY)
        text = replace(text,"@ARRAYEMPTY_"=>CPUARRAYEMPTY)
        text = replace(text,"@ARRAYEMPTYINT_"=>CPUARRAYEMPTYINT)
    elseif platform == "gpu"
        text = replace(text,"@INFUNCTION_"=>GPUINFUNCTION)
        text = replace(text,"@OUTFUNCTION_"=>GPUOUTFUNCTION)
        text = replace(text,"@ARRAY_"=>GPUARRAY)
        text = replace(text,"@ARRAYEMPTY_"=>GPUARRAYEMPTY)
        text = replace(text,"@ARRAYEMPTYINT_"=>GPUARRAYEMPTYINT)
    else
        error("""Platform has to be "cpu" of "gpu" """)
    end
    
    a = Meta.parse(text)
    
    if platform == "gpu"
        subs(a,:^,:(CUDA.pow))
    end
    
    return a
end

function platformAdapt(text::Expr;platform="cpu")
    text = string(text)
    text = platformAdapt(text,platform=platform)
        
    return text
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

"""
Function to vectorize the variables in a block of code.

# Arguments

 - **agentModel** (Model) Model that is being compiled.
 - **text** (String, Expr, Array{String}, Array{Expr}) Block(s) of code to be vectorized according to the parameters stored in the agentModel.

# Returns 

Expr or Array{Expr}
"""
function vectParams(agentModel::Model,text)
        
    #Vectorisation changes
    varsOb = ["NAME_","NAME_₁","NAME_₂","NAME_ₚ"]
    varsTar = ["v_[ic1_,POS_]","v_[ic1_,POS_]","v_[nnic2_,POS_]","v_[ic1_,POS_]"]
    text = subs(agentModel.declaredSymb["var"],varsOb,varsTar,text)
        
    interOb = ["NAME_","NAME_₁","NAME_₂","NAME_ₚ"]
    interTar = ["inter_[ic1_,POS_]","inter_[ic1_,POS_]","inter_[nnic2_,POS_]","inter_[ic1_,POS_]"]
    text = subs(agentModel.declaredSymb["inter"],interOb,interTar,text)

    locInterOb = ["NAME_","NAME_₁","NAME_₂","NAME_ₚ"]
    locInterTar = ["locInter_[ic1_,POS_]","locInter_[ic1_,POS_]","locInter_[nnic2_,POS_]","locInter_[ic1_,POS_]"]
    text = subs(agentModel.declaredSymb["locInter"],locInterOb,locInterTar,text)
    
    globOb = ["NAME_"]
    globTar = ["glob_[POS_]"]
    text = subs(agentModel.declaredSymb["glob"],globOb,globTar,text)

    locOb = ["NAME_","NAME_₁","NAME_₂","NAME_ₚ"]
    locTar = ["loc_[ic1_,POS_]","loc_[ic1_,POS_]","loc_[nnic2_,POS_]","loc_[ic1_,POS_]"]
    text = subs(agentModel.declaredSymb["loc"],locOb,locTar,text)

    for (i,j) in agentModel.declaredSymbArrays["glob"]
        ii = Meta.parse(string(i,"_"))
        text = subs(text,i,ii)
    end

    ##Random variables
    for (i,j) in agentModel.declaredRandSymb["loc"]
        ii = Meta.parse(string(i,"_"))
        text = subs(text,i,:($ii[ic1_]))
    end

    for (i,j) in agentModel.declaredRandSymb["locInter"]
        ii = Meta.parse(string(i,"_"))
        text = subs(text,i,:($ii[ic1_,ic2_]))
    end

    for (i,j) in agentModel.declaredRandSymb["glob"]
        ii = Meta.parse(string(i,"_"))
        text = subs(text,i,:($ii[1]))
    end

    for (i,j) in agentModel.declaredRandSymb["var"]
        ii = Meta.parse(string(i,"_"))
        text = subs(text,i,:($ii[ic1_]))
    end

    for i in agentModel.declaredRandSymbArrays["glob"]
        print(i[1][1])
        ii = Meta.parse(string(i[1][1],"_"))
        text = subs(text,i[1][1],ii)
    end

    ##Ids
    idsOb = ["NAME_","NAME_₁","NAME_₂","NAME_ₚ"]
    idsTar = ["ids_[ic1_,POS_]","ids_[ic1_,POS_]","ids_[nnic2_,POS_]","ids_[ic1_,POS_]"]
    text = subs(agentModel.declaredIds,idsOb,idsTar,text)

    return text
end

function vectParams(agentModel::Model,text::Array)
    textF = [] 
    for textL in text
        push!(textF,vectParams(agentModel,textL))
    end
    
    return textF
end

"""
Function that performs the vectParams, neighbourhAdapt and platformAdapt in succession.

# Arguments

 - **agentModel** (Model) Model that is being compiled.
 - **text** (String, Expr) Expression or expressions to be vectorized according to the parameters stored in the agentModel.
 - **platform** (String) Platform to be adapted. Options are "cpu" (default) or "gpu".

# Returns 

Expr
"""
function adapt(agentModel::Model, text, platform)

    #Vectorize the variables
    text = vectParams(agentModel,text)
    #Adapt the inner loops
    NEIGHBORHOODADAPT[typeof(agentModel.neighborhood)](text) 
    #Adapt to the platform
    text = platformAdapt(text,platform=platform)

    return text
end

"""
Function that pushes in a container a text after adaptation.

# Arguments

 - **container** (Array) Array where the adapted object is stored
 - **agentModel** (Model) Model that is being compiled.
 - **text** (String, Expr) Expression or expressions to be vectorized according to the parameters stored in the agentModel.
 - **platform** (String) Platform to be adapted. Options are "cpu" (default) or "gpu".

# Returns

nothing

"""
function pushAdapt!(container, agentModel::Model, platform, text)

    push!(container, adapt(agentModel, text, platform))

    return
end

