function updateFunction(agent)

    #Get parameters and make community
    args = []
    for i in keys(agent.declaredSymbols)
        push!(args,:($i))        
    end
    args2 = [:(community.$i) for i in args]

    #Get parameters that are updated and find its symbols
    parameters = [(Meta.parse(string(sym)[1:end-4]),sym,prop) for (sym,prop) in pairs(agent.declaredSymbols) if :Update in prop]


    if agent.platform == :CPU

        code = quote end
        # Go over the parameters and update accordingly
        for (s,sNew,prop) in parameters
            if :Local in prop
                push!(code.args,:(@views $s[1:N[1]] .= $sNew[1:N[1]]))
            elseif :Global in prop
                push!(code.args,:($s .= $sNew))
            elseif :Medium in prop
                push!(code.args,:($s .= $sNew))
            else
                error("Updating not implemented for ", s, " with type ", prop)
            end
        end

        #Add generated code to the agents
        agent.declaredUpdatesCode[:Update] = code
        agent.declaredUpdatesFunction[:Update_] = Main.eval(:(($(args...),) -> $code))
        agent.declaredUpdatesFunction[:Update] = Main.eval(:((community) -> community.agent.declaredUpdatesFunction[:Update_]($(args2...))))

    elseif agent.platform == :GPU
        
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
            #Total function
        agent.declaredUpdatesFunction[:Update] = Main.eval(:(function (community) 

                                                                @cuda threads=community.platform.threads blocks=community.platform.blocks community.agent.declaredUpdatesFunction[:Update1_]($(args2...))
                                                                community.agent.declaredUpdatesFunction[:Update2_]($(args2...))

                                                                return
                                                            end
                                                            ))               

    else

        error("Not implemented yet.")

    end

    return
end

"""
    function update!(community,agent)

Function that it is required to be called after performing all the functions of an step (findNeighbors, localStep, integrationStep...).
"""
function update!(community)

    checkLoaded(community)

    community.agent.declaredUpdatesFunction[:Update](community)

    return 

end