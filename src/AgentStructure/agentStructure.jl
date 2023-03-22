"""
    function getEquation(sym,code,agent)

Sets to true the the variable field of UserParameters
"""
function getEquation(sym,code,agent)

    agent.parameters[sym].variable = true
    agent.parameters[sym].pos = sum([j.variable for (i,j) in agent.parameters])

    return code

end

"""
    function getEquations!(agent)

Go over the code in updateVariable and looks for parameters defined as variables.
"""
function getEquations!(agent)

    for update in keys(agent.declaredUpdates)
        code = agent.declaredUpdates[update]

        code = postwalk(x->@capture(x,d(s_)=g_) ? getEquation(s,x,agent) : x, code)
    end

    return

end

"""
    function getEquationMedium(sym,code,agent)

Sets to true the the variableMedium field of UserParameters
"""
function getEquationMedium(sym,code,agent)

    agent.parameters[sym].variableMedium = true
    agent.parameters[sym].pos = sum([j.variableMedium for (i,j) in agent.parameters])

    return code

end

"""
    function getEquationsMedium!(agent)

Go over the code in updateVariable and looks for parameters defined as medium variables.
"""
function getEquationsMedium!(agent)

    for update in keys(agent.declaredUpdates)

        code = agent.declaredUpdates[update]

        code = postwalk(x->@capture(x,∂t(s_)=g_) ? getEquationMedium(s,x,agent) : x, code)

    end

    return

end

"""
    mutable struct Agent

Basic structure which contains the user defined parmeters of the model, the user rules of the agents, both in high level definition and the functions already compiled.

# Elements

| Field | Description |
|:---|:---|
| dims::Int | Dimensions of the model. |
| declaredVariables::OrderedDict{Symbol,Equation} | Dictionary containing the parameters that have a differential equation describing their evolution assotiated. |
| declaredVariablesMedium::OrderedDict{Symbol,EquationMedium} | Dictionary containing the parameters that have a partial differential equation describing their evolution assotiated. |
| declaredSymbols::OrderedDict{Symbol,Array{Any}} | Dictionary of parameters of the model and its properties. |
| declaredUpdates::Dict{Symbol,Expr} |  Dictionary of updating rules and their user defined content (high level code). |
| declaredUpdatesCode::Dict{Symbol,Expr} | Dictionary of updating rules after wrapping into code (low level code). |
| declaredUpdatesFunction::Dict{Symbol,Function} | Dictionary of updting rules and the compiled functions (compiled code). |
| neighbors::Symbol | Type of neighbors computation of the model. |
| integrator::Symbol | Type of integrator for the Differential Equations of the model. |
| platform::Symbol | Platform used for evolving the model. |
| removalOfAgents_::Bool | Stores the information to check wether agents are removed in the code. Auxiliar parameter for generating the code. |
| posUpdated_::Vector{Bool} | Stores the information to check wether position parameters (x,y,z) are updated in the code. Auxiliar parameter for generating the code. |

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
        integratorMedium::Symbol=:Centered,
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

|| Argument | Description |
|:---:|:---|:---|
| Args | dims | Dimensions of the system. |
| KwArgs | localInt::Vector{Symbol}=Symbol[] | User defined local integer parameters. |
|| localIntInteraction::Vector{Symbol}=Symbol[] | User defined local integer interacting parameters. |
|| localFloat::Vector{Symbol}=Symbol[] | User defined local float parameters. |
|| localFloatInteraction::Vector{Symbol}=Symbol[] | User defined local float interacting parameters. |
|| globalFloat::Vector{Symbol}=Symbol[] | User defined global float parameters. |
|| globalInt::Vector{Symbol}=Symbol[] | User defined global integer parameters. |
|| globalFloatInteraction::Vector{Symbol}=Symbol[] | User defined global float interacting parameters. |
|| globalIntInteraction::Vector{Symbol}=Symbol[] | User defined global integer interacting parameters. |
|| medium::Vector{Symbol}=Symbol[] | User defined medium (float) parameters. |
|| baseModelInit::Vector{Agent}=Agent[] | Models inherited to construct this model and which rules apply before this one. |
|| baseModelEnd::Vector{Agent}=Agent[] | Models inherited to construct this model and which rules apply after this one. |
|| neighbors::Symbol=:Full | Type of neighbor method used. |
|| integrator::Symbol=:Euler | Type of integrator used. |
|| integratorMedium::Symbol=:Centered | Type of discretizer used for the spatial medium. |
|| platform::Symbol=:CPU | Platform in which the agent will run. |
|| saving::Symbol=:RAM | Saving platform. |
|| updateGlobal::Expr=quote end | Update rule for global parameters. |
|| updateLocal::Expr=quote end | Update rule for local parameters. |
|| updateInteraction::Expr=quote end | Update rule for interacting parameters. |
|| updateMedium::Expr=quote end | Update rule for medium parameters. |
|| updateMediumInteraction::Expr=quote end | Update rule for medium interaction parameters. |
|| updateVariable::Expr=quote end | Update rule for diferential equation defining evolution of parameters. |

For a more extense explanation of how to define rules and parameters, read `Usage` in the documentation.
"""
mutable struct Agent

    dims::Int    

    positionParameters::OrderedDict{Symbol,DataType}

    parameters::OrderedDict{Symbol,UserParameter}
    
    declaredUpdates::Dict{Symbol,Expr}
    declaredUpdatesCode::Dict{Symbol,Expr}
    declaredUpdatesFunction::Dict{Symbol,Function}
    neighbors::Symbol
    platform::Symbol
    removalOfAgents_::Bool
    solveAlgorithm::Union{Symbol,DEAlgorithm}
    solveKwargs::Dict{Symbol,Any}
    solveMediumAlgorithm::Union{Symbol,DEAlgorithm}
    solveMediumKwargs::Dict{Symbol,Any}
        
    function Agent()
        new(0,
            OrderedDict{Symbol,DataType}(),
            OrderedDict{Symbol,DataType}(),
            Dict{Symbol,Expr}(),
            Dict{Symbol,Expr}(),
            Dict{Symbol,Function}(),
            :Full,
            :CPU,
            false,
            :Euler,
            Dict{Symbol,Any}(),
            Euler(),
            Dict{Symbol,Any}(),
            )
    end

    function Agent(
            dims;
            agentParameters=OrderedDict{Symbol,DataType}(),
            modelParameters=OrderedDict{Symbol,DataType}(),
            mediumParameters=OrderedDict{Symbol,DataType}(),
            positionParameters=OrderedDict(
                :x=>Float64,
                :y=>Float64,
                :z=>Float64,
            ),
            baseModelInit::Vector{Agent}=Agent[],
            baseModelEnd::Vector{Agent}=Agent[],

            updateGlobal::Expr=quote end,
            updateLocal::Expr=quote end,
            updateMedium::Expr=quote end,
            updateVariableDeterministic::Expr=quote end,
            updateVariableStochastic::Expr=quote end,

            neighbors::Symbol=:Full,
            platform::Symbol=:CPU,    
            solveAlgorithm::Union{Symbol,DEAlgorithm} = :Euler,
            solveKwargs::Dict{Symbol,Any} = Dict{Symbol,Any}(),
            solveMediumAlgorithm::Union{Symbol,DEAlgorithm} = Euler(),
            solveMediumKwargs::Dict{Symbol,Any} = Dict{Symbol,Any}(),

            compile = true,
        )

        agent = Agent()

        agent.dims = dims
        if neighbors in NEIGHBORSYMBOLS
            agent.neighbors = neighbors
        else
            error("Neighbors algorithm ", neighbors, " not defined. Specify among: ", NEIGHBORSYMBOLS)
        end
        if platform in PLATFORM
            agent.platform = platform
        else
            error("Platform ", platform, " not defined. Specify among: ", PLATFORM)
        end
        if typeof(solveAlgorithm) == Symbol
            if solveAlgorithm in keys(SOLVERS)
                agent.solveAlgorithm = solveAlgorithm
            else
                error("solveAlgorithm does not exist. Possible algorithms are: $(SOLVERS...) or DifferentialEquations algorithms from ODE or SDE." )
            end
        else
            agent.solveAlgorithm = solveAlgorithm
        end
        agent.solveKwargs = solveKwargs
        for (s,val) in DEFAULTSOLVEROPTIONS
            if !(s in keys(agent.solveKwargs))
                agent.solveKwargs[s] = val
            end
        end
        agent.solveMediumAlgorithm = solveMediumAlgorithm
        agent.solveMediumKwargs = solveMediumKwargs
        for (s,val) in DEFAULTSOLVEROPTIONS
            if !(s in keys(agent.solveMediumKwargs))
                agent.solveMediumKwargs[s] = val
            end
        end

        #Add basic agent symbols
        for (i,sym) in enumerate(keys(positionParameters))
            if i <= dims
                agent.parameters[sym] = UserParameter(positionParameters[sym],:agent)
            end
        end

        #Parameters
        for (arg,scope) = [
                            (agentParameters,:agent),
                            (modelParameters,:model),
                            (mediumParameters,:medium)            
                            ]
            params = 0
            if typeof(arg) == DataType
                params = OrderedDict([i=>j for (i,j) in zip(fieldnames(arg),fieldtypes(arg))])
            else
                params = OrderedDict(arg)
            end
            for (par,dataType) in pairs(params)
                checkDeclared(par,agent)
                agent.parameters[par] = UserParameter(dataType,scope)
            end
        end

        #Add symbols from base objects
        for base in [baseModelInit; baseModelEnd]
            for (i,j) in pairs(base.parameters)
                if !(i in keys(BASEPARAMETERS))
                    checkDeclared(i,agent)
                    agent.parameters[i] = j
                end
            end
        end
        
        #Add Updates
        for a in baseModelInit
            for (update,code) in pairs(a.declaredUpdates)
                if update in keys(agent.declaredUpdates)
                    push!(agent.declaredUpdates[update].args, copy(code))
                else
                    agent.declaredUpdates[update] = copy(code)
                end
            end
        end
        for (update,code) in zip(UPDATES, [updateGlobal, 
                                            updateLocal,  
                                            updateMedium, 
                                            updateVariableDeterministic,
                                            updateVariableStochastic])
            if update in keys(agent.declaredUpdates)
                push!(agent.declaredUpdates[update].args, code)
            else
                agent.declaredUpdates[update] = code
            end
        end
        for a in baseModelEnd
            for (update,code) in pairs(a.declaredUpdates)
                if update in keys(agent.declaredUpdates)
                    push!(agent.declaredUpdates[update].args, copy(code))
                else
                    agent.declaredUpdates[update] = copy(code)
                end
            end
        end

        # #Make explicit the updates by adding the .new tag
        # potentiallyUpdatingVars = [i for (i,var) in pairs(agent.parameters)]
        # for i in keys(agent.declaredUpdates)
        #     code = agent.declaredUpdates[i]
        #     for sym in potentiallyUpdatingVars
        #         for op in UPDATINGOPERATORS
        #             code = postwalk(x-> isexpr(x,op) ? change(sym,x) : x, code)
        #         end
        #     end
        #     agent.declaredUpdates[i] = code
        # end

        # #Change variables updated to modifiable
        # for update in keys(agent.declaredUpdates)

        #     for (sym,var) in pairs(agent.parameters)
        #         if inexpr(agent.declaredUpdates[update],:($sym.new))
        #             agent.parameters[sym].update = true
        #         elseif inexpr(agent.declaredUpdates[update],BASESYMBOLS[:AddAgentMacro].symbol) && agent.parameters[sym].scope == :agent #If add agents, all local parameters are modifiable
        #             agent.parameters[sym].update = true
        #         end
        #     end

        #     getEquations!(agent)

        #     getEquationsMedium!(agent)

        # end

        #Variables
        count = 0
        for sym in keys(agent.parameters)
            if inexpr(updateVariableDeterministic,:(dt($sym))) || inexpr(updateVariableStochastic,:(dt($sym)))
                count += 1
                agent.parameters[sym].variable = true            
                agent.parameters[sym].pos = count
            end        
        end

        #Check if there are removed agents
        agent.removalOfAgents_ = true
        for update in keys(agent.declaredUpdates)
            if inexpr(agent.declaredUpdates[update],:removeAgent)
                agent.removalOfAgents_ = true
            end
            if inexpr(agent.declaredUpdates[update],:@removeAgent)
                agent.removalOfAgents_ = true
            end
        end        

        global AGENT = agent

        #Make compiled functions
        if compile 
            localFunction(agent)
            # globalFunction(agent)
            neighborsFunction(agent)
            # interactionFunction(agent)
            # integratorFunction(agent)
            integrator2Function(agent)
            # integratorMediumFunction(agent)
        end

        return agent
    end

end

function Base.show(io::IO,abm::Agent)
    print("PARAMETERS\n")
    for (i,j) in pairs(abm.parameters)
        if string(i)[end] != '_' #Only print parameters used by the user 
            println("\t",i," (",j.dtype," ",j.scope,")")
        end
    end

    print("\n\nUPDATE RULES\n")
    for i in keys(abm.declaredUpdates)
        if [i for i in prettify(abm.declaredUpdates[i]).args if typeof(i) != LineNumberNode] != []
            print(i,"\n")
            print(" ",prettify(copy(abm.declaredUpdates[i])),"\n\n")
        end
    end
end

"""
    function checkDeclared(a::Symbol, agent::Agent) 
    function checkDeclared(a::Array{Symbol}, agent::Agent) 

Check if a symbol is already declared in the model or inherited models.
"""
function checkDeclared(a::Array{Symbol}, agent::Agent) 

    for s in a
        checkDeclared(s,agent)
    end

end

function checkDeclared(a::Symbol, agent::Agent) 

    if a in keys(agent.parameters)
        error("Symbol ", a, " already declared in the agent.")
    end

end

"""
    function change(x,code)

Function called by update to add the .new if it is an update expression (e.g. x += 4 -> x.new += 4).
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
