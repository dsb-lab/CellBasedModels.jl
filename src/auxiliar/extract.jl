function extract(code::Union{Expr,Symbol,Number}, f::Symbol)

    if typeof(code) == Symbol || typeof(code) <: Number

        return nothing

    elseif code.head == :call && code.args[1] == f

        return code.args[2]

    else

        for i in code.args
            exp = extract(i, f)
        
            if exp !== nothing
                return exp
            end
        end

        return nothing

    end

end