"""
    funntion simpleFirstLoop_(platform, code)

Returns the sent code wrapped in parallelized loop over the particles of the system adapted for each platform.
"""
function simpleFirstLoop_(platform::String, code::Expr)

    if platform == "cpu"
        code = 
            quote
                Threads.@threads for ic1_ in 1:1:N
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
    funntion simpleGridLoop_(platform, code)

Returns the sent code wrapped in parallelized loop over the grid dimensions of the system adapted for each platform.
"""
function simpleGridLoop_(platform::String, code::Expr, nloops::Int; indexes = [1,2,3])

    #Compute indexes
    vIc = [:ic1_,:ic2_,:ic3_][indexes[1:nloops]]
    vIndex = [:indexX_,:indexY_,:indexZ_][indexes[1:nloops]]
    vStride = [:strideX_,:strideY_,:strideZ_][indexes[1:nloops]]
    vNM = [:Nx_,:Ny_,:Nz_][indexes[1:nloops]]

    if platform == "cpu"
        if nloops == 0
            nothing
        elseif nloops == 1
            code = 
                quote
                    Threads.@threads for $(vIc[1]) in 1:$(vNM[1])
                        $code                    
                    end
                end
        elseif nloops == 2
            code = 
                quote
                    Threads.@threads for $(vIc[1]) in 1:$(vNM[1])
                        for $(vIc[2]) in 1:$(vNM[2])
                            $code                    
                        end
                    end
                end
        elseif nloops == 3
            code = 
                quote
                    Threads.@threads for $(vIc[1]) in 1:$(vNM[1])
                        for $(vIc[2]) in 1:$(vNM[2])
                            for $(vIc[3]) in 1:$(vNM[3])
                                $code                    
                            end                
                        end                   
                    end
                end
        end
    elseif platform == "gpu"
        code = 
            if nloops == 0
                quote
                    indexX_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
                    strideX_ = blockDim().x * gridDim().x

                    indexY_ = (threadIdx().y) + (blockIdx().y - 1) * blockDim().y
                    strideY_ = blockDim().y * gridDim().y

                    indexZ_ = (threadIdx().z) + (blockIdx().z - 1) * blockDim().z
                    strideZ_ = blockDim().z * gridDim().z
                    
                    if indexX_ == 1
                        $code
                    end
                end
            elseif nloops == 1
                code = 
                    quote
                        indexX_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
                        strideX_ = blockDim().x * gridDim().x

                        indexY_ = (threadIdx().y) + (blockIdx().y - 1) * blockDim().y
                        strideY_ = blockDim().y * gridDim().y

                        indexZ_ = (threadIdx().z) + (blockIdx().z - 1) * blockDim().z
                        strideZ_ = blockDim().z * gridDim().z

                        for $(vIc[1]) in $(vIndex[1]):$(vStride[1]):$(vNM[1])
                            $code
                        end
                    end
            elseif nloops == 2
                code = 
                    quote
                        indexX_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
                        strideX_ = blockDim().x * gridDim().x

                        indexY_ = (threadIdx().y) + (blockIdx().y - 1) * blockDim().y
                        strideY_ = blockDim().y * gridDim().y

                        indexZ_ = (threadIdx().z) + (blockIdx().z - 1) * blockDim().z
                        strideZ_ = blockDim().z * gridDim().z

                        for $(vIc[1]) in $(vIndex[1]):$(vStride[1]):$(vNM[1])
                            for $(vIc[2]) in $(vIndex[2]):$(vStride[2]):$(vNM[2])
                                $code
                            end
                        end
                    end
            elseif nloops == 3
                code = 
                    quote
                        indexX_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
                        strideX_ = blockDim().x * gridDim().x

                        indexY_ = (threadIdx().y) + (blockIdx().y - 1) * blockDim().y
                        strideY_ = blockDim().y * gridDim().y

                        indexZ_ = (threadIdx().z) + (blockIdx().z - 1) * blockDim().z
                        strideZ_ = blockDim().z * gridDim().z

                        for $(vIc[1]) in $(vIndex[1]):$(vStride[1]):$(vNM[1])
                            for $(vIc[2]) in $(vIndex[2]):$(vStride[2]):$(vNM[2])
                                for ic3_ in $(vIndex[3]):$(vStride[3]):$(vNM[3])
                                    $code
                                end
                            end
                        end
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

"""
    function simpleGridLoopWrapInFunction_(platform, name, code)

Calls toguether functions simpleGridLoop and wrapInFunction.
"""
function simpleGridLoopWrapInFunction_(platform::String, name::Symbol, code::Expr, nLoop::Int; indexes = [1,2,3])
    code = simpleGridLoop_(platform,code,nLoop,indexes=indexes)
    code = 
        :(function $name(ARGS_)
            $code
            return nothing
        end
        )

    return code
end