function argumentsFull_!(program::Program_, platform::String)

    return Nothing
end

function loopFull_(program::Program_, code::Expr, platform::String)

    code = vectorize_(program.agent, code, program)
    loop = :(
        for ic2_ in 1:N
            $code
        end)
    loop = simpleFirstLoop_(platform, loop)
    loop = subs_(loop,:nnic2_,:ic2_)

    return loop
end