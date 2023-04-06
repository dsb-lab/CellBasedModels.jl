######################################################################################################
# code to list the agents that survived
######################################################################################################
"""
    macro kernelListSurvived!()

Macro that constructs the kernel that listes the survived agents from the end of the list to fill the left gaps by removed agents.

Generates the code of the kernel function:

    function kernelListSurvivedCPU!(community)
    function kernelListSurvivedGPU!(community)

"""
macro kernelListSurvived!(platform)

    name = Meta.parse("kernelListSurvived$(platform)!")

    code = 
        quote
            count = 1
            lastPos = N[1]+NAdd_[]
            while NRemove_[] >= count
                if flagSurvive_[lastPos] == 1

                    repositionAgentInPos_[count] = lastPos
                    count += 1

                end

                lastPos -= 1

            end
        end

    #For global parameters
    code = cudaAdapt(code, eval(platform))

    code = :(  function $name(N,NAdd_,NRemove_,flagSurvive_,repositionAgentInPos_)

            $code

            return 

        end
    )

    return code
end

@kernelListSurvived! CPU
@kernelListSurvived! GPU

######################################################################################################
# code to fill the holes left by cells that did not survived
######################################################################################################
"""
    macro kernelFillHolesParameters!()

Macro to generate the function to fill the holes left by dead agents with the survived agents listed by `listSurvivedGPU!` over all the parameters that have :Local dimension (are proportional to agents).

Creates the function:

    kernelFillHolesBaseCPU!(community)
    kernelFillHolesBaseGPU!(community)
"""
macro kernelFillHolesParameters!(platform)

    #Make assignements
    if platform == :CPU
        code = quote
            for i in 1:1:NRemove_[]
                posNew = holeFromRemoveAt_[i]
                posOld = repositionAgentInPos_[i]
                if posNew < posOld
                    if length(size(par)) == 1
                        par[posNew] = par[posOld]
                    else
                        for j in 1:size(par)[2]
                            par[posNew,j] = par[posOld,j]
                        end
                    end
                end
            end
        end
    else
        code = quote
            index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
            stride = gridDim().x * blockDim().x
            for i in index:stride:NRemove_[1]
                posNew = holeFromRemoveAt_[i]
                posOld = repositionAgentInPos_[i]
                if posNew < posOld
                    if length(size(par)) == 1
                        par[posNew] = par[posOld]
                    else
                        for j in 1:size(par)[2]
                            par[posNew,j] = par[posOld,j]
                        end
                    end
                end
            end
        end
    end

    return :(
        function $(Meta.parse("kernelFillHolesParameters$(platform)!"))(par,NRemove_,holeFromRemoveAt_,repositionAgentInPos_)

            $code

            return

        end
    )

end

@kernelFillHolesParameters! CPU
@kernelFillHolesParameters! GPU

"""
    macro kernelUpdateParameters!(platform)

Kernel to update agent parameters.
"""
macro kernelUpdateParameters!(platform)

    #Make assignements
    if platform == :CPU
        code = quote
            for i in 1:1:N
                par[i] = parNew[i]
            end
        end
    else
        code = quote
            index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
            stride = gridDim().x * blockDim().x
            for i in index:stride:N
                par[i] = parNew[i]
            end
        end
    end

    return :(
        function $(Meta.parse("kernelUpdateParameters$(platform)!"))(N,par,parNew)

            $code

            return

        end
    )

end

@kernelUpdateParameters! CPU
@kernelUpdateParameters! GPU

######################################################################################################
# full update code
######################################################################################################
"""
    macro updateGPU!(arg,arg2)

Macro that constructs the function:

    function updateGPU!(community)

Function groups together the functions:
 - `listSurvivedGPU!`
 - `fillHolesGPU!`
 - `updateParametersGPU`

And updates the number of agents and resets the corresponding parmaeters after update.
"""
macro update!(platform)

    if platform == :CPU
        kernel1 = :($(Meta.parse("kernelListSurvived$(platform)!"))(community.N,community.NAdd_,community.NRemove_,community.flagSurvive_,community.repositionAgentInPos_))
        kernel2 = :($(Meta.parse("kernelFillHolesParameters$(platform)!"))(p,community.NRemove_,community.holeFromRemoveAt_,community.repositionAgentInPos_))
        kernel4 = :($(Meta.parse("kernelUpdateParameters$(platform)!"))(community.N,community.parameters[sym],community.parameters[new(sym)]))

    else
        #List and fill holes left from agent removal
        kernel1 = quote
            kernel1 = CellBasedModels.@cuda launch=false $(Meta.parse("kernelListSurvived$(platform)!"))(community.N,community.NAdd_,community.NRemove_,community.flagSurvive_,community.repositionAgentInPos_)
            kernel1(community.N,community.NAdd_,community.NRemove_,community.flagSurvive_,community.repositionAgentInPos_;threads=community.platform.agentThreads,blocks=community.platform.agentBlocks)
        end
        kernel2 = quote
            kernel2 = CellBasedModels.@cuda launch=false $(Meta.parse("kernelFillHolesParameters$(platform)!"))(p,community.NRemove_,community.holeFromRemoveAt_,community.repositionAgentInPos_)
            kernel2(p,community.NRemove_,community.holeFromRemoveAt_,community.repositionAgentInPos_;threads=community.platform.agentThreads,blocks=community.platform.agentBlocks)
        end
        kernel4 = quote
            kernel4 = CellBasedModels.@cuda launch=false $(Meta.parse("kernelUpdateParameters$(platform)!"))(community.N,p,p__)
            kernel4(community.N,p,p__;threads=community.platform.agentThreads,blocks=community.platform.agentBlocks)
        end
    end

    code = quote end
    if platform == :CPU
        code = quote
            setfield!(community,:N, Int(community.N + community.NAdd_[] - community.NRemove_[] ) )
            community.NAdd_[] = 0
            community.NRemove_[] = 0
            #Clear flags
            if community.abm.removalOfAgents_
                @views community.flagSurvive_[1:community.N] .= 1
            end
        end
    else
        code = quote
            #Update number of agents
            CUDA.@allowscalar setfield!(community,:N, Int(community.N + community.NAdd_[1] - community.NRemove_[1] ) )
            community.NAdd_ .= 0
            community.NRemove_ .= 0
            #Clear flags
            if community.abm.removalOfAgents_
                community.flagSurvive_ .= 1
            end
        end
    end

    return :(function $(Meta.parse("update$(platform)!"))(community)

            #List and fill holes left from agent removal
            if community.abm.removalOfAgents_
                $kernel1
                #id
                p = getfield(community,:id)
                if size(p)[1] == community.nMax_
                    $kernel2
                end
                #agentDE
                if community.agentDEProblem !== nothing
                    p = getfield(community.agentDEProblem,:u)
                    if size(p)[1] == community.nMax_
                        $kernel2
                    end
                end
                #neighbors
                for sym in fieldnames(typeof(community.neighbors))
                    p = getfield(community.neighbors,sym)
                    if !(typeof(p) <: Function)
                        if length(size(p)) > 0
                            if size(p)[1] == community.nMax_
                                $kernel2
                            end
                        end
                    end
                end
                #Allocate parameters
                for (sym,prop) in pairs(community.abm.parameters)
                    if prop.scope == :agent && prop.update
                        p = community.parameters[new(sym)]
                        $kernel2
                    elseif prop.scope == :agent
                        p = community.parameters[sym]
                        $kernel2
                    end
                end
            end
            $code
            #Allocate parameters
            for (sym,prop) in pairs(community.abm.parameters)
                if prop.update
                    if prop.scope == :agent
                        p = community[sym]
                        p__ = community[new(sym)]
                        $kernel4
                    elseif prop.scope == :model
                        community[sym] .= community[new(sym)]
                    elseif prop.scope == :medium
                        community[sym] .= community[new(sym)]
                    end
                end
            end
            #Update time
            setfield!(community,:t, community.t + community.dt)
            #Update GPU execution
            platformUpdate!(community.platform,community)
            
            return 

        end
    )
end

@update! CPU
@update! GPU

"""
    function update!(community)

Function that updates all the parameters after making a step in the community.
"""
function update!(community)

    checkLoaded(community)

    if typeof(community.platform) <: CPU
        updateCPU!(community)
    else
        updateGPU!(community)
    end

    return
end