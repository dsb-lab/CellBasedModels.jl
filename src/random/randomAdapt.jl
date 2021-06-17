"""
    function randomAdapt_(p, code, platform)

Function that adapt the random function invocations of the code to be executable in the different platforms.
"""
function randomAdapt_(p::Program_, code::Expr, platform::String)

    if platform == "cpu"
        for i in VALIDDISTRIBUTIONS
            code = MacroTools.postwalk(x -> @capture(x,$i(v__)) ? :(rand($i($(v...)))) : x, code)
        end
    elseif platform == "gpu"
        for i in VALIDDISTRIBUTIONS

            if MacroTools.inexpr(code,i) && !(i in VALIDDISTRIBUTIONSCUDA)
                error(i," random distribution valid for cpu but still not implemented in gpu.")
            else

                s = Meta.parse(string(i,"CUDA"))
                if i == :Normal
                    code = MacroTools.postwalk(x -> @capture(x,$i(v__)) ? :($s(randn(),$(v...))) : x, code)
                elseif i == :Uniform
                    code = MacroTools.postwalk(x -> @capture(x,$i(v__)) ? :($s(rand(),$(v...))) : x, code)
                end

            end

        end
    end    
    
    return code
end