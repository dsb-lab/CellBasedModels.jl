"""
    mutable struct Agent

Basic structure which contains the high level code specifying the rules of the agents. 
For constructing such agents, it is advised to use the macro function `@agent`.

# Elements

 - **dims::Int**: Dimensions of the model.
 - **declaredSymbols::Dict{String,Array{Symbol,1}}**: Dictionary containing all the parameters of the model.
 - **declaredUpdates::Dict{String,Expr}**: Dictionary containing all the code specifying the rules of the agents.
"""
mutable struct Agent

    dims::Int
    
    declaredSymbols::Dict{Symbol,Array{Symbol}}
    declaredUpdates::Dict{Symbol,Expr}
    declaredUpdatesCode::Dict{Symbol,Expr}
    declaredUpdatesFunction::Dict{Symbol,Function}
    neighbors::Symbol
    integrator::Symbol
    platform::Symbol
    saving::Symbol
        
    function Agent()
        new(0,
            Dict{Symbol,Array{Symbol}}(),
            Dict{Symbol,Expr}(),
            Dict{Symbol,Expr}(),
            Dict{Symbol,Function}(),
            :Full,
            :Euler,
            :CPU,
            :RAM
            )
    end

    function Agent(dims;
        localInt::Vector{Symbol}=Symbol[],
        localIntInteraction::Vector{Symbol}=Symbol[],
        localFloat::Vector{Symbol}=Symbol[],
        localFloatInteraction::Vector{Symbol}=Symbol[],
        globalFloat::Vector{Symbol}=Symbol[],
        globalInt::Vector{Symbol}=Symbol[],
        globalFloatInteraction::Vector{Symbol}=Symbol[],
        globalIntInteraction::Vector{Symbol}=Symbol[],
        medium::Vector{Symbol}=Symbol[],
        baseModelInit::Vector{Agent}=Agent[],
        baseModelEnd::Vector{Agent}=Agent[],
        neighbors::Symbol=:Full,
        integrator::Symbol=:Euler,
        platform::Symbol=:CPU,
        saving::Symbol=:RAM,
        updateGlobal::Expr=quote end,
        updateLocal::Expr=quote end,
        updateLocalInteraction::Expr=quote end,
        updateGlobalInteraction::Expr=quote end,
        updateMedium::Expr=quote end,
        updateMediumInteraction::Expr=quote end,
        updateVariable::Expr=quote end
        )

        agent = Agent()

        agent.dims = dims
        if neighbors in keys(NEIGHBORSYMBOLS)
            agent.neighbors = neighbors
        else
            error("Neighbors algorithm ", neighbors, " not defined. Specify among: ", keys(NEIGHBORSYMBOLS))
        end
        if integrator in INTEGRATOR
            agent.integrator = integrator
        else
            error("Neighbors algorithm ", integrator, " not defined. Specify among: ", INTEGRATOR)
        end
        if platform in PLATFORM
            agent.platform = platform
        else
            error("Neighbors algorithm ", platform, " not defined. Specify among: ", PLATFORM)
        end
        if saving in SAVING
            agent.saving = saving
        else
            error("Neighbors algorithm ", saving, " not defined. Specify among: ", SAVING)
        end

        #Add Symbols
            #Base symbols
        for (i,j) in pairs(BASESYMBOLS)
            agent.declaredSymbols[i] = j
        end
            #Position symbols
        for i in 1:1:dims
            agent.declaredSymbols[POSITIONSYMBOLS[i][1]] = POSITIONSYMBOLS[i][2]
        end
        for (i,j) in pairs(NEIGHBORSYMBOLS[neighbors])
            agent.declaredSymbols[i] = j
        end
        for (i,j) in [(localInt,[:Int,:Local,:NonInteraction]),
                    (localIntInteraction,[:Int,:Local,:Interaction]),
                    (localFloat,[:Float,:Local,:NonInteraction]),
                    (localFloatInteraction,[:Float,:Local,:Interaction]),
                    (globalFloat,[:Float,:Global,:NonInteraction]),
                    (globalFloatInteraction,[:Float,:Global,:Interaction]),
                    (globalInt,[:Int,:Global,:NonInteraction]),
                    (globalIntInteraction,[:Int,:Global,:Interaction]),
                    (medium,[:Float,:Medium,:NonInteraction])]
            checkDeclared(i,agent)
            for sym in i
                agent.declaredSymbols[sym] = j
            end
        end
            #Add symbols from base objects
        for base in [baseModelInit; baseModelEnd]
            for (i,j) in pairs(base.declaredSymbols)
                if !(i in keys(POSITIONSYMBOLS)) || !(i in keys(BASESYMBOLS))
                    checkDeclared(i,agent)
                    agent.declaredSymbols[i] = j
                end
            end
        end
        
        #Add Updates
        for a in baseModelInit
            for update in UPDATES
                agent.declaredUpdates[update] = a.updates[update]
            end
        end
        for (update,code) in zip(UPDATES, [updateGlobal, updateLocal, updateLocalInteraction, 
                                                updateGlobalInteraction, updateMedium, updateMediumInteraction, 
                                                updateVariable])
            agent.declaredUpdates[update] = code
        end
        for a in baseModelEnd
            for update in UPDATES
                agent.declaredUpdates[update] = a.updates[update]
            end
        end

        #Make explicit the updates by adding the .new tag
        potentiallyUpdatingVars = [var for (var,prop) in pairs(agent.declaredSymbols) if !(:Interaction in prop)]
        for i in keys(agent.declaredUpdates)
            code = agent.declaredUpdates[i]
            for k in potentiallyUpdatingVars
                code = update(code,k)
            end

            agent.declaredUpdates[i] = code
        end

        #Add updating variables
        for update in keys(agent.declaredUpdates)
            for sym in keys(agent.declaredSymbols)
                if inexpr(agent.declaredUpdates[update],:($sym.new)) && agent.declaredSymbols[sym][3] == :NonInteraction
                    symUpdate = Meta.parse(string(sym,"New_"))
                    agent.declaredSymbols[symUpdate] = copy(agent.declaredSymbols[sym])
                    agent.declaredSymbols[symUpdate][3] = :Update
                end
            end
        end

        #Compile code
        neighborsFunction(agent)

        return agent
    end

end

function Base.show(io::IO,abm::Agent)
    print("PARAMETERS\n")
    for (i,j) in pairs(abm.declaredSymbols)
        print("\t",i)
    end

    print("\n\nUPDATE RULES\n")
    for i in keys(abm.declaredUpdates)
        if [i for i in abm.declaredUpdates[i].args if typeof(i) != LineNumberNode] != []
            print(i,"\n")
            print(" ",prettify(copy(abm.declaredUpdates[i])),"\n\n")
        end
    end
end

function checkDeclared(a::Array{Symbol}, agent::Agent) 

    for s in a
        checkDeclared(s,agent)
    end

end

function checkDeclared(a::Symbol, agent::Agent) 

    if a in keys(agent.declaredSymbols)
        error("Symbol ", a, " already declared in the agent.")
    end

end

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

function addUpdates!(p::Agent)

    ##Assign updates of variable types
    for (par,prop) in pairs(p.declaredSymbols)

        #Find updates
        for up in keys(p.declaredUpdates)

            code =  postwalk(x->@capture(x, c_.new)  && c == par.name ? :ARGS_ : x , p.declaredUpdates[up]) #remove agent updates
            code =  postwalk(x->@capture(x, c_.g_.new) && c == par.name && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            
            if inexpr(code,:ARGS_) && !(par in keys(p.declaredSymbols))
                parNew = Meta.parse(string(par,"New"))
                p.declaredSymbols[parNew] = [p.declaredUpdates[1],p.declaredUpdates[2],:New]
            end

        end

        #Find variables
        for up in keys(p.declaredUpdates)

            code =  postwalk(x->@capture(x, g_(c_) = f_) && c == par.name && g == DIFFSYMBOL ? :ARGS_ : x , p.declaredUpdates[up])
            
            if inexpr(code,:ARGS_) && !(par in keys(p.declaredSymbols))
                parNew = Meta.parse(string(par,"New"))
                p.declaredSymbols[parNew] = [p.declaredUpdates[1],p.declaredUpdates[2],:New]
            end

        end

    end        
    
    return
end
