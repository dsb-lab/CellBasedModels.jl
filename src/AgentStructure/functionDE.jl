function DifferentialEquations.step!(a::Nothing,b=0,c=0)
    return 
end

#######################################################################################################
# Convert the equations
#######################################################################################################
"""
    function agentDEFunction(com)

Creates the final code provided to Agent in `updateVariable` as a function and adds it to the Agent.
"""
function functionDE(com,scope,type)

    ref = addSymbol(scope,type)

    abm = com.abm
    if !isemptyupdaterule(abm,ref)

        unwrap = quote end
        for (sym,prop) in pairs(abm.parameters)
            if prop.variable
                pos = prop.pos
                dsym = addSymbol("dt__",sym)
                push!(unwrap.args, :(@views $dsym = dVar_[$pos,:]))
                push!(unwrap.args, :(@views $sym = var_[$pos,:]))
            end
        end
        params = agentArgs(com)
        paramsRemove = Tuple([sym for (sym,prop) in pairs(abm.parameters) if prop.variable])
        params = Tuple([i for i in params if !(i in paramsRemove)])

        #Get deterministic function
        code = abm.declaredUpdates[ref]
        for sym in keys(abm.parameters)
            dsym = addSymbol("dt__",sym)
            code = postwalk(x->@capture(x,dt(s_)) && s == sym ? :($dsym[i1_]) : x, code)
        end
        code = vectorize(code,com)
        if scope == :agent
            code = vectorizeMediumInAgents(code,com)
        end

        if ! contains(string(code),"@loopOverAgents")
            code = makeSimpleLoop(code,com)
        end

        if typeof(com.platform) <: CPU
            abm.declaredUpdatesCode[ref] = 
                quote
                    function (dVar_,var_,p_,t_)
                        ($(params...),) = p_
                        $unwrap
                        $code
                        return
                    end
                end
        else
            tpos = (0,0)
            if scope == :agent
                tpos = (5,4)
            elseif scope == :model
                tpos = (3,2)
            elseif scope == :medium
                tpos = (1,0)
            end        
            abm.declaredUpdatesCode[ref] = 
                quote
                    function (dVar_,var_,p_,t_)
                        function kernel(dVar_,var_,$(params...))
                            $unwrap
                            $code
                        end
                        @cuda threads=p_[end-$(tpos[1])] blocks=p_[end-$(tpos[2])] kernel(dVar_,var_,p_...)

                        return
                    end
                end
        end
        abm.declaredUpdatesFunction[ref] = Main.eval(abm.declaredUpdatesCode[ref])
    else
        abm.declaredUpdatesFunction[ref] = Main.eval(:((a,b,c,d) -> nothing))
    end

    return

end

"""
    function agentStepDE!(community)

Function that computes a integration step of the community a time step `dt` using the defined Integrator defined in Agent.
"""
function agentStepDE!(community)

    checkLoaded(community)

    AgentBasedModels.DifferentialEquations.step!(community.agentDEProblem,community.dt,true)

    return 

end

"""
    function modelStepDE!(community)

Function that computes a integration step of the community a time step `dt` using the defined Integrator defined in Agent.
"""
function modelStepDE!(community)

    checkLoaded(community)

    AgentBasedModels.DifferentialEquations.step!(community.modelDEProblem,community.dt,true)

    return 

end

"""
    function mediumStepDE!(community)

Function that computes a integration step of the community a time step `dt` using the defined Integrator defined in Agent.
"""
function mediumStepDE!(community)

    checkLoaded(community)

    AgentBasedModels.DifferentialEquations.step!(community.mediumDEProblem,community.dt,true)

    return 

end