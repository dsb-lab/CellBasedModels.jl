@testset "SimulationSpace Free" begin

    @test hasmethod(AgentBasedModels.arguments_!,(AgentBasedModels.Program_,Agent,SimulationFree,String))
    @test hasmethod(AgentBasedModels.loop_,(AgentBasedModels.Program_,Agent,SimulationFree,Expr,String))

    @test AgentBasedModels.arguments_!(AgentBasedModels.Program_(),@agent(cell),SimulationFree(),"gpu") == Nothing
    
    @test_nowarn begin
        
        m = @agent(
            cell,

            [l1,l2]::Local,
            [i1,i2]::Identity,

            UpdateLocalInteraction = begin
                if sqrt((l1₂-l1₁)^2+(l2₂-l2₁)^2) < 5
                    l1 += 1
                end
            end
        )
        
        s = SimulationFree()

        m = compile(m,s)
    end

    m = @agent(
        cell,

        [l1,l2,intLocal,int]::Local,
        [i1,i2]::Identity,

        Equation = begin
            nothing
        end,

        UpdateInteraction = begin
            if sqrt((l1₂-l1₁)^2+(l2₂-l2₁)^2) < 5
                int += 1
            end
        end,

        UpdateLocalInteraction = begin
            if sqrt((l1₂-l1₁)^2+(l2₂-l2₁)^2) < 5
                intLocal += 1
            end
        end
    )
    s = SimulationFree()
    m = compile(m,s)

    @test begin
        com = Community(m,N=4)
        com.l1 = [1,1,0,0]
        com.l2 = [0,1,1,0]

        comt = m.evolve(com,dt=0.1,tMax=1)
        comt[1].int == [4,4,4,4] 
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

@testset "SimulationSpace Grid" begin

    @test hasmethod(SimulationGrid,(Agent, Array{<:Any,1}, Union{<:Real,Array{<:Real,1}}))
    @test hasmethod(AgentBasedModels.arguments_!,(AgentBasedModels.Program_, Agent, SimulationGrid, String))
    @test hasmethod(AgentBasedModels.loop_,(AgentBasedModels.Program_, Agent, SimulationGrid, Expr, String))

    m = @agent cell [x,y,z,w]::Local;
    @test_throws ErrorException SimulationGrid(m,[(:x,2.,1.)],1)
    @test_throws ErrorException SimulationGrid(m,[(:g,1.,2.)],1)
    @test_throws ErrorException SimulationGrid(m,[(:x,1.,2.),(:x,1.,2.)],1)
    @test_throws ErrorException SimulationGrid(m,[(:x,1.,2.),(:y,1.,2.),(:z,1.,2.),(:w,1.,2.)],1)
    @test_throws ErrorException SimulationGrid(m,[(:x,1.,2.),(:y,1.,2.),(:z,1.,2.),(:w,1.,2.)],[1,2])

    @test_nowarn SimulationGrid(m,[(:x,0.,1.),(:y,0.,2.),(:z,0.,3.)],1)
    @test_nowarn SimulationGrid(m,[(:x,0.,1.),(:y,0.,2.),(:z,0.,3.)],[1.,2.,3.])
    @test_nowarn SimulationGrid(m,[Bound(:x,0.,1.),Periodic(:y,0.,2.),Bound(:z,0.,3.)],5.)

    nn = SimulationGrid(m,[(:x,0.,1.),(:y,0.,2.),(:z,0.,3.)],1.)
    @test nn.dim == 3
    @test nn.n == 3*4*5
    @test nn.axisSize == [3,4,5]
    @test nn.cumSize == [1,3,12] 

    @test begin
        xx = []
        for x in -2.:1.:2.
            push!(xx,AgentBasedModels.position2gridVectorPosition_(x,-1.5,1.,5))
        end 
        xx == Array(1:5)
    end

    @test begin        
        xx = []
        for y in -3.:1.:3.
            for x in -2.:1.:2.
                push!(xx,AgentBasedModels.position2gridVectorPosition_(x,-1.5,1.,5,y,-2.5,1.,7))
            end 
        end 
        xx == Array(1:5*7)
    end

    @test begin
        xx = []
        for z in -4.:1.:4.
            for y in -3.:1.:3.
                for x in -2.:1.:2.
                    push!(xx,AgentBasedModels.position2gridVectorPosition_(x,-1.5,1.,5,y,-2.5,1.,7,z,-3.5,1.,9))
                end 
            end 
        end
        xx == Array(1:5*7*9)
    end

    @test begin
        xx = []
        for x in 1:3
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour_(1,x,5,false))
        end 
        xx == [-1,1,2]
    end

    @test begin
        xx = []
        for x in 1:3
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour_(2,x,5,false))
        end 
        xx == [1,2,3]
    end

    @test begin
        xx = []
        for x in 1:3
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour_(2,x,5,true))
        end 
        xx == [4,2,3]
    end

    @test begin
        xx = []
        for x in 1:3
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour_(4,x,5,true))
        end 
        xx == [3,4,2]
    end

    @test begin
        xx = []
        for x in 1:9
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour_(1,x,5,false,7,false))
        end 
        xx == [-1,-1,-1,-1,1,2,-1,6,7]
    end

    @test begin
        xx = []
        for x in 1:9
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour_(7,x,5,false,7,false))
        end 
        xx == [1,2,3,6,7,8,11,12,13]
    end

    @test begin
        xx = []
        for x in 1:9
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour_(25,x,5,false,5,false))
        end 
        xx == [19,20,-1,24,25,-1,-1,-1,-1]
    end

    @test begin
        xx = []
        for x in 1:9
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour_(2,x,5,true,7,false))
        end 
        xx == [-1,-1,-1,4,2,3,9,7,8]
    end

    @test begin
        xx = []
        for x in 1:9
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour_(4,x,5,true,7,false))
        end 
        xx == [-1,-1,-1,3,4,2,8,9,7]
    end

    @test begin
        xx = []
        for x in 1:9
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour_(6,x,5,false,7,true))
        end 
        xx == [-1,26,27,-1,6,7,-1,11,12]
    end

    @test begin
        xx = []
        for x in 1:9
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour_(19,x,5,true,5,true))
        end 
        xx == [13,14,12,18,19,17,8,9,7]
    end

    @test begin
        xx = []
        for x in 1:27
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour_(1,x,5,false,5,false,5,false))
        end 
        xx == [-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,1,2,-1,6,7,-1,-1,-1,-1,26,27,-1,31,32]
    end

    @test begin
        xx = []
        for x in 1:27
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour_(125,x,5,false,5,false,5,false))
        end 
        xx == [94,95,-1,99,100,-1,-1,-1,-1,119,120,-1,124,125,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1]
    end

    @test begin
        xx = []
        for x in 1:27
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour_(32,x,5,false,5,false,5,false))
        end 
        xx == [1,2,3,6,7,8,11,12,13,26,27,28,31,32,33,36,37,38,51,52,53,56,57,58,61,62,63]
    end

    @test begin
        xx = []
        for x in 1:27
            push!(xx,AgentBasedModels.gridVectorPositionNeighbour_(32,x,5,true,5,true,5,true))
        end 
        xx == [94,92,93,84,82,83,89,87,88,44,42,43,34,32,33,39,37,38,69,67,68,59,57,58,64,62,63]
    end

    @test_nowarn AgentBasedModels.arguments_!(AgentBasedModels.Program_(),m,nn,"cpu")

    for platform in testplatforms

        m = @agent(
            cell,

            [l1,l2,l3,intLocal,int]::Local,
            [i1,i2]::Identity,

            Equation = begin
                d_l2 = 0.
            end,

            UpdateInteraction = begin
                if abs(l1₁ - l1₂) <= 4.5
                    int += 1
                end
            end,

            UpdateLocalInteraction = begin
                intLocal += 1
            end,
        )

        s = SimulationGrid(m,[(:l1,-10,10)],[5.])
        mo = compile(m,s,platform=platform)
        #println(mo.program)
        @test begin
            com = Community(mo,N=12)
            com.l1 .= [-11,-7,-2,2,7,11,-11,-7,-2,2,7,11]
            com.l2 .= 0

            comt = mo.evolve(com,dt=0.1,tMax=1)
            (comt[1].intLocal == [4.,6.,6.,6.,6.,4.,4.,6.,6.,6.,6.,4.]) && (comt[1].int == [4.,4.,4.,4.,4.,4.,4.,4.,4.,4.,4.,4.])
        end        

        s = SimulationGrid(m,[Periodic(:l1,-10,10)],[5.])
        mo = compile(m,s,platform=platform)
        #println(mo.program)
        @test begin
            com = Community(mo,N=4)
            com.l1 .= [-7,-2,2,7]
            com.l2 .= 0

            comt = mo.evolve(com,dt=0.1,tMax=1)
            comt[1].intLocal == [3.,3.,3.,3.]
        end        

        m = @agent(
            cell,

            [l1,l2,l3,intLocal,int]::Local,
            [i1,i2]::Identity,

            Equation = begin
                d_l2 = 0.
            end,

            UpdateInteraction = begin
                if abs(l2₁ - l2₂) <= 4.5
                    int += 1
                end
            end,

            UpdateLocalInteraction = begin
                intLocal += 1
            end,
        )

        s = SimulationGrid(m,[(:l1,-20,20),(:l2,-10,10)],[5.,5.])
        mo = compile(m,s,platform=platform)
        #println(mo.program)
        @test begin
            com = Community(mo,N=12)
            com.l2 .= [-11,-7,-2,2,7,11,-11,-7,-2,2,7,11]
            com.l1 .= 0

            comt = mo.evolve(com,dt=0.1,tMax=1)
            (comt[1].intLocal == [4.,6.,6.,6.,6.,4.,4.,6.,6.,6.,6.,4.]) && (comt[1].int == [4.,4.,4.,4.,4.,4.,4.,4.,4.,4.,4.,4.])
        end        

        s = SimulationGrid(m,[Bound(:l1,-20,20),Periodic(:l2,-10,10)],[5.,5.])
        mo = compile(m,s,platform=platform)
        #println(mo.program)
        @test begin
            com = Community(mo,N=4)
            com.l2 .= [-7,-2,2,7]
            com.l1 .= 0

            comt = mo.evolve(com,dt=0.1,tMax=1)
            comt[1].intLocal == [3.,3.,3.,3.]
        end        

        m = @agent(
            cell,

            [l1,l2,l3,intLocal,int]::Local,
            [i1,i2]::Identity,

            Equation = begin
                d_l2 = 0.
            end,

            UpdateInteraction = begin
                if abs(l3₁ - l3₂) <= 4.5
                    int += 1
                end
            end,

            UpdateLocalInteraction = begin
                intLocal += 1
            end,
        )

        s = SimulationGrid(m,[(:l1,-20,20),(:l2,-10,10),(:l3,-10,10)],[5.,5.,5.])
        mo = compile(m,s,platform=platform)
        #println(mo.program)
        @test begin
            com = Community(mo,N=12)
            com.l3 .= [-11,-7,-2,2,7,11,-11,-7,-2,2,7,11]

            comt = mo.evolve(com,dt=0.1,tMax=1)
            (comt[1].intLocal == [4.,6.,6.,6.,6.,4.,4.,6.,6.,6.,6.,4.]) && (comt[1].int == [4.,4.,4.,4.,4.,4.,4.,4.,4.,4.,4.,4.])
        end        

        s = SimulationGrid(m,[(:l1,-10,10),(:l2,-10,10),Periodic(:l3,-10,10)],[5.,5.,5.])
        mo = compile(m,s,platform=platform)
        #println(mo.program)
        @test begin
            com = Community(mo,N=4)
            com.l3 .= [-7,-2,2,7]

            comt = mo.evolve(com,dt=0.1,tMax=1)
            comt[1].intLocal == [3.,3.,3.,3.]
        end        

    end

end