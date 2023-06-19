######################################################################################################
# add agent code
######################################################################################################
"""
    macro addAgentCode(arguments)

Macro that returns the special code based on the arguments provided to `addAgent`.
"""
macro addAgent(arguments...)

    abm = AGENT
    #List parameters that can be updated by the user
    updateargs = [sym for (sym,prop) in pairs(abm.parameters) if prop.scope == :agent]
    updateargs2 = [new(sym) for (sym,prop) in pairs(abm.parameters) if prop.scope == :agent]
    append!(updateargs2,updateargs)
    #Checks that the correct parameters has been declared and not others
    args = []
    code = quote end
    for i in arguments
        found = @capture(i,g_[h_] = f_)
        if found
            if !(g in updateargs2)
                error(g, " is not an agent parameter.")
            end
        else
            error(i, " is not a valid assignation of code when declaring addAgent. A Valid one should be of the form parameterOfAgent = value")
        end

        if g in args
           error(g," has been declared more than once in addAgent.") 
        end

        if i.args[1] == :id
            error("id must not be declared when calling addAgent. It is assigned automatically.")
        end

        if abm.parameters[old(g)].update
            push!(code.args,:($(new(old(g)))[i1New_]=$f))
        else
            push!(code.args,:($(old(g))[i1New_]=$f))
        end
        push!(args,g)

    end

    #Add parameters to agent that have not been user defined
    for i in updateargs
        if !(i in args) && !(new(i) in args)
            if abm.parameters[i].update
                push!(code.args,:($(new(i))[i1New_]=$i[i1_]))
            else
                push!(code.args,:($i[i1New_]=$i[i1_]))
            end
        end
    end

    #Make code
    code = quote
            i1New_ = N+Threads.atomic_add!(NAdd_,1) + 1
            idNew_ = Threads.atomic_add!(idMax_,1) + 1
            if nMax_ >= i1New_
                # flagNeighbors_[i1New_] = 1
                id[i1New_] = idNew_
                flagRecomputeNeighbors_ = 1
                # flagNeighbors_[i1New_] = 1
                flagSurvive_[i1New_] = 1
                $code
            else
                Threads.atomic_add!(NAdd_,-1)
            end
        end

    #Adapt code to platform
    code = cudaAdapt(code,abm.platform)

    code = vectorize(code,abm)

    return esc(code)
end

######################################################################################################
# remove agent code
######################################################################################################
"""
    macro removeAgent()

Macro that returns the special code based on the arguments provided to `removeAgent()`.
"""
macro removeAgent()

    abm = AGENT
    code = quote end

    #Add 1 to the number of removed
    #Add the cell position to the list of removed
    #Set survived to 0
    code = quote
            idNew_ = Threads.atomic_add!(NRemove_,1) + 1
            holeFromRemoveAt_[idNew_] = i1_ 
            flagSurvive_[i1_] = 0
            flagRecomputeNeighbors_ = 1
        end

    code = vectorize(code,abm)

    #Adapt to platform
    code = cudaAdapt(code,abm.platform)

    return esc(code)

end

######################################################################################################
# local function
######################################################################################################
"""
    function functionRule(abm,scope)

Creates the final code provided to ABM in a Rule function and adds it to the ABM. `scope` is between `agent`, `model` and `medium`.
"""
function functionRule(abm,scope)

    ref = addSymbol(scope,"Rule")

    if !isemptyupdaterule(abm,ref)
        code = abm.declaredUpdates[ref]

        #Vectorize
        code = vectorize(code,abm)
        if scope == :agent
            code = vectorizeMediumInAgents(code,abm)
        end
        #Put in loop
        if ! contains(string(code),"@loopOverAgents") && scope == :agent
            code = makeSimpleLoop(code,abm)
        elseif ! contains(string(code),"@loopOverMedium") && scope == :medium
            code = makeSimpleLoop(code,abm,nloops=abm.dims)
        end

        aux = addCuda(:(rule_($(agentArgs(abm,sym=:community)[1:end-1]...))),scope,abm) #Add code to execute kernel in cuda if GPU
        abm.declaredUpdatesCode[ref] = :(function (community)
                                                        function rule_($(agentArgs(abm)[1:end-1]...),)

                                                            $code

                                                            return
                                                        end

                                                        $aux
                                                        
                                                        return 
                                                    end)
        abm.declaredUpdatesFunction[ref] = Main.eval(
            :($(abm.declaredUpdatesCode[ref]))
        )
    else
        abm.declaredUpdatesFunction[ref] = Main.eval(:((community) -> nothing))
    end

end