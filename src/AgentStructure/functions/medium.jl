#######################################################################################################
# Get the equations
#######################################################################################################
"""
    function addToListMedium(x,agent;type)

Add the code from dt or dW (type) terms to the Corresponding `Equation` structure. Give errors if some code is already present or if SDE is not implemented for that particular integrator.
"""
function addToListMedium(x,eq;type)

    push!(getfield(eq,type), x)

    return x
 
end

"""
    function getEquationMedium(sym,code,agent)

Give errors if the symbol for an equation is not vald for an SDE or ODE.
Go over the possible dt and dW terms in the equation and add them to the structure `Equation`.
"""
function getEquationMedium(sym,code,agent)

    if agent.declaredSymbols[sym].scope != :Medium
        error("Only parameters that are medium can be defined as variables for a medium equation.")
    end

    
    eq = EquationMedium(0,
                    Union{Symbol,Expr,Number}[],
                    Union{Symbol,Expr,Number}[],
                    Union{Symbol,Expr,Number}[],
                    Union{Symbol,Expr,Number}[],
                    Union{Symbol,Expr,Number}[],
                    Union{Symbol,Expr,Number}[],
                    Union{Symbol,Expr,Number}[],
                    Union{Symbol,Expr,Number}[])
    if sym in keys(agent.declaredVariablesMedium)
        eq = agent.declaredVariablesMedium[sym]
    else
        eq.position = length(keys(agent.declaredVariablesMedium))
    end

    code = postwalk(x->@capture(x,∂2xx(m_)) ? addToListMedium(m,eq,type=:difussionXX) : x, code)
    code = postwalk(x->@capture(x,∂2yy(m_)) ? addToListMedium(m,eq,type=:difussionYY) : x, code)
    code = postwalk(x->@capture(x,∂2zz(m_)) ? addToListMedium(m,eq,type=:difussionZZ) : x, code)
    code = postwalk(x->@capture(x,∂x(m_)) ? addToListMedium(m,eq,type=:advectionX) : x, code)
    code = postwalk(x->@capture(x,∂y(m_)) ? addToListMedium(m,eq,type=:advectionY) : x, code)
    code = postwalk(x->@capture(x,∂z(m_)) ? addToListMedium(m,eq,type=:advectionZ) : x, code)
    code = postwalk(x->@capture(x,react(m_)) ? addToListMedium(m,eq,type=:reaction) : x, code)
    code = postwalk(x->@capture(x,addFromAgents(m_)) ? addToListMedium(m,eq,type=:fromAgents) : x, code)

    agent.declaredVariablesMedium[sym] = eq

    return code

end

"""
    function getEquationsMedium!(agent)

Go over the code in updateMedium and get the equations defined in the code.
"""
function getEquationsMedium!(agent)

    code = agent.declaredUpdates[:UpdateMedium]

    #Transform to basic forms
    if agent.dims == 1
        code = postwalk(x->@capture(x,∂2(m_)) ? :(∂2xx($m)) : x, code)
    elseif agent.dims == 2
        code = postwalk(x->@capture(x,∂2(m_)) ? :(∂2xx($m)+∂2yy($m)) : x, code)
    elseif agent.dims == 3
        code = postwalk(x->@capture(x,∂2(m_)) ? :(∂2xx($m)+∂2yy($m)+∂2zz($m)) : x, code)
    end
    agent.declaredUpdates[:UpdateMedium] = code

    #Get equations
    code = postwalk(x->@capture(x,∂t(s_)=g_) ? getEquationMedium(s,g,agent) : x, code)

    return

end

#######################################################################################################
# Convert the equations
#######################################################################################################
"""
    function integratorMediumFunction(agent)

Creates the final code provided to Agent in `updateMedium` as a function and adds it to the Agent.
"""
function integratorMediumFunction(agent)

    if [i for i in prettify(agent.declaredUpdates[:UpdateMedium]).args if typeof(i) != LineNumberNode] != []

        #Get code
        code = agent.declaredUpdates[:UpdateMedium]

        #Substitute equations
        for (sym,eq) in pairs(agent.declaredVariablesMedium)

            pos = agent.declaredSymbols[sym].position

            #Advection, Difussion and Reaction vectorization
            for sets in [
                            zip([:difussionXX,:difussionYY,:difussionZZ],
                                [:i1_,:i2_,:i3_],
                                [:∂2xx,:∂2yy,:∂2zz],
                                [:difussion,:difussion,:difussion],
                                [:(meshLateralSize_[1]^2),:(meshLateralSize_[2]^2),:(meshLateralSize_[3]^2)]
                                ),
                            zip([:advectionX,:advectionY,:advectionZ],
                                [:i1_,:i2_,:i3_],
                                [:∂x,:∂y,:∂z],
                                [:advection,:advection,:advection],
                                [:(meshLateralSize_[1]),:(meshLateralSize_[2]),:(meshLateralSize_[3])],
                                ),
                            zip([:reaction],
                                [:i1_],
                                [:react],
                                [:reaction],
                                [nothing],
                                )
                        ]
                for (changeArray,ind,op,operator,dx) in sets
                    v = copy(getfield(agent.declaredVariablesMedium[sym],changeArray))

                    for sym2 in getSymbolsThat(agent.declaredSymbols,:scope,:Medium)
                        b = agent.declaredSymbols[sym2].basePar
                        pos2 = agent.declaredSymbols[sym2].position
                        sym2vect = :($b[$([:i1_,:i2_,:i3_][1:agent.dims]...),$pos2])
                        sym2disc = 0
                        list = getfield(INTEGRATORMEDIUM[agent.integratorMedium],operator)
                        for (i,w) in enumerate(list)
                            l = length(list)
                            p = ceil(Int,l/2)
                            s = postwalk(x->@capture(x,s_) && s == ind ? :($ind+$(i-p)) : x, sym2vect)
                            sym2disc = :($sym2disc +$w*$s)
                        end
                        sym2disc = clean(sym2disc)
                        for j in 1:length(v)
                            if dx !== nothing
                                v[j] = postwalk(x->@capture(x,s_) && s == sym2 ? :($sym2disc/$dx) : x, v[j])
                            else
                                v[j] = postwalk(x->@capture(x,s_) && s == sym2 ? sym2disc : x, v[j])
                            end
                        end
                    end

                    code = postwalk(x->@capture(x,s_(g_)) && s == op ? popfirst!(v) : x, code)
                end
            end

            #Transform functions
            code = postwalk(x->@capture(x,δx(g_)) ? :(AgentBasedModels.functionδ($g,meshLateralSize_[1])) : x, code)
            code = postwalk(x->@capture(x,δy(g_)) ? :(AgentBasedModels.functionδ($g,meshLateralSize_[2])) : x, code)
            code = postwalk(x->@capture(x,δz(g_)) ? :(AgentBasedModels.functionδ($g,meshLateralSize_[3])) : x, code)
            code = postwalk(x->@capture(x,xₘ) ? :(simBox[1,1]+i1_*meshLateralSize_[1]) : x, code)
            code = postwalk(x->@capture(x,yₘ) ? :(simBox[2,1]+i2_*meshLateralSize_[2]) : x, code)
            code = postwalk(x->@capture(x,zₘ) ? :(simBox[3,1]+i2_*meshLateralSize_[3]) : x, code)

            code = vectorize(code,agent)

            #Put it in loop
            code = postwalk(x->@capture(x,∂t(s_) = g_) && s == sym ? noBorders(:(mediumMNew_[$([:i1_,:i2_,:i3_][1:agent.dims]...),$pos] = dt[1]*$g), agent) : x, code)

        end

        println(code)

        code = makeSimpleLoop(code,agent,nloops=agent.dims)

        #Make code
        agent.declaredUpdatesCode[:MediumStep_] = :(($(agentArgs()...),) -> $code)
        agent.declaredUpdatesFunction[:MediumStep_] = Main.eval(:($(agent.declaredUpdatesCode[:MediumStep_])))
        aux = addCuda(:(community.agent.declaredUpdatesFunction[:MediumStep_]($(agentArgs(:community)...))),agent) #Add code to execute kernel in cuda if GPU
        agent.declaredUpdatesCode[:MediumStep] = :(function (community)
                                                        $aux
                                                        return 
                                                    end)
        agent.declaredUpdatesFunction[:MediumStep] = Main.eval(
            :($(agent.declaredUpdatesCode[:MediumStep]))
        )
    else
        agent.declaredUpdatesFunction[:MediumStep] = Main.eval(:((community) -> nothing))
    end

    return

end

"""
    function integrationMediumStep!(community)

Function that computes a integration step of the medium a time step `dt` using the defined Integrator defined in Agent.
"""
function integrationMediumStep!(community)

    checkLoaded(community)

    community.agent.declaredUpdatesFunction[:MediumStep](community)

    return 

end