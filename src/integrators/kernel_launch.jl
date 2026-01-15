using KernelAbstractions
using MacroTools: @capture, postwalk

"""
    @kernel_launch function fname(args...)
        body
    end

    @kernel_launch fname(args...)
        body
    end

Define a KernelAbstractions kernel and immediately launch it. Thread counts are
picked based on backend (CPU threads = Threads.nthreads(), GPU threads = 256).
`ndrange` defaults to the maximum `length` of any AbstractArray argument (or 1 if
no arrays are present).
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

function extract_assigns(body_expr, tracked_syms)
    assigns = Tuple[]
    
    normal_heads = (:(=), :+=, :-=, :*=, :/=)
    broadcast_heads = (:.=, :.+=, :.-=, :.*=, :./=)
    
    # Expand macros
    body_expanded = macroexpand(Main, body_expr)
    
    aliases = Dict{Symbol, Union{Vector{Symbol}, Symbol}}()
    
    postwalk(body_expanded) do ex
        if ex isa Expr && ex.head == :(=)
            lhs, rhs = ex.args
            
            if lhs isa Symbol
                chain, index = chain_with_index(rhs)
                if first(chain) in keys(aliases)
                    chain = vcat(aliases[first(chain)], chain[2:end])
                end
                rhs_root = first(chain)
                
                if lhs in keys(aliases)
                    if rhs_root in tracked_syms
                        aliases[lhs] = chain``
                    else
                        delete!(aliases, lhs)
                    end
                else
                    if rhs_root in tracked_syms
                        aliases[lhs] = chain
                    end
                end
            elseif lhs isa Expr
                chain_lhs, index_lhs = chain_with_index(lhs)
                if first(chain_lhs) in keys(aliases)
                    chain_lhs = vcat(aliases[first(chain_lhs)], chain_lhs[2:end])
                end
                lhs_root = first(chain_lhs)
                tail = chain_lhs[2:end]
                
                if lhs_root in tracked_syms && index_lhs
                    push!(assigns, tuple(tail...))
                end
            end
        elseif ex isa Expr && (ex.head in (normal_heads..., broadcast_heads...))
            lhs = ex.args[1]
            chain, indexed = chain_with_index(lhs)
            
            if first(chain) in keys(aliases)
                chain = vcat(aliases[first(chain)], chain[2:end])
            end
            
            root = first(chain)
            tail = chain[2:end]
            
            if root in tracked_syms && (ex.head in broadcast_heads)
                push!(assigns, tuple(tail...))
            elseif root in tracked_syms && (ex.head in normal_heads) && indexed
                push!(assigns, tuple(tail...))
            end
        end
        ex
    end
    
    return unique(assigns)
end

macro kernel_launch(sig, body=nothing)
    cpu_threads = :(Base.Threads.nthreads())
    gpu_threads = 256

    # Parse based on whether body is separate or not
    if body === nothing
        # Function definition form: function fname(args...) body end
        @capture(sig, function fname_(args__); fbody__ end) ||
            error("@kernel_launch: expected `function fname(args...) ... end`")
        
        fname = fname_
        args = args__
        body_expr = :(begin $(fbody__...) end)
    else
        # Call form: fname(args...) with separate body block
        @capture(sig, fname_(args__)) ||
            error("@kernel_launch: expected `fname(args...)` signature")
        
        fname = fname_
        args = args__
        body_expr = body
    end

    isempty(args) && error("@kernel_launch: kernel must have at least one argument to infer backend")

    # Extract argument symbols (strip type annotations)
    arg_syms = [a isa Expr && a.head == :(::) ? a.args[1] : a for a in args]
    
    # Get tracked symbols (first two args if available)
    tracked_syms = length(arg_syms) >= 2 ? arg_syms[1:2] : arg_syms
    
    # Extract unique assigns from the body
    unique_assigns = extract_assigns(body_expr, tracked_syms)
    
    fname_esc = esc(fname)
    args_esc = [esc(a) for a in args]
    body_esc = esc(body_expr)
    
    # Build ndrange calculation based on modified fields
    ndrange_calc = if !isempty(unique_assigns) && !isempty(tracked_syms)
        first_arg = esc(arg_syms[1])
        field_accesses = [
            :(length($(foldl((acc, sym) -> :(getproperty($acc, $(QuoteNode(sym)))), 
                            assign, init=first_arg))))
            for assign in unique_assigns
        ]
        :(max($(field_accesses...)))
    else
        # Fallback to checking all array arguments
        quote
            sizes = Int[]
            for arg in ($(args_esc...),)
                if arg isa AbstractArray
                    push!(sizes, length(arg))
                end
            end
            isempty(sizes) ? 1 : maximum(sizes)
        end
    end

    quote
        KernelAbstractions.@kernel function $fname_esc($(args_esc...))
            $body_esc
        end

        backend = KernelAbstractions.get_backend($(args_esc[1]))
        threads = backend isa KernelAbstractions.CPU ? $cpu_threads : $gpu_threads

        ndrange_val = $ndrange_calc

        $fname_esc(backend, threads)($(args_esc...), ndrange=ndrange_val)
        KernelAbstractions.synchronize(backend)
    end |> esc
end