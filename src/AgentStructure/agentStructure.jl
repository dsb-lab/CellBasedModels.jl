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
        agent::Vector{Symbol}=Symbol[],
        model::Vector{Symbol}=Symbol[],
        medium::Vector{Symbol}=Symbol[],
        baseModelInit::Vector{ABM}=ABM[],
        baseModelEnd::Vector{ABM}=ABM[],
        neighbors::Symbol=:Full,
        integrator::Symbol=:Euler,
        integratorMedium::Symbol=:Centered,
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

    removalOfAgents_::Bool
        
    function ABM()
        new(0,
            OrderedDict{Symbol,DataType}(),
            OrderedDict{Symbol,DataType}(),
            Dict{Symbol,Expr}(),
            Dict{Symbol,Expr}(),
            Dict{Symbol,Function}(),
            false
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
            modelODE::Expr=quote end,
            modelSDE::Expr=quote end,

            medium=OrderedDict{Symbol,DataType}(),
            mediumRule::Expr=quote end,
            mediumODE::Expr=quote end,
            mediumSDE::Expr=quote end,

            positionParameters=OrderedDict(
                :x=>Float64,
                :y=>Float64,
                :z=>Float64,
            ),

            baseModelInit::Vector{ABM}=ABM[],
            baseModelEnd::Vector{ABM}=ABM[],
        )

        abm = ABM()

        abm.dims = dims

        #Add basic agent symbols
        for (i,sym) in enumerate(keys(positionParameters))
            if i <= dims
                abm.parameters[sym] = UserParameter(i,positionParameters[sym],:agent)
            end
        end

        #Go over parameter inputs and add them to list
        for (arg,scope) = [
                            (agent,:agent),
                            (model,:model),
                            (medium,:medium)            
                            ]
            #Promote input to ordered dictionary
            params = 0
            if typeof(arg) == DataType #Transform structures like Agent to dictionary
                params = OrderedDict([i=>j for (i,j) in zip(fieldnames(arg),fieldtypes(arg))])
            else
                params = OrderedDict(arg)
            end
            #Add parameters
            for (par,dataType) in pairs(params)
                checkDeclared(par,abm)
                abm.parameters[par] = UserParameter(par,dataType,scope)
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
                                (:agentRule,agentRule), 
                                (:agentODE,agentODE), 
                                (:agentSDE,agentSDE), 
                                (:modelRule,modelRule), 
                                (:modelODE,modelODE), 
                                (:modelSDE,modelSDE), 
                                (:mediumRule,mediumRule), 
                                (:mediumODE,mediumODE), 
                                (:mediumSDE,mediumSDE), 
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

        #Check if there are removed agents
        for update in keys(abm.declaredUpdates)
            if occursin("@removeAgent",string(abm.declaredUpdates[update]))
                abm.removalOfAgents_ = true
            end
        end        

        checkCustomCode(abm)
        addUpdates!(abm)

        global AGENT = deepcopy(abm)

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

    if code.args[1] == x
        code.args[1] = Meta.parse(string(x,"__"))
    end

    if @capture(code.args[1],g_[h__]) && g == x
        code.args[1] = Meta.parse(string(x,"__[$(h...)]"))
    end

    return code
end

"""
Function that adds the new operator to all the times the symbol s is being updated. e.g. update(x=1,x) -> x__ = 1.
The modifications are also done in the keyword arguments of the macro functions as addAgent.
"""
function update(code,s)

    for op in UPDATINGOPERATORS
        code = postwalk(x-> isexpr(x,op) ? change(s,x) : x, code)
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

"""
Function that adds to the UserParameters is they are updated, variables or variables medium and adds a position assignation when generating the matrices.
"""
function addUpdates!(abm::ABM)

    ##Assign updates of variable types

    #Write updates
    for up in keys(abm.declaredUpdates)
        for sym in keys(abm.parameters)
            abm.declaredUpdates[up] = update(abm.declaredUpdates[up],sym)
        end
    end
    #Add updates ignoring @addAgent
    for up in keys(abm.declaredUpdates)
        for sym in keys(abm.parameters)
            code = abm.declaredUpdates[up]
            code = postwalk(x->@capture(x,@addAgent(g__)) ? :(_) : x , code)
            if inexpr(code,new(sym))
                abm.parameters[sym].update = true
            end
        end
    end

    #Variables
    for scope in [:agent,:model,:medium]
        ode = addSymbol(scope,"ODE")
        sde = addSymbol(scope,"SDE")
        count = 0
        vAgent, agentODE = captureVariables(abm.declaredUpdates[ode])
        v2, agentSDE = captureVariables(abm.declaredUpdates[sde])
        append!(vAgent,v2)
        for sym in unique(vAgent)
            if sym in keys(abm.parameters)
                if abm.parameters[sym].scope == scope && abm.parameters[sym].update
                    error("$sym parameter is trying to be updated somewhere other than $ode/$sde at the same time. To avoid problems between both rules overwriting the same parameter write inplace($sym).")
                elseif abm.parameters[sym].scope == scope
                    count += 1
                    abm.parameters[sym].variable = true            
                    abm.parameters[sym].pos = count
                else
                    error("dt in $ode and $sde can only be assigned to agent parameters. Declared with $(abm.parameters[sym].scope) parameter $sym.")
                end
            end        
        end
        abm.declaredUpdates[ode] = agentODE
        abm.declaredUpdates[sde] = agentSDE
    end

    #Remove inplace operators
    for (up,code) in pairs(abm.declaredUpdates)
        abm.declaredUpdates[up] = postwalk(x->@capture(x,inplace(g_)) ? g : x , code)
    end
    
    return
end

function checkCustomCode(abm)

    #Error if dt in other place
    for up in keys(abm.declaredUpdates)

        #dt()
        if !(up in [:agentODE,:agentSDE,:modelODE,:modelSDE,:mediumODE,:mediumSDE])
            v, _ = captureVariables(abm.declaredUpdates[up])
            if !isempty(v)
                error("Cannot declared a differential equation with the dt() function in $up. The following variables have been declared erroneously:  $(v...) . ")
            end
        end

        #@addAgent
        if !(up in [:agentRule])
            if occursin("@addAgent",string(abm.declaredUpdates[up]))
                error("@addAgent can only be declared in agentRule")
            end
        end

        #@removeAgent
        if !(up in [:agentRule])
            if occursin("@removeAgent",string(abm.declaredUpdates[up]))
                error("@removeAgent can only be declared in agentRule")
            end
        end

        #@loopOverNeighbors
        if !(up in [:agentRule,:agentODE,:agentSDE])
            if occursin("@loopOverNeighbors",string(abm.declaredUpdates[up]))
                error("@loopOverNeighbors can only be declared in agent code")
            end
        end

        #@loopOverMedium
        if !(up in [:mediumRule,:mediumODE,:mediumSDE])
            if occursin("@loopOverMedium",string(abm.declaredUpdates[up]))
                error("@loopOverMedium can only be declared in agent code")
            end
        end

    end


end
