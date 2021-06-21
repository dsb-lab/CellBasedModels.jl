"""
    struct SimulationFree <: SimulationSpace

Simulation space for N-body simulations with all-with-all interactions.
The method implemented so far uses a brute force approach and only parallelizes over the number of agents, 
hence having a minimum cost of computation of ``O(N)`` at best.
In the future we will implement parallelization over the second loop to further reduce the computational cost in favourable systems.
"""
struct SimulationFree <: SimulationSpace

end

function arguments_!(program::Program_, abm::Agent, a::SimulationFree, platform::String)

    return Nothing
end

function loop_(program::Program_, abm::Agent, a::SimulationFree, code::Expr, platform::String)

    code = vectorize_(abm, code, program)
    loop = :(
        for ic2_ in 1:N
            $code
        end)
    loop = simpleFirstLoop_(platform, loop)
    loop = subs_(loop,:nnic2_,:ic2_)

    return loop
end