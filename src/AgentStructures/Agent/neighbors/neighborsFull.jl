"""
    function neighborsGrid_!(program::Agent)

Function that returns the arguments of the Grid connected neighbors.

# Args
 - **p::Agent**:  Agent structure containing all the created code when compiling.

# Return
 - `Vector{Symbols}` of additional arguments required y this neighborhood algorithm.
"""
function neighborsFull!(p::Agent)

    p.f_neighbors = (f(x) = nothing)

    return
end

"""
    function loopFull(code::Expr, p::Agent)

Function that returns the code in a loop adapted to the Full connected neighbors algorithm.

# Args
 - **code::Expr**:  Bock of code to be included in the loop.
 - **p::Agent**:  Agent structure containing all the created code when compiling.

# Return
 - Code wrapped in additional loop over nieghbors
"""
function loopFull(code::Expr, p::Agent)

    code = vectorize(code, p, interaction=true)
    loop = :(
        for ic2_ in 1:1:N
            $code
        end)
    loop = simpleFirstLoop(loop, p.platform)
    loop = postwalk(x->@capture(x,g_) && g == :nnic2_ ? :ic2_ : x, loop)

    return loop
end

NeighborsFull = Neighbors(
    DataFrame(
        name = [],
        type = [],
        use = []
    ),
    loopFull,
    neighborsFull!
)