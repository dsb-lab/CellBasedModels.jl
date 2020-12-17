function compile(agentModel::Model;platform="cpu",neighborhood="full",
    neighborhoodCondition="",nnVariables=[],radius=1.,boxSize=[],
    integrator="euler",saveRAM = false)
varDeclarations = []
fDeclarations = []
execute = []

#Parameter declare
neighborhoodFound = false
for i in keys(NEIGHBORHOODS)
    if neighborhood==i
        var,f,exec, inLoop, arg = NEIGHBORHOODS[i](agentModel,platform=platform)
        append!(varDeclarations,var)
        append!(fDeclarations,f)
        append!(execute,exec)
        neighborhoodFound = true
    end
end
if !neighborhoodFound
    error("No neigborhood called ", neighborhood,".")
end

#Integrator
for i in keys(INTEGRATORS)
    if integrator==i
        var,f,exec = INTEGRATORS[i](agentModel,neighborhood=neighborhood,platform=platform)
        integratorFound = true
    end
end
for i in keys(INTEGRATORSSDE)
    if integrator==i
        var,f,exec = INTEGRATORSSDE[i](agentModel,neighborhood=neighborhood,platform=platform)
        integratorFound = true
    end
end
if !integratorFound
    error("No integrator called ", integrator,".")
end

append!(varDeclarations,var)
append!(fDeclarations,f)
append!(execute,exec)

var,f,execNN = NEIGHBOURS[string(typeof(agentModel.neighbourhood))](agentModel,neighborhoodCondition,platform=platform)
append!(varDeclarations,var)
append!(fDeclarations,f)
append!(execute,execNN)    

#Saving
if saveRAM
    var,f,execSave = inRAMSave(agentModel)
    append!(varDeclarations,var)
    append!(fDeclarations,f)  
    ret=[:(commRAM_)]
else
    execSave = []
    ret=[:Nothing]
end

return :(
function evolve(com::Community;tMax_,dt_,t_=com.t_,N_=com.N_,nMax_=com.N_, neighMax_=nMax_,tSave_=0.,tSaveStep_=dt_,threads_=256)
    #Declaration of variables
    $(varDeclarations...)
    #Declaration of functions
    $(fDeclarations...)
        
    #println(CUDA.memory_status())
    
    #Execution of the program
    $(execNN...)
    while t_ <= tMax_
        nBlocks_ = min(round(Int,N_/threads_),2560)
        if nBlocks_ == 0
            nBlocks_ = 1
        end
        #println(nBlocks_)
        $(execute...)
            
        t_ += dt_
            
        $(execSave...)
    end
        
    #CUDA.unsafe_free!(loc_)
    #CUDA.unsafe_free!(locInter_)
    #CUDA.unsafe_free!(nnN_)
    #CUDA.unsafe_free!(nnList_)
        
    return $(ret...)
end
)
end