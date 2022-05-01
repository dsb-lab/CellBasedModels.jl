"""
    function randomAdapt_(p::Program_, code::Expr, platform::String)

Function that adapt the random function invocations of the code to be executable in the different platforms.

# Args
 - **p::Program_**: Program_ structure containing all the created code when compiling.
 - **code::Expr**:  Code to be adapted.
 - **platform::String**: Platform to adapt the code.

# Returns
 - `Expr` with the code adapted.
"""
function randomAdapt_(p::Program_, code::Expr, platform::String)

    if platform == "cpu"
        for i in VALIDDISTRIBUTIONS
            code = postwalk(x -> @capture(x,$i(v__)) ? :(AgentBasedModels.rand(AgentBasedModels.$i($(v...)))) : x, code)
        end
    elseif platform == "gpu"
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