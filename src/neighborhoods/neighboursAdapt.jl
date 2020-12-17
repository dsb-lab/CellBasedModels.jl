function neighboursAdapt(algorithms;neighborhood="full", radius=0.0, boxSize=Any[])
    
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
        count = Meta.parse("nnN_[ic1_]")
        locInter = subs(algorithms,[:nnic2_],[:(nnList_[ic1_,ic2_])])
        arg = [Meta.parse("nnN_"),Meta.parse("nnList_")]
        inLoop = 
        :(
        for ic2_ in 1:$count
            $(algorithms...)
        end    
        )
    elseif neighborhood == "nn2"
        arg = [:(nnGridBinId_),:(nnGridCounts_),:(nnGridCountsCum_),:(nnId_)]
        nBinsDimension = [ceil(Int,(i[2]-i[1])/radius/2) for i in boxSize]
        if nBinsDimension == []
            error("No box dimensions.")
        end
        if nBinsDimension[1] == 1
            l = [0]
        else
            l = [-1,0,1]
        end
        add = [1;cumprod(nBinsDimension)]
    for (pos,i) in enumerate(add[2:end-1])
        println(i)
            ll = []
            for j in l
                if i != add[pos]
                    for k in [-i,0,i]
                        push!(ll,j+k)
                    end
                else
                    ll = l
                end
            end
            l = copy(ll)
        end
        ll = []
        for i in l
            push!(ll,:(bin+$i))
        end
        inLoop = subs(:(
        begin
        bin = nnGridBinId_[ic1_]
        for gridPos_ in [$(ll...)]
                if gridPos_ > 0 && gridPos_ <= $(cumprod(nBinsDimension)[end])
                n_ = nnGridCounts_[gridPos_]-1
                start_ = nnGridCountsCum_[gridPos_]
                for ic2_ in start_:(start_+n_)
                    $(algorithms...)
                end
            end
        end    
        end
        ),:nnic2_,:(nnId_[ic2_]))  
end

return inLoop,arg
end
