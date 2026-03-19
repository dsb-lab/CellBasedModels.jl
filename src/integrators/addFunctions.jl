using MacroTools: @capture, postwalk
using ..Unitful: Dimensions, NoDims

#=
================================================================================
                        DIMENSIONAL ANALYSIS SYSTEM
================================================================================
Provides compile-time dimensional consistency checking for @addODE, @addRule, @addSDE.

Dimensions are represented as Dict{Symbol, Rational} where keys are base dimensions
(e.g., :L, :T, :M, :C) and values are their exponents.

Examples:
- Length: Dict(:L => 1)
- Velocity (L/T): Dict(:L => 1, :T => -1)
- Acceleration (L/T²): Dict(:L => 1, :T => -2)
- Dimensionless: Dict()
=#

"""
Represents dimensions as a dictionary of base dimension symbols to their exponents.
An empty Dict represents a dimensionless quantity.
"""
const DimensionDict = Dict{Symbol, Rational{Int}}

"""
    normalize_dimension(d::DimensionDict) -> DimensionDict

Remove zero-exponent dimensions from the dictionary.
"""
function normalize_dimension(d::DimensionDict)
    return DimensionDict(k => v for (k, v) in d if v != 0)
end

"""
    parse_dimension_spec(spec::Union{Nothing, Symbol, Expr}) -> DimensionDict

Convert a Parameter dimension specification to a DimensionDict.

Examples:
- `nothing` → empty Dict (dimensionless)
- `:L` → Dict(:L => 1)
- `:(L/T)` → Dict(:L => 1, :T => -1)
- `:(L*T^2)` → Dict(:L => 1, :T => 2)
"""
function parse_dimension_spec(spec::Nothing)
    return DimensionDict()
end

function parse_dimension_spec(spec::Symbol)
    return DimensionDict(spec => 1)
end

function parse_dimension_spec(spec::Expr)
    return _parse_dim_expr(spec)
end

"""
    parse_dimension_spec(spec::Dimensions) -> DimensionDict

Convert Unitful Dimensions to DimensionDict.
Maps Unitful dimension names to internal symbols:
- :Length → :L
- :Time → :T
- :Mass → :M
- :Amount → :N
- :Temperature → :Θ
- :Current → :I
- :Luminosity → :J

Examples:
- `u"𝐋"` → Dict(:L => 1)
- `u"𝐋/𝐓"` → Dict(:L => 1, :T => -1)
"""
function parse_dimension_spec(spec::Dimensions)
    # Unitful NoDims → dimensionless
    if spec == NoDims
        return DimensionDict()
    end
    
    # Mapping from Unitful dimension names to our symbols
    dim_name_map = Dict(
        :Length => :L,
        :Time => :T,
        :Mass => :M,
        :Amount => :N,
        :Temperature => :Θ,
        :Current => :I,
        :Luminosity => :J,
    )
    
    result = DimensionDict()
    
    # Unitful Dimensions are structured as:
    # Dimensions{(Dimension{:Length}(1//1), Dimension{:Time}(-1//1))}
    # Each element is a Unitful.Dimension{Name}(exponent)
    for dim in typeof(spec).parameters[1]
        # Extract dimension name from type parameter (e.g., :Length from Dimension{:Length})
        dim_name = typeof(dim).parameters[1]
        # Extract exponent value
        exp_val = dim.power
        # Map to our internal symbol
        sym = get(dim_name_map, dim_name, dim_name)
        result[sym] = Rational(exp_val)
    end
    
    return normalize_dimension(result)
end

function _parse_dim_expr(ex::Symbol)
    return DimensionDict(ex => 1)
end

function _parse_dim_expr(ex::Number)
    return DimensionDict()  # Numbers are dimensionless
end

function _parse_dim_expr(ex::Expr)
    if ex.head == :call
        op = ex.args[1]
        if op == :* && length(ex.args) >= 3
            # Multiplication: combine dimensions
            result = DimensionDict()
            for arg in ex.args[2:end]
                d = _parse_dim_expr(arg)
                for (k, v) in d
                    result[k] = get(result, k, 0//1) + v
                end
            end
            return normalize_dimension(result)
        elseif op == :/ && length(ex.args) == 3
            # Division: subtract dimensions of denominator
            num = _parse_dim_expr(ex.args[2])
            den = _parse_dim_expr(ex.args[3])
            result = copy(num)
            for (k, v) in den
                result[k] = get(result, k, 0//1) - v
            end
            return normalize_dimension(result)
        elseif op == :^ && length(ex.args) == 3
            # Power: multiply exponents
            base = _parse_dim_expr(ex.args[2])
            exp_val = ex.args[3]
            if !(exp_val isa Number)
                @warn "Non-numeric exponent in dimension expression: $ex"
                return DimensionDict(:_unknown => 1)
            end
            result = DimensionDict()
            for (k, v) in base
                result[k] = v * exp_val
            end
            return normalize_dimension(result)
        end
    end
    @warn "Unknown dimension expression: $ex"
    return DimensionDict(:_unknown => 1)
end

"""
    dim_multiply(d1::DimensionDict, d2::DimensionDict) -> DimensionDict

Multiply two dimensions (add exponents).
"""
function dim_multiply(d1::DimensionDict, d2::DimensionDict)
    result = copy(d1)
    for (k, v) in d2
        result[k] = get(result, k, 0//1) + v
    end
    return normalize_dimension(result)
end

"""
    dim_divide(d1::DimensionDict, d2::DimensionDict) -> DimensionDict

Divide two dimensions (subtract exponents).
"""
function dim_divide(d1::DimensionDict, d2::DimensionDict)
    result = copy(d1)
    for (k, v) in d2
        result[k] = get(result, k, 0//1) - v
    end
    return normalize_dimension(result)
end

"""
    dim_power(d::DimensionDict, exp::Number) -> DimensionDict

Raise dimension to a power.
"""
function dim_power(d::DimensionDict, exp::Number)
    result = DimensionDict()
    for (k, v) in d
        result[k] = v * exp
    end
    return normalize_dimension(result)
end

"""
    dims_compatible(d1::DimensionDict, d2::DimensionDict) -> Bool

Check if two dimensions are compatible (equal after normalization).
Handles the special :_unknown dimension by returning true (permissive).
"""
function dims_compatible(d1::DimensionDict, d2::DimensionDict)
    # Unknown dimensions are always compatible (permissive mode)
    if haskey(d1, :_unknown) || haskey(d2, :_unknown)
        return true
    end
    # Zero is compatible with any dimension (0 * anything = 0)
    if haskey(d1, :_zero) || haskey(d2, :_zero)
        return true
    end
    return normalize_dimension(d1) == normalize_dimension(d2)
end

"""
    dim_to_string(d::DimensionDict) -> String

Convert dimension dict to human-readable string.
"""
function dim_to_string(d::DimensionDict)
    d = normalize_dimension(d)
    if isempty(d)
        return "dimensionless"
    end
    parts = []
    for (k, v) in sort(collect(d), by=x->x[1])
        if v == 1
            push!(parts, string(k))
        elseif v == -1
            push!(parts, "$(k)⁻¹")
        else
            push!(parts, "$(k)^$(v)")
        end
    end
    return join(parts, "·")
end

"""
    extract_aliases(fdef::Expr, u_sym::Symbol, du_sym::Symbol) -> Dict{Symbol, Expr}

Walk through a function body and extract alias assignments like:
- `p = u.p` (simple alias)
- `x_i = u.n.x[i]` (indexed expression alias)
Returns a mapping from alias symbol to the original expression.
"""
function extract_aliases(fdef::Expr, u_sym::Symbol, du_sym::Symbol)
    aliases = Dict{Symbol, Expr}()
    
    postwalk(fdef) do ex
        # Look for assignments: local_var = u.something or local_var = u.something[i]
        if ex isa Expr && ex.head == :(=)
            lhs = ex.args[1]
            rhs = ex.args[2]
            
            # LHS must be a simple symbol (not a field access)
            if lhs isa Symbol && lhs != u_sym && lhs != du_sym
                # Check if RHS is a dotchain starting with u or du
                if rhs isa Expr && rhs.head == :.
                    chain = _extract_dotchain(rhs)
                    if chain !== nothing && !isempty(chain)
                        root = chain[1]
                        if root == u_sym || root == du_sym
                            aliases[lhs] = rhs
                        end
                    end
                # Also check if RHS is an indexed expression like u.n.x[i]
                elseif rhs isa Expr && rhs.head == :ref
                    base = rhs.args[1]
                    if base isa Expr && base.head == :.
                        chain = _extract_dotchain(base)
                        if chain !== nothing && !isempty(chain)
                            root = chain[1]
                            if root == u_sym || root == du_sym
                                # Store the indexed expression
                                aliases[lhs] = rhs
                            end
                        end
                    end
                end
            end
        end
        ex
    end
    
    return aliases
end

"""
    resolve_alias_chain(ex::Expr, alias_map::Dict{Symbol, Expr}) -> Expr

Given an expression and an alias map, resolve any aliased symbols.
Examples:
- `p.b[1]` with {p => u.p} → `u.p.b[1]`
- `x_i` with {x_i => u.n.x[i]} → `u.n.x[i]`
- `x_i - x_j` → resolves both x_i and x_j if they are aliases
"""
function resolve_alias_chain(ex, alias_map::Dict{Symbol, Expr})
    if isempty(alias_map)
        return ex
    end
    
    # Simple symbol - check if it's a direct alias
    if ex isa Symbol
        if haskey(alias_map, ex)
            return alias_map[ex]
        end
        return ex
    end
    
    # For dot chains, check if the root is an alias
    if ex isa Expr && ex.head == :.
        chain = _extract_dotchain(ex)
        if chain !== nothing && !isempty(chain)
            root = chain[1]
            if haskey(alias_map, root)
                # Replace root with the aliased expression
                aliased_expr = alias_map[root]
                # Build new chain: aliased_expr.rest_of_chain
                result = aliased_expr
                for i in 2:length(chain)
                    result = Expr(:., result, QuoteNode(chain[i]))
                end
                return result
            end
        end
    end
    
    # For indexing expressions like p.b[1], resolve the base
    if ex isa Expr && ex.head == :ref
        base = ex.args[1]
        resolved_base = resolve_alias_chain(base, alias_map)
        if resolved_base !== base
            return Expr(:ref, resolved_base, ex.args[2:end]...)
        end
    end
    
    return ex
end

"""
    build_dimension_map(mesh_expr::Symbol, mod::Module) -> Dict{Symbol, DimensionDict}

Build a mapping from parameter names to their dimensions by evaluating the mesh.
Returns a Dict where keys are qualified names like (:n, :x) or (:p, :α).
"""
function build_dimension_map(mesh, u_sym::Symbol)
    dim_map = Dict{Any, DimensionDict}()
    
    # Get node/element properties
    if hasfield(typeof(mesh), :_p) && mesh._p !== nothing
        for (scope_name, scope_prop) in pairs(mesh._p)
            if scope_prop !== nothing && hasfield(typeof(scope_prop), :p)
                for (prop_name, param) in pairs(scope_prop.p)
                    key = (u_sym, scope_name, prop_name)
                    dim_map[key] = parse_dimension_spec(param.dimensions)
                end
            end
        end
    end
    
    # Get shared parameters
    if hasfield(typeof(mesh), :_parameters) && mesh._parameters !== nothing
        for (name, param) in pairs(mesh._parameters)
            key = (u_sym, :p, name)
            dim_map[key] = parse_dimension_spec(param.dimensions)
        end
    end
    
    return dim_map
end

"""
    analyze_expr_dimension(ex, dim_map, u_sym, du_sym; is_derivative=true, alias_map=Dict{Symbol,Expr}()) -> DimensionDict

Recursively analyze an expression and compute its dimension.
If `is_derivative=true`, the du_sym variable is treated as a time derivative (for ODE/SDE).
If `is_derivative=false`, du_sym is just new state (for RULE).
The `alias_map` is used to resolve local aliases like `p = u.p`.
"""
function analyze_expr_dimension(ex, dim_map::Dict, u_sym::Symbol, du_sym::Symbol; 
                                 is_derivative::Bool=true, 
                                 alias_map::Dict{Symbol,Expr}=Dict{Symbol,Expr}())
    # First, resolve any aliases in the expression
    ex = resolve_alias_chain(ex, alias_map)
    
    # Literal numbers: 0 is compatible with any dimension, others are dimensionless
    if ex isa Number
        if ex == 0 || ex == 0.0
            return DimensionDict(:_zero => 1)  # Special marker for zero - compatible with anything
        end
        return DimensionDict()
    end
    
    # Simple symbol - check if it's a known variable
    if ex isa Symbol
        # Common dimensionless symbols
        if ex in (:i, :j, :t)  # indices and time variable
            return ex == :t ? DimensionDict(:T => 1) : DimensionDict()
        end
        return DimensionDict(:_unknown => 1)  # Unknown, be permissive
    end
    
    if !(ex isa Expr)
        return DimensionDict(:_unknown => 1)
    end
    
    # Field access: u.n.x, du.n.c, etc.
    if ex.head == :.
        chain = _extract_dotchain(ex)
        if chain !== nothing && length(chain) >= 3
            root = chain[1]
            if root == u_sym || root == du_sym
                key = (u_sym, chain[2], chain[3])
                if haskey(dim_map, key)
                    base_dim = dim_map[key]
                    # For du variables in ODEs/SDEs, they represent time derivatives (du/dt)
                    # So their dimension is the original dimension divided by time
                    # But for RULE, uNew is just the new state value (same dimension as u)
                    if root == du_sym && is_derivative
                        return dim_divide(base_dim, DimensionDict(:T => 1))
                    end
                    return base_dim
                end
            end
        end
        return DimensionDict(:_unknown => 1)
    end
    
    # Indexing: u.n.x[i]
    if ex.head == :ref
        base = ex.args[1]
        return analyze_expr_dimension(base, dim_map, u_sym, du_sym; is_derivative=is_derivative, alias_map=alias_map)
    end
    
    # Function calls and operations
    if ex.head == :call
        op = ex.args[1]
        args = ex.args[2:end]
        
        # Arithmetic operations (including broadcast versions)
        if op in (:+, :-, :.+, :.-)
            # Addition/subtraction: all operands must have same dimension
            if isempty(args)
                return DimensionDict()
            end
            first_dim = analyze_expr_dimension(args[1], dim_map, u_sym, du_sym; is_derivative=is_derivative, alias_map=alias_map)
            return first_dim  # Return first, consistency will be checked separately
            
        elseif op in (:*, :.*)
            # Multiplication: combine dimensions
            result = DimensionDict()
            for arg in args
                d = analyze_expr_dimension(arg, dim_map, u_sym, du_sym; is_derivative=is_derivative, alias_map=alias_map)
                result = dim_multiply(result, d)
            end
            return result
            
        elseif op in (:/, :./)
            if length(args) == 2
                num = analyze_expr_dimension(args[1], dim_map, u_sym, du_sym; is_derivative=is_derivative, alias_map=alias_map)
                den = analyze_expr_dimension(args[2], dim_map, u_sym, du_sym; is_derivative=is_derivative, alias_map=alias_map)
                return dim_divide(num, den)
            end
            
        elseif op in (:^, :.^)
            if length(args) == 2
                base = analyze_expr_dimension(args[1], dim_map, u_sym, du_sym; is_derivative=is_derivative, alias_map=alias_map)
                exp_val = args[2]
                if exp_val isa Number
                    return dim_power(base, exp_val)
                else
                    # Non-constant exponent - result is unknown
                    return DimensionDict(:_unknown => 1)
                end
            end
            
        elseif op in (:sqrt, :cbrt)
            if length(args) == 1
                d = analyze_expr_dimension(args[1], dim_map, u_sym, du_sym; is_derivative=is_derivative, alias_map=alias_map)
                exp_val = op == :sqrt ? 1//2 : 1//3
                return dim_power(d, exp_val)
            end
            
        elseif op in (:sin, :cos, :tan, :exp, :log, :abs)
            # Transcendental functions: argument must be dimensionless, result is dimensionless
            return DimensionDict()
            
        elseif op == :length
            # length returns dimensionless count
            return DimensionDict()
        end
        
        # Unknown function - be permissive
        return DimensionDict(:_unknown => 1)
    end
    
    # Broadcast operations: .+, .-, .*, ./, etc.
    if ex.head == :.  && length(ex.args) == 2 && ex.args[2] isa Expr && ex.args[2].head == :tuple
        # This is broadcast syntax like f.(args...)
        return DimensionDict(:_unknown => 1)
    end
    
    return DimensionDict(:_unknown => 1)
end

"""
Helper to extract dot-chain like u.n.x into [:u, :n, :x]
"""
function _extract_dotchain(ex)
    chain = Symbol[]
    while ex isa Expr && ex.head == :.
        prop = ex.args[2]
        if prop isa QuoteNode
            pushfirst!(chain, prop.value)
        elseif prop isa Symbol
            pushfirst!(chain, prop)
        else
            return nothing
        end
        ex = ex.args[1]
    end
    if ex isa Symbol
        pushfirst!(chain, ex)
        return chain
    end
    return nothing
end

"""
    check_assignment_dimensions(lhs, rhs, dim_map, u_sym, du_sym) -> (Bool, String)

Check if an assignment is dimensionally consistent.
Returns (is_valid, error_message).
"""
function check_assignment_dimensions(lhs, rhs, dim_map, u_sym::Symbol, du_sym::Symbol)
    lhs_dim = analyze_expr_dimension(lhs, dim_map, u_sym, du_sym)
    rhs_dim = analyze_expr_dimension(rhs, dim_map, u_sym, du_sym)
    
    if dims_compatible(lhs_dim, rhs_dim)
        return (true, "")
    else
        return (false, "Dimensional mismatch: $(lhs) has dimension [$(dim_to_string(lhs_dim))] " *
                       "but is assigned [$(dim_to_string(rhs_dim))]")
    end
end

"""
    check_addition_dimensions(ex, dim_map, u_sym, du_sym; is_derivative=true, alias_map=Dict{Symbol,Expr}()) -> Vector{String}

Check that all terms in addition/subtraction have consistent dimensions.
"""
function check_addition_dimensions(ex, dim_map, u_sym::Symbol, du_sym::Symbol; 
                                    is_derivative::Bool=true, 
                                    alias_map::Dict{Symbol,Expr}=Dict{Symbol,Expr}())
    errors = String[]
    
    postwalk(ex) do node
        if node isa Expr && node.head == :call && node.args[1] in (:+, :-, :.+, :.-)
            args = node.args[2:end]
            if length(args) >= 2
                first_dim = analyze_expr_dimension(args[1], dim_map, u_sym, du_sym; is_derivative=is_derivative, alias_map=alias_map)
                for (i, arg) in enumerate(args[2:end])
                    arg_dim = analyze_expr_dimension(arg, dim_map, u_sym, du_sym; is_derivative=is_derivative, alias_map=alias_map)
                    if !dims_compatible(first_dim, arg_dim)
                        push!(errors, "Terms in addition/subtraction have incompatible dimensions: " *
                                     "[$(dim_to_string(first_dim))] vs [$(dim_to_string(arg_dim))] in: $node")
                    end
                end
            end
        end
        node
    end
    
    return errors
end

"""
    validate_dimensions(mesh, fdefs, u_sym::Symbol, du_sym::Symbol) -> Vector{String}

Validate dimensional consistency in function definitions.
Returns a list of error messages (empty if all valid).
"""
function validate_dimensions(mesh, fdefs, u_sym::Symbol, du_sym::Symbol)
    errors = String[]
    dim_map = build_dimension_map(mesh, u_sym)
    
    for f in fdefs
        fdef = f.fdef
        
        postwalk(fdef) do ex
            # Check assignments
            if ex isa Expr && ex.head == :(=)
                lhs = ex.args[1]
                rhs = ex.args[2]
                valid, msg = check_assignment_dimensions(lhs, rhs, dim_map, u_sym, du_sym)
                if !valid
                    push!(errors, "In function $(f.fname): $msg")
                end
            end
            
            # Check broadcast assignments
            if ex isa Expr && ex.head == :.= 
                lhs = ex.args[1]
                rhs = ex.args[2]
                valid, msg = check_assignment_dimensions(lhs, rhs, dim_map, u_sym, du_sym)
                if !valid
                    push!(errors, "In function $(f.fname): $msg")
                end
            end
            
            ex
        end
        
        # Check addition consistency
        add_errors = check_addition_dimensions(fdef, dim_map, u_sym, du_sym)
        append!(errors, ["In function $(f.fname): $e" for e in add_errors])
    end
    
    return unique(errors)
end

"""
    _check_single_assignment(dim_errors, dim_map, lhs, rhs, u_sym, du_sym, func_name, is_derivative, alias_map, line_info)

Runtime helper to check a single assignment's dimensional consistency.
Pushes error messages to `dim_errors` vector.
The `line_info` parameter should be a string like "line 42" or empty.
"""
function _check_single_assignment(dim_errors::Vector{String}, dim_map, lhs, rhs, u_sym::Symbol, du_sym::Symbol, func_name::String, is_derivative::Bool, alias_map::Dict{Symbol,Expr}=Dict{Symbol,Expr}(), line_info::String="")
    lhs_dim = analyze_expr_dimension(lhs, dim_map, u_sym, du_sym; is_derivative=is_derivative, alias_map=alias_map)
    rhs_dim = analyze_expr_dimension(rhs, dim_map, u_sym, du_sym; is_derivative=is_derivative, alias_map=alias_map)
    
    location = isempty(line_info) ? "In function $func_name" : "$func_name $line_info"
    
    if !dims_compatible(lhs_dim, rhs_dim)
        msg = "$location: $(lhs) has dimension [$(dim_to_string(lhs_dim))] " *
              "but is assigned [$(dim_to_string(rhs_dim))]"
        push!(dim_errors, msg)
    end
    
    # Also check addition consistency within the rhs
    add_errors = check_addition_dimensions(rhs, dim_map, u_sym, du_sym; is_derivative=is_derivative, alias_map=alias_map)
    for e in add_errors
        push!(dim_errors, "$location: $e")
    end
    
    return nothing
end

#=
================================================================================
                        END DIMENSIONAL ANALYSIS SYSTEM
================================================================================
=#

"""
    CHECK_FUNCTIONS

A dictionary mapping special function names to a list of field extraction configurations.
Each entry specifies:
- `model`: The model type this applies to (e.g., AgentPointModel)
- `scope`: The scope symbol (e.g., :n for nodes) where fields are modified
- `arg_index`: Which argument contains the NamedTuple of field assignments (1-indexed)

When these functions are called in rules, their NamedTuple arguments are analyzed
to detect which fields are being modified.

Example:
```julia
# Register addAgent! for AgentPointModel to extract fields from argument 2, scope :n
if !haskey(CHECK_FUNCTIONS, :addAgent!)
    CHECK_FUNCTIONS[:addAgent!] = []
end
push!(CHECK_FUNCTIONS[:addAgent!], (model = AgentPointModel, scope = :n, arg_index = 2))

# Now in a rule, when we have:
# addAgent!(uNew, (x=1, y=2, z=3))
# This will detect that :n.x, :n.y, :n.z are being modified
```
"""
const CHECK_FUNCTIONS = Dict{Symbol, Vector{NamedTuple{(:model, :scope, :arg_index), Tuple{DataType, Symbol, Int}}}}()

"""
    register_check_function!(func_name::Symbol, model::DataType, scope::Symbol, arg_index::Int)

Register a special function to be analyzed for field modifications in rules.

# Arguments
- `func_name`: The name of the function (e.g., :addAgent!)
- `model`: The model type this applies to (e.g., AgentPointModel)
- `scope`: The scope symbol where fields are modified (e.g., :n for nodes)
- `arg_index`: Which argument (1-indexed) contains the NamedTuple of field assignments

# Example
```julia
register_check_function!(:addAgent!, AgentPointModel, :n, 2)
```
"""
function register_check_function!(func_name::Symbol, model::DataType, scope::Symbol, arg_index::Int)
    if !haskey(CHECK_FUNCTIONS, func_name)
        CHECK_FUNCTIONS[func_name] = []
    end
    push!(CHECK_FUNCTIONS[func_name], (model = model, scope = scope, arg_index = arg_index))
end

"""
    extract_special_function_assigns(fdefs; mod::Module=Main)

Extract field assignments from calls to special functions registered in CHECK_FUNCTIONS.
Returns a vector of tuples representing the modified fields.
"""
function extract_special_function_assigns(fdefs; mod::Module=Main)
    assigns = Tuple[]

    for f in fdefs
        fdef = f.fdef
        fdef_expanded = macroexpand(mod, fdef)
        
        tracked_syms = f.args[1:2]
        du_sym = tracked_syms[1]
        
        # Build alias map to resolve variable references
        aliases = Dict{Symbol, Vector{Symbol}}()
        
        postwalk(fdef_expanded) do ex
            # Track aliases: x = du.n creates alias x -> [du, n]
            if ex isa Expr && ex.head == :(=)
                lhs, rhs = ex.args
                if lhs isa Symbol
                    chain, _ = chain_with_index(rhs)
                    if first(chain) in tracked_syms
                        aliases[lhs] = chain
                    elseif first(chain) in keys(aliases)
                        aliases[lhs] = vcat(aliases[first(chain)], chain[2:end])
                    end
                end
            end
            
            # Detect calls to registered special functions
            if ex isa Expr && ex.head == :call
                func_name = ex.args[1]
                
                # Handle both Symbol and GlobalRef
                if func_name isa GlobalRef
                    func_name = func_name.name
                end
                
                if func_name isa Symbol && haskey(CHECK_FUNCTIONS, func_name)
                    configs = CHECK_FUNCTIONS[func_name]
                    
                    # Process all registered configurations for this function
                    for config in configs
                        # Get the argument at the specified index (add 1 because args[1] is function name)
                        if length(ex.args) >= config.arg_index + 1
                            arg = ex.args[config.arg_index + 1]
                            
                            # Extract field names from NamedTuple literal: (x=..., y=..., ...)
                            if arg isa Expr && arg.head == :tuple
                                for elem in arg.args
                                    if elem isa Expr && (elem.head == :(=) || elem.head == :kw)
                                        field_name = elem.args[1]
                                        if field_name isa Symbol
                                            # Add (scope, field_name) as an assign
                                            push!(assigns, (config.scope, field_name))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            ex
        end
    end

    return unique(assigns)
end

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
                return go(x.args[1])[1], true
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
        u_sym = f.args[2]  # The 'u' argument (second arg)

        # Use the body directly to search for topology access patterns
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
            
            # Match u.topo[:origin, :target] bracket access syntax
            # This is: ref(.(.(u, :topo), QuoteNode(:origin)), QuoteNode(:target))
            # Or: getindex(u.topo, :origin, :target)
            if ex isa Expr && ex.head == :ref && length(ex.args) == 3
                base = ex.args[1]
                origin_arg = ex.args[2]
                target_arg = ex.args[3]
                
                # Check if base is u.topo (or alias.topo where alias resolves to u)
                is_topo_access = false
                if base isa Expr && base.head == :. && length(base.args) == 2
                    obj = base.args[1]
                    prop = base.args[2]
                    prop_sym = prop isa QuoteNode ? prop.value : prop
                    if prop_sym == :topo && obj == u_sym
                        is_topo_access = true
                    end
                end
                
                if is_topo_access
                    # Handle QuoteNode for origin and target
                    origin_sym = origin_arg isa QuoteNode ? origin_arg.value : origin_arg
                    target_sym = target_arg isa QuoteNode ? target_arg.value : target_arg
                    
                    if origin_sym isa Symbol && target_sym isa Symbol
                        Base.push!(topology_pairs, (origin_sym, target_sym))
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
    special_assigns = extract_special_function_assigns(fdefs; mod=mod)
    
    # Merge regular assigns with special function assigns
    all_assigns = unique(vcat(unique_assigns, special_assigns))
    
    topology_pairs = extract_topology_loops(fdefs)

    # Build dimension checking code if requested
    # This generates runtime code that will check dimensions when the macro is evaluated
    dim_check_code = if kwargs.check_dimensions
        # Get the du and u symbols from the function arguments
        du_sym = fdefs[1].args[1]
        u_sym = fdefs[1].args[2]
        
        # For ODE/SDE, du represents time derivative; for RULE, uNew is just new state
        is_derivative = type in (:ODE, :SDE)
        
        # Collect all the expressions we need to check
        # We'll serialize them as quoted expressions for runtime analysis
        expr_checks = Expr[]
        
        for f in fdefs
            fdef = f.fdef
            
            # Extract aliases for this function (e.g., p = u.p)
            alias_map = extract_aliases(fdef, u_sym, du_sym)
            
            # Convert alias_map to quoted form for runtime
            alias_map_expr = if isempty(alias_map)
                :(Dict{Symbol,Expr}())
            else
                pairs = [:($(QuoteNode(k)) => $(QuoteNode(v))) for (k, v) in alias_map]
                :(Dict{Symbol,Expr}($(pairs...)))
            end
            
            # Track current line number while walking the AST
            current_line = Ref{Union{Int,Nothing}}(nothing)
            
            postwalk(fdef) do ex
                # Track line numbers from LineNumberNode
                if ex isa LineNumberNode
                    current_line[] = ex.line
                end
                
                # Check assignments (simple and compound) - but not inside @atomic (handled separately)
                if ex isa Expr && ex.head in (:(=), :.=, :(+=), :(-=), :(*=), :(/=))
                    lhs = ex.args[1]
                    rhs = ex.args[2]
                    # For compound assignments, the rhs should have same dimension as lhs
                    # (e.g., for +=, we're adding rhs to lhs, so dimensions must match)
                    line_str = current_line[] !== nothing ? "line $(current_line[])" : ""
                    push!(expr_checks, :(
                        CellBasedModels._check_single_assignment(
                            _dim_errors,
                            _dim_map,
                            $(QuoteNode(lhs)),
                            $(QuoteNode(rhs)),
                            $(QuoteNode(u_sym)),
                            $(QuoteNode(du_sym)),
                            $(string(f.fname)),
                            $is_derivative,
                            $alias_map_expr,
                            $line_str
                        )
                    ))
                end
                ex
            end
        end
        
        quote
            let _dim_map = CellBasedModels.build_dimension_map($(kwargs.mesh_name), $(QuoteNode(u_sym)))
                _dim_errors = String[]
                $(expr_checks...)
                if !isempty(_dim_errors)
                    @warn "Dimensional inconsistencies detected:\n" * join(_dim_errors, "\n")
                end
            end
        end
    else
        nothing
    end

    # build emitted code (unchanged structure)
    fs = [f.fname for f in fdefs]
    assigns_code = :(CellBasedModels.addFunction!($(kwargs.mesh_name),
                                                 $(QuoteNode(type)),
                                                 $(QuoteNode(kwargs.scope_name)),
                                                 $all_assigns,
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
        $dim_check_code
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
    check_dimensions = true
    for arg in ex[1:end - n]
        @capture(arg, kwarg_=value_)
        if kwarg == :model
            mesh_name = value
        elseif kwarg == :check_dimensions
            check_dimensions = value
        else
            error("Unknown keyword argument '$kwarg'")
        end
    end

    if mesh_name === nothing
        error("Expected 'model' keyword argument.")
    end

    scope_name = functions[1].fname

    return (mesh_name=mesh_name, scope_name=scope_name, check_dimensions=check_dimensions), functions

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