using MacroTools
using ForwardDiff
using Printf

# --------------------------
# Helpers
# --------------------------
function _normalize_declared_symbol_debugauto(symex)
    if symex isa Symbol
        return (symex, symex)
    end

    if symex isa Expr && symex.head == :.
        parts = String[]
        cur = symex
        while cur isa Expr && cur.head == :.
            base = cur.args[1]
            field = cur.args[2]
            field_sym = field isa QuoteNode ? field.value : field
            pushfirst!(parts, string(field_sym))
            cur = base
        end
        base_sym = cur isa Symbol ? cur : Symbol(string(cur))
        valid = Symbol(string(base_sym), "__", join(parts, "__"))
        return (valid, symex)
    end

    if symex isa Expr && symex.head == :ref
        base = symex.args[1]
        idxs = symex.args[2:end]
        base_sym = base isa Symbol ? base : Symbol(string(base))
        idx_strs = map(i -> string(i), idxs)
        valid = Symbol(string(base_sym), "_", join(idx_strs, "_"), "_")
        return (valid, symex)
    end

    error("consistency_diffauto: unsupported symbol form: $symex")
end

_replace_debugauto(ex, dict) = MacroTools.postwalk(ex) do node
    get(dict, node, node)
end

function _collect_assigned_lhs_syms_debugauto(ex)
    lhs = Symbol[]
    MacroTools.postwalk(ex) do node
        if node isa Expr && node.head == :(=)
            L = node.args[1]
            L isa Symbol && push!(lhs, L)
        end
        node
    end
    lhs
end

function _infer_free_symbols_from_block_debugauto(block::Expr)
    assigned = Set{Symbol}(_collect_assigned_lhs_syms_debugauto(block))
    seen = Set{Any}()
    ordered = Any[]  # Symbol or Expr(:.) or Expr(:ref)

    add(x) = (x in seen) ? nothing : (push!(ordered, x); push!(seen, x); nothing)

    function walk(ex)
        ex isa LineNumberNode && return
        ex isa Number && return

        if ex isa Symbol
            (ex in assigned) || add(ex)
            return
        end

        if ex isa Expr
            if ex.head == :. || ex.head == :ref
                add(ex)
                return
            end
            if ex.head == :(=)
                walk(ex.args[2])
                return
            end
            if ex.head == :call
                for a in ex.args[2:end]   # skip call head
                    walk(a)
                end
                return
            end
            if ex.head == :block
                for s in ex.args
                    walk(s)
                end
                return
            end
            for a in ex.args
                walk(a)
            end
        end
    end

    walk(block)
    filter(x -> !(x isa Symbol && x in assigned), ordered)
end

function _wrt_to_valid_debugauto(wrt, orig_to_valid::Dict{Any,Symbol}, valid_to_orig::Dict{Symbol,Any})
    if wrt isa Symbol
        haskey(valid_to_orig, wrt) || error("consistency_diffauto: differentiation variable `$wrt` must be inferable/declared")
        return wrt
    else
        haskey(orig_to_valid, wrt) || error("consistency_diffauto: differentiation variable `$wrt` must be inferable/declared")
        return orig_to_valid[wrt]
    end
end

# --------------------------
# Macro
# --------------------------
macro consistency_diffauto(block, args...)
    block isa Expr || error("consistency_diffauto: must pass a `begin ... end` block")

    symbols_ex = nothing
    derivs_ex  = nothing
    silent = false

    for a in args
        if a isa Expr && a.head == :(=) && a.args[1] == :symbols
            symbols_ex = a.args[2]
        elseif a isa Expr && a.head == :(=) && a.args[1] == :derivatives
            derivs_ex = a.args[2]
        elseif a isa Expr && a.head == :(=) && a.args[1] == :silent
            silent = a.args[2]
        else
            error("consistency_diffauto: expected `derivatives=(...)` and optionally `symbols=(...)` or `silent=true/false`")
        end
    end
    derivs_ex === nothing && error("consistency_diffauto: missing `derivatives=(...)`")
    (derivs_ex isa Expr && derivs_ex.head == :tuple) ||
        error("consistency_diffauto: `derivatives=` must be a named tuple literal")

    if symbols_ex === nothing
        inferred = _infer_free_symbols_from_block_debugauto(block)
        for entry in derivs_ex.args
            (entry isa Expr && entry.head == :(=)) || error("consistency_diffauto: derivative entries must be `name=(f,x)`")
            pair = entry.args[2]
            (pair isa Expr && pair.head == :tuple && length(pair.args) == 2) || error("consistency_diffauto: bad derivative spec")
            wrt = pair.args[2]
            (wrt in inferred) || push!(inferred, wrt)
        end
        symbols_ex = Expr(:tuple, inferred...)
    end

    (symbols_ex isa Expr && symbols_ex.head == :tuple) || error("consistency_diffauto: `symbols=` must be a tuple")

    declared = [_normalize_declared_symbol_debugauto(s) for s in symbols_ex.args]
    orig_to_valid = Dict{Any,Symbol}()
    valid_to_orig = Dict{Symbol,Any}()
    for (v, o) in declared
        orig_to_valid[o] = v
        valid_to_orig[v] = o
    end

    block_for_fun = _replace_debugauto(block, orig_to_valid)

    # (analytic_name, target, wrt_valid)
    deriv_specs = Vector{Tuple{Symbol,Symbol,Symbol}}()
    for entry in derivs_ex.args
        (entry isa Expr && entry.head == :(=)) || error("consistency_diffauto: derivative entries must be `name=(f,x)`")
        outname = entry.args[1]
        pair = entry.args[2]
        (pair isa Expr && pair.head == :tuple && length(pair.args) == 2) ||
            error("consistency_diffauto: `$outname` must be `(f, x)`")

        target = pair.args[1]
        wrt    = pair.args[2]

        (target isa Symbol) || error("consistency_diffauto: `$outname`: first element must be a Symbol (e.g. c)")
        wrt_valid = _wrt_to_valid_debugauto(wrt, orig_to_valid, valid_to_orig)
        push!(deriv_specs, (outname, target, wrt_valid))
    end

    valid_args = [v for (v, _) in declared]

    unique_targets = unique(t[2] for t in deriv_specs)
    wrappers = Expr[]
    wrapper_names = Dict{Symbol,Symbol}()

    for target in unique_targets
        fname = gensym(Symbol("__debugauto_target_", target, "__"))
        wrapper_names[target] = fname
        body = Expr(:block, block_for_fun.args...)
        push!(body.args, :(return $target))
        push!(wrappers, :(local function $fname($(valid_args...))
            $body
        end))
    end

    base_call_args = Any[]
    for a in valid_args
        if haskey(valid_to_orig, a) && !(valid_to_orig[a] isa Symbol)
            push!(base_call_args, valid_to_orig[a]) # e.g. p.p1
        else
            push!(base_call_args, a)               # e.g. x
        end
    end

    row_exprs = Expr[]
    result_exprs = Expr[]
    for (outname, target, wrt_valid) in deriv_specs
        fname = wrapper_names[target]
        idx = findfirst(==(wrt_valid), valid_args)
        idx === nothing && error("consistency_diffauto: internal error: wrt var not in args")

        call_args_t = copy(base_call_args)
        call_args_t[idx] = :t

        row_expr = quote
            local analytic_value = $outname
            local analytic_num = ForwardDiff.value(analytic_value)

            local x0 = ForwardDiff.value($(base_call_args[idx]))
            local autodiff_num = ForwardDiff.value(
                ForwardDiff.derivative(t -> $fname($(call_args_t...)), x0)
            )

            local diff = abs(autodiff_num - analytic_num)
            
            push!(__debugauto_results__, (name=$(QuoteNode(outname)), analytic=analytic_num, autodiff=autodiff_num, difference=diff))
        end

        if !silent
            push!(row_expr.args, quote
                local diff_color = if analytic_num == 0.0 || autodiff_num == 0.0
                    "\033[33m"
                elseif diff > __debugauto_tolerance__
                    "\033[31m"
                else
                    "\033[32m"
                end

                Printf.@printf("│%15s│%15.6g│%15.6g│%s%15.6g\033[0m│\n",
                    $(string(outname)), analytic_num, autodiff_num, diff_color, diff)
            end)
        end

        push!(row_exprs, row_expr)
    end

    header_exprs = if silent
        Expr[]
    else
        [
            :(Printf.@printf("┌%s┬%s┬%s┬%s┐\n", "─"^15, "─"^15, "─"^15, "─"^15)),
            :(Printf.@printf("│%15s│%15s│%15s│%15s│\n", "Derivative", "Analytic", "Autodiff", "Difference")),
            :(Printf.@printf("├%s┼%s┼%s┼%s┤\n", "─"^15, "─"^15, "─"^15, "─"^15))
        ]
    end

    footer_exprs = if silent
        Expr[]
    else
        [:(Printf.@printf("└%s┴%s┴%s┴%s┘\n", "─"^15, "─"^15, "─"^15, "─"^15))]
    end

    return esc(quote
        begin
            $block

            local __debugauto_tolerance__ = 1e-10
            local __debugauto_results__ = NamedTuple{(:name, :analytic, :autodiff, :difference), Tuple{Symbol, Float64, Float64, Float64}}[]

            $(header_exprs...)

            $(wrappers...)
            $(row_exprs...)

            $(footer_exprs...)

            $block

            __debugauto_results__
        end
    end)
end
