function countdW(code)
    x = gensym()
    code = postwalk(x->@capture(x,dW) ? gensym() : x, code)
    y = gensym()
    
    return Meta.parse(string(split(string(y),"#")[end]))-Meta.parse(string(split(string(x),"#")[end]))-1
end

function substitutedW(code;sym=:K1_)
    x = gensym()
    code = postwalk(x->@capture(x,dW) ? gensym() : x, code)
    y = gensym()
    d = Meta.parse(string(split(string(y),"#")[end]))-Meta.parse(string(split(string(x),"#")[end]))
    for i in 1:d
        for j in ["#","##","###","####","#####","######"]
            s = Symbol(string(j,Meta.parse(string(split(string(x),"#")[end]))+i))
            code = postwalk(x->@capture(x,g_) && g == s ? :(sqrt(dt)*$sym[ic1_,$i]) : x, code)
        end
    end
    code
end

"""
    function addIntegratorHeun_!(p::AgentCompiled)

Adapts the code declared in `UpdateVariable` to be integrated as the Heun method and adds the code generated to `AgentCompiled`.

```math
K₁ = f(x(t),t)Δt + g(x(t),t)ΔW
```
```math
K₂ = f(x(t)+K₁,t+Δt)Δt + g(x(t)+K₁,t+Δt)ΔW
```
```math
x(t+Δt) = x(t) + (K₁+K₂)/2
```
where ``ΔW`` is a Wiener process with step proportional to ``Δt^{1/2}``. The integration considers the SDE Stratonovich.

# Args
 - **p::AgentCompiled**:  AgentCompiled structure containing all the created code when compiling.

# Returns
 -  Nothing
"""
function addIntegratorHeun!(p::AgentCompiled)
    
    if "UpdateVariable" in keys(p.agent.declaredUpdates)

        #Create integration function
        p.program_integration = createFunction(p.agent.declaredUpdates["UpdateVariable"])
        #Create integration step function
            #Arguments first step
        args = giveArgs(p,auxiliarIntegration=(1,2),giveAllArgs=false)
            #Arguments second step
        args2 = giveArgs(p,auxiliarIntegration=(2,2),giveAllArgs=false)
            #Compute interaction
            
            #Make function
        p.program_integration_step = 
            :(function (com)
                    @platformAdapt p.f_integration($(args...))
                    @platformAdapt p.f_integration($(args2...))

                    return
                end
            )
            p.program_integration_step = platformAdapt(p,p.program_integration_step)

        p.f_integration = Main.eval(p.program_integration)
        p.f_integration_step = Main.eval(p.program_integration_step)

    end
        
    return
end

Heun = Integrator(
    [
        [:dt,:localV,:variableStep1]
        [:dt,:localV,:variableStep1]
    ],
    [:variableStep1],
    addIntegratorHeun!
)