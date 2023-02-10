"""
    function step!(community)

Executes all the step functions and updates the parameters a single time.

 1. `interactionStep!(community)`
 2. `integrationStep!(community)`
 3. `localStep!(community)`
 4. `globalStep!(community)`
 5. `update!(community)`

"""
function step!(community)

    interactionStep!(community)
    integrationStep!(community)
    localStep!(community)
    globalStep!(community)
    update!(community)

end