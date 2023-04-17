"""
    function agentStepRule!(community)

Function that computes a local step of the community a time step `dt`.
"""
function agentStepRule!(community)

    checkLoaded(community)

    community.abm.declaredUpdatesFunction[:agentRule](community)

    return 

end

"""
    function agentStepRule!(community)

Function that computes a local step of the community a time step `dt`.
"""
function modelStepRule!(community)

    checkLoaded(community)

    community.abm.declaredUpdatesFunction[:modelRule](community)

    return 

end

"""
    function agentStepRule!(community)

Function that computes a local step of the community a time step `dt`.
"""
function mediumStepRule!(community)

    checkLoaded(community)

    community.abm.declaredUpdatesFunction[:mediumRule](community)

    return 

end

"""
    function agentStepDE!(community)

Function that computes a integration step of the community a time step `dt` using the defined Integrator defined in Agent.
"""
function agentStepDE!(community)

    checkLoaded(community)

    CellBasedModels.DifferentialEquations.step!(community.agentDEProblem,community.dt,true)

    return 

end

"""
    function modelStepDE!(community)

Function that computes a integration step of the community a time step `dt` using the defined Integrator defined in Agent.
"""
function modelStepDE!(community)

    checkLoaded(community)

    CellBasedModels.DifferentialEquations.step!(community.modelDEProblem,community.dt,true)

    return 

end

"""
    function mediumStepDE!(community)

Function that computes a integration step of the community a time step `dt` using the defined Integrator defined in Agent.
"""
function mediumStepDE!(community)

    checkLoaded(community)

    CellBasedModels.DifferentialEquations.step!(community.mediumDEProblem,community.dt,true)

    return 

end

"""
    function step!(community)

Executes all the possible step functions and updates the parameters a single time.
"""
function step!(community)

    agentStepRule!(community)
    agentStepDE!(community)
    mediumStepRule!(community)
    mediumStepDE!(community)
    modelStepRule!(community)
    modelStepDE!(community)
    update!(community)
    computeNeighbors!(community)

end

"""
    function evolve!(community;
        steps,saveEach=1,
        saveToFile=false,fileName=nothing,overwrite=false,
        saveCurrentState=false,
        preallocateAgents=0,
        progressMessage=(com)->nothing)

Performs `step` number of steps on the community, saving each `saveEach` number of steps the community instance using the saving function provided in `saveFunction` (See IO). 
If `saveCurrentState` is true, the present instance is saved.

`preallocateAgents` is an integer to sent to the `loadToPlatform!` function that allocates empty space for agents if the model has to grow. The maximum number of agents in the final simulation has to be specified in here.

`progressMessage` is a function that is executed every time we save an step and can be used to print some information of progress.
"""
function evolve!(community;
    steps,saveEach=1,
    saveToFile=false,fileName=nothing,overwrite=false,
    saveCurrentState=false,
    preallocateAgents=0,
    progressMessage=(com)->nothing)

    if saveToFile && fileName === nothing
        error("Key argument fileName has to be specified with a valid name.")
    end

    loadToPlatform!(community,preallocateAgents=preallocateAgents)
    if saveCurrentState
        if saveToFile
            saveJLD2(fileName,community,overwrite=overwrite)
        else
            saveRAM!(community)
        end
    end
    for i in 1:steps
        step!(community)
        if i % saveEach == 0
            progressMessage(community)
            if saveToFile
                saveJLD2(fileName,community,overwrite=overwrite)
            else
                saveRAM!(community)
            end
        end
    end
    bringFromPlatform!(community)

end