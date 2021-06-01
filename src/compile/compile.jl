"""
Main function that plugs in all the declared parts of the Agent Based Model and generates an evolution function.

# Arguments
 - **agentModel** (Model) Agent Model to be compiled.

# Optative keywork arguments
 - **integrator** (String) Integrator to be implemented in the model ("euler" by default)
 - **neighborhood** (Neighbors) Neighbors structure definging the neighborhood method.
 - **saveRAM** (Bool) Indicate if the steps have to be saved in a CommunityInTime structure. False by default.
 - **saveCSV** (Bool) Indicate if the steps have to be saved in a folder as CSV files. False by default.
 - **positionsVTK** (Array{Symbols}) The declared symbols that will correspond to the VTK spatial positions. [:x,:y,:z] by default.
 - **debug** (Bool) Print the cleaned compiled function for debugging purposes. False by default.

# Returns

nothing
"""
function compile!(agentModel::Model;platform="cpu",
    integrator="euler",neighborhood=NeighborsFull(),saveRAM = false,saveCSV = false, debug = false)

varDeclarations = []
fDeclarations = []
execute = []
kArgs = []
initialisation = []

#Neighbours declare
if typeof(agentModel.neighborhood) in keys(NEIGHBOURS)
    var,f, execNN, inLoop, arg = NEIGHBOURS[typeof(agentModel.neighborhood)](agentModel,platform=platform)
    append!(varDeclarations,var)
    append!(fDeclarations,f)
    append!(execute,execNN)
else
    error("No neigborhood called ", agentModel.neighborhood,".")
end

#Parameter declare
var,f,exec,begining = parameterAdapt(agentModel,inLoop,arg,platform=platform)
append!(varDeclarations,var)
append!(fDeclarations,f)
append!(execute,exec)
append!(initialisation,begining)   

#Integrator
if integrator in keys(INTEGRATORS)
    var,f,exec,begining = INTEGRATORS[integrator](agentModel,inLoop,arg,platform=platform)
    append!(varDeclarations,var)
    append!(fDeclarations,f)
    append!(execute,exec)     
    append!(initialisation,begining)   
else
    error("No integrator called ", integrator,".")
end

#Saving
saving = false
execSaveList = []
execSaveFinal = []
if saveRAM
    var,f,exec = saveRAMCompile(agentModel)
    append!(varDeclarations,var)
    append!(fDeclarations,f)
    append!(execSaveList,exec)
    ret=[:(commRAM_)]

    saving = true
else
    var,f,exec = saveRAMCompile(agentModel)
    append!(varDeclarations,var)
    append!(fDeclarations,f)
    append!(execSaveList,exec)
    ret=[:ob]
end

if saveCSV
    var,f,exec = saveCSVCompile(agentModel,saveRAM=saveRAM)
    append!(varDeclarations,var)
    append!(fDeclarations,f)
    append!(execSaveList,exec)
    append!(kArgs,[:folder])

    saving = true
end

if saving == true
    push!(varDeclarations,:(countSave = 1))
    execSave = [:(
    if t >= tSave
        $(execSaveList...)
        tSave += tSaveStep
        countSave += 1
    end    
    )]
else
    execSave = []
end

program = :(
function (com::Community;$(kArgs...),tMax, dt, t=com.t, N=com.N, nMax=com.N, neighMax=nMax, tSave=0., tSaveStep=dt, threads_=256)
    #Declaration of variables
    $(varDeclarations...)
    #Declaration of functions
    $(fDeclarations...)
    
    #Execution of the program
    nBlocks_ = min(round(Int,N/threads_),2560)
    if nBlocks_ == 0
        nBlocks_ = 1
    end
    
    $(execNN...)
    $(initialisation...)
    $(initialisation...)
    $(execSave...)
    while t <= tMax
        nBlocks_ = min(round(Int,N/threads_),2560)
        if nBlocks_ == 0
            nBlocks_ = 1
        end
        #println(nBlocks_)
        $(execute...)

        t += dt

        $(execSave...)
    end

    $(execSaveFinal...)
        
    #CUDA.unsafe_free!(loc_)
    #CUDA.unsafe_free!(locInter_)
    #CUDA.unsafe_free!(nnN_)
    #CUDA.unsafe_free!(nnList_)
        
    return $(ret...)
end
)

if debug == true
    clean(program)
end

agentModel.evolve = Base.MainInclude.eval(program)

return

end


"""
Main function that plugs in all the declared parts of the Agent Based Model and generates an evolution function.
It is exactly the same as the compile function but it evals in the local scope of the module. Used for compilationof the predefined models of the library.

# Arguments
 - **agentModel** (Model) Agent Model to be compiled.

# Optative keywork arguments
 - **integrator** (String) Integrator to be implemented in the model ("euler" by default)
 - **saveRAM** (Bool) Indicate if the steps have to be saved in a CommunityInTime structure. False by default.
 - **saveVTK** (Bool) Indicate if the steps have to be saved in a VTK file (experimental). False by default.
 - **positionsVTK** (Array{Symbols}) The declared symbols that will correspond to the VTK spatial positions. [:x,:y,:z] by default.
 - **debug** (Bool) Print the cleaned compiled function for debugging purposes. False by default.

# Returns

nothing
"""
function precompile!(agentModel::Model;platform="cpu",
    integrator="euler",saveRAM = false,saveVTK = false,positionsVTK=[:x,:y,:z], debug = false)

varDeclarations = []
fDeclarations = []
execute = []
kArgs = []
initialisation = []

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
var,f,exec,begining = parameterAdapt(agentModel,inLoop,arg,platform=platform)
append!(varDeclarations,var)
append!(fDeclarations,f)
append!(execute,exec)
append!(initialisation,begining)   

#Integrator
if integrator in keys(INTEGRATORS)
    var,f,exec,begining = INTEGRATORS[integrator](agentModel,inLoop,arg,platform=platform)
    append!(varDeclarations,var)
    append!(fDeclarations,f)
    append!(execute,exec)     
    append!(initialisation,begining)   
else
    error("No integrator called ", integrator,".")
end

#Special functions
for special in agentModel.special
    var,f,execS,begining = SPECIAL[typeof(special)](special,agentModel,platform=platform)
    append!(varDeclarations,var)
    append!(fDeclarations,f)
    append!(execute,execS)    
    append!(initialisation,begining)   
end

#Saving
saving = false
execSaveList = []
execSaveFinal = []
if saveRAM
    var,f,exec = saveRAMCompile(agentModel)
    append!(varDeclarations,var)
    append!(fDeclarations,f)
    append!(execSaveList,exec)
    ret=[:(commRAM_)]

    saving = true
else
    execSave = []
    ret=[:Nothing]
end

if saveVTK
    var,f,exec,final,kargs = saveVTKCompile(agentModel,positionsVTK)
    append!(varDeclarations,var)
    append!(fDeclarations,f)  
    append!(execSaveList,exec)
    append!(execSaveFinal,final)
    append!(kArgs,kargs)

    saving = true
end

if saving == true
    push!(varDeclarations,:(countSave = 1))
    execSave = [:(
    if t >= tSave
        $(execSaveList...)
        tSave += tSaveStep
        countSave += 1
    end    
    )]
else
    execSave = []
end

program = :(
function (com::Community;$(kArgs...),tMax, dt, t=com.t, N=com.N, nMax=com.N, neighMax=nMax, tSave=0., tSaveStep=dt, threads_=256)
    #Declaration of variables
    $(varDeclarations...)
    #Declaration of functions
    $(fDeclarations...)
        
    #println(CUDA.memory_status())
    
    #Execution of the program
    nBlocks_ = min(round(Int,N/threads_),2560)
    if nBlocks_ == 0
        nBlocks_ = 1
    end
    
    $(execNN...)
    $(initialisation...)
    $(initialisation...)
    $(execSave...)
    while t <= tMax
        nBlocks_ = min(round(Int,N/threads_),2560)
        if nBlocks_ == 0
            nBlocks_ = 1
        end
        #println(nBlocks_)
        $(execute...)

        t += dt

        $(execSave...)
    end

    $(execSaveFinal...)
        
    #CUDA.unsafe_free!(loc_)
    #CUDA.unsafe_free!(locInter_)
    #CUDA.unsafe_free!(nnN_)
    #CUDA.unsafe_free!(nnList_)
        
    return $(ret...)
end
)

if debug == true
    clean(program)
end

agentModel.evolve = eval(program)

return

end
