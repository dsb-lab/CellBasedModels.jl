struct NeighborsFull <: Neighbors

end

function arguments(algorithm::NeighborsFull,platform::String)
    declare = []
    args = []
    initial = []
    inLoop = []
    return declare, args, initial, inLoop
end

function loop(algorithm::NeighborsFull, code::Expr)
    loop = :(
        for ic2_ in 1:N
            $code
        end)
    subs!(loop,:nnic2_,:ic2_)

    return loop
end