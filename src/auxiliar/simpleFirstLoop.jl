"""
    fucntion simpleFirstLoop_(code,platform)

Returns the sent code wrapped in parallelized loop over the particles of the system adapted for each platform.
"""
function simpleFirstLoop_(code::Expr,platform::String)

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
        error("Platform should be or gpu or cpu.")
    end

    return code
end