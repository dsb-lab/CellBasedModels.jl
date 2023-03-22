#######################################################################################################
# Convert the equations
#######################################################################################################
"""
    function integrator2Function(agent)

Creates the final code provided to Agent in `updateVariable` as a function and adds it to the Agent.
"""
function integrator2Function(agent)

    if [i for i in prettify(agent.declaredUpdates[:UpdateVariableDeterministic]).args if typeof(i) != LineNumberNode] != [] || 
        [i for i in prettify(agent.declaredUpdates[:UpdateVariableStochastic]).args if typeof(i) != LineNumberNode] != []

        unwrap = quote end
        for (sym,prop) in pairs(agent.parameters)
            if prop.variable
                pos = prop.pos
                dsym = Meta.parse(string(sym,"__"))
                push!(unwrap.args, :(@views $dsym = dVar_[$pos,:]))
                push!(unwrap.args, :(@views $sym = var_[$pos,:]))
            end
        end
        # params = Tuple([sym for (sym,prop) in pairs(agent.parameters) if !(prop.variable)])
        params = agentArgs(agent)
        paramsRemove = Tuple([sym for (sym,prop) in pairs(agent.parameters) if (prop.variable)])
        params = Tuple([i for i in params if !(i in paramsRemove)])

        #Get deterministic function
        code = agent.declaredUpdates[:UpdateVariableDeterministic]
        for sym in keys(agent.parameters)
            dsym = Meta.parse(string(sym,"__"))
            code = postwalk(x->@capture(x,dt(s_)) && s == sym ? :($dsym[i1_]) : x, code)
        end
        code = vectorize(code,agent)

        code = makeSimpleLoop(code,agent)
        agent.declaredUpdatesCode[:IntegratorODE] = 
            quote
                function (dVar_,var_,p_,t_)
                    ($(params...),) = p_
                    $unwrap
                    $code
                    return
                end
            end
        agent.declaredUpdatesFunction[:IntegratorODE] = Main.eval(agent.declaredUpdatesCode[:IntegratorODE])

        #Get deterministic function
        code = agent.declaredUpdates[:UpdateVariableStochastic]
        for sym in keys(agent.parameters)
            dsym = Meta.parse(string(sym,"__"))
            code = postwalk(x->@capture(x,dt(s_)) && s == sym ? :($dsym[i1_]) : x, code)
        end
        code = vectorize(code,agent)

        code = makeSimpleLoop(code,agent)
        agent.declaredUpdatesCode[:IntegratorSDE] = 
            quote
                function (dVar,var,p,t)
                    ($(params...),) = p
                    $unwrap
                    $code
                    return
                end
            end
        agent.declaredUpdatesFunction[:IntegratorSDE] = Main.eval(agent.declaredUpdatesCode[:IntegratorSDE])

        #Put all together
        agent.declaredUpdatesCode[:IntegratorStep] = 
        quote
            function (community,)
                
                CUDA.@allowscalar AgentBasedModels.DifferentialEquations.step!(community.deProblem,community.dt[1],true)

                return
            end
        end
        agent.declaredUpdatesFunction[:IntegratorStep] = Main.eval(agent.declaredUpdatesCode[:IntegratorStep])
    else
        agent.declaredUpdatesFunction[:IntegratorStep] = Main.eval(:((community) -> nothing))
    end

    return

end

"""
    function integrationStep!(community)

Function that computes a integration step of the community a time step `dt` using the defined Integrator defined in Agent.
"""
function integrationStep!(community)

    checkLoaded(community)

    community.agent.declaredUpdatesFunction[:IntegratorStep](community)

    return 

end