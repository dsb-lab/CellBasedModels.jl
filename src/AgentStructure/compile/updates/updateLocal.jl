"""
    function addUpdateLocal_!(p::Agent)

Generate the functions with the code declared in `UpdateLocal` and adds the code generated to `Agent`.

# Args
 - **p::Agent**:  Agent structure containing all the created code when compiling.

# Returns
 -  Nothing
"""
function addUpdateLocal!(abm::Agent)

    if :UpdateLocal in keys(abm.declaredUpdates)

        code = createFunction(abm.declaredUpdates[:UpdateLocal],abm,orderInteraction=1)

        #Special functions that can be interpreted
        #addAgent()
        codeFull = addEventAddAgent(codeFull,p)
        #removeAgent()
        codeFull = addEventRemoveAgent(codeFull,p)

        abm.declaredUpdatesCode[:UpdateLocal] = code
        abm.declaredUpdatesFunction[:UpdateLocal] = Main.eval(code)

    end

    return nothing
end