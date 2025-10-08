import MacroTools: @capture, postwalk, isexpr

struct ABM{D, AN, AD}

    _agents::NamedTuple

    _code::NamedTuple
    _functions::NamedTuple
    
    _integrationStructure::NamedTuple
    
end

function ABM(
        
        dims;

        agents::NamedTuple=(;),
        
        rules::Union{Expr, NamedTuple}=quote end,
        odes::Union{Expr, NamedTuple}=quote end,
        sdes::Union{Expr, NamedTuple}=quote end,
        pdesDifusion::Union{Expr, NamedTuple}=quote end,
        pdesAdvection::Union{Expr, NamedTuple}=quote end,
        pdesReaction::Union{Expr, NamedTuple}=quote end,

        integrationStructure::NamedTuple=(;),

    )
    
    agents = deepcopy(agents)
    names = keys(agents)
    types = Tuple{[typeof(par) for par in values(agents)]...}

    rules = isa(rules, Expr) ? (; main=rules) : rules
    checkUpdates!(agents, rules)
    # checkUpdates!(odes, agents)
    # checkUpdates!(sdes, agents)
    # checkUpdates!(pdesDifusion, agents)
    # checkUpdates!(pdesAdvection, agents)
    # checkUpdates!(pdesReaction, agents)
    # checkUpdates!(pdesReaction, agents)

    f = Dict{Symbol,Function}()
    makeRulesFunction!(f, rules, (dims, names, types))
    # makeStepFunction!(abm, dims, tag)

    return ABM{dims, names, types}(
        agents,
        (;), NamedTuple(f), (;)
    )

end

function Base.show(io::IO,abm::ABM)
    print("AGENTS\n")
    for (name, par) in pairs(abm._agents)
        print("\t$name - ")
        print(par,"\n\n")
    end
    print("\n\nUPDATE RULES\n")
    for (name, rule) in pairs(abm._code)
        if [i for i in prettify(rule).args if typeof(i) != LineNumberNode] != []
            print(i,"\n")
            print(" ",prettify(copy(rule)),"\n\n")
        end
    end
end

function Base.show(io::IO, ::Type{ABM{D, AN, AD}}) where {D, AN, AD}
    print(io, "ABM{$D, agents=(")
    for (i, (n, t)) in enumerate(zip(AN, AD.parameters))
        println(n,"::",t)
        i > 1 && print(io, ", ")
        print(io, n, "::", t)
    end
    print(io, ")}")
end

Base.getproperty(x::ABM, f::Symbol) = haskey(getfield(x, :_agents), f) ? x._agents[f] : getfield(x, f)

function checkUpdates!(params::NamedTuple, updates::Expr)

    postwalk(x-> @capture(x, a_[b_]) ? addUpdate(a,params, x) : x , updates)
    postwalk(x-> @capture(x, @dt(b_.a__)) ? addDt(b,a,params, x) : x , updates)

end

function checkUpdates!(params::NamedTuple, updates::NamedTuple)

    for (name, code) in pairs(updates)
        checkUpdates!(params, code)
    end

end

function addUpdate(expr, params, x)

    exprList = [Meta.parse(string(e)) for e in split("$expr", ".")]

    if !(exprList[1] == :communityNew)
        return x
    end

    p = params
    key = :community
    try
        for key in exprList[2:end]
            p = getproperty(p, key)
        end
    catch
        error("Key $key in expression @new($expr) not recognized. Is it an scope or parameter of an agent?")
    end

    p._updated = true
    
    return x

end

function addDt(a,b,c,params,x)

    if a != :community
        error("Scope $a not recognized. Use :community.")
    elseif !(b in names(params))
        error("Scope $b not recognized. Use one of $(names(params)).")
    elseif !(c in names(params[c]))
        error("Parameter $c not recognized. Use one of $(names(params[c])).")
    end

    params[b][c]._DE = true

    return x

end

function makeRulesFunction!(f, updates::NamedTuple, specialization)

    d = Dict{Symbol,Expr}()

    for (functionName, code) in pairs(updates)

        # if isdefined(CellBasedModels.CustomFunctions, functionName)
        #     error("Function $(functionName) already exists in CustomFunctions module.")
        # end

        for neighbors in NEIGHBORS_ALGS
            code_ = postwalk(x-> @capture(x, a_) && typeof(a) == Symbol ? (startswith(string(a), "@loopOverNeighbors") ? Symbol("$a$neighbors") : x) : x, code)
            code__ = quote

                function $functionName(community::CommunityABM{ABM{$(specialization...)}, CPU, $neighbors{$(specialization...)}}) 
                    function kernel!(communityNew, community) 
                        $code_
                    end
                    kernel!(community._parametersNew, community._parameters)
                end
                        
            end
            d[Symbol("$(functionName)_CPU_$neighbors")] = code__
            CellBasedModels.CustomFunctions.eval(code__)

            if hasCuda()
                code__ = quote
                    function $functionName(community::CommunityABM{ABM{$(specialization...)}, GPU, $neighbors{$(specialization...)}})
                        function kernel!(communityNew, community) 
                            $code_
                        end
                        @cuda threads=256 blocks=ceil(Int,size(community.agents,1)/256) kernel!(community._parametersNew, community._parameters)
                    end                        
                end
                d[Symbol("$(functionName)_GPU_$neighbors")] = code__
                CellBasedModels.CustomFunctions.eval(code__)
            end
        end
    
        f[functionName] = eval(Meta.parse("CellBasedModels.CustomFunctions.$functionName"))     

    end

    return NamedTuple(d)

end

function makeStepFunction!(abm::ABM, dims, tag)

    code = quote
    end
    for (name, _) in pairs(abm.rules)
        code = quote
            $code
            $name(community)
        end
    end
    code = quote
        $code
        update!(community)
    end
    code = quote
        function step!(community::Community{ABM{$dims, $tag}, P, N}) where {P<:AbstractPlatform, N<:AbstractNeighbors}
            $code
        end
    end
    d["step!"] = code
    CellBasedModels.CustomFunctions.eval(code)

    return
end

# """
#     function checkDeclared(a::Symbol, abm::ABM) 
#     function checkDeclared(a::Array{Symbol}, abm::ABM) 

# Check if a symbol is already declared in the model or inherited models.
# """
# function checkDeclared(a::Array{Symbol}, abm::ABM) 

#     for s in a
#         checkDeclared(s,abm)
#     end

# end

# function checkDeclared(a::Symbol, abm::ABM) 

#     if a in keys(abm.parameters)
#         error("Symbol ", a, " already declared in the abm.")
#     end

# end

# """
#     function change(x,code)

# Function called by update to add the .new if it is an update expression (e.g. x += 4 -> x.new += 4).
# """
# function change(x,code)

#     if code.args[1] == x
#         code.args[1] = Meta.parse(string(x,"__"))
#     end

#     if @capture(code.args[1],g_[h__]) && g == x
#         code.args[1] = :($(new(x))[$(h...)])
#     end

#     return code
# end

# """
# Function that adds the new operator to all the times the symbol s is being updated. e.g. update(x=1,x) -> x__ = 1.
# The modifications are also done in the keyword arguments of the macro functions as addAgent.
# """
# function update(code,s)

#     for op in UPDATINGOPERATORS
#         code = postwalk(x-> isexpr(x,op) ? change(s,x) : x, code)
#     end

#     return code
# end

# # """
# # Function called by update that checks that a function is a macro functions before adding the .new
# # """
# # function updateMacroFunctions(s,code)
# #     if code.args[1] in [BASESYMBOLS[:AddAgentMacro],BASESYMBOLS[:RemoveAgentMacro]]
# #         code = postwalk(x-> isexpr(x,:kw) ? change(s,x) : x, code)
# #     end

# #     return code
# # end

# """
# Function that adds to the UserParameters is they are updated, variables or variables medium and adds a position assignation when generating the matrices.
# """
# function addUpdates!(abm::ABM)

#     ##Assign updates of variable types

#     #Write updates
#     for up in keys(abm.declaredUpdates)
#         for sym in keys(abm.parameters)
#             abm.declaredUpdates[up] = update(abm.declaredUpdates[up],sym)
#         end
#     end
#     #Add updates ignoring @addAgent
#     for up in keys(abm.declaredUpdates)
#         for sym in keys(abm.parameters)
#             code = abm.declaredUpdates[up]
#             code = postwalk(x->@capture(x,@addAgent(g__)) ? :(_) : x , code)
#             if inexpr(code,new(sym))
#                 abm.parameters[sym].update = true
#             end
#         end
#     end

#     #Variables
#     for scope in [:agent,:model,:medium]
#         ode = addSymbol(scope,"ODE")
#         sde = addSymbol(scope,"SDE")
#         count = 0
#         vAgent, agentODE = captureVariables(abm.declaredUpdates[ode])
#         v2, agentSDE = captureVariables(abm.declaredUpdates[sde])
#         append!(vAgent,v2)
#         for (sym,prop) in abm.parameters #Add in dt__sym form
#             if prop.scope == scope && (inexpr(agentODE,opdt(sym)) || inexpr(agentSDE,opdt(sym)))
#                 count += 1
#                 abm.parameters[sym].update = true            
#                 abm.parameters[sym].variable = true            
#                 abm.parameters[sym].pos = count
#             end
#         end
#         for sym in unique(vAgent) #Add in dt(sym) form
#             if sym in keys(abm.parameters)
#                 if abm.parameters[sym].scope == scope && !abm.parameters[sym].variable
#                     count += 1
#                     abm.parameters[sym].update = true            
#                     abm.parameters[sym].variable = true            
#                     abm.parameters[sym].pos = count
#                 elseif abm.parameters[sym].variable
#                     nothing
#                 else
#                     error("dt in $ode and $sde can only be assigned to agent parameters. Declared with $(abm.parameters[sym].scope) parameter $sym.")
#                 end
#             end        
#         end
#         abm.declaredUpdates[ode] = agentODE
#         abm.declaredUpdates[sde] = agentSDE
#     end

#     #Remove inplace operators
#     for (up,code) in pairs(abm.declaredUpdates)
#         abm.declaredUpdates[up] = postwalk(x->@capture(x,inplace(g_)) ? g : x , code)
#     end
    
#     return
# end

# function compileABM!(abm)

#     for (scope,type) in zip(
#         [:agent,:agent,:model,:model,:medium,:medium],
#         [:ODE,:SDE,:ODE,:SDE,:ODE,:SDE]
#     )
#         functionDE(abm,scope,type)
#     end
#     for scope in [:agent,:model,:medium]
#         functionRule(abm,scope)
#     end

#     return

# end