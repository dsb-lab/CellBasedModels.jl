function addSavingCSV_!(p::Program_,platform::String)
    
    addSavingRAM_!(p,platform)

    push!(p.declareVar.args,:(saveCounter=1))

    p.execInit = postwalk(x->@capture(x,push!(commRAM_,ob)) ? :(saveCSV(ob,string(saveFile,"_",saveCounter)); saveCounter += 1) : x, p.execInit)
    p.execInloop = postwalk(x->@capture(x,push!(commRAM_,ob)) ? :(saveCSV(ob,string(saveFile,"_",saveCounter)); saveCounter += 1) : x, p.execInloop)

    p.returning = quote end

    return
end