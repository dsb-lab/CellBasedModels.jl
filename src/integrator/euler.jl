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

        for (i,j) in enumerate(abm.declaredSymbols["Variable"])
            s = Meta.parse(string(j,"̇"))
            code = MacroTools.postwalk(x -> @capture(x,$s=v__) ? :($j = $j + $(v...)) : x, code)
            vectorize_(abm,code,update="Copy")
        end

        f = simpleFirstLoopWrapInFunction_(platform,:integrationStep_!,code)

        if MacroTools.inexpr(code,:dW)
            push!(p.declareVar.args,:(dW = 0.)) #Declare variable for random initialisation
            push!(p.args,:dW)
            addRandInitialisation = [:(dW = rand()*dt)]
        else
            addRandInitialisation = []
        end
        push!(p.execInloop.args,
            :(begin
                $(addRandInitialisation...)
                integrationStep_!(ARGS_)
            end)
        )

        push!(p.declareF.args,f)

        updateVariables_!(abm,p)

    end
        
    return
end