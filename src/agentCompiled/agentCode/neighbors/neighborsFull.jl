"""
    function argumentsFull_!(program::Program_, platform::String)

Function that returns the arguments of the Full connected neighbors.

# Args
 - **p::Program_**:  Program_ structure containing all the created code when compiling.
 - **platform::String**: Platform to adapt the code.

# Return
 - `Vector{Symbols}` of additional arguments required y this neighborhood algorithm. (None in this case.) 
"""
function argumentsFull_!(program::Program_, platform::String)

    return Nothing
end

"""
    function loopFull_(program::Program_, code::Expr, platform::String)

Function that returns the code in a loop adapted to the Full connected neighbors algorithm.

# Args
 - **p::Program_**:  Program_ structure containing all the created code when compiling.
 - **code::Expr**:  Bock of code to be included in the loop.
 - **platform::String**: Platform to adapt the code.

# Return
 - `Vector{Symbols}` of additional arguments required y this neighborhood algorithm. (None in this case.) 
"""
function loopFull_(program::Program_, code::Expr, platform::String)

    code = vectorize_(program.agent, code, program,interaction=true)
    loop = :(
        for ic2_ in 1:N
            $code
        end)
    loop = simpleFirstLoop_(platform, loop)
    loop = postwalk(x->@capture(x,g_) && g == :nnic2_ ? :ic2_ : x, loop)

    return loop
end