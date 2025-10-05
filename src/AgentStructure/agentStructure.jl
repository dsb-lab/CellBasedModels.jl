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
| neighborsAlg | Algorithm to compute neighbors |
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

        agentAlg::Union{CustomAgentIntegrator,DEAlgorithm;Nothing} = CBMIntegrators.Euler(),
        agentSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),

        modelAlg::Union{DEAlgorithm;Nothing} = CBMIntegrators.Euler(),
        modelSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),

        mediumAlg::Union{CustomMediumIntegrator,DEAlgorithm;Nothing} = DifferentialEquations.AutoTsit5(DifferentialEquations.Rosenbrock23()),
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

    agent::NamedTuple
    model::Model
    medium::NamedTuple
    interaction::NamedTuple
    
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
        
    # function ABM()
    #     new(0,
    #         NamedTuple{Symbol,DataType}(),
    #         Dict{Symbol,Agent}(),
    #         Dict{Symbol,Expr}(),
    #         Dict{Symbol,Expr}(),
    #         Dict{Symbol,Function}(),
    #         false,
    #         nothing,
    #         nothing,
    #         nothing,
    #         nothing,
    #         nothing,
    #         nothing,
    #         nothing,
    #         nothing
    #         )
    # end

    function ABM(
            dims;

            agent::Union{OrderedDict{Symbol,DataType},Dict{Symbol,DataType},Agent,Vector{Agent}}=Agent[],
            agentRule::Union{Expr, NamedTuple}=quote end,
            agentODE::Union{Expr, NamedTuple}=quote end,
            agentSDE::Union{Expr, NamedTuple}=quote end,

            model::Union{OrderedDict{Symbol,DataType}, Dict{Symbol,DataType}, Model}=Model(),
            modelRule::Union{Expr, NamedTuple}=quote end,
            modelODE::Union{Expr, NamedTuple}=quote end,
            modelSDE::Union{Expr, NamedTuple}=quote end,

            medium::Union{OrderedDict{Symbol,DataType}, Dict{Symbol,DataType}, Medium, Vector{Medium}}=Medium[],
            mediumRule::Union{Expr, NamedTuple}=quote end,
            mediumODE::Union{Expr, NamedTuple}=quote end,
            mediumSDE::Union{Expr, NamedTuple}=quote end,

            interaction::Union{Interaction, Vector{Interaction}}=Interaction[],
            interactionsRule::Union{Expr, NamedTuple}=quote end,
            interactionsODE::Union{Expr, NamedTuple}=quote end,
            interactionsSDE::Union{Expr, NamedTuple}=quote end,

            baseModelInit::Vector{ABM}=ABM[],
            baseModelEnd::Vector{ABM}=ABM[],

            agentAlg::Union{CustomIntegrator,DEAlgorithm,Nothing} = nothing,
            agentSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),

            modelAlg::Union{DEAlgorithm,Nothing} = nothing,
            modelSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),

            mediumAlg::Union{CustomMediumIntegrator,DEAlgorithm,Nothing} = nothing,
            mediumSolveArgs::Dict{Symbol,Any} = Dict{Symbol,Any}(),

            neighborsAlg::Neighbors = CBMNeighbors.Full(),       
            platform::Platform = CPU(),     

            compile::Bool = true
        )

        #Check dimensions
        if dims < 0 || dims > 3
            throw(ArgumentError("ABM dims must be between 0 and 3."))
        end

        #Prepare Agents
        if !(typeof(agent) <: Union{Agent,Vector{Agent}})
            agent = deepcopy(Agent(dims, parameters=deepcopy(agent)))
        end
        if typeof(agent) <: Agent
            agent = NamedTuple{Tuple([agent.name])}(Tuple([agent]))
        elseif typeof(agent) <: Vector{Agent}
            names = Tuple(a.name for a in agent)
            if length(unique(names)) != length(names)
                throw(ArgumentError("Agents in vector must have unique names. Provided agent names: $names"))
            end
            agent = NamedTuple{names}(agent)
        end
        for ag in values(agent)
            if ag.dims != dims
                throw(ArgumentError("Agent dimensions must be equal to ABM dimensions. Agent $(ag.name) has $(ag.dims) dimensions and ABM has $dims dimensions."))
            end
        end
        for (update,code) in (
                                (:agentRule,agentRule), 
                                (:agentODE,agentODE), 
                                (:agentSDE,agentSDE), 
                                (:mediumRule,mediumRule), 
                                (:mediumODE,mediumODE), 
                                (:mediumSDE,mediumSDE), 
                                (:interactiveRule,interactiveRule), 
                                (:interactiveODE,interactiveODE), 
                                (:interactiveSDE,interactiveSDE), 
                            )
            if update in keys(abm.declaredUpdates)
                push!(abm.declaredUpdates[update].args, code)
            else
                abm.declaredUpdates[update] = code
            end
        end


        #Prepare Model
        if !(typeof(model) <: Model)
            model = Model(parameters=deepcopy(model))
        end

        #Prepare Medium
        if !(typeof(medium) <: Union{Medium,Vector{Medium}})
            medium = deepcopy(Medium(dims, parameters=deepcopy(medium)))
        end
        if typeof(medium) <: Medium
            medium = NamedTuple{Tuple([medium.name])}(Tuple([medium]))
        elseif typeof(medium) <: Vector{Medium}
            names = Tuple(m.name for m in medium)
            if length(unique(names)) != length(names)
                throw(ArgumentError("Mediums in vector must have unique names. Provided medium names: $names"))
            end
            medium = NamedTuple{names}(medium)
        end
        for m in values(medium)
            if m.dims != dims
                throw(ArgumentError("Medium dimensions must be equal to ABM dimensions. Medium $(m.name) has $(m.dims) dimensions and ABM has $dims dimensions."))
            end
        end

        #Prepare Interaction
        if typeof(interaction) <: Interaction
            interaction = NamedTuple{Tuple([interaction.name])}(Tuple([interaction]))
        elseif typeof(interaction) <: Vector{Interaction}
            names = Tuple(i.name for i in interaction)
            if length(unique(names)) != length(names)
                throw(ArgumentError("Interactions in vector must have unique names. Provided interaction names: $names"))
            end
            interaction = NamedTuple{names}(interaction)
        end 

        #Add Updates
        # for a in baseModelInit
        #     for (update,code) in pairs(a.declaredUpdates)
        #         if update in keys(abm.declaredUpdates)
        #             push!(abm.declaredUpdates[update].args, copy(code))
        #         else
        #             abm.declaredUpdates[update] = copy(code)
        #         end
        #     end
        # end
        for (update,code) in (
                                (:modelRule,modelRule), 
                                (:modelODE,modelODE), 
                                (:modelSDE,modelSDE), 
                            )
            if update in keys(abm.declaredUpdates)
                push!(abm.declaredUpdates[update].args, code)
            else
                abm.declaredUpdates[update] = code
            end
        end
        for (update,code) in (
                                (:agentRule,agentRule), 
                                (:agentODE,agentODE), 
                                (:agentSDE,agentSDE), 
                                (:mediumRule,mediumRule), 
                                (:mediumODE,mediumODE), 
                                (:mediumSDE,mediumSDE), 
                                (:interactiveRule,interactiveRule), 
                                (:interactiveODE,interactiveODE), 
                                (:interactiveSDE,interactiveSDE), 
                            )
            if update in keys(abm.declaredUpdates)
                push!(abm.declaredUpdates[update].args, code)
            else
                abm.declaredUpdates[update] = code
            end
        end
        # for a in baseModelEnd
        #     for (update,code) in pairs(a.declaredUpdates)
        #         if update in keys(abm.declaredUpdates)
        #             push!(abm.declaredUpdates[update].args, copy(code))
        #         else
        #             abm.declaredUpdates[update] = copy(code)
        #         end
        #     end
        # end

        # #Check in @inagent
        # checkInAgent(abm)

        # #Group block from @inagent
        # groupInAgent(abm)

        # checkCustomCode(abm)
        # addUpdates!(abm)     

        # #Assign other key arguments
        # setfield!(abm,:neighbors,neighborsAlg)
        # setfield!(abm,:platform,platform)
        # if agentAlg === nothing
        #     if isemptyupdaterule(abm,:agentSDE)
        #         setfield!(abm,:agentAlg,CBMIntegrators.Euler())
        #     else
        #         setfield!(abm,:agentAlg,CBMIntegrators.EM())
        #     end
        # else
        #     setfield!(abm,:agentAlg,agentAlg)
        # end
        # setfield!(abm,:agentSolveArgs,agentSolveArgs)
        # if modelAlg === nothing
        #     if isemptyupdaterule(abm,:modelSDE)
        #         setfield!(abm,:modelAlg,DifferentialEquations.Euler())
        #     else
        #         setfield!(abm,:modelAlg,DifferentialEquations.EM())
        #     end
        # else
        #     setfield!(abm,:agentAlg,agentAlg)
        # end
        # setfield!(abm,:modelSolveArgs,modelSolveArgs)
        # if mediumAlg === nothing
        #     if isemptyupdaterule(abm,:mediumSDE)
        #         setfield!(abm,:mediumAlg,DifferentialEquations.AutoTsit5(DifferentialEquations.Rosenbrock23()))
        #     else
        #         setfield!(abm,:mediumAlg,DifferentialEquations.EulerHeun())
        #     end
        # else
        #     setfield!(abm,:mediumAlg,mediumAlg)
        # end
        # setfield!(abm,:mediumSolveArgs,mediumSolveArgs)

        # # global AGENT = deepcopy(abm)
        # for (update,code) in pairs(abm.declaredUpdates)
        #     abm.declaredUpdates[update] = substitute_macros(copy(code),abm)
        # end

        # #Make compiled functions
        # if compile
        #     compileABM!(abm)
        # end

        declaredUpdates=OrderedDict{Symbol,Expr}()
        declaredUpdatesCode=OrderedDict{Symbol,Expr}()
        declaredUpdatesFunction=OrderedDict{Symbol,Function}()

        removalOfAgents_=false

        # println("dims ", typeof(dims))
        # println("agent ", typeof(agent))
        # println("model ", typeof(model))
        # println("medium ", typeof(medium))
        # println("interaction ", typeof(interaction))
        # println("parameters ", typeof(parameters))
        # println("declaredUpdates ", typeof(declaredUpdates))
        # println("declaredUpdatesCode ", typeof(declaredUpdatesCode))
        # println("declaredUpdatesFunction ", typeof(declaredUpdatesFunction))
        # println("removalOfAgents_ ", typeof(removalOfAgents_))
        # println("neighborsAlg ", typeof(neighborsAlg))
        # println("agentAlg ", typeof(agentAlg))
        # println("agentSolveArgs ", typeof(agentSolveArgs))
        # println("modelAlg ", typeof(modelAlg))
        # println("modelSolveArgs ", typeof(modelSolveArgs))
        # println("mediumAlg ", typeof(mediumAlg))
        # println("mediumSolveArgs ", typeof(mediumSolveArgs))

        new(
            dims,

            agent,
            model,
            medium,
            interaction,

            declaredUpdates,
            declaredUpdatesCode,
            declaredUpdatesFunction,

            removalOfAgents_,

            neighborsAlg,

            agentAlg,
            agentSolveArgs,
            modelAlg,
            modelSolveArgs,
            mediumAlg,
            mediumSolveArgs,
        )

    end

end

function Base.show(io::IO,abm::ABM)
    println("PARAMETERS: \n")
    print("   MODEL: \n")
    Base.show(io,abm.model)
    print("\n")

    print("   AGENTS: ")
    if length(abm.agent) == 0
        print("None\n")
    else
        print("\n")
        for agent in values(abm.agent)
            Base.show(io,agent)
            print("\n")
        end
    end

    print("   MEDIUMS: ")
    if length(abm.medium) == 0
        print("None\n")
    else
        print("\n")
        for medium in values(abm.medium)
            Base.show(io,medium)
            print("\n")
        end
    end

    print("   INTERACTIONS: ")
    if length(abm.interaction) == 0
        print("None\n")
    else
        print("\n")
        for interaction in values(abm.interaction)
            Base.show(io,interaction)
            print("\n")
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
    function checkDeclared(a::Symbol, abm) 
    function checkDeclared(a::Array{Symbol}, abm::ABM)
    function checkDeclared(a::Array{Symbol}, abm::OrderedDict) 

Check if a symbol is already declared in the model or inherited models.
"""
function checkDeclared(a::Array{Symbol}, abm, subscope::Symbol=:Main) 

    for s in a
        checkDeclared(s, abm, subscope)
    end

end

function checkDeclared(a::Symbol, abm::ABM) 

    checkDeclared(a, abm.parameters)

end

function checkDeclared(a::Symbol, abm::OrderedDict)

    if a in keys(abm)
        if !(abm[a].scope in [:agentBase, :mediumBase, :modelBase, :Dims, :SimBox])
            error("Symbol ", a, " already declared in the ABM in other scope ", abm[a].scope, "-", abm[a].subscope,". Change name in one of the two scopes.")
        end
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

"""
Function that adds to the UserParameters is they are updated, variables or variables medium and adds a position assignation when generating the matrices.
"""
function addUpdates!(abm::ABM)

    ##Assign updates of variable types

    #Write updates
    # for up in keys(abm.declaredUpdates)
    #     for sym in keys(abm.parameters)
    #         abm.declaredUpdates[up] = update(abm.declaredUpdates[up],sym)
    #     end
    # end
    #Add updates ignoring @addAgent
    for up in keys(abm.declaredUpdates)
        for sym in keys(abm.parameters)
            code = abm.declaredUpdates[up]
            code = postwalk(x->@capture(x,f_(g__)) ? :(_) : x , code)
            if inexpr(code,new(sym))
                abm.parameters[sym].update = true
                abm.parameters[sym_update(sym)] = UserParameter(sym_update(sym), abm.parameters[sym].dtype, Meta.parse(string(abm.parameters[sym].scope,"Base")), abm.parameters[sym].subscope, update=true,variable=false,pos=0, primitive=sym)
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
    # for (up,code) in pairs(abm.declaredUpdates)
    #     abm.declaredUpdates[up] = postwalk(x->@capture(x,inplace(g_)) ? g : x , code)
    # end
    
    return
end

function compileABM!(abm)

    for (scope,type) in zip(
        [:agent,:agent,:model,:model,:medium,:medium],
        [:ODE,:SDE,:ODE,:SDE,:ODE,:SDE]
    )
        functionDE(abm,scope,type)
    end
    for scope in [:agent,:model,:medium]
        functionRule(abm,scope)
    end

    return

end

function checkInAgent(abm)

    agents = unique([j.subscope for (i,j) in pairs(abm.parameters) if j.scope == :agent])

    for update in (
            :agentRule, 
            :agentODE, 
            :agentSDE, 
        )

        if !isemptyupdaterule(abm,update)

            code = copy(abm.declaredUpdates[update])
            codecheck = postwalk(x->@capture(x, @inagent a_ b_) ? quote end : x, code)
            # codecheck = postwalk(x->@capture(x, @inagent a_ b_) ? error("Name agent declared in `@inagent` [", a, "] does not exist.") : x, codecheck)
            codecheck = prettify(codecheck)
            if !iscodeempty(codecheck)
                codeprint = prettify(postwalk(x->@capture(x, @inagent a_ b_) && a in agents ? quote [good code] end : x, code))
                error("Problem in code declaration in a ABM with multiple agents declared. All code should be assigned to one or several agents in the form of: \n `\n@inagent #nameofagent1# begin\n\t ...code of agent 1...\nend\n@inagent #nameofagent2# begin\n\t ...code of agent 2...\nend`\n Problematic code: \n",codeprint)
            end

        end

    end

end

function groupInAgent(abm)

    agents = unique([j.subscope for (i,j) in pairs(abm.parameters) if j.scope == :agent])

    for update in (
            :agentRule, 
            :agentODE, 
            :agentSDE, 
        )

        if !isemptyupdaterule(abm,update)

            finalcode = quote end
            code = copy(abm.declaredUpdates[update])
            for agent in unique([agents;:Main])
                codes = []
                postwalk(x->@capture(x, @inagent a_ b_) && a == agent ? push!(codes,b) : x, code)
                if length(codes) > 0
                    finalcode = :($finalcode; @inagent $(agent) begin $(codes...) end)
                end
            end
            abm.declaredUpdates[update] = finalcode

        end

    end

end

##############################################################################
# Macros
##############################################################################

function removeAgent(code, agent, abm)

    function addParameters(abm, agent)

        abm.removalOfAgents_ = true
        abm.parameters[make_symbol_unique(agent,:NAdd)] = UserParameter(make_symbol_unique(agent,:NAdd), Threads.Atomic{Int}, :modelBase, agent)
        abm.parameters[make_symbol_unique(agent,:NRemove)] = UserParameter(make_symbol_unique(agent,:NRemove), Threads.Atomic{Int}, :modelBase, agent)
        abm.parameters[make_symbol_unique(agent,:NSurvive)] = UserParameter(make_symbol_unique(agent,:NSurvive), Threads.Atomic{Int}, :modelBase, agent)
        abm.parameters[make_symbol_unique(agent,:flagSurvive)] = UserParameter(make_symbol_unique(agent,:flagSurvive), Int, :agentBase, agent)
        abm.parameters[make_symbol_unique(agent,:holeFromRemoveAt)] = UserParameter(make_symbol_unique(agent,:holeFromRemoveAt), Int, :agentBase, agent)
        abm.parameters[make_symbol_unique(agent,:repositionAgentInPos)] = UserParameter(make_symbol_unique(agent,:repositionAgentInPos), Int, :agentBase, agent)
    
    end

    code = postwalk(x->@capture(x,@removeAgent()) ? 
            begin addParameters(abm, agent); quote 
            idNew_ = Threads.atomic_add!($(make_symbol_unique(agent,:NRemove)),1) + 1
            $(make_symbol_unique(agent,:holeFromRemoveAt))[idNew_] = i1_ 
            $(make_symbol_unique(agent,:flagSurvive))[i1_] = 0
            flagRecomputeNeighbors_ = 1
        end end : x, code
    )

    return code

end

function addAgent(code, agent, abm)

    function addParameters(abm, agent)

        abm.parameters[make_symbol_unique(agent,:NAdd)] = UserParameter(make_symbol_unique(agent,:NAdd), Threads.Atomic{Int}, :model, agent)
    
    end

    function addAgentCode(abm, agent, arguments)

        #List parameters that can be updated by the user
        updateargs = [sym for (sym,prop) in pairs(abm.parameters) if prop.scope == :agent && prop.subscope == agent]
        updateargs2 = [new(sym) for (sym,prop) in pairs(abm.parameters) if prop.scope == :agent && prop.subscope == agent]
        append!(updateargs2,updateargs)
        #Checks that the correct parameters have been declared and not others
        args = []
        code = quote end
        for i in arguments
            found = @capture(i,g_ = f_)
            if found
                if !(g in updateargs2)
                    error("Error in @addAgent. `", old(g), "`` is not a parameter of agent type ", agent, " or it is protected from direct update.")
                end
            else
                error(i, " is not a valid assignation of code when declaring addAgent. A Valid one should be of the form parameterOfAgent = value")
            end

            if g in args
            error(g," has been declared more than once in addAgent.") 
            end

            if i.args[1] == :id
                error("id must not be declared when calling addAgent. It is assigned automatically.")
            end

            if abm.parameters[old(g)].update
                push!(code.args,:($(new(old(g)))[i1New_]=$f))
            else
                push!(code.args,:($(old(g))[i1New_]=$f))
            end
            push!(args,g)

        end

        #Add parameters to agent that have not been user defined
        for i in updateargs
            if !(i in args) && !(new(i) in args)
                if abm.parameters[i].update
                    push!(code.args,:($(new(i))[i1New_]=$i[i1_]))
                else
                    push!(code.args,:($i[i1New_]=$i[i1_]))
                end
            end
        end

        #Make code
        code = quote
                i1New_ = $(make_symbol_unique(agent,:N))+Threads.atomic_add!($(make_symbol_unique(agent,:NAdd)),1) + 1
                idNew_ = Threads.atomic_add!($(make_symbol_unique(agent,:idMax)),1) + 1
                if $(make_symbol_unique(agent,:NMax)) >= i1New_
                    # flagNeighbors_[i1New_] = 1
                    id[i1New_] = idNew_
                    flagRecomputeNeighbors_ = 1
                    $(make_symbol_unique(agent,:flagSurvive))[i1New_] = 1
                    $code
                else
                    Threads.atomic_add!($(make_symbol_unique(agent,:NAdd)),-1)
                end
            end

        return code
    end

    code = postwalk(x->@capture(x,@addAgent(b__)) ? 
            begin addParameters(abm, agent); addAgentCode(abm, agent, b) end : x, code
    )

    return code

end

function add_dt(a, abm)

    if a in keys(abm.parameters)
        abm.parameters[sym_derivative(a)] = UserParameter(sym_derivative(a), abm.parameters[a].dtype, sym_base(abm.parameters[a].scope), abm.parameters[a].subscope, update=true,variable=false,pos=0,primitive=a)
        abm.parameters[sym_update(a)] = UserParameter(sym_update(a), Float64, sym_base(abm.parameters[a].scope), abm.parameters[a].subscope,update=false,variable=true,pos=0,primitive=a)
        return sym_derivative(a)
    else
        error("Error in dt() operator declaration. Symbol ", a, " is not a parameter of model.")
    end
    
end

function substitute_macros(code, abm)

    #@removeAgent 
    code = postwalk(x->@capture(x, @inagent a_ b_) ? quote @inagent $a $(removeAgent(b,a,abm)) end : x, code)      

    #@addAgent 
    code = postwalk(x->@capture(x, @inagent a_ b_) ? quote @inagent $a $(addAgent(b,a,abm)) end : x, code)

    #dt() 
    code = postwalk(x->@capture(x, dt(a_) = b_) ? :($(add_dt(a, abm)) = $b) : x, code)

    return code
    
end