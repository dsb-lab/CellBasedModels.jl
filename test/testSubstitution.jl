@testset "Substitution" begin

    substitution = AgentBasedModels.substitution

    abm = @agent(1,
            [l1,l2]::Local,
            [g1,g2]::Global,
            [ga1,ga2]::GlobalArray,
            [id1,id2]::Identity,
            [m1,m2]::Medium)
    s = SimulationFree(abm,box=[(:x,0,1)],medium=[MediumFlat("Dirichlet",10)])
    p = AgentBasedModels.Program_(abm,s)

    @test substitution(:(x,x),p) == :(localV[ic1_, 1],localV[ic1_, 1])  
    @test substitution(:(l1,l1),p) == :(localV[ic1_, 2],localV[ic1_, 2])  
    @test substitution(:(l2,l2),p) == :(localV[ic1_, 3],localV[ic1_, 3])  
    @test substitution(:(g1,g1),p) == :(globalV[1],globalV[1])  
    @test substitution(:(g2,g2),p) == :(globalV[2],globalV[2])  
    @test substitution(:(ga1,ga1),p) == :(ga1,ga1)  
    @test substitution(:(ga2,ga2),p) == :(ga2,ga2)
    @test substitution(:(agentId,agentId),p) == :(identityV[ic1_,1],identityV[ic1_,1])  
    @test substitution(:(id1,id1),p) == :(identityV[ic1_,2],identityV[ic1_,2])  
    @test substitution(:(id2,id2),p) == :(identityV[ic1_,3],identityV[ic1_,3])  
    @test substitution(:(m1,m1),p) == :(mediumV[ic1_,1],mediumV[ic1_,1])  
    @test substitution(:(m2,m2),p) == :(mediumV[ic1_,2],mediumV[ic1_,2])  

    @test substitution(:(x_new,x_new),p,post="_new",addName="Copy") == :(localVCopy[ic1_, 1],localVCopy[ic1_, 1])  
    @test substitution(:(l1_new,l1_new),p,post="_new",addName="Copy") == :(localVCopy[ic1_, 2],localVCopy[ic1_, 2])  
    @test substitution(:(l2_new,l2_new),p,post="_new",addName="Copy") == :(localVCopy[ic1_, 3],localVCopy[ic1_, 3])  
    @test substitution(:(g1_new,g1_new),p,post="_new",addName="Copy") == :(globalVCopy[1],globalVCopy[1])  
    @test substitution(:(g2_new,g2_new),p,post="_new",addName="Copy") == :(globalVCopy[2],globalVCopy[2])  
    @test substitution(:(ga1_new,ga1_new),p,post="_new",addName="Copy") == :(ga1Copy,ga1Copy)  
    @test substitution(:(ga2_new,ga2_new),p,post="_new",addName="Copy") == :(ga2Copy,ga2Copy)
    @test substitution(:(agentId_new,agentId_new),p,post="_new",addName="Copy") == :(identityVCopy[ic1_,1],identityVCopy[ic1_,1])  
    @test substitution(:(id1_new,id1_new),p,post="_new",addName="Copy") == :(identityVCopy[ic1_,2],identityVCopy[ic1_,2])  
    @test substitution(:(id2_new,id2_new),p,post="_new",addName="Copy") == :(identityVCopy[ic1_,3],identityVCopy[ic1_,3])  
    @test substitution(:(m1_new,m1_new),p,post="_new",addName="Copy") == :(mediumVCopy[ic1_,1],mediumVCopy[ic1_,1])  
    @test substitution(:(m2_new,m2_new),p,post="_new",addName="Copy") == :(mediumVCopy[ic1_,2],mediumVCopy[ic1_,2])  

    @test substitution(:(∇(x)),p, op=:∇,index=[[-1,0,0],[0,0,0],[+1,0,0]],factor=[1,1,1],opF=:(X/2)) ==
        :(((localV[ic1_ + -1, 1] + localV[ic1_, 1]) + localV[ic1_ + 1, 1]) / 2)

    @test substitution(:(∇(x)),p, op=:∇,nargs=1) == :(∇(x))
    @test substitution(:(∇(x)),p, op=:∇,nargs=1,addArgs=[:dt]) == :(∇(x,dt))
    @test substitution(:(∇(x)),p, op=:∇,nargs=1,opF=:g) == :(g(x))

end