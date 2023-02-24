######################################################################################################
# code to list the agents that survived
######################################################################################################
"""
    function listSurvivedCPU!(community)

Function that listes the survived agents from the end of the list to fill the left gaps by removed agents.
"""
function listSurvivedCPU!(community)

    count = 1
    lastPos = community.N[1]+community.NAdd_[]
    while community.NRemove_[] >= count

        if community.flagSurvive_[lastPos] == 1

            community.repositionAgentInPos_[count] = lastPos
            count += 1

        end

        lastPos -= 1

    end

    return 

end

"""
    macro kernelListSurvivedGPU!(arg,arg2)

Macro that constructs the kernel that listes the survived agents from the end of the list to fill the left gaps by removed agents in GPU. Is the GPU version of `listSurvivedCPU!`.

Generates the code of the kernel function:

    function kernelListSurvivedGPU!(community)

"""
macro kernelListSurvivedGPU!(arg,arg2)

    base = eval(arg)
    pos = eval(arg2)
    args = agentArgs(params=base,posparams=pos)

    return :(function kernelListSurvivedGPU!($(args...))

        count = 1
        lastPos = N[1]+NAdd_[1]
        while NRemove_[1] >= count

            if flagSurvive_[lastPos] == 1

                repositionAgentInPos_[count] = lastPos
                count += 1

            end

            lastPos -= 1

        end

        return 

    end)

end

@kernelListSurvivedGPU! BASEPARAMETERS POSITIONPARAMETERS

######################################################################################################
# code to fill the holes left by cells that did not survived
######################################################################################################
"""
    macro fillHolesCPU!(arg)

Macro to generate the function to fill the holes left by dead agents with the survived agents listed by `listSurvivedCPU!` over all the parameters that have :Local dimension (are proportional to agents).

Creates the function:

    fillHolesCPU!(community)
"""
macro fillHolesCPU!(arg)

    #get base parameters
    baseParameters = eval(arg)
    #Get local symbols
    localSymbols = getSymbolsThat(baseParameters,:shape,:Local)
    #Remove the ones related with reassigning position
    popat!(localSymbols,findfirst(localSymbols.==:holeFromRemoveAt_))
    popat!(localSymbols,findfirst(localSymbols.==:repositionAgentInPos_))
    #Make assignements
    code = quote end
    for sym in localSymbols
        if length(baseParameters[sym].shape)==1
            push!(code.args,
                quote
                    if length(community.$sym) > 0
                        community.$sym[posNew] = community.$sym[posOld]
                    end
                end
            )
        elseif length(baseParameters[sym].shape)==2
            push!(code.args,
                quote
                    if length(community.$sym) > 0
                        community.$sym[posNew,:] .= community.$sym[posOld,:]
                    end
                end
            )
        end
    end
    code = quote
        Threads.@threads for i in 1:1:community.NRemove_[]
            posNew = community.holeFromRemoveAt_[i]
            posOld = community.repositionAgentInPos_[i]
            if posNew < posOld
                $code
            end
        end
    end

    return :(
        function fillHolesCPU!(community)

            $code

            return

        end
    )

end

@fillHolesCPU! BASEPARAMETERS

"""
    macro kernelFillHolesGPU!(arg,arg2)

Macro to generate the function to fill the holes left by dead agents with the survived agents listed by `listSurvivedGPU!` over all the parameters that have :Local dimension (are proportional to agents).

Creates the function:

    kernelFillHolesGPU!(community)
"""
macro kernelFillHolesGPU!(arg,arg2)

    #get base parameters
    baseParameters = eval(arg)
    pos = eval(arg2)
    args = agentArgs(params=baseParameters,posparams=pos)
    #Get local symbols
    localSymbols = getSymbolsThat(baseParameters,:shape,:Local)
    #Remove the ones related with reassigning position
    popat!(localSymbols,findfirst(localSymbols.==:holeFromRemoveAt_))
    popat!(localSymbols,findfirst(localSymbols.==:repositionAgentInPos_))
    #Make assignements
    code = quote end
    for sym in localSymbols
        if length(baseParameters[sym].shape)==1
            push!(code.args,
                quote
                    if length($sym) > 0
                        $sym[posNew] = $sym[posOld]
                    end
                end
            )
        elseif length(baseParameters[sym].shape)==2
            push!(code.args,
                quote
                    if length($sym) > 0
                        for i2_ in 1:1:size($sym)[2]
                            $sym[posNew,i2_] = $sym[posOld,i2_]
                        end
                    end
                end
            )
        end
    end
    code = quote
        index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        stride = gridDim().x * blockDim().x
        for i in index:stride:NRemove_[]
            posNew = holeFromRemoveAt_[i]
            posOld = repositionAgentInPos_[i]
            if posNew < posOld
                $code
            end
        end
    end

    return :(
        function kernelFillHolesGPU!($(args...))

            $code

            return

        end
    )

end

@kernelFillHolesGPU! BASEPARAMETERS POSITIONPARAMETERS

######################################################################################################
# code to save updated parameters .new in the base array
######################################################################################################
"""
    macro updateParameters!(arg, platform)

Macro to generate the code that assigns the updated parameters assigned in XXXNew_ to the base parameter XXX_ in BASEPARAMETERS.

Creates the functions:

    updateParametersCPU!(community)
    updateParametersGPU!(community)
"""
macro updateParameters!(arg, platform)

    #get base parameters
    baseParameters = eval(arg)
    #Get local symbols
    newSymbols = [i for i in keys(baseParameters) if occursin("New_",string(i))]
    oldSymbols = [Meta.parse(string(split(string(i),"New_")[1],"_")) for i in newSymbols]
    old = []
    for i in oldSymbols
        if !(i in keys(baseParameters)) 
            push!(old,Meta.parse(string(split(string(i),"_")[1])))
        else 
            push!(old,i)
        end
    end
    oldSymbols = old

    #Make code
    code = quote end
    for (n,o) in zip(newSymbols, oldSymbols)
        s = string((n,o))
        if :Local in baseParameters[n].shape && length(baseParameters[n].shape) > 1 && platform == :CPU #Only views if cpu, rest, pure copy
            push!(code.args,
                quote
                    if length(community.$n) > 0
                        @views community.$o[1:community.N[1],:] .= community.$n[1:community.N[1],:]
                    end
                end
            )
        else
            push!(code.args,
                quote
                    if length(community.$n) > 0
                        community.$o .= community.$n
                    end
                end
            )
        end
    end

    #Make function
    name = Meta.parse("updateParameters$(platform)!")

    return :(
        function $name(community)

            $code

            return

        end
    )

end

@updateParameters! BASEPARAMETERS CPU
@updateParameters! BASEPARAMETERS GPU

######################################################################################################
# full update code
######################################################################################################
"""
    function updateCPU!(community)

Function groups together the functions:
 - `listSurvivedCPU!`
 - `fillHolesCPU!`
 - `updateParametersCPU`

And updates the number of agents and resets the corresponding parmaeters after update.
"""
function updateCPU!(community)

    #List and fill holes left from agent removal
    listSurvivedCPU!(community)
    fillHolesCPU!(community)
    #Update number of agents
    community.N[1] += community.NAdd_[] - community.NRemove_[] 
    community.NAdd_[] = 0
    community.NRemove_[] = 0
    #Clear flags
    if community.agent.removalOfAgents_
        @views community.flagSurvive_[1:community.N[1]] .= 0
    end
    #Update parameters
    updateParametersCPU!(community)
    #Update time
    community.t .+= community.dt

    return 

end

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
macro updateGPU!(arg,arg2)

    base = eval(arg)
    pos = eval(arg2)
    args = agentArgs(:community,params=base,posparams=pos)

    return :(function updateGPU!(community)

        #List and fill holes left from agent removal
        kernel1 = @cuda launch=false kernelListSurvivedGPU!($(args...))
        kernel1($(args...);threads=community.platform.threads,blocks=community.platform.threads)
        kernel2 = @cuda launch=false kernelFillHolesGPU!($(args...))
        kernel2($(args...);threads=community.platform.threads,blocks=community.platform.threads)
        #Update number of agents
        community.N .+= community.NAdd_ - community.NRemove_ 
        community.NAdd_ .= 0
        community.NRemove_ .= 0
        #Clear flags
        if community.agent.removalOfAgents_
            community.flagSurvive_ .= 0
        end
        #Update parameters
        updateParametersGPU!(community)
        #Update time
        community.t .+= community.dt
        #Update GPU execution
        setfield!(com,:platform,AgentBasedModels.Platform(256,ceil(Int,Array{Float64}(getfield(community,:N))[1]/256)))

        return 

        end
    )
end

@updateGPU!(BASEPARAMETERS,POSITIONPARAMETERS)

"""
    function update!(community)

Function that updates all the parameters after making a step in the community.
"""
function update!(community)

    checkLoaded(community)

    if community.agent.platform == :CPU
        updateCPU!(community)
    else
        updateGPU!(community)
    end

    return
end