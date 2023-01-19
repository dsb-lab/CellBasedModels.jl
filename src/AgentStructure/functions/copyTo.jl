function copyTo(agent::Agent)

    #Id
    updatecode = quote id[repositionAgentInPos_[ic1_]]=id[removeAgentInPos_[ic1_]] end

    #Positions
    updateargs = [sym for (sym,prop) in pairs(agent.declaredSymbols) if prop[3] in [:Position]]
    for i in updateargs #Update them
        push!(updatecode,:($i[repositionAgentInPos_[ic1_]]=$i[removeAgentInPos_[ic1_]]))
    end

    #Update position
    updateargs = [sym for (sym,prop) in pairs(agent.declaredSymbols) if (prop[3] in [:Update]) && (prop[2] in [:Position])]
    for i in updateargs #Update them
        push!(updatecode,:($i[repositionAgentInPos_[ic1_]]=$i[removeAgentInPos_[ic1_]]))
    end

    #User arguments
    updateargs = [sym for (sym,prop) in pairs(agent.declaredSymbols) if prop[3] in [:UserUpdatable]]
    for i in updateargs #Update them
        push!(updatecode,:($i[repositionAgentInPos_[ic1_]]=$i[removeAgentInPos_[ic1_]]))
    end

    #Update user locals
    updateargs = [sym for (sym,prop) in pairs(agent.declaredSymbols) if (prop[3] in [:Update]) && (prop[2] in [:UserUpdatable])]
    for i in updateargs #Update them
        push!(updatecode,:($i[repositionAgentInPos_[ic1_]]=$i[removeAgentInPos_[ic1_]]))
    end

    #Neighbor 
    if agent.neighbors == :Full
        nothing
    elseif agent.neighbors == :VerletTime
        push!(updatecode,:(neighborN_[repositionAgentInPos_[ic1_]]=neighborN_[removeAgentInPos_[ic1_]]))
        push!(updatecode,:(for ic2_ in 1:1:neighborN_[repositionAgentInPos_[ic1_]] 
                                neighborList_[repositionAgentInPos_[ic1_],ic2_]=neighborList_[removeAgentInPos_[ic1_],ic2_]
                            end
                        )
            )
    elseif agent.neighbors == :VerletDisplacement
        push!(updatecode,:(neighborN_[repositionAgentInPos_[ic1_]]=neighborN_[removeAgentInPos_[ic1_]]))
        push!(updatecode,:(for ic2_ in 1:1:neighborN_[repositionAgentInPos_[ic1_]] 
                                neighborList_[repositionAgentInPos_[ic1_],ic2_]=neighborList_[removeAgentInPos_[ic1_],ic2_]
                            end
                        )
            )
        if agents.dims > 0
            push!(updatecode,:(xOld_[repositionAgentInPos_[ic1_]]=xOld_[removeAgentInPos_[ic1_]]))
        end
        if agents.dims > 1
            push!(updatecode,:(yOld_[repositionAgentInPos_[ic1_]]=yOld_[removeAgentInPos_[ic1_]]))
        end
        if agents.dims > 2
            push!(updatecode,:(zOld_[repositionAgentInPos_[ic1_]]=zOld_[removeAgentInPos_[ic1_]]))
        end
        push!(updatecode,:(accumulatedDistance_[repositionAgentInPos_[ic1_]]=accumulatedDistance_[removeAgentInPos_[ic1_]]))
    elseif agent.neighbors == :CellLinked

    end

    if agent.platform == :CPU #Nene
        updatecode = quote
            Threads.@threads for ic1_ in 1:1:NRemove_[]
                $updatecode
            end

            return
        end
    elseif  agent.platform == :GPU
        updatecode = quote
            $CUDATHREADS1D
            for ic1_ in index:stride:NRemove_[]
                $updatecode
            end

            return
        end
    end

end