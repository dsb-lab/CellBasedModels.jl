"""
Function called by update to add the .new if it is an update expression.
"""
function change(x,code)

    if code.args[1] == x
        code.args[1] = :($x.new)
    end
    for op in INTERACTIONSYMBOLS
        if code.args[1] == :($x.$op)
            code.args[1] = :($x.new.$op)
        end
    end

    return code
end

"""
Function called by update that checks that a function is a macro functions before adding the .new
"""
function updateMacroFunctions(s,code)
    if code.args[1] in MACROFUNCTIONS
        code = postwalk(x-> isexpr(x,:kw) ? change(s,x) : x, code)
    end

    return code
end

"""
Function that adds .new to all the times the symbol s is being updated. e.g. update(x=1,x) -> x.new = 1.
The modifications are also done in the keyword arguments of the macro functions as addAgent.
"""
function update(code,s)

    for op in UPDATINGOPERATORS
        code = postwalk(x-> isexpr(x,op) ? change(s,x) : x, code)
    end
    code = postwalk(x-> isexpr(x,:call) ? updateMacroFunctions(s,x) : x, code) #Update keyarguments of macrofunctions

    return code
end

"""
    macro @agent(dims, varargs...) 

Basic Macro to create an instance of Agent. It generates an Agent type with the characteristics specified in its arguments.

# Args
 - **dims**: Number of dimensions of the agent (0,1,2 or 3).

# Varargs
All the arguments that will define the behavior of the agents.
Check the [documentation](https://dsb-lab.github.io/AgentBasedModels.jl/dev/Usage.html#Defining-Agent-Properties) for the details of the possible varargs.

# Returns
 - `Agent` with the specified rules.
"""
macro agent(dims, varargs...) 

    boundaryDeclared = false

    #Create agent
    m = Agent()

    #Assign dimensions
    m.dims = dims

    #Load base symbols
    m.declaredSymbols = copy(BASESYMBOLS)

    #Add position symbols
    if 0 > dims || dims > 3
        error("Dims has to be an integer between 0 and 3.")
    elseif dims == 0
        nothing
    else
        append!(m.declaredSymbols,POSITIONSYMBOLS[1:dims,:])
    end

    #Add declared contributions
    for ii in varargs
        if typeof(ii) != Expr
            error(ii, " should be and expression containing at least a name and a type. Example variable::Variable.") 
        end

        if ii.head == :call
            t = eval(ii)
            if typeof(t) != Expr
                error("Function ", ii, " should return a piece of code to be added to the agent.")
            elseif t.head != :block
                t = quote $t end
            end

            t = t.args
        else 
            t = [ii]
        end

        for i in t
            if typeof(i) == LineNumberNode
                nothing
            elseif i.head == :(::)
                name = i.args[1]
                type = i.args[2]

                if !(type in VALIDTYPES)
                    error(type, " is not a valid tag.") 
                elseif typeof(name) == Expr
                    if !(name.head in [:vect, :.])
                        error(name, " should be a symbol or an array of symbols. Check how to declare ", type, " types.")
                    elseif name.head == :vect
                        names = Symbol[]
                        for j in name.args
                            if typeof(j) != Symbol
                                error(j, " in ", i, " should be a symbol.  Check how to declare ", type, " types.")
                            end
                            push!(names,j)
                        end
                        name = names
                    elseif !(type in [:BaseModel])
                        error(i, " should be and expression containing at least a name and a type. Example var::LocalFloat.") 
                    end
                end    

                if type == :BaseModel
                    if typeof(name) == Array{Symbol,1}
                        for baseModel in name
                            if inexpr(baseModel,:(AgentBasedModels.Models))
                                baseModel = eval(baseModel)
                            else
                                baseModel = Main.eval(baseModel)
                            end

                            if m.dims != baseModel.dims
                                error("Base model", name," has different dimensions as model ",baseModel," that is being declared.")
                            end

                            checkDeclared(m,baseModel.declaredSymbols[(size(BASEARGS)[1]+dims+1):end])
                            append!(m.declaredSymbols,baseModel.declaredSymbols[(size(BASEARGS)[1]+dims+1):end])
                            checkDeclared(m,baseModel.declaredSymbolsUpdated)
                            append!(m.declaredSymbols,baseModel.declaredSymbolsUpdated)

                            for i in keys(baseModel.declaredUpdates)
                                if !(i in keys(m.declaredUpdates))
                                    m.declaredUpdates[i] = copy(baseModel.declaredUpdates[i])
                                else
                                    append!(m.declaredUpdates[i].args,baseModel.declaredUpdates[i].args)
                                end
                            end                            
                        end
                    else
                            if inexpr(name,:(AgentBasedModels.Models))
                                baseModel = eval(name)
                            else
                                baseModel = Main.eval(name)
                            end

                        if m.dims != baseModel.dims
                            error("Base model", name," has different dimensions as model ",baseModel," that is being declared.")
                        end

                        checkDeclared(m,baseModel.declaredSymbols[(size(BASEARGS)[1]+dims+1):end])
                        append!(m.declaredSymbols,baseModel.declaredSymbols[(size(BASEARGS)[1]+dims+1):end])
                        checkDeclared(m,baseModel.declaredSymbolsUpdated)
                        append!(m.declaredSymbols,baseModel.declaredSymbolsUpdated)

                        for i in keys(baseModel.declaredUpdates)
                            if !(i in keys(m.declaredUpdates))
                                m.declaredUpdates[i] = copy(baseModel.declaredUpdates[i])
                            else
                                append!(m.declaredUpdates[i].args,baseModel.declaredUpdates[i].args)
                            end
                        end                            
                    end

                elseif type == :NeighborsAlgorithm

                    if typeof(name) != Symbol
                        error("Neighbors algorithm can only be one.")
                    end

                    try 
                        name = eval(name)
                    catch
                        error("Neighbors algorithm not known.")
                    end

                    if typeof(name)<:Integrator
                        m.neighbors = name
                    end

                elseif type == :IntegrationAlgorithm

                    if typeof(name) != Symbol
                        error("Integration algorithm can only be one.")
                    end

                    try 
                        name = eval(name)
                    catch
                        error("Integrator not known.")
                    end

                    if typeof(name)<:Integrator
                        m.integrator = name
                    end

                elseif type == :ComputingPlatform

                    if typeof(name) != Symbol
                        error("Computational platform can only be one.")
                    end

                    if name in PLATFORMS
                        m.platform = name
                    else
                        error(name, " not a valid computing platform. Valid computing platforms are: ", PLATFORMS)
                    end

                elseif type == :SavingPlatform

                    if typeof(name) != Symbol
                        error("Saving platform can only be one.")
                    end

                    if name in SAVING
                        m.saving = name
                    else
                        error(name, " not a valid saving platform. Valid saving platforms are: ", SAVING)
                    end

                else

                    checkDeclared(m,name)
                    if typeof(name) <: Array
                        for symb in name
                            push!(m.declaredSymbols,[symb,type,:General])
                        end
                    else
                        push!(m.declaredSymbols,[name,type,:General])
                    end

                end

            elseif i.head == :(=)
                if i.args[1] in VALIDUPDATES
                    if !(i.args[1] in keys(m.declaredUpdates))
                        if i.args[2].head == :block
                            m.declaredUpdates[i.args[1]] = i.args[2]
                        else
                            m.declaredUpdates[i.args[1]] = quote $(i.args[2]) end
                        end
                    elseif i.args[2].head == :block
                        append!(m.declaredUpdates[i.args[1]].args,i.args[2].args)
                    else
                        push!(m.declaredUpdates[i.args[1]].args,i.args[2])
                    end
                else
                    error(i.args[1], " is not a valid type.")
                end
            else
                error(i, " is not an understood rule or variable declaration. Error in ", ii)
            end 
        end
    end

    #Make explicit the updates by adding the .new tag
    for i in keys(m.declaredUpdates)
        code = m.declaredUpdates[i]
        for k in m.declaredSymbols[[type in UPDATINGTYPES for type in m.declaredSymbols.type],:].name
            code = update(code,k)
        end

        m.declaredUpdates[i] = code
    end

    #Add updates
    addUpdates!(m)
        
    #Add additional parameters of the integrator

    return m
end

