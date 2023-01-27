#######################################################################################################
# Get the equations
#######################################################################################################
function addToList(x,agent;type)

    if type == :Deterministic

        sym = [i for i in keys(agent.declaredVariables)][end]
        if agent.declaredVariables[sym].deterministic != :nothing
            error("Deterministic term dt(  ) has been defined more than one for variable $sym." )
        end
        agent.declaredVariables[sym].deterministic = x

    elseif type == :Stochastic 

        sym = [i for i in keys(agent.declaredVariables)][end]
        if agent.declaredVariables[sym].stochastic != :nothing
            error("Stochastic term dW(  ) has been defined more than one for variable $sym." )
        end
        agent.declaredVariables[sym].stochastic = x

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

    agent.declaredVariables[sym] = Equation(0,:nothing,:nothing)
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

        code = agent.declaredUpdates[:UpdateVariable]

        for (sym,eq) in pairs(agent.declaredVariables)

            #future step
            eqcode = :()
            if i == integ.length
                eqcode = :($sym.new)
                eqcode = vectorize(eqcode,agent)
            else
                eqcode = :(varAux_[i1_,$(eq.position),$i])
            end

            #past step
            past = :($sym)
            past = vectorize(past,agent)

            #right terms
            terms = []
            for (cd,ds) in [(:deterministic,:dt), (:stochastic,:dW)]

                codeDet = getfield(eq,cd)
                if codeDet != :nothing
                    codeDet = :($(getfield(integ,ds)[i])*$codeDet) #Add time differential multiplication

                    if i == 1

                        codeDet = vectorize(codeDet,agent) #Just vectorize
                        push!(terms,codeDet)

                    else

                        for (sym2,eq2) in pairs(agent.declaredVariables) #Vectorize with the appropiate weights for each time point
                            s = :($past)
                            for (j,w) in enumerate(integ.weight[i-1])
                                if w ≈ 1.
                                    s = :($s+varAux_[i1_,$(eq2.position),$(i-1)]) 
                                elseif w ≈ 0.
                                    nothing
                                else
                                    s = :($s+$w*varAux_[i1_,$(eq2.position),$(i-1)]) 
                                end
                            end

                            codeDet = postwalk(x->@capture(x,g_) && g==sym2 ? s : x, codeDet)
                        end
                        
                        codeDet = vectorize(codeDet,agent)
                        push!(terms,codeDet)
                        
                    end
                end

            end

            if length(terms) == 1
                eqcode = :($eqcode = $(terms[1]))
            else
                eqcode = :($eqcode = $(terms[1])+$(terms[2]))
            end

            code = postwalk(x->@capture(x,d(s_)=g_) && s == sym ? eqcode : x, code)

        end

        code = vectorize(code,agent)
        code = makeSimpleLoop(code,agent)

        if integ.length == 1
            agent.declaredUpdatesCode[:IntegratorStep_] = 
            quote
                function ($(agentArgs()...),)

                    $code

                    return
                end
            end
            agent.declaredUpdatesFunction[:IntegratorStep_] = Main.eval(agent.declaredUpdatesCode[:IntegratorStep_])

            aux = addCuda(:(community.agent.declaredUpdatesFunction[:IntegratorStep_]($(agentArgs(:community)...))),agent) #Add code to execute kernel in cuda if GPU
            agent.declaredUpdatesCode[:IntegratorStep] = :(function (community)
                                                            $aux
                                                            return 
                                                        end)    
            agent.declaredUpdatesFunction[:IntegratorStep] = Main.eval(agent.declaredUpdatesCode[:IntegratorStep])
        else
            s = Meta.parse("IntegratorStep$(i)_")
                            :IntegratorStep1_
            agent.declaredUpdatesCode[s] = 
            quote
                function ($(agentArgs()...),)

                    $code

                    return
                end
            end

            println(prettify(agent.declaredUpdatesCode[s]))

            agent.declaredUpdatesFunction[s] = Main.eval(agent.declaredUpdatesCode[s])
        end

    end

    if integ.length > 1

        #Make sum of steps in final form
        code = quote end
        for (sym,eq) in pairs(agent.declaredVariables) #Vectorize with the appropiate weights for each time point

            #past step
            past = :($sym)
            past = vectorize(past,agent)

            s = :($(integ.finalWeights[1])*$sym.new)
            for (j,w) in enumerate(integ.finalWeights)
                if j > 1
                    s = :($s+$w*varAux_[i1_,$(eq.position),$(j-1)]) 
                end
            end
            s = :($sym.new = $past+$s)
            s = vectorize(s,agent)
            push!(code.args,s)
        end
        code = makeSimpleLoop(code,agent)

        agent.declaredUpdatesCode[:IntegratorStep_] = 
        :(function ($(agentArgs()...),)
        
                $code

                return
            end)
        agent.declaredUpdatesFunction[:IntegratorStep_] = Main.eval(agent.declaredUpdatesCode[:IntegratorStep_])

        #Make series of steps if more than a step is performed
        auxs = quote end
        for i in 1:integ.length
            s = Meta.parse("community.agent.declaredUpdatesFunction[:IntegratorStep$(i)_]")
            aux = addCuda(:( $s( $(agentArgs(:community)...), ) ),agent) #Add code to execute kernel in cuda if GPU
            push!(auxs.args, aux)
        end
        aux = addCuda(:(community.agent.declaredUpdatesFunction[:IntegratorStep_]($(agentArgs(:community)...))),agent) #Add code to execute kernel in cuda if GPU
        push!(auxs.args, aux)

        #Put all together
        agent.declaredUpdatesCode[:IntegratorStep] = 
        quote
            function (community,)

                $auxs

                return
            end
        end
        agent.declaredUpdatesFunction[:IntegratorStep] = Main.eval(agent.declaredUpdatesCode[:IntegratorStep])

    end

    # println(prettify(agent.declaredUpdatesCode[:IntegratorStep_]))
    # println(prettify(agent.declaredUpdatesCode[:IntegratorStep]))
        
    return

end

function integrationStep!(community)

    checkLoaded(community)

    community.agent.declaredUpdatesFunction[:IntegratorStep](community)

    return 

end