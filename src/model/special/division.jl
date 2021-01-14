"""
    struct DivisionProcess <: Special

Struct containing the conditions for the division process.
"""
struct DivisionProcess <: Special
    condition::Expr
    update::Expr
end

"""
    function addDivision!(agentModel::Model, condition::String, update::String; randVar = Tuple{Symbol,String}[])

Function that adds a division process of the particles to the model. Cells divide under condition and update the new parameters with update.

Examples
```
m = Model();
addLocal!(m,[:g,:tDiv]); #Add two local variables, g and the time of division tDiv

condition = 
"
tDiv < t
"

update =
"
g₁ = gₚ*r #Asymmetric split of the component between the two daughter particles
g₁ = tDivₚ+1.

g₂ = gₚ*(1-r)
g₂ = tDivₚ+1.
"

addDivision!(m,condition,update,randVar=[(:r,"Uniform",0.,1.)])
```
"""
function addDivision!(agentModel::Model, condition::String, update::String; randVar = Tuple{Symbol,String}[])

    #Check is a division process already exists
    if DivisionProcess in [typeof(i) for i in agentModel.special]
        error("A division process is already present in the model. Only one division process can exist in the model.")
    end

    condition = Meta.parse(condition)
    update = Meta.parse(string("begin ", update, " end"))

    #Add tags to cells if not added
    addIfNot!(agentModel.declaredIds, [:id_,:parent_])
    #Check random variables
    checkRandDeclared(agentModel, randVar)
    
    append!(agentModel.declaredRandSymb["locRand"],randVar)
    push!(agentModel.special,DivisionProcess(condition,update))
    
    return
end

"""
    function divisionCompile(division::DivisionProcess,agentModel::Model; platform::String) 
"""
function divisionCompile(division::DivisionProcess,agentModel::Model; platform::String)
    
    comArgs = commonArguments(agentModel)
    cond = division.condition
    update = division.update
    
    varDeclare = Expr[]
    fDeclare = Expr[]
    execute = Expr[]
        
    if  platform == "cpu"
        #Declare variables
        varDeclare = [
        platformAdapt(
            :(divList_ = @ARRAY_zeros(Int,nMax_)),
                platform=platform)
        ]

        #Declare functions
        aux = []
        for ic2_ in 1:length(agentModel.declaredSymb["loc"])
            push!(aux,:(loc_[nnic2_,$ic2_] = loc_[ic1_,$ic2_]))
        end
        for ic2_ in 1:length(agentModel.declaredIds)
            push!(aux,:(ids_[nnic2_,$ic2_] = ids_[ic1_,$ic2_]))
        end
        push!(fDeclare,
            platformAdapt(
            vectParams(agentModel,:(
            function addDiv_($(comArgs...),divList_)
                lockDiv_ = Threads.SpinLock()
                divN_ = 0
                #Check division cells
                Threads.@threads for ic1_ in 1:N
                    if $cond
                        lock(lockDiv_)
                        divN_ += 1
                        divList_[divN_] = ic1_
                        unlock(lockDiv_)
                    end
                end
                #Make divisions
                if divN_ > 0
                    #Check if there is space
                    if N_+divN_>nMax_
                        error("In the next division there will be more cells than allocated cells. Evolve again with a higher nMax_.")
                    end
    
                    Threads.@threads for ic1_ in 1:divN_
                        
                        nnic2_ = N+ic1_
                        ic1_ = divList_[ic1_]

                        $(aux...)

                        $update

                        parent_₂ = id_₁
                        parent_₁ = id_₁
                        id_₂ = N_+ic1_
                        id_₁ = N_+ic1_+divN_
                    end
                    N += divN_
                end
                                
                return N
            end
            )), platform=platform)
            ) 

        #Execute
        push!(execute,
            platformAdapt(
            vectParams(agentModel,:(
                N = addDiv_($(comArgs...),divList_)
            )), platform=platform)
            )
        
    elseif platform == "gpu"
        
        #Declare variables
        varDeclare = [
        platformAdapt(
            :(divList_ = @ARRAY_zeros(Int,nMax_)),
                platform=platform),
        platformAdapt(
            :(divN_ = @ARRAY_zeros(Int,1)),
                platform=platform)
        ]

        #Declare functions
        
        push!(fDeclare,
            platformAdapt(
            vectParams(agentModel,:(
            function addDiv1_($(comArgs...),divList_,divN_)

                index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
                stride_ = blockDim().x * gridDim().x                

                #Check division cells
                for ic1_ in index_:stride_:N
                    if $cond
                        divN = CUDA.atomic_add!(pointer(divN_,1),1)
                        divList_[divN] = ic1_
                    end
                end

                return
            end
            )), platform=platform)
            ) 

        aux = []
        for ic2_ in 1:length(agentModel.declaredSymb["loc"])
            push!(aux,:(loc_[nnic2_,$ic2_] = loc_[ic1_,$ic2_]))
        end
        for ic2_ in 1:length(agentModel.declaredIds)
            push!(aux,:(ids_[nnic2_,$ic2_] = ids_[ic1_,$ic2_]))
        end
        push!(fDeclare,
            platformAdapt(
            vectParams(agentModel,:(
            function addDiv2_($(comArgs...),divList_,divN_)

                index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
                stride_ = blockDim().x * gridDim().x                

                #Check division cells
                for ic1_ in index_:stride_:divN_
        
                    nnic2_ = N+ic1_
                    ic1_ = divList_[ic1_]

                    $(aux...)

                    $update
        
                    parent_₂ = id_₁
                    parent_₁ = id_₁
                    id_₂ = N+ic1_
                    id_₁ = N+ic1_+divN_
                end

                return nothing
            end
            )), platform=platform)
            ) 

        #Execute
        push!(execute,
            platformAdapt(
            vectParams(agentModel,:(
            begin
                divN_ = @ARRAY_ones(Int,1)
                @OUTFUNCTION_ addDiv1_($(comArgs...),divList_,divN_)
                divN = Array(divN_)[1]-1
                if N+divN > nMax_
                    error("In the next division there will be more cells than allocated cells. Evolve again with a higher nMax_.")
                elseif divN > 0
                    @OUTFUNCTION_ addDiv2_($(comArgs...),divList_,divN)
                    N += divN
                end
            end
            )), platform=platform)
            )
    end
    
    return varDeclare,fDeclare,execute
end