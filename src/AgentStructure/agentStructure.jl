"""
    mutable struct Agent

Basic structure which contains the high level code specifying the rules of the agents. 

# Elements

 - **dims::Int**: Dimensions of the model.
 - **declaredSymbols::OrderedDict{Symbol,Array{Any}}**: Dictionary of parameters of the model and its properties.
 - **declaredUpdates::Dict{Symbol,Expr}**:  Dictionary of updating rules.
 - **declaredUpdatesCode::Dict{Symbol,Expr}**: Dictionary of updating rules after wrapping into code.
 - **declaredUpdatesFunction::Dict{Symbol,Function}**: Dictionary of updting rules and the compiled functions.
 - **neighbors::Symbol**: Type of neighbors computation of the model.
 - **integrator::Symbol**: Type of integrator for the Differential Equations of the model.
 - **platform::Symbol**: Platform used for evolving the model.
 - **saving::Symbol**: Saving method.

# Constructors

    function Agent()

Generates an empty instance of Agent to be filled.

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
        updateInteraction::Expr=quote end,
        updateMedium::Expr=quote end,
        updateMediumInteraction::Expr=quote end,
        updateVariable::Expr=quote end
        )

Generates an agent based model with defined parameters and rules.

## Arguments
 - **dims**: Dimensions of the system.

## Keyword arguments
 - **localInt::Vector{Symbol}=Symbol[]**: User defined local integer parameters.
 - **localIntInteraction::Vector{Symbol}=Symbol[]**: User defined local integer interacting parameters.
 - **localFloat::Vector{Symbol}=Symbol[]**: User defined local float parameters.
 - **localFloatInteraction::Vector{Symbol}=Symbol[]**: User defined local float interacting parameters.
 - **globalFloat::Vector{Symbol}=Symbol[]**: User defined global float parameters.
 - **globalInt::Vector{Symbol}=Symbol[]**: User defined global integer parameters.
 - **globalFloatInteraction::Vector{Symbol}=Symbol[]**: User defined global float interacting parameters.
 - **globalIntInteraction::Vector{Symbol}=Symbol[]**: User defined global integer interacting parameters.
 - **medium::Vector{Symbol}=Symbol[]**: User defined medium (float) parameters.
 - **baseModelInit::Vector{Agent}=Agent[]**: Models inherited to construct this model and which rules apply before this one.
 - **baseModelEnd::Vector{Agent}=Agent[]**: Models inherited to construct this model and which rules apply after this one.
 - **neighbors::Symbol=:Full**: Type of neighbor method used.
 - **integrator::Symbol=:Euler**: Type of integrator used.
 - **platform::Symbol=:CPU**: Platform in which the agent will run.
 - **saving::Symbol=:RAM**: Saving platform.
 - **updateGlobal::Expr=quote end**: Update rule for global parameters.
 - **updateLocal::Expr=quote end**: Update rule for local parameters.
 - **updateInteraction::Expr=quote end**: Update rule for interacting parameters.
 - **updateMedium::Expr=quote end**: Update rule for medium parameters.
 - **updateMediumInteraction::Expr=quote end**: Update rule for medium interaction parameters.
 - **updateVariable::Expr=quote end**: Update rule for diferential equation defining evolution of parameters.

For a more extense explanation of how to define rules and parameters, read `Usage` in the documentation.
"""
mutable struct Agent

    dims::Int
    
    declaredSymbols::OrderedDict{Symbol,UserParameter}
    declaredUpdates::Dict{Symbol,Expr}
    declaredUpdatesCode::Dict{Symbol,Expr}
    declaredUpdatesFunction::Dict{Symbol,Function}
    neighbors::Symbol
    integrator::Symbol
    platform::Symbol
    saving::Symbol
    removalOfAgents_::Bool
    posUpdated_::Vector{Bool}
        
    function Agent()
        new(0,
            OrderedDict{Symbol,Array{Symbol}}(),
            Dict{Symbol,Expr}(),
            Dict{Symbol,Expr}(),
            Dict{Symbol,Function}(),
            :Full,
            :Euler,
            :CPU,
            :RAM,
            false,
            [false,false,false]
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
        updateInteraction::Expr=quote end,
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

        #User defined symbols
        for (i,j) in [                                        #dtype    #scope      #reset     #basePar    #pos
                    (localInt,                  UserParameter(:Int,     :Local,      false,    :liNM_,      1)),
                    (localIntInteraction,       UserParameter(:Int,     :Local,      true,     :lii_,       1)),
                    (localFloat,                UserParameter(:Float,   :Local,      false,    :lfNM_,      1)),
                    (localFloatInteraction,     UserParameter(:Float,   :Local,      true,     :lfi_,       1)),
                    (globalFloat,               UserParameter(:Float,   :Global,     false,    :gfNM_,      1)),
                    (globalFloatInteraction,    UserParameter(:Float,   :Global,     true,     :gfi_,       1)),
                    (globalInt,                 UserParameter(:Int,     :Global,     false,    :giNM_,      1)),
                    (globalIntInteraction,      UserParameter(:Int,     :Global,     true,     :gii_,       1)),
                    (medium,                    UserParameter(:Float,   :Medium,     false,    :medium_,    1))]
            checkDeclared(i,agent)
            for sym in i
                agent.declaredSymbols[sym] = deepcopy(j)
            end
        end
        #Add symbols from base objects
        for base in [baseModelInit; baseModelEnd]
            for (i,j) in pairs(base.declaredSymbols)
                if !(i in keys(BASEPARAMETERS))
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
        for (update,code) in zip(UPDATES, [updateGlobal, 
                                            updateLocal, 
                                            updateInteraction, 
                                            updateMedium, 
                                            updateMediumInteraction, 
                                            updateVariable])
            agent.declaredUpdates[update] = code
        end
        for a in baseModelEnd
            for update in UPDATES
                agent.declaredUpdates[update] = a.updates[update]
            end
        end

        #Make explicit the updates by adding the .new tag
        potentiallyUpdatingVars = [[i for (i,var) in pairs(agent.declaredSymbols) if !(var.reset)]...,POSITIONPARAMETERS[1:agent.dims]...]
        for i in keys(agent.declaredUpdates)
            code = agent.declaredUpdates[i]
            for sym in potentiallyUpdatingVars
                for op in UPDATINGOPERATORS
                    code = postwalk(x-> isexpr(x,op) ? change(sym,x) : x, code)
                end
            end
            agent.declaredUpdates[i] = code
        end

        #Change variables updated to modifiable
        for update in [:UpdateLocal]#keys(agent.declaredUpdates)
            for (sym,var) in pairs(agent.declaredSymbols)
                if inexpr(agent.declaredUpdates[update],:($sym.new)) && !(var.reset)
                    var.basePar = baseParameterToModifiable(var.basePar)
                    agent.declaredSymbols[sym]  = var
                elseif inexpr(agent.declaredUpdates[update],BASESYMBOLS[:AddAgentMacro].symbol) && !(var.reset) #If add agents, all local parameters are modifiable
                    var.basePar = baseParameterToModifiable(var.basePar)
                    agent.declaredSymbols[sym]  = var
                end
            end
        end

        #Make list of positions of user parameters
        for find in unique([j.basePar for (i,j) in pairs(agent.declaredSymbols)])
            vars = [j for (i,j) in pairs(agent.declaredSymbols) if j.basePar == find]
            for (count,var) in enumerate(vars)
                var.position = count
            end
        end

        #Check if there is removed agents
        for update in keys(agent.declaredUpdates)
            for (sym,var) in pairs(agent.declaredSymbols)
                if inexpr(agent.declaredUpdates[update],:removeAgent)
                    agent.removalOfAgents_ = true
                end
            end
        end        

        #Check which position vectors are updated
        new = BASESYMBOLS[:UpdateSymbol].symbol
        for update in keys(agent.declaredUpdates)
            if inexpr(agent.declaredUpdates[update],:($(POSITIONPARAMETERS[1]).$new)) || inexpr(agent.declaredUpdates[update],BASESYMBOLS[:AddAgentMacro])
                agent.posUpdated_[1] = true
            end
            if inexpr(agent.declaredUpdates[update],:($(POSITIONPARAMETERS[2]).$new)) || inexpr(agent.declaredUpdates[update],BASESYMBOLS[:AddAgentMacro])
                agent.posUpdated_[2] = true
            end
            if inexpr(agent.declaredUpdates[update],:($(POSITIONPARAMETERS[3]).$new)) || inexpr(agent.declaredUpdates[update],BASESYMBOLS[:AddAgentMacro])
                agent.posUpdated_[3] = true
            end
        end    

        #Make compiled functions
        localFunction(agent)
        # localInteractionsFunction(agent)

        return agent
    end

end

function Base.show(io::IO,abm::Agent)
    print("PARAMETERS\n")
    for (i,j) in pairs(abm.declaredSymbols)
        if string(i)[end] != '_' #Only print parameters used by the user 
            println("\t",i," (",j.dtype," ",j.shape,")")
        end
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

    new = BASESYMBOLS[:UpdateSymbol].symbol
    if code.args[1] == x
        code.args[1] = :($x.$new)
    end
    for op in [BASESYMBOLS[:InteractionIndex1],BASESYMBOLS[:InteractionIndex2]]
        if code.args[1] == :($x.$op)
            code.args[1] = :($x.$new.$op)
        end
    end

    return code
end

# """
# Function called by update that checks that a function is a macro functions before adding the .new
# """
# function updateMacroFunctions(s,code)
#     if code.args[1] in [BASESYMBOLS[:AddAgentMacro],BASESYMBOLS[:RemoveAgentMacro]]
#         code = postwalk(x-> isexpr(x,:kw) ? change(s,x) : x, code)
#     end

#     return code
# end

# """
# Function that adds the new operator to all the times the symbol s is being updated. e.g. update(x=1,x) -> x.new = 1.
# The modifications are also done in the keyword arguments of the macro functions as addAgent.
# """
# function update(code,s)

#     for op in UPDATINGOPERATORS
#         code = postwalk(x-> isexpr(x,op) ? change(s,x) : x, code)
#     end
#     code = postwalk(x-> isexpr(x,:call) ? updateMacroFunctions(s,x) : x, code) #Update keyarguments of macrofunctions

#     return code
# end

# function addUpdates!(p::Agent)

#     ##Assign updates of variable types
#     for par in [keys(p.declaredSymbols)...,POSITIONPARAMETERS[1:agent.dims]...]

#         #Find updates
#         for up in keys(p.declaredUpdates)

#             code =  postwalk(x->@capture(x, c_.new)  && c == par.name ? :ARGS_ : x , p.declaredUpdates[up]) #remove agent updates
#             code =  postwalk(x->@capture(x, c_.g_.new) && c == par.name && g in INTERACTIONSYMBOLS ? :ARGS_ : x , code)
            
#             if inexpr(code,:ARGS_) && !(par in keys(p.declaredSymbols))
#                 parNew = Meta.parse(string(par,"New_"))
#                 p.declaredSymbols[parNew] = [p.declaredUpdates[1],p.declaredUpdates[2],:New]
#             end

#         end

#         #Find variables
#         for up in keys(p.declaredUpdates)

#             code =  postwalk(x->@capture(x, g_(c_) = f_) && c == par.name && g == DIFFSYMBOL ? :ARGS_ : x , p.declaredUpdates[up])
            
#             if inexpr(code,:ARGS_) && !(par in keys(p.declaredSymbols))
#                 parNew = Meta.parse(string(par,"New_"))
#                 p.declaredSymbols[parNew] = [p.declaredUpdates[1],p.declaredUpdates[2],:New]
#             end

#         end

#     end        
    
#     return
# end
