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
                    error(i, " should be and expression containing at least a name and a type. Example variable::Variable.") 
                elseif typeof(name) == Expr
                    if !(name.head == :vect)
                        error(name, " should be a symbol or an array of symbols. Check how to declare ", type, " types.")
                    else
                        names = Symbol[]
                        for j in name.args
                            if typeof(j) != Symbol
                                error(j, " in ", i, " should be a symbol.  Check how to declare ", type, " types.")
                            end
                            push!(names,j)
                        end
                        name = names
                    end
                end    

                if type == :BaseModel
                    if typeof(name) == Array{Symbol,1}
                        for baseModel in name
                            baseModel = eval(baseModel)

                            if m.dims != baseModel.dims
                                error("Base model", name," has different dimensions as model that is being declared.")
                            end

                            for i in keys(declaredSymbols)
                                if i == Local
                                    checkDeclared_(m,getproperty(baseModel,i))
                                    append!(m.declaredSymbols[string(type)],getproperty(baseModel,i)[(m.dims+1):end])
                                end
                            end
                        end
                    else
                        baseModel = eval(name)

                        if m.dims != baseModel.dims
                            error("Base model", name," has different dimensions as model that is being declared.")
                        end

                        for i in keys(declaredSymbols)
                            if i == Local
                                checkDeclared_(m,getproperty(baseModel,i))
                                append!(m.declaredSymbols[string(type)],getproperty(baseModel,i)[(m.dims+1):end])
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
                    end
                elseif i.args[1] == :(Boundary)
                    if boundaryDeclared
                        error("Boundary can only be declared once.")
                    end
                    boundary = Main.eval(i.args[2])
                    if !(typeof(boundary)<:Boundary)
                        error("Boundary has to be declared with a type boundary.")
                    elseif dims != boundary.dims
                        error("Boundary must have the same dimensions as the agent.") 
                    else
                        m.boundary = boundary
                        boundaryDeclared = true
                    end
                else
                    error(i.args[1], " is not a valid type.")
                end
            else
                error(i, " is not an understood rule or variable declaration. Error in ", ii)
            end 
        end
    end

    if !boundaryDeclared && !isempty(m.declaredSymbols["Medium"])
        error("If medium variables are declared, a boundary must be explicitely declared.")
    elseif !boundaryDeclared
        m.boundary = BoundaryFlat(dims)
    end
        
    return m
end

