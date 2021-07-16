"""
    struct SimulationFree <: SimulationSpace

Simulation space for N-body simulations with all-with-all interactions.
The method implemented so far uses a brute force approach and only parallelizes over the number of agents, 
hence having a minimum cost of computation of ``O(N)`` at best.
In the future we will implement parallelization over the second loop to further reduce the computational cost in favourable systems.
"""
struct SimulationFree <: SimulationSpace

    box::Array{<:FlatBoundary,1}
    medium::Array{<:Medium,1}

end

function SimulationFree(abm::Agent; box::Array{<:Any,1}=Array{FlatBoundary,1}(), medium::Array{<:Medium,1}=Array{Medium,1}())

    #Check dimensionality
    if length(box) != abm.dims && isempty(abm.declaredSymbols["Medium"])
        error("Box has to be the same length as dimensions.")
    end
    #Make consistent box format adding Open to tuples
    box2 = Array{FlatBoundary,1}()
    for i in 1:length(box)
        if typeof(box[i])<:Tuple{Symbol,<:Real,<:Real}
            push!(box2, Bound(box[i]...))
        elseif typeof(box[i])<:FlatBoundary
            push!(box2,box[i])
        else
            error("Dimension has to be defined as a tupple with (Symbol, Real, Real) or a FlatBoundary Type.")
        end
    end

    #Check limits are correct
    vars = [i.s for i in box2]
    if !isempty(vars)
        checkIsDeclared_(abm,vars)
    end
    for i in box2
        if i.max <= i.min
            error("Superior limit is equal or smaller than inferior limit for ", i.s, ". The entry should be of the form (BoundaryType)(symbol,min,max,vargs...).")
        end
    end

    #Check medium has the same dimensions
    if abm.dims != length(medium)
        error("Medium has to be specified with the same dimensions as the model. For that, it is necessary to also define a box.")
    end

    #Check symbols
    for b in box2
        for i in keys(b.addSymbols)
            for j in b.addSymbols[i]
                checkIsDeclared_(abm,j)
            end
        end
    end

    return SimulationFree(box2,medium)

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