"""
    function getEquation(sym,code,abm)

Sets to true the the variable field of UserParameters
"""
function getEquation(sym,code,abm)

    abm.parameters[sym].variable = true
    abm.parameters[sym].pos = sum([j.variable for (i,j) in abm.parameters])

    return code

end

"""
    function getEquations!(abm)

Go over the code in updateVariable and looks for parameters defined as variables.
"""
function getEquations!(abm)

    for update in keys(abm.declaredUpdates)
        code = abm.declaredUpdates[update]

        code = postwalk(x->@capture(x,d(s_)=g_) ? getEquation(s,x,abm) : x, code)
    end

    return

end

"""
    function getEquationMedium(sym,code,abm)

Sets to true the the variableMedium field of UserParameters
"""
function getEquationMedium(sym,code,abm)

    abm.parameters[sym].variableMedium = true
    abm.parameters[sym].pos = sum([j.variableMedium for (i,j) in abm.parameters])

    return code

end

"""
    function getEquationsMedium!(abm)

Go over the code in updateVariable and looks for parameters defined as medium variables.
"""
function getEquationsMedium!(abm)

    for update in keys(abm.declaredUpdates)

        code = abm.declaredUpdates[update]

        code = postwalk(x->@capture(x,∂t(s_)=g_) ? getEquationMedium(s,x,abm) : x, code)

    end

    return

end

"""
    mutable struct ABM

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

    function ABM()

Generates an empty instance of ABM to be filled.

    function ABM(dims;
        localInt::Vector{Symbol}=Symbol[],
        localIntInteraction::Vector{Symbol}=Symbol[],
        localFloat::Vector{Symbol}=Symbol[],
        localFloatInteraction::Vector{Symbol}=Symbol[],
        globalFloat::Vector{Symbol}=Symbol[],
        globalInt::Vector{Symbol}=Symbol[],
        globalFloatInteraction::Vector{Symbol}=Symbol[],
        globalIntInteraction::Vector{Symbol}=Symbol[],
        medium::Vector{Symbol}=Symbol[],
        baseModelInit::Vector{ABM}=ABM[],
        baseModelEnd::Vector{ABM}=ABM[],
        neighbors::Symbol=:Full,
        integrator::Symbol=:Euler,
        integratorMedium::Symbol=:Centered,
        platform::Symbol=:CPU,
        saving::Symbol=:RAM,
        updateGlobal::Expr=quote end,
        agentRule::Expr=quote end,
        updateInteraction::Expr=quote end,
        mediumODE::Expr=quote end,
        mediumODEInteraction::Expr=quote end,
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
|| baseModelInit::Vector{ABM}=ABM[] | Models inherited to construct this model and which rules apply before this one. |
|| baseModelEnd::Vector{ABM}=ABM[] | Models inherited to construct this model and which rules apply after this one. |
|| neighbors::Symbol=:Full | Type of neighbor method used. |
|| integrator::Symbol=:Euler | Type of integrator used. |
|| integratorMedium::Symbol=:Centered | Type of discretizer used for the spatial medium. |
|| platform::Symbol=:CPU | Platform in which the agent will run. |
|| saving::Symbol=:RAM | Saving platform. |
|| updateGlobal::Expr=quote end | Update rule for global parameters. |
|| agentRule::Expr=quote end | Update rule for local parameters. |
|| updateInteraction::Expr=quote end | Update rule for interacting parameters. |
|| mediumODE::Expr=quote end | Update rule for medium parameters. |
|| mediumODEInteraction::Expr=quote end | Update rule for medium interaction parameters. |
|| updateVariable::Expr=quote end | Update rule for diferential equation defining evolution of parameters. |

For a more extense explanation of how to define rules and parameters, read `Usage` in the documentation.
"""
mutable struct ABM

    dims::Int    

    positionParameters::OrderedDict{Symbol,DataType}

    parameters::OrderedDict{Symbol,UserParameter}
    
    declaredUpdates::Dict{Symbol,Expr}
    declaredUpdatesCode::Dict{Symbol,Expr}
    declaredUpdatesFunction::Dict{Symbol,Function}
    neighbors::Symbol
    platform::Symbol
    removalOfAgents_::Bool
        
    function ABM()
        new(0,
            OrderedDict{Symbol,DataType}(),
            OrderedDict{Symbol,DataType}(),
            Dict{Symbol,Expr}(),
            Dict{Symbol,Expr}(),
            Dict{Symbol,Function}(),
            :Full,
            :CPU,
            false,
            )
    end

    function ABM(
            dims;

            agent=OrderedDict{Symbol,DataType}(),
            agentRule::Expr=quote end,
            agentODE::Expr=quote end,
            agentSDE::Expr=quote end,

            model=OrderedDict{Symbol,DataType}(),
            modelRule::Expr=quote end,

            medium=OrderedDict{Symbol,DataType}(),
            mediumODE::Expr=quote end,

            positionParameters=OrderedDict(
                :x=>Float64,
                :y=>Float64,
                :z=>Float64,
            ),

            baseModelInit::Vector{ABM}=ABM[],
            baseModelEnd::Vector{ABM}=ABM[],

            neighbors::Symbol=:Full,
            platform::Symbol=:CPU,    

            compile = true,
        )

        abm = ABM()

        abm.dims = dims
        if neighbors in NEIGHBORSYMBOLS
            abm.neighbors = neighbors
        else
            error("Neighbors algorithm ", neighbors, " not defined. Specify among: ", NEIGHBORSYMBOLS)
        end
        if platform in PLATFORM
            abm.platform = platform
        else
            error("Platform ", platform, " not defined. Specify among: ", PLATFORM)
        end

        #Add basic agent symbols
        for (i,sym) in enumerate(keys(positionParameters))
            if i <= dims
                abm.parameters[sym] = UserParameter(positionParameters[sym],:agent)
            end
        end

        #Parameters
        for (arg,scope) = [
                            (agent,:agent),
                            (model,:model),
                            (medium,:medium)            
                            ]
            params = 0
            if typeof(arg) == DataType
                params = OrderedDict([i=>j for (i,j) in zip(fieldnames(arg),fieldtypes(arg))])
            else
                params = OrderedDict(arg)
            end
            for (par,dataType) in pairs(params)
                checkDeclared(par,abm)
                abm.parameters[par] = UserParameter(dataType,scope)
            end
        end

        #Add symbols from base objects
        for base in [baseModelInit; baseModelEnd]
            for (i,j) in pairs(base.parameters)
                if !(i in keys(BASEPARAMETERS))
                    checkDeclared(i,abm)
                    abm.parameters[i] = j
                end
            end
        end
        
        #Add Updates
        for a in baseModelInit
            for (update,code) in pairs(a.declaredUpdates)
                if update in keys(abm.declaredUpdates)
                    push!(abm.declaredUpdates[update].args, copy(code))
                else
                    abm.declaredUpdates[update] = copy(code)
                end
            end
        end
        for (update,code) in (
                                (:modelRule,modelRule), 
                                (:agentRule,agentRule), 
                                (:agentODE,agentODE), 
                                (:agentSDE,agentSDE), 
                                (:mediumODE,mediumODE), 
                            )
            if update in keys(abm.declaredUpdates)
                push!(abm.declaredUpdates[update].args, code)
            else
                abm.declaredUpdates[update] = code
            end
        end
        for a in baseModelEnd
            for (update,code) in pairs(a.declaredUpdates)
                if update in keys(abm.declaredUpdates)
                    push!(abm.declaredUpdates[update].args, copy(code))
                else
                    abm.declaredUpdates[update] = copy(code)
                end
            end
        end

        #Variables
        count = 0
        for sym in keys(abm.parameters)
            if inexpr(agentODE,:(dt($sym))) || inexpr(agentSDE,:(dt($sym)))
                count += 1
                abm.parameters[sym].variable = true            
                abm.parameters[sym].pos = count
            end        
        end

        #Variablesmedium
        count = 0
        for sym in keys(abm.parameters)
            if inexpr(mediumODE,:(dt($sym)))
                count += 1
                abm.parameters[sym].variableMedium = true            
                abm.parameters[sym].pos = count
            end        
        end

        #Check if there are removed agents
        abm.removalOfAgents_ = true
        for update in keys(abm.declaredUpdates)
            if inexpr(abm.declaredUpdates[update],:removeAgent)
                abm.removalOfAgents_ = true
            end
            if inexpr(abm.declaredUpdates[update],:@removeAgent)
                abm.removalOfAgents_ = true
            end
        end        

        global AGENT = deepcopy(abm)

        #Make compiled functions
        if compile 
            agentRuleFunction(abm)
            agentDEFunction(abm)
            mediumDEFunction(abm)
            neighborsFunction(abm)
            # globalFunction(abm)
        end

        return abm        
    end

end

function Base.show(io::IO,abm::ABM)
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
    function checkDeclared(a::Symbol, abm::ABM) 
    function checkDeclared(a::Array{Symbol}, abm::ABM) 

Check if a symbol is already declared in the model or inherited models.
"""
function checkDeclared(a::Array{Symbol}, abm::ABM) 

    for s in a
        checkDeclared(s,abm)
    end

end

function checkDeclared(a::Symbol, abm::ABM) 

    if a in keys(abm.parameters)
        error("Symbol ", a, " already declared in the abm.")
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

# function addUpdates!(p::ABM)

#     ##Assign updates of variable types
#     for par in [keys(p.declaredSymbols)...,POSITIONPARAMETERS[1:abm.dims]...]

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
