"""
    struct DivisionProcess <: Special

Struct containing the conditions for the division process.
"""
struct DivisionProcess <: Special
    condition::Expr
    update::Array{Expr}
end

"""
    function addDivisionProcess!(agentModel::Model, condition::String, update::String; randVar = Tuple{Symbol,String}[])

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

addDivisionProcess!(m,condition,update,randVar=[(:r,"Uniform",0.,1.)])
```
"""
function addDivisionProcess!(agentModel::Model, condition::String, update::String; randVar = Tuple{Symbol,String}[])
    
    updateL = splitUpdating(update)

    #Add id tag to cells if not added
    if !(:id_ in agentModel.declaredIds)
        push!(agentModel.declaredIds,:id_)
    end 
    #Add parent tag to cells if not added
    if !(:parent_ in agentModel.declaredIds)
        push!(agentModel.declaredIds,:parent_)
    end 

    for (pos,rule) in enumerate(updateL)
        s = Meta.parse(rule).args[1]
        if !occursin("_aux",string(s)) #Check that is not an auxiliar variable
            if string(s)[end] in ['₁','ₚ'] #Check problematic declarations
                for i in pos+1:length(updateL)
                    s = Meta.parse(string(string(s)[1:end-1],"₁"))
                    if findSymbol(updateL[i],s)
                        error("Parameter ", Meta.parse(string(string(s)[1:end-1],"₁")), "/", Meta.parse(string(string(s)[1:end-1],"ₚ")), " has been updated and afterwards used. Parent and Daugther 1 share the same memory space in order to make the division process more efficient. Please, add the updating rules in an order that prevents overwriting already updated parameters. If it is impossible, declare an auxiliary parameter using the notation NAMEOFPARAMETER_aux.")
                    end
                    s = Meta.parse(string(string(s)[1:end-1],"ₚ"))
                    if findSymbol(updateL[i],s)
                        error("Parameter ", Meta.parse(string(string(s)[1:end-1],"₁")), "/", Meta.parse(string(string(s)[1:end-1],"ₚ")), " has been updated and afterwards used. Parent and Daugther 1 share the same memory space in order to make the division process more efficient. Please, add the updating rules in an order that prevents overwriting already updated parameters. If it is impossible, declare an auxiliary parameter using the notation NAMEOFPARAMETER_aux.")
                    end
                end
            end
        end
    end
    
    push!(agentModel.special,DivisionProcess(Meta.parse(condition),[Meta.parse(i) for i in updateL]))
    
    return
end

"""
    function divisionCompile(agentModel::Model, platform::String, varDeclaredAll::Array{Expr})
"""
function divisionCompile(agentModel::Model, platform::String, varDeclaredAll::Array{Expr})
    
    varD = [i.args[1] for i in varDeclaredAll]
    
    comArgs = commonArguments(agentModel)
    cond = vectParams(agentModel, agentModel.division[1])
    update = vectParams(agentModel, agentModel.division[2])
    
    varDeclare = Expr[]
    fDeclare = Expr[]
    execute = Expr[]
        
    if  platform == "cpu"
        #Declare variables
        varDeclare = [
        platformAdapt(
            :(divList_ = @ARRAY_zeros(Int,nMax_)),
                platform=platform),
            :(divN_ = 0)
        ]
        push!(varD,:(divList_))
        
        #Make preallocation
        add = []
        for i in varD
            push!(add,
                :($i = [$i;@ARRAY_zeros(nAddBatch_,size($i)[2:end]...)])
            )
        end
        push!(add, :(nMax_+=nAddBatch))

        #Declare functions
        push!(fDeclare,
            platformAdapt(
            :(
            function addDiv_($(comArgs...),ic1_,nnic2_,devList_)
                $(update...)
                return
            end
            ), platform=platform)
            ) 

        #Execute
        push!(fDeclare,
            platformAdapt(
            :(begin
            
            lockDiv_ = Threads.SpinLock()
            divN_ = 0
            #Check division cells
            Threads.@threads for ic1_ in 1:N_
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
                while N_+divN_>nMax_
                    warn("Reneed to allocate. The agent based model has run out of preallocated memory in the number of particles. If this message appears many times, it may indicate a source of slowing the program. Possible solutions are starting the simulator with more preallocated particles (nMax_), or to increase the increase batch (nAddBatch_).")
                    $(add...)
                end

                Threads.@threads for ic1_ in 1:divN_
                    addDiv_($(comArgs...),divList_[ic1_],N_+ic1_,devList_)
                end
                N_ += divN_
            end
                        
            end
            ), platform=platform)
            ) 
        
    elseif platform == "gpu"
        
        update = subs(update,:nnic2_,:(divCum_[ic1_]))
        
        #Declare variables
        varDeclare = [
        platformAdapt(
            :(divCond_ = @ARRAY_zeros(Int,nMax_)),
                platform=platform),
        platformAdapt(
            :(divCum_ = @ARRAY_zeros(Int,nMax_)),
                platform=platform),
            :(nDiv_ = 0)
        ]    
        append!(varD,[:(divCond_),:(divCum_)])

        #Make preallocation
        add = []
        for i in varD
            push!(add,
                :($i = [$i;@ARRAY_zeros(nAddBatch_,size($i)[2:end]...)])
            )
        end
        push!(add, :(nMax_+=nAddBatch))
        
        #Declare functions
        push!(fDeclare,
            platformAdapt(
            :(
            function divCondition_($(comArgs...),divCond_)
                @INFUNCTION_ for ic1_ in index_:stride_:N_
                    if $cond
                        divCond_[ic1_] = 1
                    end
                end
                return
            end
            ), platform=platform)
            )
        push!(fDeclare,
            platformAdapt(
            :(
            function addDiv_($(comArgs...),divCond_,divCum_)
                @INFUNCTION_ for ic1_ in index_:stride_:N_
                    if divCond_[ic1_] == 1
                        $(update...)
                    end
                end
                return
            end
            ), platform=platform)
            )

        #Execute
        push!(execute,
            platformAdapt(
            :(begin
            divCond_ .= 0
            @OUTFUNCTION_ divCondition_($(comArgs...),divCond_)
            nDiv_ = sum(divCond_)
            if nDiv_ > 0
                #Check
                #Check if there is space
                while N_+divN_>nMax_
                    warn("Reneed to allocate. The agent based model has run out of preallocated memory in the number of particles. If this message appears many times, it may indicate a source of slowing the program. Possible solutions are starting the simulator with more preallocated particles (nMax_), or to increase the increase batch (nAddBatch_).")
                    $(add...)
                end
                divCum_ = cumsum(divCond_)
                @OUTFUNCTION_ addDiv_($(comArgs...),divCond_,divSum_)
            end
            end
            ), platform=platform)
            )
    end
    
    return varDeclare,fDeclare,execute
end