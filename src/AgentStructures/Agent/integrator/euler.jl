"""
    function addIntegratorEuler_!(p::Agent)

Adapts the code declared in `UpdateVariable` to be integrated as the Euler method and adds the code generated to `Agent`.

```math
x(t+Δt) = x(t) + a*Δt +b*ΔW
```

# Args
 - **p::Agent**:  CompiledAgent structure containing all the created code when compiling.

# Returns
 -  Nothing
"""
function addIntegratorEuler!(p::Agent)
    
    if "UpdateVariable" in keys(p.agent.declaredUpdates)

        #Create integration function
        p.CompiledAgentintegration = createFunction(p.agent.declaredUpdates["UpdateVariable"])
        #Create integration step function
        args = giveArgs(p,auxiliarIntegration=0,giveAllArgs=false)
        p.CompiledAgentintegration_step = 
            :(function (com)
                    @platformAdapt p.f_integration($(args...))

                    return
                end
            )
            p.CompiledAgentintegration_step = platformAdapt(p,p.CompiledAgentintegration_step)

        p.f_integration = Main.eval(p.CompiledAgentintegration)
        p.f_integration_step = Main.eval(p.CompiledAgentintegration_step)

    end
        
    return
end

#Struct
Euler = Integrator(
    [
        [:dt,:localV,:localVCopy]
    ],
    [],
    addIntegratorEuler!
)