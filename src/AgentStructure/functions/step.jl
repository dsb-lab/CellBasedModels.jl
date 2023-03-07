"""
    function step!(community)

Executes all the step functions and updates the parameters a single time.

 1. `interactionStep!(community)`
 2. `integrationStep!(community)`
 3. `integrationMediumStep!(community)`
 4. `localStep!(community)`
 5. `globalStep!(community)`
 6. `update!(community)`

"""
function step!(community)

    interactionStep!(community)
    integrationStep!(community)
    integrationMediumStep!(community)
    localStep!(community)
    globalStep!(community)
    update!(community)
    computeNeighbors!(community)

end

"""
    function evolve!(community;steps,saveEach=1,saveFunction=saveRAM!,saveCurrentState=false,preallocateAgents=0)

Performs `step` number of steps on the community, saving each `saveEach` number of steps the community instance using the saving function provided in `saveFunction` (See IO). 
If `saveCurrentState` is true, the present instance is saved.

`preallocateAgents` is an integer to sent to the `loadToPlatform!` function that allocates empty space for agents if the model has to grow. The maximum number of agents in the final simulation has to be specified in here.
"""
function evolve!(community;steps,saveEach=1,saveFunction=saveRAM!,saveCurrentState=false,preallocateAgents=0)

    loadToPlatform!(community,preallocateAgents=preallocateAgents)
    if saveCurrentState
        saveFunction(community)
    end
    for i in 1:steps
        step!(community)
        if i % saveEach == 0
            saveFunction(community)
        end
    end
    bringFromPlatform!(community)

end