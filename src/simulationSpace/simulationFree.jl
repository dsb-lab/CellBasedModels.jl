struct SimulationFree <: SimulationSpace

end

function arguments_!(a::SimulationFree, data::Program_, platform::String)

    return Nothing
end

function loop_(a::SimulationFree, code::Expr)
    loop = :(
        for ic2_ in 1:N
            $code
        end)
    loop = subs_(loop,:nnic2_,:ic2_)

    return loop
end