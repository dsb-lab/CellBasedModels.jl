#######################################################################################################
# Convert the equations
#######################################################################################################
"""
    function agentDEFunction(com)

Creates the final code provided to Agent in `updateVariable` as a function and adds it to the Agent.
"""
function agentDEFunction(com)

    abm = com.abm
    if isemptyupdaterule(abm,:agentODE) || isemptyupdaterule(abm,:agentSDE)

        unwrap = quote end
        for (sym,prop) in pairs(abm.parameters)
            if prop.variable
                pos = prop.pos
                dsym = Meta.parse(string(sym,"__"))
                push!(unwrap.args, :(@views $dsym = dVar_[$pos,:]))
                push!(unwrap.args, :(@views $sym = var_[$pos,:]))
            end
        end
        params = agentArgs(com)
        paramsRemove = Tuple([sym for (sym,prop) in pairs(abm.parameters) if (prop.variable)])
        params = Tuple([i for i in params if !(i in paramsRemove)])

        #Get deterministic function
        code = abm.declaredUpdates[:agentODE]
        for sym in keys(abm.parameters)
            dsym = Meta.parse(string(sym,"__"))
            code = postwalk(x->@capture(x,dt(s_)) && s == sym ? :($dsym[i1_]) : x, code)
        end
        code = vectorize(code,com)

        if ! contains(string(code),"@loopOverAgents")
            code = makeSimpleLoop(code,com)
        end

        if typeof(com.platform) <: CPU
            abm.declaredUpdatesCode[:agentODE] = 
                quote
                    function (dVar_,var_,p_,t_)
                        ($(params...),) = p_
                        $unwrap
                        $code
                        return
                    end
                end
        else
            abm.declaredUpdatesCode[:agentODE] = 
                quote
                    function (dVar_,var_,p_,t_)
                        function kernel(dVar_,var_,$(params...))
                            $unwrap
                            $code
                        end
                        @cuda threads=p_[end-1] blocks=p_[end] kernel(dVar_,var_,p_...)

                        return
                    end
                end
        end
        abm.declaredUpdatesFunction[:agentODE] = Main.eval(abm.declaredUpdatesCode[:agentODE])

        #Get stochastic function
        code = abm.declaredUpdates[:agentSDE]
        for sym in keys(abm.parameters)
            dsym = Meta.parse(string(sym,"__"))
            code = postwalk(x->@capture(x,dt(s_)) && s == sym ? :($dsym[i1_]) : x, code)
        end
        code = vectorize(code,com)

        if ! contains(string(code),"@loopOverAgents")
            code = makeSimpleLoop(code,com)
        end

        if typeof(com.platform) <: CPU
            abm.declaredUpdatesCode[:agentSDE] = 
                quote
                    function (dVar_,var_,p_,t_)
                        ($(params...),) = p_
                        $unwrap
                        $code
                        return
                    end
                end
        else
            abm.declaredUpdatesCode[:agentSDE] = 
                quote
                    function (dVar_,var_,p_,t_)
                        function kernel(dVar_,var_,$(params...))
                            $unwrap
                            $code
                        end
                        @cuda threads=p_[end-1] blocks=p_[end] kernel(dVar_,var_,p_...)

                        return
                    end
                end
        end
        abm.declaredUpdatesFunction[:agentSDE] = Main.eval(abm.declaredUpdatesCode[:agentSDE])

        #Put all together
        abm.declaredUpdatesCode[:agentDE] = 
        quote
            function (community,)
                
                CUDA.@allowscalar AgentBasedModels.DifferentialEquations.step!(community.deProblem,community.dt[1],true)

                return
            end
        end
        abm.declaredUpdatesFunction[:agentDE] = Main.eval(abm.declaredUpdatesCode[:agentDE])
    else
        abm.declaredUpdatesFunction[:agentDE] = Main.eval(:((community) -> nothing))
    end

    return

end

"""
    function agentStepDE!(community)

Function that computes a integration step of the community a time step `dt` using the defined Integrator defined in Agent.
"""
function agentStepDE!(community)

    checkLoaded(community)

    community.abm.declaredUpdatesFunction[:agentDE](community)

    return 

end