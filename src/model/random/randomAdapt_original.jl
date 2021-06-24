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

                start = Meta.parse(split(string(MacroTools.gensym()),"#")[end])
                s = Meta.parse(string(i,"_"))
                code = MacroTools.postwalk(x -> @capture(x,$i(v__)) ? :($s($(MacroTools.gensym(string("$i")))[ic1_],$(v...))) : x, code)
                stop = Meta.parse(split(string(MacroTools.gensym()),"#")[end])

                for j in start+1:stop-1
                    name = Symbol(string("##",i,"#",j))
                    println(name)
                    push!(p.declareVar.args,:($name = zeros(nMax)))
                    push!(p.execInit.args,:(CUDA.rand($name)))
                    push!(p.execInloop.args,:(CUDA.rand($name)))
                end

            end

        end
    end    
    
    return code
end