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

    code = vectorize(code)
    code = cudaAdapt(code, platform)

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
    macro kernelFillHolesBase!()

Macro to generate the function to fill the holes left by dead agents with the survived agents listed by `listSurvivedGPU!` over all the parameters that have :Local dimension (are proportional to agents).

Creates the function:

    kernelFillHolesBaseCPU!(community)
    kernelFillHolesBaseGPU!(community)
"""
macro kernelFillHolesBase!(platform)

    #get base parameters
    baseParameters = BASEPARAMETERS
    #Get local symbols
    localSymbols = getSymbolsThat(BASEPARAMETERS,:shape,:Local)
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
    if platform == :CPU
        code = quote
            for i in 1:1:NRemove_[]
                posNew = holeFromRemoveAt_[i]
                posOld = repositionAgentInPos_[i]
                flagSurvive_[posOld] = 0
                if posNew < posOld
                    $code
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
                flagSurvive_[posOld] = 0
                if posNew < posOld
                    $code
                end
            end
        end
    end
    # code = vectorize(code)
    code = cudaAdapt(code,platform)

    localSymbols = getSymbolsThat(BASEPARAMETERS,:shape,:Local)
    localSymbols=[localSymbols;[:NRemove_]]

    return :(
        function $(Meta.parse("kernelFillHolesBase$(platform)!"))($(localSymbols...))

            $code

            return

        end
    )

end

@kernelFillHolesBase! CPU
@kernelFillHolesBase! GPU

macro kernelFillHolesParameters!(platform)

    #Make assignements
    if platform == :CPU
        code = quote
            for i in 1:1:NRemove_[]
                posNew = holeFromRemoveAt_[i]
                posOld = repositionAgentInPos_[i]
                if posNew < posOld
                    par[posNew] = par[posOld]
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
                    par[posNew] = par[posOld]
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

# ######################################################################################################
# # code to save updated parameters .new in the base array
# ######################################################################################################
# """
#     macro updateParameters!(arg, platform)

# Macro to generate the code that assigns the updated parameters assigned in XXXNew_ to the base parameter XXX_ in BASEPARAMETERS.

# Creates the functions:

#     updateParametersCPU!(community)
#     updateParametersGPU!(community)
# """
# macro updateParameters!(arg, platform)

#     #get base parameters
#     baseParameters = eval(arg)
#     #Get local symbols
#     newSymbols = [i for i in keys(baseParameters) if occursin("New_",string(i))]
#     oldSymbols = [Meta.parse(string(split(string(i),"New_")[1],"_")) for i in newSymbols]
#     old = []
#     for i in oldSymbols
#         if !(i in keys(baseParameters)) 
#             push!(old,Meta.parse(string(split(string(i),"_")[1])))
#         else 
#             push!(old,i)
#         end
#     end
#     oldSymbols = old

#     #Make code
#     code = quote end
#     for (n,o) in zip(newSymbols, oldSymbols)
#         s = string((n,o))
#         if :Local in baseParameters[n].shape && length(baseParameters[n].shape) > 1 && platform == :CPU #Only views if cpu, rest, pure copy
#             push!(code.args,
#                 quote
#                     if length(community.$n) > 0
#                         @views community.$o[1:community.N[1],:] .= community.$n[1:community.N[1],:]
#                     end
#                 end
#             )
#         else
#             push!(code.args,
#                 quote
#                     if length(community.$n) > 0
#                         community.$o .= community.$n
#                     end
#                 end
#             )
#         end
#     end

#     #Make function
#     name = Meta.parse("updateParameters$(platform)!")

#     return :(
#         function $name(community)

#             $code

#             return

#         end
#     )

# end

# @updateParameters! BASEPARAMETERS CPU
# @updateParameters! BASEPARAMETERS GPU

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

    localSymbols = getSymbolsThat(BASEPARAMETERS,:shape,:Local)
    localSymbols=[localSymbols;[:NRemove_]]
    localSymbols = [:(community.$i) for i in localSymbols]

    kernel1 = addCuda(:($(Meta.parse("kernelListSurvived$(platform)!"))(community.N,community.NAdd_,community.NRemove_,community.flagSurvive_,community.repositionAgentInPos_)),platform)
    kernel2 = addCuda(:($(Meta.parse("kernelFillHolesBase$(platform)!"))($(localSymbols...))),platform)
    kernel3 = addCuda(:($(Meta.parse("kernelFillHolesParameters$(platform)!"))(community.parameters[sym],community.NRemove_,community.holeFromRemoveAt_,community.repositionAgentInPos_)),platform)

    code = quote end
    if platform == :CPU
        code = quote
            community.N[1] += community.NAdd_[] - community.NRemove_[] 
            community.NAdd_[] = 0
            community.NRemove_[] = 0
            #Clear flags
            if community.agent.removalOfAgents_
                @views community.flagSurvive_[1:community.N[1]] .= 1
            end
        end
    else
        code = quote
            #Update number of agents
            community.N .+= community.NAdd_ - community.NRemove_
            community.NAdd_ .= 0
            community.NRemove_ .= 0
            #Clear flags
            if community.agent.removalOfAgents_
                community.flagSurvive_ .= 1
            end
        end
    end

    return :(function $(Meta.parse("update$(platform)!"))(community)

            #List and fill holes left from agent removal
            $kernel1
            $kernel2
            #Update parameters
            for (sym,prop) in pairs(community.agent.parameters)
                if prop.scope == :agent
                    $kernel3
                end
            end
            $code
            #Update time
            community.t .+= community.dt
            #Update GPU execution
            setfield!(community,:platform,AgentBasedModels.Platform(256,ceil(Int,Array{Float64}(getfield(community,:N))[1]/256)))

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

    if community.agent.platform == :CPU
        updateCPU!(community)
    else
        updateGPU!(community)
    end

    return
end