function compile(agentModel::Model;platform="cpu",
    integrator="euler",saveRAM = false)
varDeclarations = []
fDeclarations = []
execute = []

#Neighbours declare
if typeof(agentModel.neighborhood) in keys(NEIGHBOURS)
    var,f,execNN, inLoop, arg = NEIGHBOURS[typeof(agentModel.neighborhood)](agentModel,platform=platform)
    append!(varDeclarations,var)
    append!(fDeclarations,f)
    append!(execute,execNN)
else
    error("No neigborhood called ", agentModel.neighborhood,".")
end

#Parameter declare
var,f,exec = parameterAdapt(agentModel,inLoop,arg,platform=platform)
append!(varDeclarations,var)
append!(fDeclarations,f)
append!(execute,exec)

#Integrator
if integrator in keys(INTEGRATORS)
    var,f,exec = INTEGRATORS[integrator](agentModel,inLoop,arg,platform=platform)
    append!(varDeclarations,var)
    append!(fDeclarations,f)
    append!(execute,exec)        
elseif integrator in keys(INTEGRATORSSDE)
    var,f,exec = INTEGRATORSSDE[integrator](agentModel,inLoop,arg,platform=platform)
    integratorFound = true
    append!(varDeclarations,var)
    append!(fDeclarations,f)
    append!(execute,exec)
else
    error("No integrator called ", integrator,".")
end

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

program = :(
function evolve(com::Community;tMax_,dt_,t_=com.t_,N_=com.N_,nMax_=com.N_, neighMax_=nMax_,tSave_=0.,tSaveStep_=dt_,threads_=256)
    #Declaration of variables
    $(varDeclarations...)
    #Declaration of functions
    $(fDeclarations...)
        
    #println(CUDA.memory_status())
    
    #Execution of the program
    nBlocks_ = min(round(Int,N_/threads_),2560)
    if nBlocks_ == 0
        nBlocks_ = 1
    end
    
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

agentModel.evolve = eval(program)

return program

end