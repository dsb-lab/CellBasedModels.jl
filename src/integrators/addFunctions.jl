using MacroTools: @capture, postwalk

"""
    analyze_rule_code(fdef::Expr; tracked_syms, protected_syms=Symbol[])

Analyze the body of a function definition (AST) to detect assignments involving the
given tracked symbols. Supports simple alias propagation and invalidation.

Returns a NamedTuple with fields:
- `assigns`     :: Vector{String}  — list of tracked assignments
- `violations`  :: Vector{String}  — assignments that modify protected symbols
"""
function chain_with_index(lhs)
    function go(x)
        if x isa Expr
            if x.head == :ref
                return go(lhs.args[1])[1], true
            elseif x.head == :.
                return vcat(go(x.args[1])[1], go(x.args[2])[1]), false
            else
                return [x], false
            end
        elseif x isa QuoteNode
            return [x.value], false
        elseif x isa Symbol
            return [x], false
        else
            return [x], false
        end
    end
    return go(lhs)
end

function extract_assigns(fdefs; mod::Module=Main)
    assigns = Tuple[]

    # Heads we treat differently
    normal_heads     = (:(=), :+=, :-=, :*=, :/=)
    broadcast_heads  = (:.=, :.+=, :.-=, :.*=, :./=)

    for f in fdefs
        fdef = f.fdef

        # Expand macros in the function body
        fdef_expanded = macroexpand(mod, fdef)

        # tracked: first arg (du), second (u) is protected
        tracked_syms   = f.args[1:2]
        du_sym         = tracked_syms[1]
        u_sym          = tracked_syms[2]
        protected_syms = [u_sym]

        @capture(fdef_expanded, function fname_(args__); body__ end) ||
            error("Expected a function definition expression")

        aliases = Dict{Symbol, Union{Vector{Symbol}, Symbol}}()

        postwalk(fdef_expanded) do ex
            # Maintain alias map: x = du.a.a  (adds),  x = something_else (removes)
            if ex isa Expr && ex.head == :(=)

                lhs, rhs = ex.args
                if lhs isa Symbol# && rhs isa Symbol
                    # println("Cases 0: ", ex)
                    chain, index = chain_with_index(rhs)
                    # println(chain, index)

                    if first(chain) in keys(aliases)
                        chain = vcat(aliases[first(chain)], chain[2:end])
                    end
                    rhs_root = first(chain)
                    tail = chain[2:end]

                    if lhs in protected_syms
                        nothing
                        # error("Assignment to protected symbol $(join(chain, '.')) is forbidden.")
                        # @warn("Assignment to protected symbol '$lhs' is might give unexpected behaviours. Just do it if you are not modifying the parameter in other way that might override it.")
                    elseif lhs in tracked_syms
                        # println("Cases 0.0: ", ex)
                        error("Direct assignment to tracked symbol '$lhs = ...' is forbidden. You will be overriding a parameter of the function.")
                    elseif lhs in keys(aliases)
                        if rhs_root in tracked_syms
                            # println("Cases 0.1: ", ex)
                            aliases[lhs] = chain
                        else
                            # println("Cases 0.2: ", ex)
                            delete!(aliases, lhs)
                        end
                    else
                        if rhs_root in tracked_syms
                            # println("Cases 0.3: ", ex)
                            aliases[lhs] = chain
                        # else
                        #     println("Cases 0.4: ", ex)
                        end
                    end
                elseif lhs isa Expr
                    # println("Cases 0: ", ex)
                    chain_lhs, index_lhs = chain_with_index(lhs)
                    if first(chain_lhs) in keys(aliases)
                        chain_lhs = vcat(aliases[first(chain_lhs)], chain_lhs[2:end])
                    end
                    lhs_root = first(chain_lhs)
                    tail = chain_lhs[2:end]

                    chain, index = chain_with_index(rhs)
                    if first(chain) in keys(aliases)
                        chain = vcat(aliases[first(chain)], chain[2:end])
                    end
                    rhs_root = first(chain)

                    if lhs_root in protected_syms
                        nothing
                        # error("Assignment to protected symbol $(join(chain_lhs, '.')) is forbidden.")
                        # @warn("Assignment to protected symbol '$(join(chain_lhs, '.'))' is might give unexpected behaviours. Just do it if you are not modifying the parameter in other way that might override it.")
                    # elseif lhs_root in tracked_syms && index_lhs && kwargs.broadcasting
                    #     error("Assignment to tracked symbol $(join(chain_lhs, '.')) when `broadcasting=true` without a broadcasting operator is disallowed.")
                    # elseif lhs_root in tracked_syms && !index_lhs && !kwargs.broadcasting
                    #     error("Assignment to vector-like field without indexing: $(join(chain_lhs, '.')). Use indexing (e.g. $(du_sym).scope.param[i] = ...).")
                    elseif lhs_root in tracked_syms && index_lhs
                        Base.push!(assigns, tuple(tail...))
                    # else
                    #     println("Cases 0.6: ", ex)
                    end
                end

                # println("Aliases after assignment: ", aliases)

            # Handle *all* assignment-like expressions (incl. broadcast)
            elseif ex isa Expr && (ex.head in (normal_heads..., broadcast_heads...))
                lhs = ex.args[1]
                chain, indexed = chain_with_index(lhs)

                # Resolve simple alias for the root
                if first(chain) in keys(aliases)
                    chain = vcat(aliases[first(chain)], chain[2:end])
                end

                root = first(chain)
                tail = chain[2:end]

                if root in protected_syms
                    nothing
                    # error("Assignment to protected symbol $(join(chain, '.')) is forbidden.")
                    # @warn("Assignment to protected symbol '$(join(chain, '.'))' is might give unexpected behaviours. Just do it if you are not modifying the parameter in other way that might override it.")
                # elseif root in tracked_syms && (ex.head in broadcast_heads) && !(kwargs.broadcasting)
                #     error("Broadcast assignment to tracked symbol $(join(chain, '.')) is forbidden without `broadcasting=true`.")

                elseif root in tracked_syms && (ex.head in broadcast_heads)
                    Base.push!(assigns, tuple(tail...))

                # elseif root in tracked_syms && (ex.head in normal_heads) && kwargs.broadcasting && !indexed
                #     error("Assignment to tracked symbol $(join(chain, '.')) when `broadcasting=true` without a broadcasting operator is disallowed.")
                    
                # elseif root in tracked_syms && (ex.head in normal_heads) && kwargs.broadcasting && indexed
                #     error("Non-broadcast assignment to tracked symbol $(join(chain, '.')) is forbidden when `broadcasting=true`. Use broadcast assignment (e.g. `.=`). This is disallowed as in some platforms indexing is disallowed.")

                elseif root in tracked_syms && (ex.head in normal_heads) && indexed

                    Base.push!(assigns, tuple(tail...))

                end
            end
            ex
        end
    end

    unique_assigns = unique(assigns)
    isPrivate(x) = length(x) > 0 && any(startswith(string(x[i]), '_') for i in 1:length(x))
    unique_assigns = [i for i in unique_assigns if !isPrivate(i)]

    return unique_assigns
end

function extract_topology_loops(fdefs)
    topology_pairs = Tuple[]

    for f in fdefs
        fdef = f.fdef

        # Use the body directly to search for loopOverTopology calls
        postwalk(fdef) do ex
            # Match loopOverTopology with any number of arguments
            # Common patterns: loopOverTopology(mesh, :origin, :target, index)
            #                  loopOverTopology(mesh, :origin, :target)
            if ex isa Expr && ex.head == :call && length(ex.args) >= 1
                func = ex.args[1]
                if func == :loopOverTopology || (func isa GlobalRef && func.name == :loopOverTopology)
                    # Extract origin and target (args 3 and 4 in 0-indexed, or 2 and 3 in 1-indexed after function name)
                    if length(ex.args) >= 4
                        origin_arg = ex.args[3]
                        target_arg = ex.args[4]
                        
                        # Handle QuoteNode
                        origin_sym = origin_arg isa QuoteNode ? origin_arg.value : origin_arg
                        target_sym = target_arg isa QuoteNode ? target_arg.value : target_arg
                        
                        if origin_sym isa Symbol && target_sym isa Symbol
                            Base.push!(topology_pairs, (origin_sym, target_sym))
                        end
                    end
                end
            end
            ex
        end
    end

    return unique(topology_pairs)
end

function analyze_rule_code(kwargs, fdefs; type, mod::Module=Main)

    unique_assigns = extract_assigns(fdefs; mod=mod)
    topology_pairs = extract_topology_loops(fdefs)

    # build emitted code (unchanged structure)
    fs = [f.fname for f in fdefs]
    assigns_code = :(CellBasedModels.addFunction!($(kwargs.mesh_name),
                                                 $(QuoteNode(type)),
                                                 $(QuoteNode(kwargs.scope_name)),
                                                 $unique_assigns,
                                                 ($(fs...),)))

    topology_code = if !isempty(topology_pairs)
        :(CellBasedModels.addTopologicalRelations!($(kwargs.mesh_name), $(tuple(topology_pairs...))))
    else
        nothing
    end

    functions_code = [quote
        function $(f.fname)($(f.args...))
            $(f.fdef)
            $(f.fname)($(f.args...))
        end
    end for f in fdefs]

    quote
        $(functions_code...)
        $assigns_code
        $topology_code
    end
end

function extract_parameters(n, ex)

    functions = []
    for i in n-1:-1:0
        fdef = ex[end - i]
        @capture(fdef, function fname_(args__); body__ end) ||
            error("Last $n arguments of @addX macro should be followed by a function definition of the form `function f!(uNew, u, p, t) ... end`. Found: $fdef")

        arg_syms = [a isa Expr && a.head == :(::) ? a.args[1] : a for a in args]
        nargs = length(arg_syms)
        nargs == 4 || error("Function must have four arguments (uNew, u, p, t).")

        Base.push!(functions, (fname=fname, args=arg_syms, fdef=fdef, body=body))
    end

    mesh_name = nothing
    for arg in ex[1:end - n]
        @capture(arg, kwarg_=value_)
        if kwarg == :model
            mesh_name = value
        else
            error("Unknown keyword argument '$kwarg'")
        end
    end

    if mesh_name === nothing
        error("Expected 'model' keyword argument.")
    end

    scope_name = functions[1].fname

    return (mesh_name=mesh_name, scope_name=scope_name), functions

end

macro addRule(ex...)

    kwargs, functions = extract_parameters(1, ex)
    code = analyze_rule_code(kwargs, functions; type=:RULE, mod=__module__)

    return esc(code)
end

macro addODE(ex...)

    kwargs, functions = extract_parameters(1, ex)
    code = analyze_rule_code(kwargs, functions; type=:ODE, mod=__module__)

    return esc(code)
end

macro addSDE(ex...)

    kwargs, functions = extract_parameters(2, ex)
    code = analyze_rule_code(kwargs, functions; type=:SDE, mod=__module__)

    return esc(code)
end

function extract_parameters_kernel_launch(ex)

    functions = []
    fdef = ex[end]
    @capture(fdef, function fname_(args__); body__ end) ||
        error("Last argument of @kernel_launch macro should be followed by a function definition of the form `function f!(uNew, u, p, t) ... end`. Found: $fdef")

        arg_syms = [a isa Expr && a.head == :(::) ? a.args[1] : a for a in args]
        nargs = length(arg_syms)
        nargs == 4 || error("Function must have four arguments. e.g (uNew, u, p, t) or (du, u, p, t).")

    Base.push!(functions, (fname=fname, args=arg_syms, fdef=fdef, body=body))

    cpu_threads = Threads.nthreads()
    gpu_threads = 256
    ndrange = nothing
    for arg in ex[1:end - 1]
        @capture(arg, kwarg_=value_)
        if kwarg == :cpu_threads
            if value > cpu_threads
                @warn("Requested number of CPU threads ($value) exceeds available threads ($cpu_threads). Using maximum available threads.")
            end
            cpu_threads = min(value, cpu_threads)
        elseif kwarg == :gpu_threads
            gpu_threads = value
        elseif kwarg == :ndrange
            ndrange = value
        else
            error("Unknown keyword argument '$kwarg'")
        end
    end

    if ndrange === nothing
        error("Expected 'ndrange' keyword argument indicating the size of the ndrange. e.g. ndrange=uNew.n")
    end

    return (cpu_threads=cpu_threads, gpu_threads=gpu_threads, ndrange=ndrange), functions
    
end

function extract_calls(fdefs; mod::Module=Main)
    assigns = Tuple[]

    for f in fdefs
        fdef = f.fdef

        # Expand macros in the function body
        fdef_expanded = macroexpand(mod, fdef)

        # tracked: first arg (du), second (u) is protected
        tracked_syms   = f.args[1:2]
        du_sym         = tracked_syms[1]
        u_sym          = tracked_syms[2]
        protected_syms = [u_sym]

        postwalk(fdef_expanded) do ex
            #For simple meshes
            du = nothing
            @capture(ex, du_.field_.variable_)
            if du == du_sym || du == u_sym
                Base.push!(assigns, (field, variable))
            end
            #For multi meshes
            du = nothing
            @capture(ex, du_.mesh_.field_.variable_)
            if du == du_sym || du == u_sym
                Base.push!(assigns, (mesh_, field, variable))
            end
        end
    end

    unique_assigns = unique(assigns)

    return unique_assigns
end

macro kernel_launch(ex...)

    kwargs, functions = extract_parameters_kernel_launch(ex)
    unique_assigns = extract_calls(functions; mod=__module__)

    fname = functions[1].fname
    fargs = functions[1].args
    fbody = functions[1].body

    ndrange_exprs = [length(i) == 2 ? :(CellBasedModels.lengthProperties($(fargs[1]).$(i[1]))) : :(CellBasedModels.lengthProperties($(fargs[1]).$(i[1]).$(i[2]))) for i in unique_assigns]
    ndrange_calc = isempty(ndrange_exprs) ? :(1) : :(max($(ndrange_exprs...)))

    code = quote
        CellBasedModels.@kernel function $fname($(fargs...))
            $(fbody...)
        end

        backend = KernelAbstractions.get_backend($(fargs[1]))
        threads = backend isa CellBasedModels.CPU ? $(kwargs.cpu_threads) : $(kwargs.gpu_threads)

        # ndrange_val = $ndrange_calc
        # println("Launching kernel with ndrange = ", ndrange_val, " and threads = ", threads)
        ndrange = $(kwargs.ndrange) isa UnstructuredMeshField ? length($(kwargs.ndrange)) : $(kwargs.ndrange)
        $fname(backend, threads)($(fargs...), ndrange=ndrange)
        KernelAbstractions.synchronize(backend)
    end

    # println(code)

    return esc(code)
end