using MacroTools
using Symbolics
using Symbolics.SymbolicUtils.Code: cse!, CSEState, topological_sort

# --- normalize declared symbol forms (x, p.p1, p[i1], p[i1,i2]) -> valid Symbol + original Expr key
function _normalize_declared_symbol(symex)
    if symex isa Symbol
        return (symex, symex)
    end

    # dotted: p.p1, q.r.s, ...
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

    # indexing: p[i1], p[i1,i2], ...
    if symex isa Expr && symex.head == :ref
        base = symex.args[1]
        idxs = symex.args[2:end]
        base_sym = base isa Symbol ? base : Symbol(string(base))
        idx_strs = map(i -> string(i), idxs)
        valid = Symbol(string(base_sym), "_", join(idx_strs, "_"), "_")
        return (valid, symex)
    end

    error("diffsym: unsupported symbol form in `symbols=`: $symex")
end

# collect LHS of assignments in a block (only simple `x = ...`)
function _collect_assigned_lhs_syms(ex)
    lhs = Symbol[]
    MacroTools.postwalk(ex) do node
        if node isa Expr && node.head == :(=)
            L = node.args[1]
            if L isa Symbol
                push!(lhs, L)
            end
        end
        node
    end
    lhs
end

# replace nodes according to a Dict (Expr/Symbol keys)
_replace(ex, dict) = MacroTools.postwalk(ex) do node
    get(dict, node, node)
end

# ------------------------------------------------------------
# Symbol extraction (no need to declare `symbols=`)
# ------------------------------------------------------------

# Recursively collect "symbol-like" references from expressions:
# - Symbols (x, y, p, i, ...)
# - dotted Expr(:.) treated as atomic (p.p1)
# - indexing Expr(:ref) treated as atomic (p[i])
# Excludes:
# - LHS assigned locals
# - function name position in calls (f in f(a) is not a symbol)
function _infer_free_symbols_from_block(block::Expr)
    assigned = Set{Symbol}(_collect_assigned_lhs_syms(block))
    seen = Set{Any}()
    ordered = Any[]   # Any = Symbol or Expr(:.) or Expr(:ref)

    function add_candidate(x)
        if !(x in seen)
            push!(ordered, x)
            push!(seen, x)
        end
    end

    function walk(ex; in_call_head::Bool=false)
        ex isa LineNumberNode && return
        ex isa Number && return

        if ex isa Symbol
            # ignore things that are assigned locals
            if !(ex in assigned)
                add_candidate(ex)
            end
            return
        end

        if ex isa Expr
            # treat dotted/ref as atomic symbols
            if ex.head == :. || ex.head == :ref
                add_candidate(ex)
                return
            end

            if ex.head == :(=)
                # walk only RHS; LHS is local definition
                walk(ex.args[2])
                return
            end

            if ex.head == :call
                # do NOT walk function position (args[1])
                for a in ex.args[2:end]
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

            # generic Expr
            for a in ex.args
                walk(a)
            end
        end
    end

    walk(block)

    # remove any assigned locals that slipped in (symbols only)
    inferred = Any[]
    for x in ordered
        if x isa Symbol
            x in assigned && continue
        end
        push!(inferred, x)
    end
    return inferred
end

# ------------------------------------------------------------
# AST -> Symbolics interpreter (no eval)
# ------------------------------------------------------------

function _resolve_base_fun(f::Symbol)
    isdefined(Base, f) || error("diffsym: unsupported function/operator `$f` in symbolic block (not in Base). ")
    return getfield(Base, f)
end

function _to_symbolics(ex, env::Dict{Symbol,Any})
    ex isa LineNumberNode && return nothing
    ex isa Number && return ex

    if ex isa Symbol
        haskey(env, ex) || error("diffsym: symbol `$ex` not found in symbolic environment. Declare it or ensure it is inferred.")
        return env[ex]
    end

    # Handle GlobalRef (e.g., Main.x from macro expansion)
    if ex isa GlobalRef
        sym = ex.name
        haskey(env, sym) || error("diffsym: symbol `$sym` not found in symbolic environment. Declare it or ensure it is inferred.")
        return env[sym]
    end

    if ex isa Expr
        if ex.head == :call
            f = ex.args[1]
            args = ex.args[2:end]

            # Handle qualified names like Main.:* or Base.:+
            fname = if f isa Symbol
                f
            elseif f isa Expr && f.head == :.
                # e.g., :(Main.:*) -> extract the symbol
                f.args[2] isa QuoteNode ? f.args[2].value : f.args[2]
            elseif f isa GlobalRef
                f.name
            else
                nothing
            end

            if fname isa Symbol
                fn = _resolve_base_fun(fname)
                sargs = Any[]
                for a in args
                    sa = _to_symbolics(a, env)
                    sa === nothing && continue
                    push!(sargs, sa)
                end
                return fn(sargs...)
            else
                error("diffsym: unsupported call head `$f` in symbolic block (only Base symbols supported)")
            end
        elseif ex.head == :block
            last = nothing
            for stmt in ex.args
                val = _to_symbolics(stmt, env)
                val === nothing && continue
                last = val
            end
            return last
        elseif ex.head == :if || ex.head == :elseif
            # Handle if-else expressions: if cond then_branch else else_branch end
            # Use Base.ifelse which Symbolics extends for symbolic expressions
            cond = _to_symbolics(ex.args[1], env)
            then_branch = _to_symbolics(ex.args[2], env)
            if length(ex.args) >= 3
                else_branch = _to_symbolics(ex.args[3], env)
            else
                else_branch = 0  # default to 0 if no else branch
            end
            return Base.ifelse(cond, then_branch, else_branch)
        elseif ex.head == :comparison
            # Handle comparison expressions like a > b
            # These become symbolic inequalities
            if length(ex.args) == 3
                left = _to_symbolics(ex.args[1], env)
                op = ex.args[2]
                right = _to_symbolics(ex.args[3], env)
                fn = _resolve_base_fun(op)
                return fn(left, right)
            else
                error("diffsym: chained comparisons not supported in symbolic block")
            end
        elseif ex.head == :tuple
            # Handle tuple expressions - return as a Julia Tuple
            return Tuple(_to_symbolics(a, env) for a in ex.args)
        else
            error("diffsym: unsupported expression head `$(ex.head)` in symbolic block")
        end
    end

    error("diffsym: unsupported node in symbolic block: $ex")
end

function _interpret_block(sym_block::Expr, declared_vars::Dict{Symbol,Any})
    env = Dict{Symbol,Any}(declared_vars)
    sym_block.head == :block || error("diffsym: expected a begin/end block")

    for stmt in sym_block.args
        stmt isa LineNumberNode && continue

        if stmt isa Expr && stmt.head == :(=)
            lhs = stmt.args[1]
            rhs = stmt.args[2]
            if lhs isa Symbol
                # Simple assignment: name = expr
                env[lhs] = _to_symbolics(rhs, env)
            elseif lhs isa Expr && lhs.head == :tuple
                # Tuple destructuring: (a, b, c) = expr
                rhs_val = _to_symbolics(rhs, env)
                if rhs_val isa Tuple
                    length(lhs.args) == length(rhs_val) || error("diffsym: tuple destructuring mismatch: $(length(lhs.args)) variables on LHS vs $(length(rhs_val)) values on RHS")
                    for (i, var) in enumerate(lhs.args)
                        var isa Symbol || error("diffsym: tuple destructuring only supports simple symbols, got `$var`")
                        env[var] = rhs_val[i]
                    end
                else
                    error("diffsym: tuple destructuring requires RHS to return a tuple, got `$(typeof(rhs_val))`")
                end
            else
                error("diffsym: only simple `name = expr` or tuple destructuring `(a, b) = expr` assignments supported in block for symbolic pass; got `$lhs`")
            end
        else
            _to_symbolics(stmt, env)
        end
    end

    return env
end

# Map a derivative "wrt" entry (Symbol or Expr like p.p1 / p[i]) to the internal valid Symbol.
function _wrt_to_valid(wrt, orig_to_valid::Dict{Any,Symbol}, valid_to_orig::Dict{Symbol,Any})
    if wrt isa Symbol
        haskey(valid_to_orig, wrt) || error("diffsym: differentiation variable `$wrt` must appear in `symbols=` (or be inferable)")
        return wrt
    else
        haskey(orig_to_valid, wrt) || error("diffsym: differentiation variable `$wrt` must appear in `symbols=` (or be inferable)")
        return orig_to_valid[wrt]
    end
end

# ------------------------------------------------------------
# Macro
# ------------------------------------------------------------
macro diffsym(block, args...)
    block isa Expr || error("diffsym: must pass a `begin ... end` block")

    # Expand any nested macros in the block first (in caller's module context)
    block = macroexpand(__module__, block)

    # --- extract keywords (symbols optional)
    # Note: `=` in macro args can be parsed as `:=` or `:kw` depending on context
    symbols_ex = nothing
    derivs_ex  = nothing
    for a in args
        if a isa Expr && (a.head == :(=) || a.head == :kw)
            key = a.args[1]
            val = a.args[2]
            if key == :symbols
                symbols_ex = val
            elseif key == :derivatives
                derivs_ex = val
            else
                error("diffsym: expected `derivatives=(...)` and optionally `symbols=(...)`")
            end
        else
            error("diffsym: expected `derivatives=(...)` and optionally `symbols=(...)`")
        end
    end
    derivs_ex === nothing && error("diffsym: missing `derivatives=(...)`")

    # Normalize derivs_ex to always be a tuple
    # Single entry like derivatives=(dc_dx=(c,x)) without trailing comma parses as :(=), not :tuple
    if derivs_ex isa Expr && (derivs_ex.head == :(=) || derivs_ex.head == :kw)
        derivs_ex = Expr(:tuple, derivs_ex)
    end

    (derivs_ex isa Expr && derivs_ex.head == :tuple) ||
        error("diffsym: `derivatives=` must be a named tuple literal, e.g. derivatives=(dc_dx=(c,x),)")

    # If symbols not provided, infer them from the block + ensure wrt variables are included
    if symbols_ex === nothing
        inferred = _infer_free_symbols_from_block(block)  # Any[Symbol or Expr(:.) or Expr(:ref)]

        # also include any wrt entries from derivatives, even if not used in the block
        for entry in derivs_ex.args
            (entry isa Expr && (entry.head == :(=) || entry.head == :kw)) || error("diffsym: each derivative entry must be like `dc_dx = (c, x)`")
            pair = entry.args[2]
            (pair isa Expr && pair.head == :tuple && length(pair.args) == 2) ||
                error("diffsym: `$(entry.args[1])` must be a 2-tuple `(f, x)`")
            wrt = pair.args[2]
            if !(wrt in inferred)
                push!(inferred, wrt)
            end
        end

        symbols_ex = Expr(:tuple, inferred...)
    end

    (symbols_ex isa Expr && symbols_ex.head == :tuple) ||
        error("diffsym: `symbols=` must be a tuple, e.g. symbols=(x, y, p.p1)")

    # --- build mappings for declared symbols
    declared = [_normalize_declared_symbol(s) for s in symbols_ex.args]  # (valid, original_expr)
    orig_to_valid = Dict{Any, Symbol}()   # :(p.p1) => :p__p1
    valid_to_orig = Dict{Symbol, Any}()   # :p__p1 => :(p.p1)

    for (v, o) in declared
        orig_to_valid[o] = v
        valid_to_orig[v] = o
    end

    # --- reject assignments to declared symbols inside the user block
    # (now declared symbols include inferred free symbols; we only forbid assigning those)
    assigned_lhs = Any[]
    MacroTools.postwalk(block) do node
        if node isa Expr && node.head == :(=)
            push!(assigned_lhs, node.args[1])
        end
        node
    end
    for L in assigned_lhs
        if haskey(orig_to_valid, L) || (L isa Symbol && haskey(valid_to_orig, L) && valid_to_orig[L] isa Symbol)
            error("diffsym: declared/inferred symbol `$L` is assigned inside the block; not allowed")
        end
    end

    # --- symbolic-pass rewrite: p.p1 -> p__p1, p[i] -> p_i_
    sym_block = _replace(block, orig_to_valid)

    # --- parse derivative requests
    # store (outname, f_sym, wrt_valid_sym)
    deriv_specs = Vector{Tuple{Symbol, Symbol, Symbol}}()
    for entry in derivs_ex.args
        (entry isa Expr && (entry.head == :(=) || entry.head == :kw)) ||
            error("diffsym: each derivative entry must be like `dc_dx = (c, x)`")

        outname = entry.args[1]
        pair = entry.args[2]
        (pair isa Expr && pair.head == :tuple && length(pair.args) == 2) ||
            error("diffsym: `$outname` must be a 2-tuple `(f, x)`")

        f = pair.args[1]
        wrt = pair.args[2]

        (f isa Symbol) || error("diffsym: `$outname`: first element must be a Symbol (e.g. c)")

        wrt_valid = _wrt_to_valid(wrt, orig_to_valid, valid_to_orig)
        push!(deriv_specs, (outname, f, wrt_valid))
    end

    # ------------------------------------------------------------
    # NO EVAL: build Symbolics variables + interpret block into Symbolics IR
    # ------------------------------------------------------------
    declared_vars = Dict{Symbol,Any}()
    for (v, _) in declared
        declared_vars[v] = Symbolics.variable(v)
    end

    env = _interpret_block(sym_block, declared_vars)

    # Collect all derivative symbolic expressions
    deriv_syms = []
    deriv_names = Symbol[]
    for (outname, f, wrt_valid) in deriv_specs
        haskey(env, f) || error("diffsym: requested derivative of `$f`, but `$f` is not defined in the block")

        fexpr = env[f]
        xvar  = declared_vars[wrt_valid]

        d = Symbolics.expand_derivatives(Symbolics.Differential(xvar)(fexpr))
        d = Symbolics.simplify(d)
        push!(deriv_syms, d)
        push!(deriv_names, outname)
    end

    # Apply Common Subexpression Elimination (CSE) across ALL derivatives
    cse_state = CSEState()
    cse_output_vars = []
    for d in deriv_syms
        # cse! takes the unwrapped expression and accumulates common subexpressions in state
        r = cse!(Symbolics.unwrap(d), cse_state)
        push!(cse_output_vars, r)
    end

    # Get topologically sorted CSE assignments
    sorted_assigns = topological_sort(cse_state.sorted_exprs)

    deriv_assign_exprs = Expr[]
    
    # First, add the CSE intermediate variable assignments
    for item in sorted_assigns
        lhs_ex = Symbolics.toexpr(item.lhs)
        rhs_ex = Symbolics.toexpr(item.rhs)
        # substitute valid symbols back to original dotted/bracket expressions
        rhs_ex_orig = MacroTools.postwalk(rhs_ex) do node
            if node isa Symbol && haskey(valid_to_orig, node)
                valid_to_orig[node]
            else
                node
            end
        end
        push!(deriv_assign_exprs, :($lhs_ex = $rhs_ex_orig))
    end

    # Then add the final derivative assignments using the CSE output variables
    for (i, outname) in enumerate(deriv_names)
        ex_d = Symbolics.toexpr(cse_output_vars[i])

        # substitute valid symbols back to original dotted/bracket expressions
        ex_d_orig = MacroTools.postwalk(ex_d) do node
            if node isa Symbol && haskey(valid_to_orig, node)
                valid_to_orig[node]
            else
                node
            end
        end

        push!(deriv_assign_exprs, :($outname = $ex_d_orig))
    end

    return esc(quote
        begin
            $block
            $(deriv_assign_exprs...)
        end
    end)
end
