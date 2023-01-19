######################################################################################################
# code to fill the holes in the array left by dead cells
######################################################################################################
function listSurvived(N,NAdd_,NRemove_,repositionAgentInPos_::Array,flagSurvive_)

    count = 0
    lastPos = N[]+NAdd_[]
    while NRemove_[] > count

        if flagSurvive_[lastPos] == 1

            repositionAgentInPos_[count] = lastPos
            count += 1

        end

        lastPos -= 1

    end

    return 

end

function fillHoles(agent::Agent)

    args = []
    for i in keys(agent.declaredSymbols)
        push!(args,:($i))        
    end

    #Get parameters that are updated and find its symbols
    parameters = [(sym,prop) for (sym,prop) in pairs(agent.declaredSymbols) if prop[4]]

    #Make code for kernel of local updates (to only update until N and not nMax_) and the rest
    code = quote end
    for (s,prop) in parameters
        if :Local in prop
            push!(code.args,:($s[holeFromRemoveAt_[i1_]] = $s[repositionAgentInPos_[i1_]])) #Not bradcast as it is inside custom kernel
        elseif :VerletList in prop
            push!(code.args,:(for i2_ in 1:1:neighborN_; $s[holeFromRemoveAt_[i1_],i2_] .= $s[repositionAgentInPos_[i1_],i1_]; end)) #Broadcasted
        else
            error("Updating not implemented for ", s, " with type ", prop)
        end
    end
    code = makeSimpleLoop(code,agent)
    #Change running pace
    code = postwalk(x->@capture(x,N[1]) ? :(NRemove_[]) : x, code)
    #Add generated code to the agents
    agent.declaredUpdatesCode[:FillHoles_] = code

    #Partial functions
    agent.declaredUpdatesFunction[:FillHoles_] = Main.eval(:(
                                                            function ($(args...),) 
                                                                $code 
                                                                return nothing
                                                            end
                                                        ))

    return

end

######################################################################################################
# code to save updated parameters .new in the base array
######################################################################################################
function updateParameters(agent)

    #Get parameters and make community
    args = []
    for i in keys(agent.declaredSymbols)
        push!(args,:($i))        
    end
    args2 = [:(community.$i) for i in args]

    #Get parameters that are updated and find its symbols
    parameters = [(Meta.parse(string(sym)[1:end-4]),sym,prop) for (sym,prop) in pairs(agent.declaredSymbols) if prop[3] == :Update]

    #Make code for kernel of local updates (to only update until N and not nMax_) and the rest
    codeLocal = quote end
    codeRest = quote end
    for (s,sNew,prop) in parameters
        if :Local in prop
            push!(codeLocal.args,:($s[i1_] = $sNew[i1_])) #Not bradcast as it is inside custom kernel
        elseif :Global in prop
            push!(codeRest.args,:($s .= $sNew)) #Broadcasted
        elseif :Medium in prop
            push!(codeRest.args,:($s .= $sNew)) #Broadcasted
        else
            error("Updating not implemented for ", s, " with type ", prop)
        end
    end
    codeLocal = makeSimpleLoop(codeLocal,agent)
    #Add generated code to the agents
        #Code
    agent.declaredUpdatesCode[:Update1] = codeLocal
    agent.declaredUpdatesCode[:Update2] = codeRest
        #Partial functions
    agent.declaredUpdatesFunction[:Update1_] = Main.eval(:(
                                                            function ($(args...),) 
                                                                $codeLocal 
                                                                return nothing
                                                            end
                                                        ))
    agent.declaredUpdatesFunction[:Update2_] = Main.eval(:(($(args...),) -> $codeRest))

    return

end

function updateFunction(agent)

    args = []
    for i in keys(agent.declaredSymbols)
        push!(args,:($i))        
    end
    args2 = [:(community.$i) for i in args]

    #Make functions to fill holes left from removeAgents
    fillHoles(agent)

    #Make functions to update paremters from .new
    updateParameters(agent)
 
    #Total function
    aux1 = addCuda(:(AgentBasedModels.listSurvived(community.N,
                                community.NAdd_,
                                community.NRemove_,
                                community.repositionAgentInPos_::Array,
                                community.flagSurvive_)),agent) #Add code to execute kernel in cuda if GPU
    aux2 = addCuda(:(community.agent.declaredUpdatesFunction[:FillHoles_]($(args2...))),agent) #Add code to execute kernel in cuda if GPU
    aux3 = addCuda(:(community.agent.declaredUpdatesFunction[:Update1_]($(args2...))),agent) #Add code to execute kernel in cuda if GPU
    agent.declaredUpdatesFunction[:UpdateParameters] = Main.eval(:(function (community) 
                                                            $aux1
                                                            $aux2
                                                            community.N .+= community.NAdd_[]-community.NRemove_[]
                                                            community.NAdd_[] = 0
                                                            community.NRemove_[] = 0
                                                            $aux3
                                                            community.agent.declaredUpdatesFunction[:Update2_]($(args2...))
                                                            return
                                                        end
                                                        ))               

    return

end

"""
    function update!(community,agent)

Function that it is required to be called after performing all the functions of an step (findNeighbors, localStep, integrationStep...).
"""
function update!(community)

    checkLoaded(community)

    community.agent.declaredUpdatesFunction[:UpdateParameters](community)

    return 

end