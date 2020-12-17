function neighboursAdapt(algorithms;neighborhood="full", boxSize=Any[])
    
    if neighborhood == "full"
        count = :N_
        locInter = subs(algorithms,[:nnic2_],[:ic2_])
        arg = []
        inLoop = 
        :(
        for ic2_ in 1:$count
            $(algorithms...)
        end    
        )
    elseif neighborhood == "nn"
    elseif neighborhood == "nn2"
end

return inLoop,arg
end
