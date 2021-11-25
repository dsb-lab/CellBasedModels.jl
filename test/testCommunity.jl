@testset "community" begin

    #Create community
    @test_nowarn begin
        m = @agent(
            0,
            
            [v,l,i]::Local,
            g::Global,
            ga::GlobalArray,
            
            Equation = v̇ = 34*dt ,
            UpdateLocal = l += 1,
            UpdateGlobal = begin
                g += Normal(1,2) + Normal(1,2) + Uniform(1,2) 
                ga[3,2] += 3
            end,
            UpdateInteraction = i += 1,
            UpdateLocalInteraction = i += 1
        )                

        m = compile(m)

        com = Community(m)
        com = Community(m,N=30)
    end

    #Get variables
    @test_nowarn begin
        m = @agent(
            2,
            
            [id1,id2,id3]::Identity,
            [l1,l2,l3]::Local,
            [g1,g2,g3]::Global,
            [ga1,ga2,ga3]::GlobalArray,
            [m1,m2]::Medium,

            Boundary = BoundaryFlat(2,Periodic(),Periodic())
        )                

        m = compile(m)

        com = Community(m,N=10,mediumN=[10,10])

        com.declaredSymbols_
        com.t
        com.N
        com.id1
        com.id2
        com.id3
        com.l1
        com.l2
        com.l3
        com.g1
        com.g2
        com.g3
        com.ga1
        com.ga2
        com.ga3
        com.simulationBox
        com.radiusInteraction
    end

    #Get variables
    @test_nowarn begin
        m = @agent(
            2,
            
            [id1,id2,id3]::Identity,
            [l1,l2,l3]::Local,
            [g1,g2,g3]::Global,
            [ga1,ga2,ga3]::GlobalArray,
            [m1,m2,m3]::Medium,

            Boundary = BoundaryFlat(2,Periodic(),Periodic())
        )                

        m = compile(m)

        com = Community(m,N=10,mediumN=[2,2])

        com.id1[1] = 1
        com.id2[1] = 2
        com.id3[1] = 3
        com.l1[1] = 1
        com.l2[1] = 2
        com.l3[1] = 3
        com.ga1 = ones(2,2)
        com.ga2 = 2*ones(2,2)
        com.ga3 = 3*ones(2,2)
        com.g1 = 1
        com.g2 = 2
        com.g3 = 3
        com.m1[1,1] = 1
        com.m2[1,1] = 2
        com.m3[1,1] = 3
        com.simulationBox = [0. 1.;0. 1.]
        com.radiusInteraction = [0.,1.]
        com.radiusInteraction = 1.
        
        if com.id1[1] != 1 error() end
        if com.id2[1] != 2 error() end
        if com.id3[1] != 3 error() end
        if com.l1[1] != 1. error() end
        if com.l2[1] != 2. error() end
        if com.l3[1] != 3. error() end
        if com.ga1[1,1] != 1. error() end
        if com.ga2[1,1] != 2. error() end
        if com.ga3[1,1] != 3. error() end
        if com.g1 != 1. error() end
        if com.g2 != 2. error() end
        if com.g3 != 3. error() end
        if com.m1[1,1] != 1. error() end
        if com.m2[1,1] != 2. error() end
        if com.m3[1,1] != 3. error() end

        com.id1 .= 1
        com.id2 .= 2
        com.id3 .= 3
        com.l1 .= 1
        com.l2 .= 2
        com.l3 .= 3
        com.ga1 .= 4
        com.ga2 .= 5
        com.ga3 .= 6
        com.m1 .= 1
        com.m2 .= 2
        com.m3 .= 3

        if com.id1 != 1*ones(com.N) error() end
        if com.id2 != 2*ones(com.N) error() end
        if com.id3 != 3*ones(com.N) error() end
        if com.l1 != 1. *ones(com.N) error() end
        if com.l2 != 2. *ones(com.N) error() end
        if com.l3 != 3. *ones(com.N) error() end
        if com.ga1 != 4. *ones(2,2) error() end
        if com.ga2 != 5. *ones(2,2) error() end
        if com.ga3 != 6. *ones(2,2) error() end
        if com.m1 != 1. *ones(4,4) error() end
        if com.m2 != 2. *ones(4,4) error() end
        if com.m3 != 3. *ones(4,4) error() end
    end

    @test_throws ErrorException begin
        m = @agent(0) 
        m = compile(m)
        com = Community(m,N=10)

        com.id = 1
    end

    @test_throws MethodError begin
        m = @agent(0) 
        m = compile(m)
        com = Community(m,N=10)

        com.id = [1]
    end

    @test_throws ErrorException begin
        m = @agent(0) 
        m = compile(m)
        com = Community(m,N=10)

        com.id = 1
    end

    @test_throws MethodError begin
        m = @agent(0) 
        m = compile(m)
        com = Community(m,N=10)

        com.id = [1]
    end

    @test_throws ErrorException begin
        m = @agent(0,ga::GlobalArray) 
        m = compile(m)
        com = Community(m,N=10)

        com.ga = 1
    end

    #initialisers
    m = @agent 3
    mo = compile(m)
    f(x) = sqrt(sum(x.^2)) < 10

    @test_nowarn initialiseCommunityCompactHexagonal(mo,[-10 10;-10 10;-10 10],.5)
    @test_nowarn initialiseCommunityCompactHexagonal(mo,[-10 10;-10 10;-10 10],.5,fExtrude = f)
    @test_nowarn initialiseCommunityCompactCubic(mo,[-10 10;-10 10;-10 10],.5)
    @test_nowarn initialiseCommunityCompactCubic(mo,[-10 10;-10 10;-10 10],.5,fExtrude = f)

end