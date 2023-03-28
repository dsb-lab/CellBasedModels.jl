#######################################################################################################
# Convert the equations
#######################################################################################################
"""
    function mediumDEFunction(abm)

Creates the final code provided to ABM in `updateVariable` as a function and adds it to the ABM.
"""
function mediumDEFunction(com)

    abm = com.abm
    if isemptyupdaterule(abm,:mediumODE)

        unwrap = quote end
        for (sym,prop) in pairs(abm.parameters)
            if prop.variableMedium
                pos = prop.pos
                dsym = Meta.parse(string(sym,"__"))
                if abm.dims == 1
                    push!(unwrap.args, :(@views $dsym = dVar_[$pos,:]))
                    push!(unwrap.args, :(@views $sym = var_[$pos,:]))
                elseif abm.dims == 2
                    push!(unwrap.args, :(@views $dsym = dVar_[$pos,:,:]))
                    push!(unwrap.args, :(@views $sym = var_[$pos,:,:]))
                elseif abm.dims == 3
                    push!(unwrap.args, :(@views $dsym = dVar_[$pos,:,:,:]))
                    push!(unwrap.args, :(@views $sym = var_[$pos,:,:,:]))
                end
            end
        end
        params = agentArgs(abm)
        paramsRemove = Tuple([sym for (sym,prop) in pairs(abm.parameters) if (prop.variableMedium)])
        params = Tuple([i for i in params if !(i in paramsRemove)])

        #Get deterministic function
        code = abm.declaredUpdates[:mediumODE]
        for sym in keys(abm.parameters)
            dsym = Meta.parse(string(sym,"__"))
            code = postwalk(x->@capture(x,dt(s_)) && s == sym ? :($dsym[i1_]) : x, code)
        end
        code = vectorize(code,com)

        code = makeSimpleLoop(code,com,nloops=abm.dims)
        
        if typeof(com.platform) <: CPU
            abm.declaredUpdatesCode[:mediumODE] = 
                quote
                    function (dVar_,var_,p_,t_)
                        ($(params...),) = p_
                        $unwrap
                        $code
                        return
                    end
                end
        else
            abm.declaredUpdatesCode[:mediumODE] = 
                quote
                    function (dVar_,var_,p_,t_)
                        function kernel(dVar_,var_,$(params...))
                            $unwrap
                            $code
                        end
                        @cuda threads=(10) blocks=(1) kernel(dVar_,var_,p_...)

                        return
                    end
                end
        end
        # println((abm.declaredUpdatesCode[:mediumODE]))
        abm.declaredUpdatesFunction[:mediumODE] = Main.eval(abm.declaredUpdatesCode[:mediumODE])

        #Put all together
        abm.declaredUpdatesCode[:mediumDE] = 
        quote
            function (community,)
                
                CUDA.@allowscalar AgentBasedModels.DifferentialEquations.step!(community.deProblemMedium,community.dt[1],true)

                return

            end
        end
        abm.declaredUpdatesFunction[:mediumDE] = Main.eval(abm.declaredUpdatesCode[:mediumDE])
    else
        abm.declaredUpdatesFunction[:mediumDE] = Main.eval(:((community) -> nothing))
    end

    return

end

"""
    function mediumStepDE!(community)

Function that computes a integration step of the community a time step `dt` using the defined Integrator defined in ABM.
"""
function mediumStepDE!(community)

    checkLoaded(community)

    community.abm.declaredUpdatesFunction[:mediumDE](community)

    return 

end