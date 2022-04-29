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

function addBaseModelsAgent(m,name,type)

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

    return
end

function addSymbolsAgent(m,name,type;init=nothing)

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

            if init === nothing
                init = [nothing for i in 1:length(name)]
            else
                if length(name) != length(init.args)
                    error("Declared parameters and initialization has to be of the same length. $(length(name)) parameters where declared and $(length(init.args)) initialized.")
                end
                inits = Union{Real,Nothing}[]
                for j in init.args
                    push!(inits, eval(j))
                end
                init = inits
            end
        end
    else
        name = [name]
        init = [init]
    end    
    
    checkDeclared_(m,name)
    for (i,n) in enumerate(name)
        m.declaredSymbols[string(type)][n] = init[i]
    end

    return
end

function addUpdatesAgent(m,name,code)

    if name in VALID_UPDATES
        if !(string(name) in keys(m.declaredUpdates))
            if code.head == :block
                m.declaredUpdates[string(name)] = code
            else
                m.declaredUpdates[string(name)] = quote $(code) end
            end
        elseif code.head == :block
            append!(m.declaredUpdates[string(name)].args,code.args)
        else
            push!(m.declaredUpdates[string(name)].args,code)
        end
    else
        error(name, " is not a valid type.")
    end

    return
end

"""
    macro @agent(dims, varargs...) 

Basic Macro to create an instance of Agent. It generates an Agent type with the characteristics specified in its arguments.

Check the [documentation](https://dsb-lab.github.io/AgentBasedModels.jl/dev/Usage.html#Defining-Agent-Properties) for details of the possible varargs.
"""
macro agent(dims, varargs...) 

    boundaryDeclared = false

    m = Agent()
    m.dims = dims

    if dims == 0
        nothing
    elseif dims == 1
        m.declaredSymbols["Local"][:x] = nothing
    elseif dims == 2
        m.declaredSymbols["Local"][:x] = nothing
        m.declaredSymbols["Local"][:y] = nothing
    elseif dims == 3
        m.declaredSymbols["Local"][:x] = nothing
        m.declaredSymbols["Local"][:y] = nothing
        m.declaredSymbols["Local"][:z] = nothing
    else
        error("Dims has to be an integer between 0 and 3.")
    end
    m.declaredSymbols["Identity"][:id] = nothing

    #Add all contributions
    for i in varargs
        if typeof(i) == LineNumberNode
            nothing
        else
            foundSomewhere = false
            found = @capture(i,name_::BaseModel)
            if found
                addBaseModelsAgent(m,name,type)
                foundSomewhere = true
            end
            if !foundSomewhere
                found = @capture(i,name_::type_)
                if found
                    addSymbolsAgent(m,name,type)
                    foundSomewhere = true
                end
            end
            if !foundSomewhere
                found = @capture(i,name_::type_=init_)
                if found
                    addSymbolsAgent(m,name,type,init = init)
                    foundSomewhere = true
                end
            end
            if !foundSomewhere
                found = @capture(i,name_=code_)
                if found
                    addUpdatesAgent(m,name,code)
                    foundSomewhere = true
                end
            end
            if !foundSomewhere
                error(i, " is not an understood rule or variable declaration.")
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

