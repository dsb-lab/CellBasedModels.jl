"""
Function called by update to add the .new if it is an update expression.
"""
function change(x,code)

    if code.args[1] == x
        code.args[1] = :($x.new)
    end
    for op in INTERACTIONSYMBOLS
        if code.args[1] == :($x.$op)
            code.args[1] = :($x.$op.new)
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

    for op in UPDATEOPERATORS
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

    m = Agent()
    m.dims = dims

    if dims == 0
        nothing
    elseif dims == 1
        push!(m.declaredSymbols["Local"],:x)
    elseif dims == 2
        push!(m.declaredSymbols["Local"],:x,:y)
    elseif dims == 3
        push!(m.declaredSymbols["Local"],:x,:y,:z)
    else
        error("Dims has to be an integer between 0 and 3.")
    end
    push!(m.declaredSymbols["Identity"],:id)

    #Add all contributions
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

                if !(type in VALID_TYPES)
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
                        error(i, " should be and expression containing at least a name and a type. Example variable::Variable.") 
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

                            for i in keys(m.declaredSymbols)
                                if i == "Local"
                                    checkDeclared_(m,baseModel.declaredSymbols[i][(m.dims+1):end])
                                    append!(m.declaredSymbols[i],baseModel.declaredSymbols[i][(m.dims+1):end])
                                elseif i == "Identity"
                                    checkDeclared_(m,baseModel.declaredSymbols[i][2:end])
                                    append!(m.declaredSymbols[i],baseModel.declaredSymbols[i][2:end])
                                else
                                    checkDeclared_(m,baseModel.declaredSymbols[i])
                                    append!(m.declaredSymbols[i],baseModel.declaredSymbols[i])
                                end
                            end

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

                        for i in keys(m.declaredSymbols)
                            if i == "Local"
                                checkDeclared_(m,baseModel.declaredSymbols[i][(m.dims+1):end])
                                append!(m.declaredSymbols[i],baseModel.declaredSymbols[i][(m.dims+1):end])
                            elseif i == "Identity"
                                checkDeclared_(m,baseModel.declaredSymbols[i][2:end])
                                append!(m.declaredSymbols[i],baseModel.declaredSymbols[i][2:end])
                            else
                                checkDeclared_(m,baseModel.declaredSymbols[i])
                                append!(m.declaredSymbols[i],baseModel.declaredSymbols[i])
                            end
                        end

                        for i in keys(baseModel.declaredUpdates)
                            if !(i in keys(m.declaredUpdates))
                                m.declaredUpdates[i] = copy(baseModel.declaredUpdates[i])
                            else
                                append!(m.declaredUpdates[i].args,baseModel.declaredUpdates[i].args)
                            end
                        end                            
                    end

                else
                    checkDeclared_(m,name)
                    if typeof(name) == Array{Symbol,1}
                        append!(m.declaredSymbols[string(type)],name)
                    else
                        push!(m.declaredSymbols[string(type)],name)
                    end
                end

            elseif i.head == :(=)
                if i.args[1] in VALID_UPDATES
                    if !(string(i.args[1]) in keys(m.declaredUpdates))
                        if i.args[2].head == :block
                            m.declaredUpdates[string(i.args[1])] = i.args[2]
                        else
                            m.declaredUpdates[string(i.args[1])] = quote $(i.args[2]) end
                        end
                    elseif i.args[2].head == :block
                        append!(m.declaredUpdates[string(i.args[1])].args,i.args[2].args)
                    else
                        push!(m.declaredUpdates[string(i.args[1])].args,i.args[2])
                    end
                else
                    error(i.args[1], " is not a valid type.")
                end
            else
                error(i, " is not an understood rule or variable declaration. Error in ", ii)
            end 
        end
    end

    for i in keys(m.declaredUpdates) #Make explicit the updates
        code = m.declaredUpdates[i]
        for j in UPDATINGTYPES
            for k in m.declaredSymbols[j]
                code = update(code,k)
            end
        end

        m.declaredUpdates[i] = code
    end

        
    return m
end

