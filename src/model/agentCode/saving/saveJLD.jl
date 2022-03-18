function addSavingJLD_!(p::Program_,platform::String)
    
    addSavingRAM_!(p,platform)

    push!(p.declareVar.args,:(saveCounter=1))

    p.execInit = postwalk(x->@capture(x,push!(commRAM_,ob)) ? :(AgentBasedModels.jldopen(string(saveFile,".jld"), "w") do file write(file, string(saveCounter), ob) end; saveCounter += 1) : x, p.execInit)
    p.execInloop = postwalk(x->@capture(x,push!(commRAM_,ob)) ? :(AgentBasedModels.jldopen(string(saveFile,".jld"), "r+") do file write(file, string(saveCounter), ob) end; saveCounter += 1) : x, p.execInloop)

    p.returning = quote end

    return
end