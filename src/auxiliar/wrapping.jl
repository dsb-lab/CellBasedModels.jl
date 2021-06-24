"""
    funntion simpleFirstLoop_(platform, code)

Returns the sent code wrapped in parallelized loop over the particles of the system adapted for each platform.
"""
function simpleFirstLoop_(platform::String, code::Expr)

    if platform == "cpu"
        code = 
            quote
                Threads.@threads for ic1_ in 1:N
                    $code                    
                end
            end
    elseif platform == "gpu"
        code = 
            quote
                index_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
                stride_ = blockDim().x * gridDim().x
                for ic1_ in index_:stride_:N
                    $code
                end
            end
    else
        error("Platform should be or cpu or gpu. ", platform, " was given.")
    end

    return code
end

"""
    function wrapInFunction_(name, code)

Return **code** wrapped in a function called **name** and which returns nothing.
"""
function wrapInFunction_(name::Symbol, code::Expr)
    code = 
        :(function $name(ARGS_)
            $code
            return nothing
        end
        )

    return code
end

"""
    function simpleLoopWrapInFunction_(platform, name, code)

Calls toguether functions simpleFirstLoop and wrapInFunction.
"""
function simpleFirstLoopWrapInFunction_(platform::String, name::Symbol, code::Expr)
    code = simpleFirstLoop_(platform,code)
    code = 
        :(function $name(ARGS_)
            $code
            return nothing
        end
        )

    return code
end