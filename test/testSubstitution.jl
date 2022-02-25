@testset "Substitution" begin

    vectorize_ = AgentBasedModels.vectorize_

    abm = @agent(1,
            [l1,l2]::Local,
            [li1,li2]::LocalInteraction,
            [g1,g2]::Global,
            [ga1,ga2]::GlobalArray,
            [id1,id2]::Identity,
            [idi1,idi2]::IdentityInteraction,
            [m1,m2]::Medium,
            UpdateLocal=begin 
                x += 1
                id += 1
                l1 += 1
                l2 += 1
                li1 += 1
                li2 += 1
                g1 += 1
                g2 += 1
                ga1 += 1
                ga2 += 1
                id1 += 1
                id2 += 1
                idi1 += 1
                idi2 += 1
                m1 += 1
                m2 += 1
            end,
    )
    p = AgentBasedModels.Program_(abm)
    for i in AgentBasedModels.UPDATINGTYPES
        p.update[i] = Dict(k=>j for (j,k) in enumerate(abm.declaredSymbols[i]))
    end

    @test vectorize_(abm,:(x,x),p) == :(localV[ic1_, 1],localV[ic1_, 1])  
    @test vectorize_(abm,:(l1,l1),p) == :(localV[ic1_, 2],localV[ic1_, 2])  
    @test vectorize_(abm,:(l2,l2),p) == :(localV[ic1_, 3],localV[ic1_, 3])  
    @test vectorize_(abm,:(g1,g1),p) == :(globalV[1],globalV[1])  
    @test vectorize_(abm,:(g2,g2),p) == :(globalV[2],globalV[2])  
    @test vectorize_(abm,:(ga1,ga1),p) == :(ga1,ga1)  
    @test vectorize_(abm,:(ga2,ga2),p) == :(ga2,ga2)
    @test vectorize_(abm,:(id,id),p) == :(identityV[ic1_,1],identityV[ic1_,1])  
    @test vectorize_(abm,:(id1,id1),p) == :(identityV[ic1_,2],identityV[ic1_,2])  
    @test vectorize_(abm,:(id2,id2),p) == :(identityV[ic1_,3],identityV[ic1_,3])  
    # @test vectorize_(abm,:(m1,m1),p) == :(mediumV[ic1_,1],mediumV[ic1_,1])  
    # @test vectorize_(abm,:(m2,m2),p) == :(mediumV[ic1_,2],mediumV[ic1_,2])  

    @test vectorize_(abm,:(x.new,x.new),p) == :(localVCopy[ic1_, 1],localVCopy[ic1_, 1])  
    @test vectorize_(abm,:(l1.new,l1.new),p) == :(localVCopy[ic1_, 2],localVCopy[ic1_, 2])  
    @test vectorize_(abm,:(l2.new,l2.new),p) == :(localVCopy[ic1_, 3],localVCopy[ic1_, 3])  
    @test vectorize_(abm,:(g1.new,g1.new),p) == :(globalVCopy[1],globalVCopy[1])  
    @test vectorize_(abm,:(g2.new,g2.new),p) == :(globalVCopy[2],globalVCopy[2])  
    @test vectorize_(abm,:(ga1[1].new,ga1[1].new),p) == :(ga1_Copy[1],ga1_Copy[1])  
    @test vectorize_(abm,:(ga2[1].new,ga2[1].new),p) == :(ga2_Copy[1],ga2_Copy[1])
    @test vectorize_(abm,:(id.new,id.new),p) == :(identityVCopy[ic1_,1],identityVCopy[ic1_,1])  
    @test vectorize_(abm,:(id1.new,id1.new),p) == :(identityVCopy[ic1_,2],identityVCopy[ic1_,2])  
    @test vectorize_(abm,:(id2.new,id2.new),p) == :(identityVCopy[ic1_,3],identityVCopy[ic1_,3])  
    # @test vectorize_(abm,:(m1.new,m1.new),p) == :(mediumVCopy[ic1_,1],mediumVCopy[ic1_,1])  
    # @test vectorize_(abm,:(m2.new,m2.new),p) == :(mediumVCopy[ic1_,2],mediumVCopy[ic1_,2])  

    # @test vectorize_(abm,:(∇(x)),p, op=:∇,index=[[-1,0,0],[0,0,0],[+1,0,0]],factor=[1,1,1],opF=:(X/2)) ==
    #     :(((localV[ic1_ + -1, 1] + localV[ic1_, 1]) + localV[ic1_ + 1, 1]) / 2)

    # @test vectorize_(abm,:(∇(x)),p, op=:∇,nargs=1) == :(∇(x))
    # @test vectorize_(abm,:(∇(x)),p, op=:∇,nargs=1,addArgs=[:dt]) == :(∇(x,dt))
    # @test vectorize_(abm,:(∇(x)),p, op=:∇,nargs=1,opF=:g) == :(g(x))

end