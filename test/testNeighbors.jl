@testset "Neighbors Full" begin

    @test hasmethod(AgentBasedModels.argumentsFull_!,(AgentBasedModels.Program_,String))
    @test hasmethod(AgentBasedModels.loopFull_,(AgentBasedModels.Program_,Expr,String))

    @test AgentBasedModels.argumentsFull_!(AgentBasedModels.Program_(@agent(3)),"gpu") == Nothing
    
    @test_nowarn begin
        
        m = @agent(
            0,

            [l1,l2]::Local,
            [i1,i2]::Identity,

            UpdateLocalInteraction = begin
                if sqrt((l1_j-l1_i)^2+(l2_j-l2_i)^2) < 5
                    l1 += 1
                end
            end
        )
        m = compile(m)
    end

    m = @agent(
        0,

        [l1,l2,intLocal,int]::Local,
        [i1,i2]::Identity,

        Equation = begin
            nothing
        end,

        UpdateInteraction = begin
            if sqrt((l1_j-l1_i)^2+(l2_j-l2_i)^2) < 5
                int_i += 1
            end
        end,

        UpdateLocalInteraction = begin
            if sqrt((l1_j-l1_i)^2+(l2_j-l2_i)^2) < 5
                intLocal_i += 1
            end
        end
    )
    m = compile(m,debug=false)

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

@testset "Neighbors Grid" begin

    @test hasmethod(AgentBasedModels.argumentsGrid_!,(AgentBasedModels.Program_, String))
    @test hasmethod(AgentBasedModels.loopGrid_,(AgentBasedModels.Program_, Expr, String))
    
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

    m = @agent 3 [w]::Local;

    @test_nowarn AgentBasedModels.argumentsGrid_!(AgentBasedModels.Program_(m),"cpu")

    mo = compile(m,neighbors="grid",debug=false)
    @test_throws ErrorException begin #Error if box not specified
        com = Community(mo,N=12)
        com.x .= [-11,-7,-2,2,7,11,-11,-7,-2,2,7,11]
        com.y .= 0

        comt = mo.evolve(com,dt=0.1,tMax=1)
    end

    for platform in testplatforms

        #Check 1D
        m = @agent(
            1,

            [intLocal,int]::Local,

            Equation = begin
                d_l2 = 0.
            end,

            UpdateInteraction = begin
                if abs(x_i - x_j) <= .9
                    int += 1
                end
            end,

            UpdateLocalInteraction = begin
                intLocal += 1
            end,
        )

        mo = compile(m,platform=platform,neighbors="grid",debug=false)
        # println(mo.program)
        @test begin
            com = Community(mo,N=4)
            com.x .= [-1.5,-.5,.5,1.5]
            com.simulationBox = [-1. 1.]
            com.radiusInteraction = 1.1

            comt = mo.evolve(com,dt=0.1,tMax=1)
            (comt[1].intLocal == [2,3,3,2]) && (comt[1].int == [1,1,1,1])
        end   

        #Check 2D
        m = @agent(
            2,

            [intLocal,int]::Local,

            Equation = begin
                d_l2 = 0.
            end,

            UpdateInteraction = begin
                if sqrt((x_i - x_j)^2+(y_i - y_j)^2) <= 1.1
                    int += 1
                end
            end,

            UpdateLocalInteraction = begin
                intLocal += 1
            end,
        )

        mo = compile(m,platform=platform,neighbors="grid",debug=false)
        # println(mo.program)
        @test begin
            com = Community(mo,N=16)
            com.x .= [-1.5,-.5,.5,1.5,-1.5,-.5,.5,1.5,-1.5,-.5,.5,1.5,-1.5,-.5,.5,1.5]
            com.y .= [-1.5,-1.5,-1.5,-1.5,-.5,-.5,-.5,-.5,.5,.5,.5,.5,1.5,1.5,1.5,1.5]
            com.simulationBox = [-1. 1.;-1. 1.]
            com.radiusInteraction = 1.1

            comt = mo.evolve(com,dt=0.1,tMax=1)
            (comt[1].intLocal == [4.,6.,6.,4.,6.,9.,9.,6.,6.,9.,9.,6.,4.,6.,6.,4.]) && (comt[1].int == [3.,4.,4.,3.,4.,5.,5.,4.,4.,5.,5.,4.,3.,4.,4.,3.])
        end                  

        #Check 3D
        m = @agent(
            3,

            [intLocal,int]::Local,

            Equation = begin
                d_l2 = 0.
            end,

            UpdateInteraction = begin
                if sqrt((x_i - x_j)^2+(y_i - y_j)^2+(z_i - z_j)^2) <= 1.1
                    int += 1
                end
            end,

            UpdateLocalInteraction = begin
                intLocal += 1
            end,
        )

        mo = compile(m,platform=platform,neighbors="grid",debug=false)
        # println(mo.program)
        @test begin
            com = Community(mo,N=64)
            intLocal = zeros(64)
            intt = zeros(64)
            for (i,x) in enumerate([-1.5,-.5,.5,1.5])
                for (j,y) in enumerate([-1.5,-.5,.5,1.5])
                    for (k,z) in enumerate([-1.5,-.5,.5,1.5])
                        com.x[i+4*(j-1)+16*(k-1)] = x 
                        com.y[i+4*(j-1)+16*(k-1)] = y 
                        com.z[i+4*(j-1)+16*(k-1)] = z

                        intLocal[i+4*(j-1)+16*(k-1)] = 27.
                        intt[i+4*(j-1)+16*(k-1)] = 7.
                        if abs(x) == 1.5 || abs(y) == 1.5 || abs(z) == 1.5
                            intLocal[i+4*(j-1)+16*(k-1)] = 18.
                            intt[i+4*(j-1)+16*(k-1)] = 6.
                        end
                        if (abs(x) == 1.5 && abs(y) == 1.5) || (abs(x) == 1.5 && abs(z) == 1.5) || (abs(y) == 1.5 && abs(z) == 1.5)
                            intLocal[i+4*(j-1)+16*(k-1)] = 12.
                            intt[i+4*(j-1)+16*(k-1)] = 5.
                        end
                        if abs(x) == 1.5 && abs(y) == 1.5 && abs(z) == 1.5
                            intLocal[i+4*(j-1)+16*(k-1)] = 8.
                            intt[i+4*(j-1)+16*(k-1)] = 4.
                        end
                    end
                end
            end                        
            com.simulationBox = [-1. 1.;-1. 1.;-1. 1]
            com.radiusInteraction = 1.1
            comt = mo.evolve(com,dt=0.1,tMax=1)
            (comt[1].intLocal == intLocal) && (comt[1].int == intt)
        end                  

        #Check 1D Periodic
        m = @agent(
            1,

            [intLocal,int]::Local,

            Equation = begin
                d_l2 = 0.
            end,

            UpdateInteraction = begin
                if abs(x_i - x_j) <= .9
                    int += 1
                end
            end,

            UpdateLocalInteraction = begin
                intLocal += 1
            end,

            Boundary = BoundaryFlat(1,Periodic())
        )

        mo = compile(m,platform=platform,neighbors="grid",debug=false)
        # println(mo.program)
        @test begin
            com = Community(mo,N=4)
            com.x .= [-1.5,-.5,.5,1.5]
            com.simulationBox = [-1.6 1.6]
            com.radiusInteraction = 1.

            comt = mo.evolve(com,dt=0.1,tMax=1)
            (comt[1].intLocal == [3,3,3,3]) && (comt[1].int == [1,1,1,1])
        end   

        #Check 2D Periodic
        m = @agent(
            2,

            [intLocal,int]::Local,

            Equation = begin
                d_l2 = 0.
            end,

            UpdateInteraction = begin
                if sqrt((x_i - x_j)^2+(y_i - y_j)^2) <= 1.1
                    int += 1
                end
            end,

            UpdateLocalInteraction = begin
                intLocal += 1
            end,

            Boundary = BoundaryFlat(2,Periodic())
        )

        mo = compile(m,platform=platform,neighbors="grid",debug=false)
        # println(mo.program)
        @test begin
            com = Community(mo,N=16)
            com.x .= [-1.5,-.5,.5,1.5,-1.5,-.5,.5,1.5,-1.5,-.5,.5,1.5,-1.5,-.5,.5,1.5]
            com.y .= [-1.5,-1.5,-1.5,-1.5,-.5,-.5,-.5,-.5,.5,.5,.5,.5,1.5,1.5,1.5,1.5]
            com.simulationBox = [-2. 2.;-2. 2.]
            com.radiusInteraction = 1.1

            comt = mo.evolve(com,dt=0.1,tMax=1)
            (comt[1].intLocal == [6.,6.,6.,6.,9.,9.,9.,9.,9.,9.,9.,9.,6.,6.,6.,6.]) && (comt[1].int == [3.,4.,4.,3.,4.,5.,5.,4.,4.,5.,5.,4.,3.,4.,4.,3.])
        end                  

        m = @agent(
            2,

            [intLocal,int]::Local,

            Equation = begin
                d_l2 = 0.
            end,

            UpdateInteraction = begin
                if sqrt((x_i - x_j)^2+(y_i - y_j)^2) <= 1.1
                    int += 1
                end
            end,

            UpdateLocalInteraction = begin
                intLocal += 1
            end,

            Boundary = BoundaryFlat(2,Free(),Periodic())
        )

        mo = compile(m,platform=platform,neighbors="grid",debug=false)
        # println(mo.program)
        @test begin
            com = Community(mo,N=16)
            com.x .= [-1.5,-.5,.5,1.5,-1.5,-.5,.5,1.5,-1.5,-.5,.5,1.5,-1.5,-.5,.5,1.5]
            com.y .= [-1.5,-1.5,-1.5,-1.5,-.5,-.5,-.5,-.5,.5,.5,.5,.5,1.5,1.5,1.5,1.5]
            com.simulationBox = [-2. 2.;-2. 2.]
            com.radiusInteraction = 1.1

            comt = mo.evolve(com,dt=0.1,tMax=1)
            (comt[1].intLocal == [6.,9.,9.,6.,6.,9.,9.,6.,6.,9.,9.,6.,6.,9.,9.,6.]) && (comt[1].int == [3.,4.,4.,3.,4.,5.,5.,4.,4.,5.,5.,4.,3.,4.,4.,3.])
        end 

        m = @agent(
            2,

            [intLocal,int]::Local,

            Equation = begin
                d_l2 = 0.
            end,

            UpdateInteraction = begin
                if sqrt((x_i - x_j)^2+(y_i - y_j)^2) <= 1.1
                    int += 1
                end
            end,

            UpdateLocalInteraction = begin
                intLocal += 1
            end,

            Boundary = BoundaryFlat(2,Periodic(),Periodic())
        )

        mo = compile(m,platform=platform,neighbors="grid",debug=false)
        # println(mo.program)
        @test begin
            com = Community(mo,N=16)
            com.x .= [-1.5,-.5,.5,1.5,-1.5,-.5,.5,1.5,-1.5,-.5,.5,1.5,-1.5,-.5,.5,1.5]
            com.y .= [-1.5,-1.5,-1.5,-1.5,-.5,-.5,-.5,-.5,.5,.5,.5,.5,1.5,1.5,1.5,1.5]
            com.simulationBox = [-2. 2.;-2. 2.]
            com.radiusInteraction = 1.1

            comt = mo.evolve(com,dt=0.1,tMax=1)
            (comt[1].intLocal == [9.,9.,9.,9.,9.,9.,9.,9.,9.,9.,9.,9.,9.,9.,9.,9.]) && (comt[1].int == [3.,4.,4.,3.,4.,5.,5.,4.,4.,5.,5.,4.,3.,4.,4.,3.])
        end 

        #Check 3D Periodic
        m = @agent(
            3,

            [intLocal,int]::Local,

            Equation = begin
                d_l2 = 0.
            end,

            UpdateInteraction = begin
                if sqrt((x_i - x_j)^2+(y_i - y_j)^2+(z_i - z_j)^2) <= 1.1
                    int += 1
                end
            end,

            UpdateLocalInteraction = begin
                intLocal += 1
            end,

            Boundary = BoundaryFlat(3,Periodic(),Free(),Free())
        )

        mo = compile(m,platform=platform,neighbors="grid",debug=false)
        # println(mo.program)
        @test begin
            com = Community(mo,N=64)
            intLocal = zeros(64)
            intt = zeros(64)
            for (i,x) in enumerate([-1.5,-.5,.5,1.5])
                for (j,y) in enumerate([-1.5,-.5,.5,1.5])
                    for (k,z) in enumerate([-1.5,-.5,.5,1.5])
                        com.x[i+4*(j-1)+16*(k-1)] = x 
                        com.y[i+4*(j-1)+16*(k-1)] = y 
                        com.z[i+4*(j-1)+16*(k-1)] = z

                        intLocal[i+4*(j-1)+16*(k-1)] = 27.
                        intt[i+4*(j-1)+16*(k-1)] = 7.

                        if (abs(x) == 1.5 && abs(y) == 1.5) || (abs(x) == 1.5 && abs(z) == 1.5) || abs(y) == 1.5 || abs(z) == 1.5
                            intLocal[i+4*(j-1)+16*(k-1)] = 18.
                        end
                        if (abs(y) == 1.5 && abs(z) == 1.5)
                            intLocal[i+4*(j-1)+16*(k-1)] = 12.
                        end

                        if abs(x) == 1.5 || abs(y) == 1.5 || abs(z) == 1.5
                            intt[i+4*(j-1)+16*(k-1)] = 6.
                        end
                        if (abs(x) == 1.5 && abs(y) == 1.5) || (abs(x) == 1.5 && abs(z) == 1.5) || (abs(y) == 1.5 && abs(z) == 1.5)
                            intt[i+4*(j-1)+16*(k-1)] = 5.
                        end
                        if abs(x) == 1.5 && abs(y) == 1.5 && abs(z) == 1.5
                            intt[i+4*(j-1)+16*(k-1)] = 4.
                        end
                    end
                end
            end                        
            com.simulationBox = [-2. 2.;-2. 2.;-2. 2]
            com.radiusInteraction = 1.1
            comt = mo.evolve(com,dt=0.1,tMax=1)
            (comt[1].intLocal == intLocal) && (comt[1].int == intt)
        end                  

        m = @agent(
            3,

            [intLocal,int]::Local,

            Equation = begin
                d_l2 = 0.
            end,

            UpdateInteraction = begin
                if sqrt((x_i - x_j)^2+(y_i - y_j)^2+(z_i - z_j)^2) <= 1.1
                    int += 1
                end
            end,

            UpdateLocalInteraction = begin
                intLocal += 1
            end,

            Boundary = BoundaryFlat(3,Free(),Periodic(),Free())
        )

        mo = compile(m,platform=platform,neighbors="grid",debug=false)
        # println(mo.program)
        @test begin
            com = Community(mo,N=64)
            intLocal = zeros(64)
            intt = zeros(64)
            for (i,x) in enumerate([-1.5,-.5,.5,1.5])
                for (j,y) in enumerate([-1.5,-.5,.5,1.5])
                    for (k,z) in enumerate([-1.5,-.5,.5,1.5])
                        com.x[i+4*(j-1)+16*(k-1)] = x 
                        com.y[i+4*(j-1)+16*(k-1)] = y 
                        com.z[i+4*(j-1)+16*(k-1)] = z

                        intLocal[i+4*(j-1)+16*(k-1)] = 27.
                        intt[i+4*(j-1)+16*(k-1)] = 7.

                        if (abs(x) == 1.5 && abs(y) == 1.5) || (abs(y) == 1.5 && abs(z) == 1.5) || abs(x) == 1.5 || abs(z) == 1.5
                            intLocal[i+4*(j-1)+16*(k-1)] = 18.
                        end
                        if (abs(x) == 1.5 && abs(z) == 1.5)
                            intLocal[i+4*(j-1)+16*(k-1)] = 12.
                        end

                        if abs(x) == 1.5 || abs(y) == 1.5 || abs(z) == 1.5
                            intt[i+4*(j-1)+16*(k-1)] = 6.
                        end
                        if (abs(x) == 1.5 && abs(y) == 1.5) || (abs(x) == 1.5 && abs(z) == 1.5) || (abs(y) == 1.5 && abs(z) == 1.5)
                            intt[i+4*(j-1)+16*(k-1)] = 5.
                        end
                        if abs(x) == 1.5 && abs(y) == 1.5 && abs(z) == 1.5
                            intt[i+4*(j-1)+16*(k-1)] = 4.
                        end
                    end
                end
            end                        
            com.simulationBox = [-2. 2.;-2. 2.;-2. 2]
            com.radiusInteraction = 1.1
            comt = mo.evolve(com,dt=0.1,tMax=1)
            (comt[1].intLocal == intLocal) && (comt[1].int == intt)
        end                  

        m = @agent(
            3,

            [intLocal,int]::Local,

            Equation = begin
                d_l2 = 0.
            end,

            UpdateInteraction = begin
                if sqrt((x_i - x_j)^2+(y_i - y_j)^2+(z_i - z_j)^2) <= 1.1
                    int += 1
                end
            end,

            UpdateLocalInteraction = begin
                intLocal += 1
            end,

            Boundary = BoundaryFlat(3,Free(),Free(),Periodic())
        )

        mo = compile(m,platform=platform,neighbors="grid",debug=false)
        # println(mo.program)
        @test begin
            com = Community(mo,N=64)
            intLocal = zeros(64)
            intt = zeros(64)
            for (i,x) in enumerate([-1.5,-.5,.5,1.5])
                for (j,y) in enumerate([-1.5,-.5,.5,1.5])
                    for (k,z) in enumerate([-1.5,-.5,.5,1.5])
                        com.x[i+4*(j-1)+16*(k-1)] = x 
                        com.y[i+4*(j-1)+16*(k-1)] = y 
                        com.z[i+4*(j-1)+16*(k-1)] = z

                        intLocal[i+4*(j-1)+16*(k-1)] = 27.
                        intt[i+4*(j-1)+16*(k-1)] = 7.

                        if (abs(x) == 1.5 && abs(z) == 1.5) || (abs(y) == 1.5 && abs(z) == 1.5) || abs(x) == 1.5 || abs(y) == 1.5
                            intLocal[i+4*(j-1)+16*(k-1)] = 18.
                        end
                        if (abs(x) == 1.5 && abs(y) == 1.5)
                            intLocal[i+4*(j-1)+16*(k-1)] = 12.
                        end

                        if abs(x) == 1.5 || abs(y) == 1.5 || abs(z) == 1.5
                            intt[i+4*(j-1)+16*(k-1)] = 6.
                        end
                        if (abs(x) == 1.5 && abs(y) == 1.5) || (abs(x) == 1.5 && abs(z) == 1.5) || (abs(y) == 1.5 && abs(z) == 1.5)
                            intt[i+4*(j-1)+16*(k-1)] = 5.
                        end
                        if abs(x) == 1.5 && abs(y) == 1.5 && abs(z) == 1.5
                            intt[i+4*(j-1)+16*(k-1)] = 4.
                        end
                    end
                end
            end                        
            com.simulationBox = [-2. 2.;-2. 2.;-2. 2]
            com.radiusInteraction = 1.1
            comt = mo.evolve(com,dt=0.1,tMax=1)
            (comt[1].intLocal == intLocal) && (comt[1].int == intt)
        end                  

        m = @agent(
            3,

            [intLocal,int]::Local,

            Equation = begin
                d_l2 = 0.
            end,

            UpdateInteraction = begin
                if sqrt((x_i - x_j)^2+(y_i - y_j)^2+(z_i - z_j)^2) <= 1.1
                    int += 1
                end
            end,

            UpdateLocalInteraction = begin
                intLocal += 1
            end,

            Boundary = BoundaryFlat(3,Periodic(),Periodic(),Periodic())
        )

        mo = compile(m,platform=platform,neighbors="grid",debug=false)
        # println(mo.program)
        @test begin
            com = Community(mo,N=64)
            intLocal = zeros(64)
            intt = zeros(64)
            for (i,x) in enumerate([-1.5,-.5,.5,1.5])
                for (j,y) in enumerate([-1.5,-.5,.5,1.5])
                    for (k,z) in enumerate([-1.5,-.5,.5,1.5])
                        com.x[i+4*(j-1)+16*(k-1)] = x 
                        com.y[i+4*(j-1)+16*(k-1)] = y 
                        com.z[i+4*(j-1)+16*(k-1)] = z

                        intLocal[i+4*(j-1)+16*(k-1)] = 27.
                        intt[i+4*(j-1)+16*(k-1)] = 7.

                        if abs(x) == 1.5 || abs(y) == 1.5 || abs(z) == 1.5
                            intt[i+4*(j-1)+16*(k-1)] = 6.
                        end
                        if (abs(x) == 1.5 && abs(y) == 1.5) || (abs(x) == 1.5 && abs(z) == 1.5) || (abs(y) == 1.5 && abs(z) == 1.5)
                            intt[i+4*(j-1)+16*(k-1)] = 5.
                        end
                        if abs(x) == 1.5 && abs(y) == 1.5 && abs(z) == 1.5
                            intt[i+4*(j-1)+16*(k-1)] = 4.
                        end
                    end
                end
            end                        
            com.simulationBox = [-2. 2.;-2. 2.;-2. 2]
            com.radiusInteraction = 1.1
            comt = mo.evolve(com,dt=0.1,tMax=1)
            (comt[1].intLocal == intLocal) && (comt[1].int == intt)
        end                  


    end

end