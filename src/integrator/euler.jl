"""
    function integratorEuler_(abm, space, p, platform)

Adapter for the Euler integration step method.

```math
x(t+Δt) = x(t) + a*Δt +b*ΔW
```
"""
function addIntegratorEuler_!(abm::Agent, space::SimulationFree, p::Program_, platform::String)
    
    if !emptyquote_(abm.declaredUpdates["Equation"])
        
        code = abm.declaredUpdates["Equation"]

        code = MacroTools.postwalk(x -> @capture(x,dW) ? :(randn()) : x, code)

        for (i,j) in enumerate(abm.declaredSymbols["Variable"])
            s = Meta.parse(string(j,"̇"))
            code = MacroTools.postwalk(x -> @capture(x,$s=v__) ? :($j = $j + $(v...)) : x, code)
            vectorize_(abm,code,update="Copy")
        end

        f = simpleFirstLoopWrapInFunction_(platform,:integrationStep_,code)

        push!(p.declareF.args,f)
        push!(p.execInloop.args,:(integrationStep_(ARGS_)))

    end
        
    return
end