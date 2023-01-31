#######################################################################################################
# Get the equations
#######################################################################################################
function addToList(x,agent;type)

    if type == :Deterministic

        sym = [i for i in keys(agent.declaredVariables)][end]
        if agent.declaredVariables[sym].deterministic != 0
            error("Deterministic term dt(  ) has been defined more than one for variable $sym." )
        end
        agent.declaredVariables[sym].deterministic = x
        agent.declaredVariables[sym].positiondt = sum([j.positiondt > 0 for (i,j) in pairs(agent.declaredVariables)]) + 1

    elseif type == :Stochastic 

        sym = [i for i in keys(agent.declaredVariables)][end]
        if agent.declaredVariables[sym].stochastic != 0
            error("Stochastic term dW(  ) has been defined more than one for variable $sym." )
        elseif !INTEGRATOR[agent.integrator].stochasticImplemented
            error("Stochastic integration has not been implemented for this method." )
        end
        agent.declaredVariables[sym].stochastic = x
        agent.declaredVariables[sym].positiondW = sum([j.positiondW > 0 for (i,j) in pairs(agent.declaredVariables)]) + 1

    end

    return x

end

function getEquation(sym,code,agent)

    if sym in POSITIONPARAMETERS[end:-1:agent.dims+1]

        error("Position parameter $sym not existing for a model with $(agent.dims) dimensions.")

    elseif sym in keys(agent.declaredSymbols)

        if agent.declaredSymbols[sym].scope != :Local
            error("Only parameters that are local can be defined as variables.")
        elseif sym in keys(agent.declaredVariables)
            error("Equation for symbol $sym has been defined more than once.")
        end

    end

    agent.declaredVariables[sym] = Equation(0,0,0,0,0)
    agent.declaredVariables[sym].position = length(keys(agent.declaredVariables))

    code = postwalk(x->@capture(x,dt(m_)) ? addToList(m,agent,type=:Deterministic) : x, code)
    code = postwalk(x->@capture(x,dW(m_)) ? addToList(m,agent,type=:Stochastic) : x, code)

    return code

end

function getEquations!(agent)

    code = agent.declaredUpdates[:UpdateVariable]

    code = postwalk(x->@capture(x,d(s_)=g_) ? getEquation(s,g,agent) : x, code)

    return

end

#######################################################################################################
# Convert the equations
#######################################################################################################
function integratorFunction(agent)

    integ = INTEGRATOR[agent.integrator]

    for i in 1:integ.length

        #Get code
        code = agent.declaredUpdates[:UpdateVariable]
        #Clean variables in the first loop
        if i == 1
            cleanCode = quote end
            for (sym,eq) in pairs(agent.declaredVariables)
                push!(cleanCode.args,
                    :($sym.new = 0)
                )
            end
            push!(cleanCode.args,code)
            code = cleanCode
        end

        #Substitute equations
        for (sym,eq) in pairs(agent.declaredVariables)

            #Substitute variables according to step in Buthcer table
            terms = []
            for (cd) in [:deterministic, :stochastic]

                codeEq = getfield(eq,cd)
                for (sym2,eq2) in pairs(agent.declaredVariables) #Vectorize with the appropiate weights for each time point
                    if i == 1 #For the first weight use the original positions
                        s = :($sym2)
                    else #For the rest use the new positions positions
                        s = :(varAux_[i1_,$(getfield(eq2,:position)),$(i-1)])
                    end

                    codeEq = postwalk(x->@capture(x,g_) && g==sym2 ? s : x, codeEq)
                end
                
                push!(terms,:($codeEq))

            end

            sub = quote end
            sNew = :()
            for j in i:integ.length
                if j == 1 #For the first weight use the original positions
                    s = :($sym)
                else #For the rest use the new positions positions
                    s = :(varAux_[i1_,$(getfield(eq,:position)),$i])
                end

                sNew = :(varAux_[i1_,$(getfield(eq,:position)),$j])

                if j == i
                    push!(sub.args,
                        :($sNew += $sym + $(integ.weight[j][i]) * ($(terms[1])*dt + $(terms[2])*varAuxΔW_[i1_,$(getfield(eq,:positiondW)),$j]*sqrt(dt)))
                    )
                else
                    push!(sub.args,
                        :($sNew += $(integ.weight[j][i]) * ($(terms[1])*dt + $(terms[2])*varAuxΔW_[i1_,$(getfield(eq,:positiondW)),$j]*sqrt(dt)))
                    )
                end
            end
            push!(sub.args,
                :($sym.new = varAux_[i1_,$(getfield(eq,:position)),$i])
            )

            code = postwalk(x->@capture(x,d(s_)=g_) && s == sym ? sub : x, code) 
            code = clean(code)

        end

        code = vectorize(code,agent)
        # println(prettify(code))
        code = makeSimpleLoop(code,agent)

        s = Meta.parse("IntegratorStep$(i)_")
        agent.declaredUpdatesCode[s] = 
            quote
                function ($(agentArgs()...),)

                    $code

                    return
                end
            end

        agent.declaredUpdatesFunction[s] = Main.eval(agent.declaredUpdatesCode[s])
    end

    #Make series of steps if more than a step is performed
    auxs = quote end
    for i in 1:integ.length
        s = Meta.parse("community.agent.declaredUpdatesFunction[:IntegratorStep$(i)_]")
        aux = addCuda(:( $s( $(agentArgs(:community)...), ) ),agent) #Add code to execute kernel in cuda if GPU
        push!(auxs.args, aux)
    end

    #Clean auxiliar variables
    cleanCode = quote
        @views community.varAux_[1:community.N[1],:,:] .= 0
        if length(community.varAuxΔW_) > 0
            @views AgentBasedModels.randn!(community.varAuxΔW_[1:community.N[1],:,:])
        end
    end
    if agent.platform == :GPU
        cleanCode = quote
            community.varAux_ .= 0
            if length(community.varAuxΔW_) > 0
                AgentBasedModels.randn!(community.varAuxΔW_)
            end
        end
    end

    #Put all together
    agent.declaredUpdatesCode[:IntegratorStep] = 
    quote
        function (community,)
            $cleanCode
            $auxs
            return
        end
    end
    agent.declaredUpdatesFunction[:IntegratorStep] = Main.eval(agent.declaredUpdatesCode[:IntegratorStep])
        
    return

end

function integrationStep!(community)

    checkLoaded(community)

    community.agent.declaredUpdatesFunction[:IntegratorStep](community)

    return 

end