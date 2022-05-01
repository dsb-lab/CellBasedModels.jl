@testset "Neighbors Full" begin

    @test hasmethod(AgentBasedModels.argumentsFull_!,(AgentBasedModels.Program_,String))
    @test hasmethod(AgentBasedModels.loopFull_,(AgentBasedModels.Program_,Expr,String))

    @test AgentBasedModels.argumentsFull_!(AgentBasedModels.Program_(@agent(3)),"gpu") == Nothing
    
    @test_nowarn begin
        
        m = @agent(
            0,

            [l1,l2]::Local,
            [i1,i2]::Identity,

            UpdateInteraction = begin
                if sqrt((l1.j-l1.i)^2+(l2.j-l2.i)^2) < 5
                    l1.i += 1
                end
            end
        )
        m = compile(m)
    end

    m = @agent(
        0,

        [l1,l2]::Local,
        [intLocal,int]::LocalInteraction,
        [i1,i2]::IdentityInteraction,

        UpdateVariable = begin
            nothing
        end,

        UpdateInteraction = begin
            if sqrt((l1.j-l1.i)^2+(l2.j-l2.i)^2) < 5
                int.i += 1
            end
        end,

        UpdateInteraction = begin
            if sqrt((l1.j-l1.i)^2+(l2.j-l2.i)^2) < 5
                intLocal.i += 1
            end
        end
    )
    # print(m)
    m = compile(m)

    @test begin
        com = Community(m,N=4)
        com.l1 = [1,1,0,0]
        com.l2 = [0,1,1,0]

        comt = m.evolve(com,dt=0.1,tMax=1)
        comt[2].int == [4,4,4,4] 
    end    

    @test begin
        com = Community(m,N=4)
        com.l1 = [1,1,0,0]
        com.l2 = [0,1,1,0]

        comt = m.evolve(com,dt=0.1,tMax=1)
        comt[1].intLocal == [4,4,4,4] 
    end    

    @test begin
        com = Community(m,N=4)
        com.l1 = [7,7,0,0]
        com.l2 = [0,7,7,0]

        comt = m.evolve(com,dt=0.1,tMax=1)
        comt[1].int == [1,1,1,1] 
    end    

    @test begin
        com = Community(m,N=4)
        com.l1 = [7,7,0,0]
        com.l2 = [0,7,7,0]

        comt = m.evolve(com,dt=0.1,tMax=1)
        comt[1].intLocal == [1,1,1,1] 
    end    

end