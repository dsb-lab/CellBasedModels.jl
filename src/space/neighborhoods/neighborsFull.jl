struct NeighborsFull <: Neighbors

end

function arguments_(neighbors::NeighborsFull, space::Space, platform::String)
    declareVar = Nothing
    declareF = Nothing
    args = Nothing
    argsEval = Nothing
    execInit = Nothing
    execInloop = Nothing
    execAfter = Nothing
    return declareVar, declareF, args, argsEval, execInit, execInloop, execAfter
end

function loop_(neighbors::NeighborsFull, space::Space, code::Expr)
    loop = :(
        for ic2_ in 1:N
            $code
        end)
    loop = subs_(loop,:nnic2_,:ic2_)

    return loop
end