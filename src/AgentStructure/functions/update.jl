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
function updateParametersCPU!(community)

    if size(community.xNew_)[1] > 0
        @views community.x[1:community.N[1],:] .= community.xNew_[1:community.N[1],:]
    end

    if size(community.yNew_)[1] > 0
        @views community.y[1:community.N[1],:] .= community.yNew_[1:community.N[1],:]
    end

    if size(community.zNew_)[1] > 0
        @views community.z[1:community.N[1],:] .= community.zNew_[1:community.N[1],:]
    end

    if size(community.liMNew_)[2] > 0
        @views community.liM_[1:community.N[1],:] .= community.liMNew_[1:community.N[1],:]
    end

    if size(community.lfMNew_)[2] > 0
        @views community.lfM_[1:community.N[1],:] .= community.lfMNew_[1:community.N[1],:]
    end

    if size(community.gfMNew_)[1] > 0
        @views community.gfM_ .= community.gfMNew_
    end

    if size(community.giMNew_)[1] > 0
        @views community.giM_ .= community.giMNew_
    end

    if length(community.mediumMNew_) > 0
        @views community.mediumM_ .= community.mediumMNew_
    end

    return

end

function updateParametersGPU!(community)

    if size(community.xNew_)[1] > 0
        community.x .= community.xNew_
    end

    if size(community.yNew_)[1] > 0
        community.y .= community.yNew_
    end

    if size(community.zNew_)[1] > 0
        community.z .= community.zNew_
    end

    if size(community.liMNew_)[2] > 0
        community.liM_ .= community.liMNew_
    end

    if size(community.lfMNew_)[2] > 0
        community.lfM_ .= community.lfMNew_
    end

    if size(community.gfMNew_)[1] > 0
        community.gfM_ .= community.gfMNew_
    end

    if size(community.giMNew_)[1] > 0
        community.giM_ .= community.giMNew_
    end

    if length(community.mediumMNew_) > 0
        community.mediumM_ .= community.mediumMNew_
    end

    return

end


"""
    function update!(community,agent)

Function that it is required to be called after performing all the functions of an step (findNeighbors, localStep, integrationStep...).
"""
function updateCPU!(community)

    checkLoaded(community)

    updateParametersCPU!(community)

    return 

end

function updateGPU!(community)

    checkLoaded(community)

    updateParametersGPU!(community)

    return 

end