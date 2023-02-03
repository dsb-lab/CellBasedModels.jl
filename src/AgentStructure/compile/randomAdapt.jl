VALIDDISTRIBUTIONS = [i for i in names(Distributions) if uppercasefirst(string(i)) == string(i)]
VALIDDISTRIBUTIONSCUDA = [:Normal,:Uniform,:Exponential]

#Random distribution transformations for cuda capabilities
NormalCUDA(x,μ,σ) = σ*CUDA.sqrt(2.)*SpecialFunctions.erfinv(2*(x-.5))+μ
UniformCUDA(x,l0,l1) = (l1-l0)*x+l0
ExponentialCUDA(x,θ) = -CUDA.log(1-x)*θ

"""
    function randomAdapt_(code::Expr, p::Agent)

Function that adapt the random function invocations of the code to be executable in the different platforms.

# Args
 - **p::Agent**: Agent structure containing all the created code when compiling.
 - **code::Expr**:  Code to be adapted.

# Returns
 - `Expr` with the code adapted.
"""
function randomAdapt(code::Expr, p::Agent)

    if p.platform == "cpu"
        for i in VALIDDISTRIBUTIONS
            code = postwalk(x -> @capture(x,$i(v__)) ? :(AgentBasedModels.rand(AgentBasedModels.$i($(v...)))) : x, code)
        end
    elseif p.platform == "gpu"
        for i in VALIDDISTRIBUTIONS

            if inexpr(code,i) && !(i in VALIDDISTRIBUTIONSCUDA)
                error(i," random distribution valid for cpu but still not implemented in gpu.")
            else

                s = Meta.parse(string("AgentBasedModels.",i,"CUDA"))
                code = postwalk(x -> @capture(x,$i(v__)) ? :($s(AgentBasedModels.rand(),$(v...))) : x, code)

            end

        end
    end    
    
    return code
end