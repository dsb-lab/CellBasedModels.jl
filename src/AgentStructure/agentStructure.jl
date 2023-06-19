"""
    mutable struct ABM

Basic structure which contains the user defined parmeters of the model, the user rules of the agents, both in high level definition and the functions already compiled.

# Elements

| Field | Description |
|:---|:---|
| dims::Int | Dimensions of the model. |
| parameters::OrderedDict{Symbol,UserParameter} | Dictionary of parameters of the model and its properties. |
| declaredUpdates::Dict{Symbol,Expr} |  Dictionary of updating rules and their user defined content (high level code). |
| declaredUpdatesCode::Dict{Symbol,Expr} | Dictionary of updating rules after wrapping into code (low level code). |
| declaredUpdatesFunction::Dict{Symbol,Function} | Dictionary of updting rules and the compiled functions (compiled code). |
| agentDEProblem | ODEProblem or SDEProblem object of Agent |
| agentAlg | Algorithm for the ODEProblem or SDEProblem of Agent |
| agentSolveArgs | Parameters for the ODEProblem or SDEProblem of Agent |
| modelDEProblem | ODEProblem or SDEProblem object of Model |
| modelAlg |Algorithm for the ODEProblem or SDEProblem of Model |
| modelSolveArgs |Parameters for the ODEProblem or SDEProblem of Model |
| mediumDEProblem | ODEProblem or SDEProblem object of Medium |
| mediumAlg |Algorithm for the ODEProblem or SDEProblem of Medium |
| mediumSolveArgs |Parameters for the ODEProblem or SDEProblem of Medium |
| neighbors | Algorithm to compute neighbors |
| platform | Platform in which to run the model |
| removalOfAgents_::Bool | Stores the information to check wether agents are removed in the code. Auxiliar parameter for generating the code. |

# Constructors

    function ABM()

Generates an empty instance of ABM to be filled.

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

        baseModelInit::Vector{ABM}=ABM[],
        baseModelEnd::Vector{ABM}=ABM[],

        agentAlg::Union{CustomIntegrator,DEAlgorithm} = CBMIntegrators.Euler(),
        agentSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),

        modelAlg::Union{CustomIntegrator,DEAlgorithm} = CBMIntegrators.Euler(),
        modelSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),

        mediumAlg::Union{CustomIntegrator,DEAlgorithm} = DifferentialEquations.AutoTsit5(DifferentialEquations.Rosenbrock23()),
        mediumSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),

        neighborsAlg::Neighbors = CBMNeighbors.Full(),       
        platform::Platform = CPU(),     
    )

Generates an agent based model with defined parameters and rules.

|| Argument | Description |
|:---:|:---|:---|
| Args | dims | Dimensions of the system. |
| KwArgs | agent=OrderedDict{Symbol,DataType}() | Agent parameters |
|| agentRule::Expr=quote end | Agent rules |
|| agentODE::Expr=quote end | Agent Ordinary Differential Equations definition |
|| agentSDE::Expr=quote end | Agent Stochastic Differential Equations term definition  |
|| model=OrderedDict{Symbol,DataType}() | Model parameters |
|| modelRule::Expr=quote end | Model rules  |
|| modelODE::Expr=quote end | Model Ordinary Differential Equations definition  |
|| modelSDE::Expr=quote end | Model Ordinary Differential Equations definition  |
|| medium=OrderedDict{Symbol,DataType}() | Medium parameters |
|| mediumRule::Expr=quote end | Medium rules  |
|| mediumODE::Expr=quote end | Medium Ordinary Differential Equations definition  |
|| mediumSDE::Expr=quote end | Medium Ordinary Differential Equations definition  |
|| baseModelInit::Vector{ABM}=ABM[] | ABM model whose rules will act before this ABM rules |
|| baseModelEnd::Vector{ABM}=ABM[] | ABM model whose rules will act after this ABM rules |

For a more extense explanation of how to define rules and parameters, read `Usage` in the documentation.
"""
mutable struct ABM

    dims::Int    

    parameters::OrderedDict{Symbol,UserParameter}
    
    declaredUpdates::Dict{Symbol,Expr}
    declaredUpdatesCode::Dict{Symbol,Expr}
    declaredUpdatesFunction::Dict{Symbol,Function}

    removalOfAgents_::Bool

    neighbors

    platform

    agentAlg
    agentSolveArgs
    modelAlg
    modelSolveArgs
    mediumAlg
    mediumSolveArgs
        
    function ABM()
        new(0,
            OrderedDict{Symbol,DataType}(),
            Dict{Symbol,Expr}(),
            Dict{Symbol,Expr}(),
            Dict{Symbol,Function}(),
            false,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing
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

            baseModelInit::Vector{ABM}=ABM[],
            baseModelEnd::Vector{ABM}=ABM[],

            agentAlg::Union{CustomIntegrator,DEAlgorithm,Nothing} = nothing,
            agentSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),

            modelAlg::Union{DEAlgorithm,Nothing} = nothing,
            modelSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),

            mediumAlg::Union{DEAlgorithm,Nothing} = nothing,
            mediumSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),

            neighborsAlg::Neighbors = CBMNeighbors.Full(),       
            platform::Platform = CPU(),     

            compile::Bool = true
            )

        abm = ABM()

        abm.dims = dims

        #Add basic agent symbols
        for (i,sym) in enumerate(keys(positionParameters))
            if i <= dims
                abm.parameters[sym] = UserParameter(i,positionParameters[sym],:agent)
            end
        end

        #Add basic medium symbols
        for (i,sym) in enumerate(keys(positionMediumParameters))
            if i <= dims && length(medium) > 0
                abm.parameters[sym] = UserParameter(i,positionMediumParameters[sym],:medium)
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
                if !(i in keys(BASEPARAMETERS)) && !(i in [:x,:y,:z,:xₘ,:yₘ,:zₘ])
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

        #Assign other key arguments
        setfield!(abm,:neighbors,neighborsAlg)
        setfield!(abm,:platform,platform)
        if agentAlg === nothing
            if isemptyupdaterule(abm,:agentSDE)
                setfield!(abm,:agentAlg,CBMIntegrators.Euler())
            else
                setfield!(abm,:agentAlg,CBMIntegrators.EM())
            end
        else
            setfield!(abm,:agentAlg,agentAlg)
        end
        setfield!(abm,:agentSolveArgs,agentSolveArgs)
        if modelAlg === nothing
            if isemptyupdaterule(abm,:modelSDE)
                setfield!(abm,:modelAlg,DifferentialEquations.Euler())
            else
                setfield!(abm,:modelAlg,DifferentialEquations.EM())
            end
        else
            setfield!(abm,:agentAlg,agentAlg)
        end
        setfield!(abm,:modelSolveArgs,modelSolveArgs)
        if mediumAlg === nothing
            if isemptyupdaterule(abm,:mediumSDE)
                setfield!(abm,:mediumAlg,DifferentialEquations.AutoTsit5(DifferentialEquations.Rosenbrock23()))
            else
                setfield!(abm,:mediumAlg,DifferentialEquations.EulerHeun())
            end
        else
            setfield!(abm,:mediumAlg,mediumAlg)
        end
        setfield!(abm,:mediumSolveArgs,mediumSolveArgs)

        global AGENT = deepcopy(abm)

        #Make compiled functions
        if compile
            for (scope,type) in zip(
                [:agent,:agent,:model,:model,:medium,:medium],
                [:ODE,:SDE,:ODE,:SDE,:ODE,:SDE]
            )
                functionDE(abm,scope,type)
            end
            for scope in [:agent,:model,:medium]
                functionRule(abm,scope)
            end
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

    if code.args[1] == x
        code.args[1] = Meta.parse(string(x,"__"))
    end

    if @capture(code.args[1],g_[h__]) && g == x
        code.args[1] = :($(new(x))[$(h...)])
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
        for (sym,prop) in abm.parameters #Add in dt__sym form
            if prop.scope == scope && (inexpr(agentODE,opdt(sym)) || inexpr(agentSDE,opdt(sym)))
                count += 1
                abm.parameters[sym].update = true            
                abm.parameters[sym].variable = true            
                abm.parameters[sym].pos = count
            end
        end
        for sym in unique(vAgent) #Add in dt(sym) form
            if sym in keys(abm.parameters)
                if abm.parameters[sym].scope == scope && !abm.parameters[sym].variable
                    count += 1
                    abm.parameters[sym].update = true            
                    abm.parameters[sym].variable = true            
                    abm.parameters[sym].pos = count
                elseif abm.parameters[sym].variable
                    nothing
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