struct SimulationFixed <: SimulationSpace

end

function arguments_(neighbors::SimulationFixed, space::Space, platform::String)
    declareVar = Nothing
    declareF = Nothing
    args = Nothing
    argsEval = Nothing
    execInit = Nothing
    execInloop = Nothing
    execAfter = Nothing

    error("Not implemented yet.")

    return declareVar, declareF, args, argsEval, execInit, execInloop, execAfter
end

function loop_(neighbors::SimulationFixed, space::Space, code::Expr)
    
    error("Not implemented yet.")

    return loop
end