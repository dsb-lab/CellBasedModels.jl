function DifferentialEquations.step!(a::Nothing,b=0,c=0)
    return 
end

#######################################################################################################
# Convert the equations
#######################################################################################################
"""
    function functionDE(abm,scope,type)

Creates the final code for Differential Equation functions to be provided to DifferentialEquations.ODEProblem. `scope` is between `agent`, `model` and `medium`, `type` `SDE` or `ODE`.
"""
function functionDE(abm,scope,type)

    ref = addSymbol(scope,type)

    if !isemptyupdaterule(abm,ref)

        unwrap = quote end
        for (sym,prop) in pairs(abm.parameters)
            if prop.variable
                pos = prop.pos
                dsym = addSymbol("dt__",sym)
                if prop.scope == :agent && scope == :agent
                    push!(unwrap.args, :(@views $dsym = dVar_[$pos,:]))
                    push!(unwrap.args, :(@views $sym = var_[$pos,:]))
                    push!(unwrap.args, :(@views $(new(sym)) = var_[$pos,:]))
                elseif prop.scope == :model && scope == :model
                    push!(unwrap.args, :(@views $dsym = dVar_[$pos:$pos]))
                    push!(unwrap.args, :(@views $sym = var_[$pos:$pos]))
                    push!(unwrap.args, :(@views $(new(sym)) = var_[$pos,:]))
                elseif prop.scope == :medium && scope == :medium
                    if abm.dims == 1
                        push!(unwrap.args, :(@views $dsym = dVar_[$pos,:]))
                        push!(unwrap.args, :(@views $sym = var_[$pos,:]))
                        push!(unwrap.args, :(@views $(new(sym)) = var_[$pos,:]))
                    elseif abm.dims == 2
                        push!(unwrap.args, :(@views $dsym = dVar_[$pos,:,:]))
                        push!(unwrap.args, :(@views $sym = var_[$pos,:,:]))
                        push!(unwrap.args, :(@views $(new(sym)) = var_[$pos,:,:]))
                    elseif abm.dims == 3
                        push!(unwrap.args, :(@views $dsym = dVar_[$pos,:,:,:]))
                        push!(unwrap.args, :(@views $sym = var_[$pos,:,:,:]))
                        push!(unwrap.args, :(@views $(new(sym)) = var_[$pos,:,:,:]))
                    end
                end
            end
        end
        params = agentArgs(abm)
        paramsRemove = [sym for (sym,prop) in pairs(abm.parameters) if prop.variable && prop.scope == scope] #remove updates
        paramsRemove2 = [new(sym) for sym in paramsRemove if abm.parameters[sym].update] #remove news
        params = Tuple([i for i in params if !(i in [paramsRemove;paramsRemove2])])

        #Get deterministic function
        code = abm.declaredUpdates[ref]
        for sym in keys(abm.parameters)
            dsym = addSymbol("dt__",sym)
            code = postwalk(x->@capture(x,dt(s_)) && s == sym ? :($dsym[i1_]) : x, code)
        end
        code = vectorize(code,abm)
        if scope == :agent
            code = vectorizeMediumInAgents(code,abm)
        end

        if ! contains(string(code),"@loopOverAgents") && scope == :agent
            code = makeSimpleLoop(code,abm)
        elseif ! contains(string(code),"@loopOverMedium") && scope == :medium
            code = makeSimpleLoop(code,abm,nloops=abm.dims)
        end

        if typeof(abm.platform) <: CPU
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
                        function kernel(dVar_,var_,$(params[1:end-1]...))
                            $unwrap
                            $code

                            return
                        end
                        # params = $params
                        # println($(string(scope)), " ", $(length(params))," ", length(p_))
                        # println([(p,typeof(i)) for (p,i) in zip(params,p_) if !(typeof(i) <: CuArray || typeof(i) <: Number || typeof(i) <: SubArray)])
                        CUDA.@sync CUDA.@cuda threads=p_.platform.$(addSymbol(scope,"Threads")) blocks=p_.platform.$(addSymbol(scope,"Blocks")) kernel(dVar_,var_,[i for i in p_ if typeof(i) <: CuArray || typeof(i) <: Number || typeof(i) <: SubArray]...)

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