"""
    function simpleFirstLoop_(code::Expr, platform::String)

Returns the sent code wrapped in parallelized in the specified platform loop over the number of agents of the system.

# Args
- **code::Expr**: Code to include in the loop.
- **platform::String**: Platform to adapt the loop.

 # Returns
 - `Expr` with the code of the created loop.
"""
function simpleFirstLoop(code::Expr,platform::Symbol)

    if platform == :CPU
        code = 
            quote
                Threads.@threads for ic1_ in 1:1:N
                    $code                    
                end
            end
    elseif platform == :GPU
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
    function simpleGridLoop_(platform::String, code::Expr, nloops::Int; indexes = [1,2,3])

Returns the sent code wrapped in parallelized in the specified platform loop over the number of agents of the system and over the specified number of loops.

# Args
 - **platform::String**: Platform to adapt the loop.
 - **code::Expr**: Code to include in the loop.
 - **nloops::Int**: Number of loops of the code.

# KwArgs
 - **indexes = [1,2,3]**: Numbers to specify the indexes.

 # Returns
 - `Expr` with the code of the created loop.
"""
function simpleGridLoop_(platform::String, code::Expr, nloops::Int; indexes = [1,2,3])

    #Compute indexes
    vIc = MEDIUMITERATIONSYMBOLS[indexes[1:nloops]]
    vIndex = MEDIUMINDEXSYMBOLS[indexes[1:nloops]]
    vStride = MEDIUMSTRIDESYMBOLS[indexes[1:nloops]]
    vNM = MEDIUMSUMATIONSYMBOLS[indexes[1:nloops]]

    if platform == "cpu"
        if nloops == 0
            nothing
        elseif nloops == 1
            code = 
                quote
                    Threads.@threads for $(vIc[1]) in 1:1:$(vNM[1])
                        $code                    
                    end
                end
        elseif nloops == 2
            code = 
                quote
                    Threads.@threads for $(vIc[1]) in 1:1:$(vNM[1])
                        for $(vIc[2]) in 1:1:$(vNM[2])
                            $code                    
                        end
                    end
                end
        elseif nloops == 3
            code = 
                quote
                    Threads.@threads for $(vIc[1]) in 1:1:$(vNM[1])
                        for $(vIc[2]) in 1:1:$(vNM[2])
                            for $(vIc[3]) in 1:1:$(vNM[3])
                                $code                    
                            end                
                        end                   
                    end
                end
        end
    elseif platform == "gpu"

        head = quote end
        append!(head.args,[
        quote
            indexX_ = (threadIdx().x) + (blockIdx().x - 1) * blockDim().x
            strideX_ = blockDim().x * gridDim().x
        end,
        quote
            indexY_ = (threadIdx().y) + (blockIdx().y - 1) * blockDim().y
            strideY_ = blockDim().y * gridDim().y
        end,
        quote
            indexZ_ = (threadIdx().z) + (blockIdx().z - 1) * blockDim().z
            strideZ_ = blockDim().z * gridDim().z
        end][1:nloops]
        )

        code = 
            if nloops == 0
                quote
                    $head
                    
                    if indexX_ == 1
                        $code
                    end
                end
            elseif nloops == 1
                code = 
                    quote
                        $head

                        for $(vIc[1]) in $(vIndex[1]):$(vStride[1]):$(vNM[1])
                            $code
                        end
                    end
            elseif nloops == 2
                code = 
                    quote
                        $head

                        for $(vIc[1]) in $(vIndex[1]):$(vStride[1]):$(vNM[1])
                            for $(vIc[2]) in $(vIndex[2]):$(vStride[2]):$(vNM[2])
                                $code
                            end
                        end
                    end
            elseif nloops == 3
                code = 
                    quote
                        $head

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
    function wrapInFunction_(name::Symbol, code::Expr)

Return **code** wrapped in an anonymous function and which returns nothing.

#Args
 - **name::Symbol**: name of the function to create
 - **code::Expr**: Code to be included in the function.

 # Returns
 - `Expr` with the code of the created function.
"""
function wrapInFunction(code::Expr, args::Array)
    code = 
        :(function ($(args...),)
            $code
            return nothing
        end
        )

    return code
end

"""
    function simpleLoopWrapInFunction(code::Expr,platform::Symbol, name::Symbol)

Return **code** wrapped in a loop, wrapped in a anonymous function and which returns nothing.

#Args
- **code::Expr**: Code to be included in the function.
- **platform::String**: name of the function to create
 - **name::Symbol**: name of the function to create

# Returns
 - `Expr` with the code of the created function.
"""
function simpleFirstLoopWrapInFunction(code::Expr, platform::Symbol, args::Array)
    code = simpleFirstLoop(code,platform)
    code = 
        :(function ($(args...),)
            $code
            return nothing
        end
        )

    return code
end

"""
    function simpleGridLoopWrapInFunction_(platform::String, name::Symbol, code::Expr, nLoop::Int; indexes = [1,2,3])

Return **code** wrapped in a loop, wrapped in a function called **name** and which returns nothing.

#Args
 - **platform::String**: name of the function to create
 - **name::Symbol**: name of the function to create
 - **code::Expr**: Code to be included in the function.
 - **nloops::Int**: Number of loops of the code.

# KwArgs
 - **indexes = [1,2,3]**: Numbers to specify the indexes.

 # Returns
 - `Expr` with the code of the created function.
"""
function simpleGridLoopWrapInFunction_(platform::String, name::Symbol, args::Array, code::Expr, nLoop::Int; indexes = [1,2,3])
    code = simpleGridLoop_(platform,code,nLoop,indexes=indexes)
    code = 
        :(function $name($(args...))
            $code
            return nothing
        end
        )

    return code
end